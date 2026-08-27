# Attendance System - Backend

Express + PostgreSQL (Sequelize) backend for a location-based class attendance system.

## Setup

```bash
cd attendance-backend
npm install
cp .env.example .env   # then edit .env with your DB credentials + JWT secret
```

Create the database (once):
```bash
createdb attendance_db
```

Run the server (auto-creates/syncs tables from the Sequelize models):
```bash
npm run dev
```

Alternatively, you can run `db/schema.sql` directly against Postgres for a fully explicit schema
(recommended for production instead of `sequelize.sync`).

## Folder Structure

```
attendance-backend/
├── src/
│   ├── config/db.js          # Sequelize connection
│   ├── models/                # Sequelize models + associations (index.js)
│   ├── controllers/           # auth / admin / teacher / student logic
│   ├── routes/                # route definitions per role
│   ├── middleware/             # JWT auth + role-based access control
│   ├── utils/                 # haversine.js (distance calc), csvGenerator.js
│   └── app.js                 # express app config
├── generated_csv/             # CSV files saved here after sessions end
├── db/schema.sql              # raw SQL schema (alternative to sequelize.sync)
├── server.js                  # entry point
└── package.json
```

## Roles & Flow Summary

- **Admin**: creates teachers/students, creates courses, assigns teacher to course,
  enrolls students, and resolves drop-course notifications sent by teachers.
- **Teacher**: starts a session (GPS + radius), ends a session (auto-generates a CSV of
  that class's attendance), downloads per-session CSV, downloads a student-wise course
  summary CSV, and sends drop-course enroll requests to admin.
- **Student**: views enrolled courses, checks for an active session, and marks
  attendance (only accepted if within the session's GPS radius).

## Key Endpoints

| Method | Route | Role | Purpose |
|---|---|---|---|
| POST | /auth/register | - | create account |
| POST | /auth/login | - | get JWT |
| POST | /admin/teachers | admin | create teacher |
| POST | /admin/students | admin | create student |
| POST | /admin/courses | admin | create course |
| PUT | /admin/courses/:courseId/assign-teacher | admin | assign teacher |
| POST | /admin/enroll | admin | enroll student in course |
| GET | /admin/notifications | admin | view drop-course requests |
| POST | /admin/notifications/:id/resolve | admin | approve + enroll |
| GET | /teacher/courses | teacher | list own courses |
| POST | /teacher/session/start | teacher | start class session (lat/long/radius) |
| POST | /teacher/session/:id/end | teacher | end session -> generates CSV |
| GET | /teacher/session/:id/attendance-csv | teacher | download that class's CSV |
| GET | /teacher/course/:id/summary-csv | teacher | student-wise full history CSV |
| POST | /teacher/drop-course-request | teacher | notify admin to enroll a reg. no |
| GET | /student/courses | student | list enrolled courses |
| GET | /student/session/active/:courseId | student | check for a live session |
| POST | /student/attendance/mark | student | mark attendance (lat/long) |

All routes except `/auth/*` require header: `Authorization: Bearer <token>`
