const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onValueWritten }                       = require("firebase-functions/v2/database");
const admin                                    = require("firebase-admin");
const alerts                                   = require("./alerts");

admin.initializeApp();

const RTDB_PATH = "featured_match/admin_current";

// Scores, liveMatch and playerStats land as separate writes a moment apart
// (worker and scoring panel alike). Wait for the rest before reading.
const SETTLE_MS = 4000;

// ─────────────────────────────────────────────────────────────
//  HELPER — queue a notification
// ─────────────────────────────────────────────────────────────
async function queueNotification(payload) {
  await admin.firestore()
    .collection("notifications/queue/pending")
    .add({ ...payload, createdAt: admin.firestore.FieldValue.serverTimestamp() });
}

// ─────────────────────────────────────────────────────────────
//  HELPERS — match alerts
// ─────────────────────────────────────────────────────────────
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function loadAlertSettings() {
  const snap = await admin.firestore().collection("config").doc("match_alerts").get();
  return alerts.normaliseSettings(snap.exists ? snap.data() : {});
}

async function readRtdb(child) {
  const snap = await admin.database().ref(`${RTDB_PATH}/${child}`).get();
  return snap.val() || {};
}

/**
 * Run `decide(state)` against the match's alert state inside a transaction and
 * queue whatever it returns. The state write and the queued notifications
 * commit together, so two triggers racing on the same ball can't both send.
 * `decide` returns { events, patch }.
 */
