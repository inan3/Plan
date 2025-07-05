/* eslint-disable max-len */
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {getFirestore} from "firebase-admin/firestore";
import Stripe from "stripe";

/* ---- secreto ---- */
const STRIPE_SECRET = defineSecret("STRIPE_SECRET_KEY");
let stripe: Stripe | undefined;
const getStripe = () =>
  stripe ?? (stripe = new Stripe(STRIPE_SECRET.value(), {apiVersion:
    "2022-11-15"}));

/* ---- createStripeAccount ---- */
export const createStripeAccount = onCall(
  {region: "europe-west1", secrets: [STRIPE_SECRET]},
  async (req) => {
    if (!req.auth?.uid) {
      throw new HttpsError("unauthenticated",
        "Debe iniciar sesión");
    }
    const {email} = req.data as { email?: string };
    const account = await getStripe().accounts.create({type: "express", email});
    await getFirestore().doc(`users/${req.auth.uid}`).update({
      stripeAccountId: account.id});
    return {accountId: account.id};
  },
);

/* ---- createAccountLink ---- */
export const createAccountLink = onCall(
  {region: "europe-west1", secrets: [STRIPE_SECRET]},
  async (req) => {
    if (!req.auth?.uid) {
      throw new HttpsError("unauthenticated",
        "Debe iniciar sesión");
    }
    const {accountId} = req.data as { accountId: string };
    const link = await getStripe().accountLinks.create({
      account: accountId,
      refresh_url: "https://example.com/reauth",
      return_url: "https://example.com/return",
      type: "account_onboarding",
    });
    return {url: link.url};
  },
);

/* ---- retrieveAccount ---- */
export const retrieveAccount = onCall(
  {region: "europe-west1", secrets: [STRIPE_SECRET]},
  async (req) => {
    if (!req.auth?.uid) {
      throw new HttpsError("unauthenticated",
        "Debe iniciar sesión");
    }
    const {accountId} = req.data as { accountId: string };
    const account = await getStripe().accounts.retrieve(accountId);
    return {account};
  },
);
