import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
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

function asBool(v: unknown): boolean | undefined {
  return typeof v === "boolean" ? v : undefined;
}

function asNum(v: unknown): number | undefined {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  return undefined;
}

function isDayClosedOrFullTransition(
  before: admin.firestore.DocumentData,
  after: admin.firestore.DocumentData,
): { shouldRun: boolean; reason: "closed" | "full" | null } {
  const beforeOpen = asBool(before?.isOpen);
  const afterOpen = asBool(after?.isOpen);
  if (beforeOpen === true && afterOpen === false) {
    return { shouldRun: true, reason: "closed" };
  }

  const beforeBookings = asNum(before?.currentBookings) ?? 0;
  const afterBookings = asNum(after?.currentBookings) ?? 0;
  const beforeMax = asNum(before?.maxAppointments);
  const afterMax = asNum(after?.maxAppointments);

  // "Full" transition: previously below capacity, now at/above capacity, while still open.
  if (
    afterOpen !== false &&
    afterMax != null &&
    afterMax > 0 &&
    beforeMax === afterMax &&
    beforeBookings < afterMax &&
    afterBookings >= afterMax
  ) {
    return { shouldRun: true, reason: "full" };
  }
  return { shouldRun: false, reason: null };
}

function isTerminalAppointmentStatus(raw: unknown): boolean {
  const s = String(raw ?? "").trim().toLowerCase();
  return s === "completed" || s === "complete" || s === "done" || s === "cancelled" || s === "canceled";
}

function isWaitingAppointmentStatus(raw: unknown): boolean {
  const s = String(raw ?? "").trim().toLowerCase();
  // App uses "pending" for waiting; tolerate legacy "waiting".
  return s === "pending" || s === "waiting";
}

function wasBookedPatientSlotStatus(raw: unknown): boolean {
  const s = String(raw ?? "").trim().toLowerCase();
  return (
    s === "pending" ||
    s === "booked" ||
    s === "waiting" ||
    s === "confirmed" ||
    s === "arrived"
  );
}

function appointmentDateLabelKu(raw: unknown): string {
  if (raw && typeof raw === "object" && "toDate" in (raw as any)) {
    try {
      const d = (raw as admin.firestore.Timestamp).toDate();
      const y = d.getFullYear();
      const m = String(d.getMonth() + 1).padStart(2, "0");
      const day = String(d.getDate()).padStart(2, "0");
      return `${y}/${m}/${day}`;
    } catch {
      // fallthrough
    }
  }
  const s = String(raw ?? "").trim();
  return s || "—";
}

async function createNotificationRowsAndPush(
  appointmentId: string,
  patientKeys: string[],
  title: string,
  message: string,
  type: string,
  doctorName: string,
  doctorImage: string,
): Promise<void> {
  const keys = [...new Set(patientKeys.map((k) => k.trim()).filter(Boolean))];
  if (keys.length === 0) return;
  const batch = db.batch();
  for (const key of keys) {
    const ref = db.collection("notifications").doc();
    batch.set(ref, {
      patientId: key,
      recipientKeys: [key],
      message,
      title,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: "unread",
      appointmentId,
      type,
      doctorName,
      doctorImage,
    });
  }
  await batch.commit();
}

async function loadDoctorSnapshot(doctorId: string): Promise<{ name: string; imageUrl: string }> {
  const id = doctorId.trim();
  if (!id) return { name: "", imageUrl: "" };
  try {
    const doc = await db.collection("users").doc(id).get();
    const data = doc.data() ?? {};
    const name = String(data.fullName_ku ?? data.fullName ?? data.name ?? "").trim();
    const imageUrl = String(data.profileImageUrl ?? "").trim();
    return { name, imageUrl };
  } catch {
    return { name: "", imageUrl: "" };
  }
}

/**
 * When a doctor day becomes "Closed" (isOpen=false) or transitions to "Full"
 * (currentBookings >= maxAppointments), cancel all active appointments for that day.
 *
 * - Updates: status -> "cancelled", cancellationReason -> "doctor_day_closed"
 * - Notifies: writes [notifications] rows which triggers onRootNotificationCreated -> FCM
 */