async function commitAlerts(key, title, decide) {
  const db = admin.firestore();
  const alertsDoc = db.collection("notifications").doc("alerts");
  const stateRef = alertsDoc.collection("matches").doc(key);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(stateRef);
    const state = snap.exists ? snap.data() : null;
    const { events, patch } = decide(state);
    const now = Date.now();
    const sent = { ...((state && state.sent) || {}) };

    for (const e of events) {
      const logRef = alertsDoc.collection("log").doc();
      const queueRef = db.collection("notifications").doc("queue").collection("pending").doc();
      tx.set(queueRef, {
        ...alerts.queuePayload(e, key),
        logId: logRef.id,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.set(logRef, {
        key: e.key,
        kind: e.kind,
        title: e.title,
        body: e.body,
        matchKey: key,
        matchTitle: title,
        queueId: queueRef.id,
        status: "queued",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      for (const k of [e.key, ...(e.marks || [])]) sent[k] = now;
    }

    tx.set(stateRef, {
      ...(state || {}),
      ...patch,
      matchKey: key,
      title,
      sent,
      updatedAt: now,
    });
    return events;
  });
}

// ─────────────────────────────────────────────────────────────
//  1. SEND NOTIFICATION (queue processor)
// ─────────────────────────────────────────────────────────────
exports.sendNotification = onDocumentCreated(
  "notifications/queue/pending/{docId}",
  async (event) => {
    const data = event.data.data();
    const message = {
      notification: {
        title: data.title,
        body:  data.body,
        ...(data.imageUrl ? { imageUrl: data.imageUrl } : {}),
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          ...(data.imageUrl ? { imageUrl: data.imageUrl } : {}),
          // Same tag replaces the older notification in the tray.
          ...(data.tag ? { tag: data.tag } : {}),
        },
      },
      data: {
        type:  data.type  || "custom",
        extra: data.extra || "",
        ...(data.alert        ? { alert:        data.alert }        : {}),
        ...(data.newsId       ? { newsId:       data.newsId }       : {}),
        ...(data.productId    ? { productId:    data.productId }    : {}),
        ...(data.targetUserId ? { targetUserId: data.targetUserId } : {}),
      },
    };

    if (data.targetToken) {
      message.token = data.targetToken;
    } else {
      message.topic = data.topic || "cricket_notification";
    }

    // Match alerts keep a log the admin panel shows; mirror the outcome there.
    const markLog = (fields) => data.logId
      ? admin.firestore().collection("notifications").doc("alerts")
          .collection("log").doc(data.logId).update(fields).catch(() => null)
      : null;

    try {
      await admin.messaging().send(message);
      await event.data.ref.update({
        status: "sent",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await markLog({ status: "sent", sentAt: admin.firestore.FieldValue.serverTimestamp() });
    } catch (error) {
      await markLog({ status: "failed", error: error.message });
      if (
        error.code === "messaging/registration-token-not-registered" &&
        data.targetUserId
      ) {
        await admin.firestore()
          .collection("dugout_users").doc(data.targetUserId)
          .update({ fcmToken: admin.firestore.FieldValue.delete() });
      }
      await event.data.ref.update({ status: "failed", error: error.message });
      console.error("❌ Notification failed:", error.message);
    }
  }
);

// ─────────────────────────────────────────────────────────────
//  2. MATCH ALERTS — score updates (RTDB trigger)
//  Wickets, milestones, innings break, close finishes. Rules and
//  titles live in alerts.js; settings in Firestore config/match_alerts.
// ─────────────────────────────────────────────────────────────
exports.autoScoreNotification = onValueWritten(
  { ref: `${RTDB_PATH}/scores`, region: "us-central1", memory: "256MiB" },
  async (event) => {
    if (!event.data.after.exists()) return null;
    await wait(SETTLE_MS);

    const [settings, docSnap, scores, liveMatch, playerStats] = await Promise.all([
      loadAlertSettings(),
      admin.firestore().collection("featured_match").doc("admin_current").get(),
      readRtdb("scores"),
      readRtdb("liveMatch"),
      readRtdb("playerStats"),
    ]);
    const doc = docSnap.exists ? docSnap.data() : {};
    const key = alerts.matchKey(doc);
    if (!key) return null;

    const snap = alerts.buildSnapshot({
      meta: doc.meta, teams: doc.teams, scores, liveMatch, playerStats,
    });

    const sent = await commitAlerts(key, (doc.meta && doc.meta.title) || "", (state) => {
      // The snapshot is remembered even while alerts are off, so switching
      // them back on mid-match doesn't dump everything that happened since.
      const { events, base } = alerts.scoreEvents(state, snap, settings);
      const capped = alerts.applyCap(settings.enabled ? events : [], state, settings, snap.day);
      return {
        events: capped.send,
        patch: {
          base,
          counts: capped.counts,
          seenLive: Boolean(state && state.seenLive) || snap.status.includes("live"),
        },
      };
    });

    for (const e of sent) console.log(`Queued ${e.key}: ${e.title}`);
    return null;
  }
);

// ─────────────────────────────────────────────────────────────
//  2b. MATCH ALERTS — toss, super over, stumps, result
//  Firestore trigger on the featured match document.
// ─────────────────────────────────────────────────────────────
exports.matchStatusNotification = onDocumentWritten(
  "featured_match/admin_current",
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after  = event.data.after.exists  ? event.data.after.data()  : null;
    // Reactions and team edits write this document too; skip those quickly.
    if (!after || !alerts.docChangeMatters(before, after)) return null;

    const settings = await loadAlertSettings();
    if (!settings.enabled) return null;
    const key = alerts.matchKey(after);
    if (!key) return null;

    const [scores, liveMatch] = await Promise.all([readRtdb("scores"), readRtdb("liveMatch")]);
    const snap = alerts.buildSnapshot({ meta: after.meta, teams: after.teams, scores, liveMatch });
    const ctx = {
      ballsBowled: alerts.totalBalls(snap),
      scoreLine: alerts.scoreLine(snap),
      isRecent: alerts.isRecent(after.meta && after.meta.matchDate),
    };

    const sent = await commitAlerts(key, (after.meta && after.meta.title) || "", (state) => {
      const events = alerts.docEvents(before, after, state, settings, ctx);
      const capped = alerts.applyCap(events, state, settings, snap.day);
      return { events: capped.send, patch: { counts: capped.counts } };
    });

    for (const e of sent) console.log(`Queued ${e.key}: ${e.title}`);
    return null;
  }
);

// ─────────────────────────────────────────────────────────────
//  3. AI PREDICTION NOTIFICATION — Firestore trigger (unchanged)
//  ai_prediction still lives in Firestore
// ─────────────────────────────────────────────────────────────
exports.aiPredictionNotification = onDocumentWritten(
  "featured_match/admin_current",
  async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();
    if (!before || !after) return null;

    const wasGenerated = before.ai_prediction?.generated === true;
    const isGenerated  = after.ai_prediction?.generated  === true;
    if (wasGenerated || !isGenerated) return null;

    const confidence = after.ai_prediction?.confidence || "moderate";
    const confEmoji  = confidence === "high"     ? "🔥"
                     : confidence === "moderate" ? "⚡"
                     : "🤔";

    await queueNotification({
      title: `AI Match Prediction is LIVE ${confEmoji}`,
      body:  `Our AI has picked a winner. See who it backs on CricView 👉`,
      topic: "ai_prediction",
      type:  "ai_prediction",
    });

    console.log(`✅ AI prediction notification queued`);
    return null;
  }
);

// ─────────────────────────────────────────────────────────────
//  4. DUGOUT REPLY NOTIFICATION — Firestore (unchanged)
// ─────────────────────────────────────────────────────────────
exports.dugoutReplyNotification = onDocumentCreated(
  "dugout_post/featured/comments/{commentId}",
  async (event) => {
    const reply = event.data.data();
    if (!reply?.replyTo) return null;

    const replierName = reply.userName || "Someone";
    const replyText   = reply.text     || "";
    const replierUid  = reply.userId   || "";

    const parentDoc = await admin.firestore()
      .collection("dugout_post/featured/comments")
      .doc(reply.replyTo).get();

    if (!parentDoc.exists) return null;

    const originalUid = parentDoc.data().userId;
    if (originalUid === replierUid) return null;

    const userDoc  = await admin.firestore()
      .collection("dugout_users").doc(originalUid).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return null;

    await queueNotification({
      title:        `${replierName} replied to you 💬`,
      body:         replyText.length > 80 ? replyText.slice(0, 80) + "…" : replyText,
      targetToken:  fcmToken,
      targetUserId: originalUid,
      type:         "dugout_reply",
    });

    return null;
  }
);