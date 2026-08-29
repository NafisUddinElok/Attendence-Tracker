# Attendance Management System

A full-stack university attendance management system with GPS-based geofencing and role-based access control. The application allows teachers to take attendance within a defined classroom radius, students to verify their presence using device location, and administrators to manage academic records.

## Overview

Traditional attendance methods such as paper sheets and roll calls are time-consuming and vulnerable to proxy attendance. This system provides a digital solution where:

- **Teachers** can initiate time-limited attendance sessions with a defined GPS radius (e.g., 30 meters).
- **Students** can mark their attendance only if their physical device location is within the allowed geofenced area.
- **Administrators** oversee academic entities including departments, faculty accounts, student registrations, and course assignments.

The application supports three user roles: **Admin**, **Teacher**, and **Student**.

---

## Features

### Admin
- **Student Management**: Register new students using their registration number. The system automatically parses the student's admission year, academic session, and department from the registration number.
- **Teacher Management**: Register faculty members and assign them to specific academic departments.
- **Class Management**: Create courses and assign teachers. Creating a class automatically enrolls all active students belonging to that department and academic session.
- **Class Status Control**: View active classes and end or archive completed courses.
- **Password Reset**: Manually reset or override passwords for any user account.

### Teacher
- **Authentication**: Secure login using email and password.
- **Class Overview**: View assigned classes, total enrollments, and course details.
- **Live Attendance Sessions**:
  - Start an attendance session with customizable GPS radius (in meters) and expiration time (in minutes).
  - Live dashboard showing real-time student check-ins.
  - Manually stop an active session at any time.
- **Student Roster Management**: View enrolled students in a class, add additional students, or remove existing enrollments.
- **Attendance Reports**:
  - View a summary matrix showing total sessions, sessions attended, and attendance percentage per student.
  - Export attendance reports directly to CSV format.

### Student
- **Authentication**: Login using student registration number and password.
- **Enrolled Classes**: View all currently enrolled active courses.
- **GPS Attendance Submission**:
  - Discover active attendance sessions for enrolled classes.
  - Submit attendance with one tap; the system calculates the distance from the teacher's coordinates using the Haversine formula and validates that the student is within the allowed radius.
  - Device install identifier tracking to prevent multiple submissions from the same physical device.
- **Attendance History**: View past attendance records and overall attendance percentage per course.

---

## Technology Stack

### Frontend
- **Framework**: Flutter (Dart)
- **State Management**: Riverpod (`flutter_riverpod`)
- **Navigation**: GoRouter (`go_router`)
- **Location Services**: Geolocator (`geolocator`)
- **Storage**: SharedPreferences (`shared_preferences`)
- **Networking**: `http`

### Backend
- **Framework**: Dart Frog (Server-side Dart)
- **Database**: PostgreSQL
- **Authentication**: JSON Web Tokens (`dart_jsonwebtoken`) and BCrypt password hashing (`bcrypt`)
- **Calculations**: Haversine distance algorithm for geospatial validation

### Infrastructure
- **Containerization**: Docker & Docker Compose (for PostgreSQL)

---

## Project Structure

```text
attSystem/
├── backend/
│   ├── lib/
│   │   ├── db/                 # Database connection, schema migrations, and seed scripts
│   │   ├── middleware/         # JWT authentication and role-based guards
│   │   └── utils/              # Haversine distance calculation and registration parser
│   ├── routes/
│   │   └── api/
│   │       ├── admin/          # Admin endpoints (students, teachers, classes, password reset)
│   │       ├── attendance/     # Attendance claim verification endpoint
│   │       ├── auth/           # Login and token generation
│   │       ├── classes/        # Class rosters, attendance reports, and CSV export
│   │       ├── sessions/       # Session management (start, stop, active records)
│   │       ├── student/        # Student classes, active sessions, and attendance history
│   │       └── teacher/        # Teacher class listings
│   └── pubspec.yaml
│
├── frontend/
│   ├── lib/
│   │   ├── core/               # Theme definitions, router configuration, and constants
│   │   ├── data/               # Data models and API client repository
│   │   ├── providers/          # Riverpod state providers and controllers
│   │   ├── screens/
│   │   │   ├── admin/          # Admin screens (dashboard, class/user creation, password reset)
│   │   │   ├── auth/           # Login screen
│   │   │   ├── student/        # Student dashboard, live claim screen, and history
│   │   │   └── teacher/        # Teacher dashboard, live session monitor, and reports
│   │   └── widgets/            # Reusable UI components (radar animation, cards, buttons)
│   └── pubspec.yaml
│
└── docker-compose.yml          # PostgreSQL database container setup
```

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.0.0 or higher)
- [Dart SDK](https://dart.dev/get-dart)
- [Dart Frog CLI](https://dartfrog.vgv.dev/docs/overview): install via `dart pub global activate dart_frog_cli`
- [PostgreSQL](https://www.postgresql.org) or [Docker Desktop](https://www.docker.com)

### 1. Database Setup
Start the PostgreSQL instance:

```bash
# Using Docker
docker compose up -d

# Or using a local PostgreSQL installation
createdb attdb
```

### 2. Backend Setup
Navigate to the backend directory, install dependencies, and start the server:

```bash
cd backend
dart pub get
dart_frog dev
```

The server will run on `http://localhost:8080`. Database tables and initial demo data are created automatically on startup.

### 3. Frontend Setup
In a new terminal window, navigate to the frontend directory and start the application:

```bash
cd frontend
flutter pub get

# Run on Web (Chrome)
flutter run -d chrome

# Or run on a connected device/emulator
flutter run
```

---

## Default Demo Accounts

On initial run, the system automatically populates the database with demo accounts:

| Role | Username / Identifier | Password | Details |
|---|---|---|---|
| **Admin** | `admin@example.com` | `password` | Super Admin account |
| **Teacher** | `teacher@example.com` | `password` | Software Engineering Faculty |
| **Student** | `2023831001` – `2023831060` | *(Same as Reg No)* | 60 demo students (e.g. `2023831018` / `2023831018`) |

A sample course (`SWE-301: Software Architecture`) is automatically created and assigned to the demo teacher with all 60 students enrolled.

---

## License

This project is open source and available under the [MIT License](LICENSE).
