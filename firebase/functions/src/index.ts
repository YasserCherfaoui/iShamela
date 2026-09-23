/**
 * iShamela Cloud Functions — SPEC-022 §5, SPEC-024 §4, ADR-002.
 * Region: europe-west1.
 */

import * as admin from 'firebase-admin';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onCall } from 'firebase-functions/v2/https';
import {
  AuthDeps,
  FirestoreDeps,
  handleDeleteAccount,
  handleResetPassword,
  handleSendOtp,
  handleVerifyOtp,
  ResetPasswordRequest,
  SendOtpRequest,
  VerifyOtpRequest,
} from './handlers';

setGlobalOptions({ region: 'europe-west1' });

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();

function liveAuthDeps(): AuthDeps {
  return {
    async getUserByEmail(email) {
      try {
        return await auth.getUserByEmail(email);
      } catch (err: unknown) {
        const code = (err as { code?: string }).code;
        if (code === 'auth/user-not-found') {
          return null;
        }
        throw err;
      }
    },
    updateUser: (uid, props) => auth.updateUser(uid, props),
    revokeRefreshTokens: (uid) => auth.revokeRefreshTokens(uid),
    deleteUser: (uid) => auth.deleteUser(uid),
  };
}

function liveFirestoreDeps(): FirestoreDeps {
  return {
    otpDoc: (id) => db.collection('otps').doc(id),
    addMail: (data) => db.collection('mail').add(data),
    recursiveDeleteUser: (uid) =>
      db.recursiveDelete(db.collection('users').doc(uid)),
  };
}

const deps = { auth: liveAuthDeps(), db: liveFirestoreDeps() };

export const sendOtp = onCall({ region: 'europe-west1' }, async (request) =>
  handleSendOtp((request.data ?? {}) as SendOtpRequest, deps),
);

export const verifyOtp = onCall({ region: 'europe-west1' }, async (request) =>
  handleVerifyOtp((request.data ?? {}) as VerifyOtpRequest, deps),
);

export const resetPassword = onCall(
  { region: 'europe-west1' },
  async (request) =>
    handleResetPassword((request.data ?? {}) as ResetPasswordRequest, deps),
);

export const deleteAccount = onCall(
  { region: 'europe-west1' },
  async (request) => handleDeleteAccount(request.auth?.uid, deps),
);

// Re-export handlers for tests / tooling.
export {
  handleDeleteAccount,
  handleResetPassword,
  handleSendOtp,
  handleVerifyOtp,
} from './handlers';
