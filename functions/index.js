const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendNotification = onDocumentCreated(
  "notifications/queue/pending/{docId}",
  async (event) => {
    const data = event.data.data();

    const message = {
      notification: {
        title: data.title,
        body: data.body,
        ...(data.imageUrl ? { imageUrl: data.imageUrl } : {}),
      },
      android: {
        notification: {
          sound: "default",
          ...(data.imageUrl ? { imageUrl: data.imageUrl } : {}),
        },
      },
      topic: data.topic || "cricket_notification",
      data: {
        type: data.type || "custom",
        extra: data.extra || "",
      },
    };

    try {
      await admin.messaging().send(message);
      await event.data.ref.update({
        status: "sent",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log("✅ Notification sent:", data.title);
    } catch (error) {
      await event.data.ref.update({ status: "failed", error: error.message });
      console.error("❌ Failed:", error);
    }
  }
);