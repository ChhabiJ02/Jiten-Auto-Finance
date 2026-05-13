const functions = require("firebase-functions");
const axios = require("axios");

const getApiKey = () => {
  try {
    return functions.config().twofactor.api_key;
  } catch (e) {
    throw new functions.https.HttpsError("internal", "API key not configured.");
  }
};

const otpRequestCount = {};
const MAX_REQUESTS_PER_HOUR = 5;

function isRateLimited(phone) {
  const now = Date.now();
  const windowMs = 60 * 60 * 1000;
  if (!otpRequestCount[phone]) {
    otpRequestCount[phone] = { count: 1, firstRequest: now };
    return false;
  }
  const entry = otpRequestCount[phone];
  if (now - entry.firstRequest > windowMs) {
    otpRequestCount[phone] = { count: 1, firstRequest: now };
    return false;
  }
  if (entry.count >= MAX_REQUESTS_PER_HOUR) return true;
  entry.count++;
  return false;
}

exports.sendAdminOtp = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "You must be logged in.");
  const phone = (data.phone || "").toString().trim();
  if (!phone || phone.length < 10) throw new functions.https.HttpsError("invalid-argument", "Valid phone number required.");
  if (isRateLimited(phone)) throw new functions.https.HttpsError("resource-exhausted", "Too many OTP requests. Please wait 1 hour.");
  try {
    const API_KEY = getApiKey();
    const response = await axios.get("https://2factor.in/API/V1/" + API_KEY + "/SMS/" + phone + "/AUTOGEN/OTP1");
    if (response.data.Status === "Success") {
      return { success: true, sessionId: response.data.Details, message: "OTP sent successfully." };
    } else {
      throw new functions.https.HttpsError("internal", "Failed to send OTP.");
    }
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    console.error("sendOtp error:", error.message);
    throw new functions.https.HttpsError("internal", "OTP sending failed.");
  }
});

exports.verifyAdminOtp = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "You must be logged in.");
  const sessionId = (data.sessionId || "").toString().trim();
  const otp = (data.otp || "").toString().trim();
  if (!sessionId || !otp || otp.length !== 6) throw new functions.https.HttpsError("invalid-argument", "Valid session ID and 6-digit OTP required.");
  try {
    const API_KEY = getApiKey();
    const response = await axios.get("https://2factor.in/API/V1/" + API_KEY + "/SMS/VERIFY/" + sessionId + "/" + otp);
    if (response.data.Status === "Success" && response.data.Details === "OTP Matched") {
      return { success: true, message: "OTP verified successfully." };
    } else {
      throw new functions.https.HttpsError("invalid-argument", "Invalid or expired OTP.");
    }
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    console.error("verifyOtp error:", error.message);
    throw new functions.https.HttpsError("internal", "OTP verification failed.");
  }
});

exports.resendAdminOtp = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "You must be logged in.");
  const phone = (data.phone || "").toString().trim();
  if (!phone || phone.length < 10) throw new functions.https.HttpsError("invalid-argument", "Valid phone number required.");
  if (isRateLimited(phone)) throw new functions.https.HttpsError("resource-exhausted", "Too many OTP requests. Please wait 1 hour.");
  try {
    const API_KEY = getApiKey();
    const response = await axios.get("https://2factor.in/API/V1/" + API_KEY + "/SMS/" + phone + "/AUTOGEN/OTP1");
    if (response.data.Status === "Success") {
      return { success: true, sessionId: response.data.Details, message: "OTP resent successfully." };
    } else {
      throw new functions.https.HttpsError("internal", "Failed to resend OTP.");
    }
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    console.error("resendOtp error:", error.message);
    throw new functions.https.HttpsError("internal", "OTP resend failed.");
  }
});