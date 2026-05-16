const admin = require('firebase-admin');
const fs = require('fs');

let initialized = false;

function parseServiceAccountJson(rawValue, sourceLabel) {
  try {
    return JSON.parse(rawValue);
  } catch (error) {
    console.warn(
      `Firebase credentials from ${sourceLabel} could not be parsed. Push notifications are disabled.`,
    );
    return null;
  }
}

function loadServiceAccountFromEnv() {
  const {
    FIREBASE_SERVICE_ACCOUNT_JSON,
    FIREBASE_SERVICE_ACCOUNT_JSON_PATH,
    FIREBASE_PROJECT_ID,
    FIREBASE_CLIENT_EMAIL,
    FIREBASE_PRIVATE_KEY,
  } = process.env;

  if (FIREBASE_SERVICE_ACCOUNT_JSON) {
    const fromJsonEnv = parseServiceAccountJson(
      FIREBASE_SERVICE_ACCOUNT_JSON,
      'FIREBASE_SERVICE_ACCOUNT_JSON',
    );

    if (fromJsonEnv) {
      return fromJsonEnv;
    }
  }

  if (FIREBASE_SERVICE_ACCOUNT_JSON_PATH) {
    if (!fs.existsSync(FIREBASE_SERVICE_ACCOUNT_JSON_PATH)) {
      console.warn(
        `Firebase credentials file was not found at "${FIREBASE_SERVICE_ACCOUNT_JSON_PATH}". Push notifications are disabled unless FIREBASE_SERVICE_ACCOUNT_JSON is provided.`,
      );
    } else {
      const rawJson = fs.readFileSync(FIREBASE_SERVICE_ACCOUNT_JSON_PATH, 'utf8');
      const fromPath = parseServiceAccountJson(
        rawJson,
        'FIREBASE_SERVICE_ACCOUNT_JSON_PATH',
      );

      if (fromPath) {
        return fromPath;
      }
    }
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
