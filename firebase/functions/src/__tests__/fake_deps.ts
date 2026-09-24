/**
 * In-memory Firestore-ish stubs for OTP / mail / user subtree tests.
 * Mimics the document API surface used by the callables (get/set/update/delete).
 */

import { Timestamp } from 'firebase-admin/firestore';

type DocData = Record<string, unknown>;

class FakeDocSnapshot {
  constructor(
    readonly id: string,
    private readonly dataOrNull: DocData | null,
  ) {}

  get exists(): boolean {
    return this.dataOrNull !== null;
  }

  data(): DocData | undefined {
    return this.dataOrNull ?? undefined;
  }
}

export class FakeDocRef {
  constructor(
    private readonly store: Map<string, DocData>,
    readonly id: string,
  ) {}

  async get(): Promise<FakeDocSnapshot> {
    const data = this.store.get(this.id) ?? null;
    return new FakeDocSnapshot(this.id, data ? { ...data } : null);
  }

  async set(data: DocData): Promise<void> {
    this.store.set(this.id, { ...data });
  }

  async update(data: DocData): Promise<void> {
    const existing = this.store.get(this.id);
    if (!existing) {
      throw new Error(`No document to update: ${this.id}`);
    }
    this.store.set(this.id, { ...existing, ...data });
  }

  async delete(): Promise<void> {
    this.store.delete(this.id);
  }
}

export function createFakeFirestore() {
  const otps = new Map<string, DocData>();
  const sentEmails: DocData[] = [];
  const deletedUsers: string[] = [];

  return {
    otps,
    /** @deprecated alias for tests that still read `.mail` */
    get mail() {
      return sentEmails;
    },
    sentEmails,
    deletedUsers,
    deps: {
      otpDoc: (id: string) =>
        new FakeDocRef(otps, id) as unknown as FirebaseFirestore.DocumentReference,
      recursiveDeleteUser: async (uid: string) => {
        deletedUsers.push(uid);
      },
    },
    sendEmail: async (msg: {
      to: string;
      subject: string;
      text: string;
      html: string;
    }) => {
      sentEmails.push({
        to: [msg.to],
        message: {
          subject: msg.subject,
          text: msg.text,
          html: msg.html,
        },
      });
    },
  };
}

export function createFakeAuth(opts?: {
  users?: Record<string, { uid: string; email: string; emailVerified?: boolean }>;
}) {
  const users = new Map(
    Object.entries(opts?.users ?? {}).map(([email, u]) => [email.toLowerCase(), { ...u }]),
  );
  const updated: Array<{ uid: string; props: Record<string, unknown> }> = [];
  const revoked: string[] = [];
  const deleted: string[] = [];

  return {
    updated,
    revoked,
    deleted,
    users,
    deps: {
      getUserByEmail: async (email: string) => {
        const u = users.get(email.toLowerCase());
        return u
          ? ({
              uid: u.uid,
              email: u.email,
              emailVerified: u.emailVerified ?? false,
            } as import('firebase-admin').auth.UserRecord)
          : null;
      },
      updateUser: async (uid: string, props: import('firebase-admin').auth.UpdateRequest) => {
        updated.push({ uid, props: props as Record<string, unknown> });
        for (const u of users.values()) {
          if (u.uid === uid) {
            if (props.emailVerified !== undefined) {
              u.emailVerified = props.emailVerified;
            }
          }
        }
        return { uid } as import('firebase-admin').auth.UserRecord;
      },
      revokeRefreshTokens: async (uid: string) => {
        revoked.push(uid);
      },
      deleteUser: async (uid: string) => {
        deleted.push(uid);
        for (const [email, u] of users) {
          if (u.uid === uid) {
            users.delete(email);
          }
        }
      },
    },
  };
}

export { Timestamp };
