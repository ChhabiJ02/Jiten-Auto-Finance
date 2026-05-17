const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.deleteUserCompletely = functions.https.onCall(async (data, context) => {
  try {
    const uid = data.uid;

    if (!uid) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "UID is required"
      );
    }

    // Delete from Authentication
    await admin.auth().deleteUser(uid);

    // Delete from Firestore
    await admin.firestore()
      .collection("users")
      .doc(uid)
      .delete();

    return {
      success: true,
      message: "User deleted completely",
    };
  } catch (error) {
    console.error(error);

    throw new functions.https.HttpsError(
      "internal",
      error.message
    );
  }
});