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

    // Evita auto-notificarse
    if (n.senderId === n.receiverId) return;

  // Tokens del receptor
  const receiverRef = getFirestore().doc(`users/${n.receiverId}`);
  const receiverSnap = await receiverRef.get();
  let tokens: string[] = receiverSnap.get("tokens") ?? [];
  if (tokens.length === 0) return;

  // Tokens del emisor
  const senderSnap = await getFirestore()
    .doc(`users/${n.senderId}`)
    .get();
  const senderTokens: string[] = senderSnap.get("tokens") ?? [];

  // Evita tokens compartidos
  tokens = tokens.filter((t) => !senderTokens.includes(t));
  if (tokens.length === 0) return;

    // Envío
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

    // Limpia tokens inválidos
    const invalid: string[] = [];
    resp.responses.forEach((r, i) => { //  ← flecha añadida
      if (!r.success &&
          r.error?.code === "messaging/registration-token-not-registered") {
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
