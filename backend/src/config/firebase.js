const admin = require('firebase-admin');
const fs = require('fs');

let initialized = false;

function loadServiceAccountFromEnv() {
  const {
    FIREBASE_SERVICE_ACCOUNT_JSON,
    FIREBASE_SERVICE_ACCOUNT_JSON_PATH,
    FIREBASE_PROJECT_ID,
    FIREBASE_CLIENT_EMAIL,
    FIREBASE_PRIVATE_KEY,
  } = process.env;

  if (FIREBASE_SERVICE_ACCOUNT_JSON_PATH) {
    const rawJson = fs.readFileSync(FIREBASE_SERVICE_ACCOUNT_JSON_PATH, 'utf8');
    return JSON.parse(rawJson);
  }

  if (FIREBASE_SERVICE_ACCOUNT_JSON) {
    return JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON);
  }

  if (FIREBASE_PROJECT_ID && FIREBASE_CLIENT_EMAIL && FIREBASE_PRIVATE_KEY) {
    return {
      projectId: FIREBASE_PROJECT_ID,
      clientEmail: FIREBASE_CLIENT_EMAIL,
      privateKey: FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    };
  }

  return null;
}

function initializeFirebase() {
  if (initialized) {
    return admin;
  }

  const serviceAccount = loadServiceAccountFromEnv();

  if (!serviceAccount) {
    console.warn('Firebase credentials are not configured. Push notifications are disabled.');
    return null;
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  initialized = true;
  return admin;
}

module.exports = {
  initializeFirebase,
};
