/**
 * iShamela Cloud Functions — SPEC-022 §5, SPEC-024 §4, ADR-002.
 * Region: europe-west1.
 *
 * OTP email is sent directly via Resend (no Firebase Extensions).
 */

import * as admin from 'firebase-admin';
import { defineSecret, defineString } from 'firebase-functions/params';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onCall } from 'firebase-functions/v2/https';
import { sendViaResend } from './email';
import {
  AuthDeps,
  FirestoreDeps,
  handleDeleteAccount,
  handleResetPassword,
  handleSendOtp,
  handleVerifyOtp,
  HandlerDeps,
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

/** Set with: firebase functions:secrets:set RESEND_API_KEY */
const resendApiKey = defineSecret('RESEND_API_KEY');

/**
 * Verified sender, e.g. `الشاملة <noreply@ishamela.online>`.
 * Override: firebase functions:config or params — `RESEND_FROM`.
 */
const resendFrom = defineString('RESEND_FROM', {
  default: 'الشاملة <noreply@ishamela.online>',
});

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
    recursiveDeleteUser: (uid) =>
      db.recursiveDelete(db.collection('users').doc(uid)),
  };
}

function liveDeps(): HandlerDeps {
  return {
    auth: liveAuthDeps(),
    db: liveFirestoreDeps(),
    sendEmail: (msg) =>
      sendViaResend(resendApiKey.value(), resendFrom.value(), msg),
  };
}

export const sendOtp = onCall(
  { region: 'europe-west1', secrets: [resendApiKey] },
  async (request) =>
    handleSendOtp((request.data ?? {}) as SendOtpRequest, liveDeps()),
);

export const verifyOtp = onCall({ region: 'europe-west1' }, async (request) =>
  handleVerifyOtp((request.data ?? {}) as VerifyOtpRequest, liveDeps()),
);

export const resetPassword = onCall(
  { region: 'europe-west1' },
  async (request) =>
    handleResetPassword((request.data ?? {}) as ResetPasswordRequest, liveDeps()),
);

export const deleteAccount = onCall(
  { region: 'europe-west1' },
  async (request) => handleDeleteAccount(request.auth?.uid, liveDeps()),
);

export {
  handleDeleteAccount,
  handleResetPassword,
  handleSendOtp,
  handleVerifyOtp,
} from './handlers';
