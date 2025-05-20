import {initializeApp} from "firebase-admin/app";
import {getMessaging} from "firebase-admin/messaging";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

initializeApp();

const titles: Record<string, string> = {
  join_request: "Solicitud de unión",
  invitation: "Invitación a un plan",
  join_accepted: "Solicitud aceptada",
  join_rejected: "Solicitud rechazada",
  follow_request: "Solicitud de follow",
  follow_accepted: "Follow aceptado",
  follow_rejected: "Follow rechazado",
  new_plan_published: "Nuevo plan publicado",
};

export const sendPushOnNotification = onDocumentCreated(
  {region: "europe-west1", document: "/notifications/{id}"},
  async (event) => {
    const n = event.data?.data();
    if (!n) return;
    if (n.senderId === n.receiverId) return;

    const db = getFirestore();

    // --- tokens del receptor ---
    const receiverRef = db.doc(`users/${n.receiverId}`);
    const receiverSnap = await receiverRef.get();
    const receiverTokens: string[] = receiverSnap.get("tokens") ?? [];
    if (receiverTokens.length === 0) return;

    // --- tokens del emisor (para no duplicar) ---
    const senderSnap = await db.doc(`users/${n.senderId}`).get();
    const senderTokens: string[] = senderSnap.get("tokens") ?? [];

    // 1) quita duplicados
    let tokens = receiverTokens.filter((t) => !senderTokens.includes(t));

    // 2) si quedaron 0, usa los originales (prefiero notificar al receptor
    //    aun con riesgo de duplicar en el emisor que silenciar la notificación)
    if (tokens.length === 0) tokens = receiverTokens;

    const resp = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: titles[n.type] ?? "Notificación",
        body: n.senderName ?
          `${n.senderName} • ${n.planType ?? ""}` :
          "Abre la app para más detalles",
      },
      android: {notification: {channelId: "plan_high"}},
      data: {
        type: n.type,
        planId: n.planId ?? "",
        senderId: n.senderId ?? "",
      },
    });

    // limpia tokens inválidos
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

export const sendPushOnMessage = onDocumentCreated(
  {region: "europe-west1", document: "/messages/{id}"},
  async (event) => {
    const m = event.data?.data();
    if (!m) return;
    if (m.senderId === m.receiverId) return;

    const db = getFirestore();

    // --- tokens del receptor ---
    const receiverRef = db.doc(`users/${m.receiverId}`);
    const receiverSnap = await receiverRef.get();
    const receiverTokens: string[] = receiverSnap.get("tokens") ?? [];
    if (receiverTokens.length === 0) return;

    // --- tokens del emisor (para no duplicar) ---
    const senderRef = db.doc(`users/${m.senderId}`);
    const senderSnap = await senderRef.get();
    const senderTokens: string[] = senderSnap.get("tokens") ?? [];
    const senderName: string = senderSnap.get("name") ?? "";

    // 1) quita duplicados
    let tokens = receiverTokens.filter((t) => !senderTokens.includes(t));

    // 2) si quedaron 0, usa los originales
    if (tokens.length === 0) tokens = receiverTokens;

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
