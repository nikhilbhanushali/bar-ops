import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

export const whoami = functions.region('asia-south1').https.onCall(async (_, ctx) => {
  if (!ctx.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in first');
  }
  const uid = ctx.auth.uid;
  const snap = await admin.firestore().doc(`users/${uid}`).get();
  return {
    uid,
    email: ctx.auth.token.email ?? null,
    hasProfile: snap.exists,
    role: snap.exists ? snap.get('role') : null,
  };
});
