// functions/src/index.ts
import {initializeApp} from "firebase-admin/app";
import {getMessaging} from "firebase-admin/messaging";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

import {
  onDocumentCreated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import * as functions from "firebase-functions/v1";

import {ImageAnnotatorClient} from "@google-cloud/vision";
import {HttpsError} from "firebase-functions/v1/https";

import type {DocumentSnapshot} from "firebase-admin/firestore";

/* ──────────────────────── tipos ──────────────────────── */
interface CreatedEvent<T = DocumentSnapshot> {
  data?: T;
  params: Record<string, string>;
}

interface WrittenEvent<T = DocumentSnapshot> {
  data?: {
    before?: T;
    after?: T;
  };
  params: Record<string, string>;
}

/* ──────────────────────── init ──────────────────────── */
initializeApp();

/* ──────────────────────── textos ──────────────────────── */
const titles: Record<string, string> = {
  join_request: "Solicitud de unión",
  invitation: "Invitación a un plan",
  invitation_accepted: "Invitación aceptada",
  invitation_rejected: "Invitación rechazada",
  join_accepted: "Solicitud aceptada",
  join_rejected: "Solicitud rechazada",
  follow_request: "Solicitud de follow",
  follow_accepted: "Follow aceptado",
  follow_rejected: "Follow rechazado",
  new_plan_published: "Nuevo plan publicado",
  plan_chat_message: "Nuevo comentario",
  welcome: "Bienvenido a Plan",
  plan_left: "Participante ha abandonado",
  removed_from_plan: "Has sido eliminado de un plan",
  special_plan_deleted: "Plan especial eliminado",
  special_plan_left: "Salida de plan especial",
};

/* ──────────────────────── visión ──────────────────────── */
const vision = new ImageAnnotatorClient();

/* ──────────────────── detección explícitos ──────────────────── */
export const detectExplicitContent = functions
  .region("europe-west1")
  .https.onCall(async (data) => {
    const base64 = data?.image as string | undefined;
    if (!base64) {
      throw new HttpsError("invalid-argument", "Image data missing");
    }
    const [result] = await vision.safeSearchDetection(
      Buffer.from(base64, "base64")
    );
    const ann = result.safeSearchAnnotation;
    if (!ann) return {explicit: false};
    const isExplicit = [ann.adult, ann.violence, ann.racy].some(
      (v) => v === "LIKELY" || v === "VERY_LIKELY"
    );
    return {explicit: isExplicit};
  });

/* ────────────────────── notificaciones ────────────────────── */
export const sendPushOnNotification = onDocumentCreated(
  {region: "europe-west1", document: "/notifications/{id}"},
  async (event: CreatedEvent) => {
    const n = event.data?.data();
    if (!n || n.senderId === n.receiverId) return;

    const db = getFirestore();
    const receiverRef = db.doc(`users/${n.receiverId}`);
    const recvSnap = await receiverRef.get();
    const recvTokens: string[] = recvSnap.get("tokens") ?? [];
    if (recvTokens.length === 0) return;

    const sendSnap = await db.doc(`users/${n.senderId}`).get();
    const sendTokens: string[] = sendSnap.get("tokens") ?? [];

    let tokens = recvTokens.filter((t) => !sendTokens.includes(t));
    if (tokens.length === 0) tokens = recvTokens;

    const notif = {
      title: titles[n.type] ?? "Notificación",
      body:
        n.type === "special_plan_deleted" ?
          `${n.senderName} ha eliminado el plan especial` :
          n.type === "special_plan_left" ?
            `${n.senderName} ha decidido abandonar el plan especial` :
            n.senderName ?
              `${n.senderName} • ${n.planType ?? ""}` :
              "Abre la app para más detalles",
    };

    const resp = await getMessaging().sendEachForMulticast({
      tokens,
      notification: notif,
      android: {notification: {channelId: "plan_high"}},
      data: {
        type: n.type,
        planId: n.planId ?? "",
        senderId: n.senderId ?? "",
      },
    });

    const invalid: string[] = [];
    resp.responses.forEach((r, i) => {
      if (
        !r.success &&
        r.error?.code === "messaging/registration-token-not-registered"
      ) {
        invalid.push(tokens[i]);
      }
    });

    if (invalid.length) {
      await receiverRef.update({
        tokens: FieldValue.arrayRemove(...invalid),
      });
    }
  }
);

/* ────────────────── limpieza datos usuario ────────────────── */
export const cleanupUserData = functions
  .region("europe-west1")
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;
    const db = getFirestore();
    try {
      await db.doc(`users/${uid}`).delete();
    } catch (e: unknown) {
      console.error("Failed to clean user data", e);
    }
  });

