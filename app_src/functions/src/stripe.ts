import * as functions from "firebase-functions/v1";
import { getFirestore } from "firebase-admin/firestore";
import Stripe from "stripe";

const stripe = new Stripe(functions.config().stripe.secret as string, {
  apiVersion: "2023-10-16",
});

export const createStripeAccount = functions
  .region("europe-west1")
  .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) throw new functions.https.HttpsError("unauthenticated", "Debe iniciar sesión");

    const email = data?.email as string | undefined;
    const account = await stripe.accounts.create({ type: "express", email });
    await getFirestore().doc(`users/${uid}`).update({ stripeAccountId: account.id });
    return { accountId: account.id };
  });

export const createAccountLink = functions
  .region("europe-west1")
  .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) throw new functions.https.HttpsError("unauthenticated", "Debe iniciar sesión");

    const accountId = data?.accountId as string;
    const link = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: "https://example.com/reauth",
      return_url: "https://example.com/return",
      type: "account_onboarding",
    });
    return { url: link.url };
  });

export const retrieveAccount = functions
  .region("europe-west1")
  .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) throw new functions.https.HttpsError("unauthenticated", "Debe iniciar sesión");

    const accountId = data?.accountId as string;
    const account = await stripe.accounts.retrieve(accountId);
    return { account };
  });
