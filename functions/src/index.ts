import * as admin from "firebase-admin";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

const db = admin.firestore();

const NOTIF_TITLE = "نۆرینگە";

function normStatus(raw: unknown): string {
  return String(raw ?? "pending").trim().toLowerCase();
}

function isCancelledStatus(s: string): boolean {
  return s === "cancelled" || s === "canceled" || s === "rejected";
}

/** Display date for Kurdish notification body (matches common app `yyyy/MM/dd`). */
function formatAppointmentDate(data: admin.firestore.DocumentData): string {
  const d = data.date;
  if (d && typeof (d as admin.firestore.Timestamp).toDate === "function") {
    const dt = (d as admin.firestore.Timestamp).toDate();
    const y = dt.getFullYear();
    const m = String(dt.getMonth() + 1).padStart(2, "0");
    const day = String(dt.getDate()).padStart(2, "0");
    return `${y}/${m}/${day}`;
  }
  if (typeof d === "string" && d.trim().length > 0) {
    return d.trim();
  }
  return "—";
}

function dayKeyFromDateLabel(dateLabel: string): string {
  return dateLabel.replace(/\//g, "-").replace(/[^\w\-]/g, "_");
}

function patientPairKey(patientId: string, userId: string): string {
  const parts = [patientId, userId].map((s) => s.trim()).filter(Boolean);
  parts.sort();
  return parts.length > 0 ? parts.join("|") : "unknown";
}

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
    });
    logger.info("FCM multicast", {
      success: res.successCount,
      failure: res.failureCount,
    });
  }
}

async function addNotificationInboxEntries(
  patientId: string,
  userId: string,
  entry: {
    title: string;
    body: string;
    type: string;
    appointmentId: string;
  },
): Promise<void> {
  const ids = [...new Set([patientId, userId].map((s) => s.trim()).filter(Boolean))];
  const batch = db.batch();
  for (const id of ids) {
    const ref = db
      .collection("users")
      .doc(id)
      .collection("notificationInbox")
      .doc();
    batch.set(ref, {
      ...entry,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });
  }
  await batch.commit();
}

/**
 * When an appointment becomes cancelled/rejected, notify the patient via FCM and
 * append an inbox row. Clinic-day bulk cancels dedupe to one push per patient per day.
 */
export const onAppointmentCancelledNotify = onDocumentUpdated(
  "appointments/{apptId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }

    const sb = normStatus(before.status);
    const sa = normStatus(after.status);
    if (isCancelledStatus(sb) || !isCancelledStatus(sa)) {
      return;
    }

    const apptId = event.params.apptId as string;
    const patientId = String(after.patientId ?? "").trim();
    const userId = String(after.userId ?? "").trim();
    const reason = String(after.cancellationReason ?? "").trim();
    const dateLabel = formatAppointmentDate(after);

    const isClinicClosure = reason === "clinic_closed";

    const bodyIndividual =
      `ببوورە، نۆرەکەت لە ڕێکەوتی ${dateLabel} لەلایەن نۆرینگەوە هەڵوەشایەوە.`;
    const bodyClinic =
      `ئاگاداری: نۆرینگە لە ڕێکەوتی ${dateLabel} داخراوە، تکایە نۆرەیەکی نوێ وەربگرە.`;

    const body = isClinicClosure ? bodyClinic : bodyIndividual;
    const type = isClinicClosure ? "clinic_closed" : "appointment_cancelled";

    const dataPayload: Record<string, string> = {
      type,
      appointmentId: apptId,
      date: dateLabel,
    };

    if (isClinicClosure) {
      const dk = dayKeyFromDateLabel(dateLabel);
      const pair = patientPairKey(patientId, userId);
      const dedupeId = `${pair}_${dk}`.replace(/[^a-zA-Z0-9_|\-]/g, "_");
      const dedupeRef = db.collection("clinicClosureNotifyDedupe").doc(dedupeId);

      let shouldNotify = false;
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(dedupeRef);
        if (snap.exists) {
          return;
        }
        shouldNotify = true;
        tx.set(dedupeRef, {
          firstAppointmentId: apptId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      if (!shouldNotify) {
        logger.info("Skip duplicate clinic-closure notify", { dedupeId, apptId });
        return;
      }

      const tokens = await collectFcmTokens(patientId, userId);
      await sendMulticast(tokens, NOTIF_TITLE, body, dataPayload);
      await addNotificationInboxEntries(patientId, userId, {
        title: NOTIF_TITLE,
        body,
        type,
        appointmentId: apptId,
      });
      return;
    }

    const tokens = await collectFcmTokens(patientId, userId);
    await sendMulticast(tokens, NOTIF_TITLE, body, dataPayload);
    await addNotificationInboxEntries(patientId, userId, {
      title: NOTIF_TITLE,
      body,
      type,
      appointmentId: apptId,
    });
  },
);
