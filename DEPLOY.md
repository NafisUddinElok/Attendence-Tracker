# Deploying Attendance Tracker to Render

This guide walks you from a fresh clone to a running backend on Render with a managed Postgres database and a Flutter mobile app talking to it.

## 1. Push your code to GitHub

Render deploys from a Git repository. If `Attendence-Tracker` isn't already on GitHub:

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<you>/Attendence-Tracker.git
git push -u origin main
```

> Render's free plan requires the repo to be **public** *or* you to be on a paid plan. Public is fine for a class project.

## 2. Apply the Render blueprint

The repo ships a `render.yaml` that declares both services (API + Postgres) so you can launch them with one click.

1. Sign in at <https://dashboard.render.com>.
2. Click **New + → Blueprint**.
3. Point Render at your GitHub repo (e.g. `you/Attendence-Tracker`).
4. Render will detect `render.yaml` and show two services:
   - `attendance-db`   — managed PostgreSQL (free plan).
   - `attendance-api`  — Node.js web service, linked to the DB.
5. Click **Apply**. Render will:
   - Provision Postgres. `DATABASE_URL` is auto-injected into the web service.
   - Build the Node app (`npm ci --omit=dev`).
   - Start the server (`npm start`).
   - Run `database/tables/*.sql` then `database/migrations/*.sql` on first boot (because `DB_BOOTSTRAP=1`).

Provisioning usually takes 3–5 minutes.

## 3. Verify the API is live

Once the `attendance-api` service shows a green **Live** badge:

```
https://attendance-api.onrender.com/health
```

You should get back something like:

```json
{"status":"ok","uptime":12.3,"ts":1716470000000}
```

If you see a 502, the most common cause is that the migration failed. Open the service's **Logs** tab and look for `[bootstrap] migration failed:`. The SQL files are idempotent, so a re-deploy will simply retry.

## 4. (Optional) Override secrets

`render.yaml` auto-generates `JWT_ACCESS_SECRET` and `KDF_PEPPER`. To rotate them:

1. Open `attendance-api` → **Environment**.
2. Edit the value.
3. **Save** — Render redeploys.

> If you change `JWT_ACCESS_SECRET` after users have registered, all existing access tokens will be invalidated. Users will need to log in again. Refresh tokens stay valid because they live in the DB and are signed with `JWT_REFRESH_SECRET` (which you'll want to add the same way).

## 5. Point Flutter at the Render URL

The Flutter app already reads `API_BASE_URL` from a `--dart-define` flag (default is `http://10.0.2.2:5000` for the Android emulator).

For a **debug** run that talks to Render:

```bash
cd frontend/mobile_app
flutter run --dart-define=API_BASE_URL=https://attendance-api.onrender.com
```

For a **release** APK / AAB:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://attendance-api.onrender.com
```

For iOS:

```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://attendance-api.onrender.com
```

> On Android the emulator hits the host machine via `10.0.2.2`. Against Render there is no special host alias — the device just opens a TLS connection to `attendance-api.onrender.com`. Make sure **Cleartext traffic** is *off* for the release build (it is by default — Render serves HTTPS only).

## 6. CORS

For now the blueprint sets `CORS_ORIGINS=*`, which is fine because the Flutter client doesn't send an `Origin` header. If you later add a web frontend, lock this down to its origin:

```
CORS_ORIGINS=https://your-web-client.onrender.com
```

## 7. Schema migrations after the first deploy

`DB_BOOTSTRAP=1` is harmless to leave on — every SQL file is guarded with `IF NOT EXISTS`, so re-running it is a no-op. If you want to turn it off after the schema is settled:

1. `attendance-api` → **Environment** → `DB_BOOTSTRAP` → set to `0`.
2. Save. Next deploy skips the bootstrap step.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `ECONNREFUSED` in logs | `DATABASE_URL` missing or wrong | Verify the `fromService` link in `render.yaml` resolved. Check **Environment → DATABASE_URL**. |
| `self-signed certificate in certificate chain` | `DB_SSL=enable` but local Postgres without SSL | Set `DB_SSL=disable` (or unset `DATABASE_URL`). |
| `[bootstrap] migration failed: ...` | A migration is not idempotent | Open **Logs**, find the offending statement, fix the SQL, redeploy. |
| Flutter app shows "Network error" | Wrong `--dart-define` or the service is sleeping (free tier spins down) | First request after idle takes ~30s. Confirm with `curl https://attendance-api.onrender.com/health`. |

## Cost notes

- **Free Postgres**: 1 GB, expires after 90 days. After that you must re-provision.
- **Free web service**: spins down after 15 minutes of idle. First request is slow.
- **No credit card** is required to apply the blueprint.

If you need always-on, switch both services to a paid plan in **Settings → Plan**.