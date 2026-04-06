import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

const db = admin.firestore();

const NOTIF_TITLE = "نۆرینگە";

async function collectFcmTokens(
  patientId: string,
  userId: string,
): Promise<string[]> {
  const tokens = new Set<string>();
  const ids = [...new Set([patientId, userId].map((s) => s.trim()).filter(Boolean))];

  for (const id of ids) {
    const doc = await db.collection("users").doc(id).get();
    const data = doc.data() ?? {};
    const map = data.fcmTokens as Record<string, unknown> | undefined;
    if (map && typeof map === "object") {
      for (const k of Object.keys(map)) {
        if (k.length > 20) tokens.add(k);
      }
    }
    const legacy = data.fcmToken as string | undefined;
    if (legacy && legacy.length > 20) tokens.add(legacy);
  }
  return [...tokens];
}

async function collectFcmTokensForKeys(keys: string[]): Promise<string[]> {
  const tokens = new Set<string>();
  for (const id of keys) {
    for (const t of await collectFcmTokens(id, "")) {
      tokens.add(t);
    }
  }
  return [...tokens];
}

function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    out.push(arr.slice(i, i + size));
  }
  return out;
}

async function sendMulticast(
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  if (tokens.length === 0) {
    return;
  }
  for (const part of chunk(tokens, 500)) {
    const res = await admin.messaging().sendEachForMulticast({
      tokens: part,
      notification: { title, body },
      data,
      android: { priority: "high" },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });
    logger.info("FCM multicast", {
      success: res.successCount,
      failure: res.failureCount,
    });
  }
}

/**
 * Client writes [notifications] rows; this sends the lock-screen FCM payload.
 * Avoids duplicate pushes from a separate [appointments] update trigger.
 */
export const onRootNotificationCreated = onDocumentCreated(
  "notifications/{notifId}",
  async (event) => {
    const snap = event.data;
    if (!snap) {
      return;
    }
    const data = snap.data();
    const rawKeys = data.recipientKeys;
    let keys = Array.isArray(rawKeys)
      ? rawKeys.map((k) => String(k).trim()).filter(Boolean)
      : [];
    const singlePatient = String(data.patientId ?? "").trim();
    if (keys.length === 0 && singlePatient.length > 0) {
      keys = [singlePatient];
    }
    const title = String(data.title ?? NOTIF_TITLE).trim() || NOTIF_TITLE;
    const body = String(data.message ?? "").trim();
    if (!body) {
      logger.warn("onRootNotificationCreated: empty body", { id: snap.id });
      return;
    }
    const type = String(data.type ?? "unknown");
    const appointmentId = String(data.appointmentId ?? "");

    const tokens = await collectFcmTokensForKeys(keys);
    if (tokens.length === 0) {
      logger.info("onRootNotificationCreated: no tokens", {
        id: snap.id,
        keys,
      });
      return;
    }

    await sendMulticast(tokens, title, body, {
      type,
      appointmentId,
      notificationId: snap.id,
    });
  },
);