export const onAvailableDayClosedOrFull = onDocumentUpdated(
  "available_days/{dayId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const trans = isDayClosedOrFullTransition(before, after);
    if (!trans.shouldRun) return;

    const dayId = String(event.params.dayId ?? "").trim();
    const doctorId = String(after.doctorId ?? "").trim();
    if (!dayId || !doctorId) {
      logger.warn("onAvailableDayClosedOrFull: missing ids", { dayId, doctorId });
      return;
    }

    // Use availableDayDocId for primary matching (modern booking flow).
    const apptSnap = await db
      .collection("appointments")
      .where("doctorId", "==", doctorId)
      .where("availableDayDocId", "==", dayId)
      .get();

    if (apptSnap.empty) {
      logger.info("onAvailableDayClosedOrFull: no appointments", { dayId, doctorId });
      return;
    }

    const { name: doctorName, imageUrl: doctorImage } = await loadDoctorSnapshot(doctorId);

    const chunkSize = 400;
    const docs = apptSnap.docs.filter((d) => {
      const st = d.data().status;
      return !isTerminalAppointmentStatus(st) && isWaitingAppointmentStatus(st);
    });
    if (docs.length === 0) return;

    const title = "ئاگاداری نۆرە";
    const dayLabel = appointmentDateLabelKu(after.date);
    const message =
      trans.reason === "full"
        ? `ببوورە، نۆرینگە لە ڕێکەوتی ${dayLabel} پڕ بووە و نۆرەکەت هەڵوەشایەوە.`
        : "ببورە، ئەم بەروارە لەلایەن پزیشکەوە داخراوە و نۆرەکەت هەڵوەشایەوە.";

    for (let i = 0; i < docs.length; i += chunkSize) {
      const slice = docs.slice(i, i + chunkSize);
      const batch = db.batch();
      for (const d of slice) {
        batch.update(d.ref, {
          status: "cancelled",
          cancellationReason: "doctor_day_closed",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // Create notifications after status change so clients update immediately.
      for (const d of slice) {
        const data = d.data();
        const keys = [String(data.patientId ?? ""), String(data.userId ?? "")].filter(Boolean);
        await createNotificationRowsAndPush(
          d.id,
          keys,
          title,
          message,
          "doctor_day_closed",
          doctorName,
          doctorImage,
        );
      }
    }

    logger.info("onAvailableDayClosedOrFull: cancelled", {
      dayId,
      doctorId,
      count: docs.length,
      reason: trans.reason,
    });
  },
);

/**
 * Secretary (or calendar) cancels a single slot: live [appointments] becomes `available`
 * with `cancellationReason: secretary` and patient fields cleared — use **before** snapshot
 * for patient ids. Writes [notifications] so [onRootNotificationCreated] sends FCM.
 *
 * Doctor single-slot cancel from the app already creates [notifications] on the client;
 * this trigger is scoped to `secretary` only to avoid duplicate pushes.
 */
export const onAppointmentSecretarySlotReleased = onDocumentUpdated(
  "appointments/{apptId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const afterSt = String(after.status ?? "").trim().toLowerCase();
    const reason = String(after.cancellationReason ?? "").trim().toLowerCase();
    if (afterSt !== "available" || reason !== "secretary") return;

    const beforeSt = String(before.status ?? "").trim().toLowerCase();
    if (!wasBookedPatientSlotStatus(beforeSt)) return;

    const appointmentId = String(event.params.apptId ?? "").trim();
    const patientId = String(before.patientId ?? "").trim();
    const userId = String(before.userId ?? "").trim();
    const keys = [...new Set([patientId, userId].filter(Boolean))];
    if (keys.length === 0 || !appointmentId) {
      logger.warn("onAppointmentSecretarySlotReleased: missing patient keys", {
        appointmentId,
      });
      return;
    }

    const doctorId = String(before.doctorId ?? "").trim();
    const { name: doctorName, imageUrl: doctorImage } = await loadDoctorSnapshot(doctorId);
    const dayLabel = appointmentDateLabelKu(before.date);
    const title = "ئاگاداری نۆرە";
    const message = `ببوورە، نۆرەکەت لە ڕێکەوتی ${dayLabel} لەلایەن سکرتێرەوە هەڵوەشایەوە.`;

    await createNotificationRowsAndPush(
      appointmentId,
      keys,
      title,
      message,
      "appointment_cancelled",
      doctorName,
      doctorImage,
    );

    logger.info("onAppointmentSecretarySlotReleased: notified", {
      appointmentId,
      keys,
    });
  },
);
