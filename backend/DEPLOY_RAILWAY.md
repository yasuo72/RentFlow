# RentFlow Backend on Railway

## What is already prepared

- Railway can deploy from the repo root because the root `package.json` forwards startup to `backend/`.
- The backend now:
  - listens on `0.0.0.0:$PORT`
  - trusts the Railway proxy
  - shuts down cleanly on `SIGTERM`
  - auto-creates the first `super_admin` account if one does not exist
  - supports comma-separated `CLIENT_URL` values for CORS

## Railway environment variables

Set these in Railway:

- `PORT=5000`
- `MONGODB_URI=...`
- `JWT_SECRET=...`
- `JWT_EXPIRES_IN=30d`
- `CLIENT_URL=*`
- `CLOUDINARY_CLOUD_NAME=...`
- `CLOUDINARY_API_KEY=...`
- `CLOUDINARY_API_SECRET=...`
- `SUPER_ADMIN_NAME=Owner`
- `SUPER_ADMIN_PHONE=...`
- `SUPER_ADMIN_PASSWORD=...`
- `SUPER_ADMIN_EMAIL=...`

Optional Firebase push configuration:

- `FIREBASE_SERVICE_ACCOUNT_JSON={...}`

or

- `FIREBASE_PROJECT_ID=...`
- `FIREBASE_CLIENT_EMAIL=...`
- `FIREBASE_PRIVATE_KEY=...`

For Railway, prefer `FIREBASE_SERVICE_ACCOUNT_JSON` instead of a local JSON file path.

## Recommended Railway notes

- Keep `ENABLE_SCHEDULED_JOBS=true` only on one backend replica, otherwise rent reminder jobs will run multiple times.
- Use the Railway health check path:
  - `/health`
- If you later deploy a web frontend, replace `CLIENT_URL=*` with your exact domains:
  - `https://your-app.up.railway.app,https://your-custom-domain.com`
