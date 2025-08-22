import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

const db = admin.firestore();

function asHttpsError(err: any): never {
  // Log the raw error for debugging
  functions.logger.error('Callable error', { err: String(err), code: err?.code, info: err?.errorInfo });

  const rawCode: string = err?.code || err?.errorInfo?.code || '';

  // Common Admin SDK auth errors
  if (rawCode.includes('auth/email-already-exists')) {
    throw new functions.https.HttpsError('already-exists', 'Email already exists');
  }
  if (rawCode.includes('auth/invalid-email')) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid email');
  }
  if (rawCode.includes('auth/uid-already-exists')) {
    throw new functions.https.HttpsError('already-exists', 'UID already exists');
  }
  if (rawCode.includes('permission-denied')) {
    throw new functions.https.HttpsError('permission-denied', 'Permission denied');
  }

  // Fallback with message
  throw new functions.https.HttpsError('internal', err?.message || 'Internal error');
}

async function assertIsAdmin(uid: string): Promise<void> {
  try {
    const snap = await db.doc(`users/${uid}`).get();
    if (!snap.exists) {
      throw new functions.https.HttpsError('permission-denied', 'No profile');
    }
    const role = snap.get('role');
    if (role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Admin only');
    }
  } catch (e) {
    asHttpsError(e);
  }
}

function normalizeRole(role: string): string {
  const r = (role || '').toLowerCase().trim();
  const allowed = ['admin', 'store', 'designer', 'engineer', 'accounts'];
  if (!allowed.includes(r)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid role');
  }
  return r;
}

export const createUserWithRole = functions
  .region('asia-south1')
  .https.onCall(
    async (
      data: { displayName: string; email: string; role: string },
      context: functions.https.CallableContext,
    ) => {
      try {
        if (!context.auth) {
          throw new functions.https.HttpsError('unauthenticated', 'Sign in');
        }
        await assertIsAdmin(context.auth.uid);

        const displayName = (data?.displayName || '').trim();
        const email = (data?.email || '').trim();
        const role = normalizeRole(data?.role || '');

        if (!displayName || !email) {
          throw new functions.https.HttpsError('invalid-argument', 'Missing fields');
        }

        // Pre-check: if email already exists, return a friendly error
        try {
          const existing = await admin.auth().getUserByEmail(email);
          if (existing) {
            throw new functions.https.HttpsError('already-exists', 'Email already exists');
          }
        } catch (e: any) {
          // getUserByEmail throws if not found -> ignore that specific case
          if (!String(e?.code || '').includes('auth/user-not-found')) {
            asHttpsError(e);
          }
        }

        const userRecord = await admin.auth().createUser({
          email,
          displayName,
          emailVerified: false,
          disabled: false,
        });

        await admin.auth().setCustomUserClaims(userRecord.uid, { role });

        const now = new Date().toISOString();
        await db.doc(`users/${userRecord.uid}`).set(
          {
            displayName,
            email,
            phone: '',
            role,
            status: 'active',
            createdAt: now,
            createdBy: context.auth.uid,
            updatedAt: now,
            updatedBy: context.auth.uid,
          },
          { merge: true },
        );

        functions.logger.info('User created', { uid: userRecord.uid, email, role });
        return { uid: userRecord.uid };
      } catch (e) {
        asHttpsError(e);
      }
    },
  );

export const setUserStatus = functions
  .region('asia-south1')
  .https.onCall(
    async (
      data: { uid: string; status: 'active' | 'suspended' },
      context: functions.https.CallableContext,
    ) => {
      try {
        if (!context.auth) {
          throw new functions.https.HttpsError('unauthenticated', 'Sign in');
        }
        await assertIsAdmin(context.auth.uid);

        const uid = (data?.uid || '').trim();
        const status = (data?.status || '').trim() as 'active' | 'suspended';
        if (!uid || !['active', 'suspended'].includes(status)) {
          throw new functions.https.HttpsError('invalid-argument', 'Bad input');
        }

        const now = new Date().toISOString();
        await db.doc(`users/${uid}`).set(
          { status, updatedAt: now, updatedBy: context.auth.uid },
          { merge: true },
        );

        await admin.auth().updateUser(uid, { disabled: status === 'suspended' });
        functions.logger.info('User status updated', { uid, status });
        return { ok: true };
      } catch (e) {
        asHttpsError(e);
      }
    },
  );

export const setUserRole = functions
  .region('asia-south1')
  .https.onCall(
    async (
      data: { uid: string; role: string },
      context: functions.https.CallableContext,
    ) => {
      try {
        if (!context.auth) {
          throw new functions.https.HttpsError('unauthenticated', 'Sign in');
        }
        await assertIsAdmin(context.auth.uid);

        const uid = (data?.uid || '').trim();
        const role = normalizeRole(data?.role || '');

        if (!uid) {
          throw new functions.https.HttpsError('invalid-argument', 'Missing uid');
        }

        const now = new Date().toISOString();
        await db.doc(`users/${uid}`).set(
          { role, updatedAt: now, updatedBy: context.auth.uid },
          { merge: true },
        );

        await admin.auth().setCustomUserClaims(uid, { role });
        functions.logger.info('User role updated', { uid, role });
        return { ok: true };
      } catch (e) {
        asHttpsError(e);
      }
    },
  );