/* ────────────────────── push de mensajes ───────────────────── */
export const sendPushOnMessage = onDocumentCreated(
  {region: "europe-west1", document: "/messages/{id}"},
  async (event: CreatedEvent) => {
    const m = event.data?.data();
    if (!m || m.senderId === m.receiverId) return;

    const db = getFirestore();
    const receiverRef = db.doc(`users/${m.receiverId}`);
    const recvSnap = await receiverRef.get();
    const recvTokens: string[] = recvSnap.get("tokens") ?? [];
    if (recvTokens.length === 0) return;

    const senderSnap = await db.doc(`users/${m.senderId}`).get();
    const senderTokens: string[] = senderSnap.get("tokens") ?? [];
    const senderName: string = senderSnap.get("name") ?? "";

    let tokens = recvTokens.filter((t) => !senderTokens.includes(t));
    if (tokens.length === 0) tokens = recvTokens;

    const resp = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "Nuevo mensaje",
        body: `Tienes un mensaje de ${senderName}`,
      },
      android: {notification: {channelId: "plan_high"}},
      data: {
        type: "chat_message",
        senderId: m.senderId ?? "",
        messageId: event.params.id,
      },
    });

    const invalid: string[] = [];
    resp.responses.forEach((r, i) => {
      if (
        !r.success &&
        r.error?.code === "messaging/registration-token-not-registered"
      ) {
        invalid.push(tokens[i]);
      }
    });

    if (invalid.length) {
      await receiverRef.update({
        tokens: FieldValue.arrayRemove(...invalid),
      });
    }
  }
);

/* ─── notificaciones de eliminación / salida de participantes ─── */
export const notifyRemovedParticipants = onDocumentWritten(
  {region: "europe-west1", document: "/plans/{planId}"},
  async (event: WrittenEvent) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const removed: string[] =
      before.participants?.filter(
        (p: string) => !(after.participants ?? []).includes(p)
      ) ?? [];
    if (removed.length === 0) return;

    const db = getFirestore();
    const planId = event.params.planId;
    const creatorId: string = after.createdBy;
    const creatorSnap = await db.doc(`users/${creatorId}`).get();
    const senderName: string = creatorSnap.get("name") ?? "";
    const senderPhoto: string = creatorSnap.get("photoUrl") ?? "";
    const planType: string = after.type ?? "Plan";

    await Promise.all(
      removed.map(async (uid: string) => {
        await db.collection("notifications").add({
          type: "removed_from_plan",
          receiverId: uid,
          senderId: creatorId,
          planId,
          planType,
          senderProfilePic: senderPhoto,
          senderName,
          timestamp: FieldValue.serverTimestamp(),
          read: false,
        });
      })
    );
  }
);

/* ─────────────── actualización de estadísticas ─────────────── */
export const updateCreatorStats = onDocumentWritten(
  {region: "europe-west1", document: "/plans/{planId}"},
  async (event: WrittenEvent) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const beforeChecked: string[] = before.checkedInUsers ?? [];
    const afterChecked: string[] = after.checkedInUsers ?? [];
    if (afterChecked.length <= beforeChecked.length) return;

    const added = afterChecked.filter((u: string) => !beforeChecked.includes(u));
    if (added.length === 0) return;

    const creatorId: string = after.createdBy;
    if (!creatorId) return;

    const db = getFirestore();
    const creatorRef = db.doc(`users/${creatorId}`);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(creatorRef);
      if (!snap.exists) return;

      const data = snap.data() ?? {};
      const total = (data.total_participants_until_now ?? 0) + added.length;
      const maxPart = Math.max(
        data.max_participants_in_one_plan ?? 0,
        afterChecked.length
      );

      tx.update(creatorRef, {
        total_participants_until_now: total,
        max_participants_in_one_plan: maxPart,
      });
    });
  }
);

/* ────────────────── notificación de bienvenida ───────────────── */
export const createWelcomeNotification = onDocumentCreated(
  {region: "europe-west1", document: "/users/{userId}"},
  async (event: CreatedEvent) => {
    const userId = event.params.userId;
    const data = event.data?.data();
    if (!data) return;

    const db = getFirestore();
    await db.collection("notifications").add({
      type: "welcome",
      receiverId: userId,
      senderId: "system",
      senderName: "Plan",
      senderProfilePic: "",
      message:
        "El equipo de Plan te da la bienvenida a la app que te conecta con " +
        "nuevas experiencias y personas. ¡Comienza a explorar y a crear " +
        "momentos inolvidables!",
      timestamp: FieldValue.serverTimestamp(),
      read: false,
    });
  }
);

/* ──────────── búsqueda de email por username ──────────── */
export const getEmailByUsername = functions
  .region("europe-west1")
  .https.onCall(async (data) => {
    const username = (data?.username as string | undefined)?.trim();
    if (!username) {
      throw new HttpsError("invalid-argument", "Missing username");
    }

    const db = getFirestore();
    const snap = await db
      .collection("users")
      .where("user_name_lowercase", "==", username.toLowerCase())
      .limit(1)
      .get();

    if (snap.empty) return {email: null};

    const email = snap.docs[0].get("email") as string | undefined;
    return {email: email ?? null};
  });
