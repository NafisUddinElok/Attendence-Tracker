-- ============================================================
-- Remove leftover QR/TOTP attendance system
-- Migration: 002_remove_qr_totp.sql
--
-- Attendance marking no longer uses a rotating QR code (see
-- attendanceController.js / student_attendance_screen.dart — the
-- live app flow is geofence + BLE (optional) + device + face only).
-- totp_secret was only ever consumed by the old QR token endpoints,
-- which are being removed too. Safe to drop.
-- ============================================================

BEGIN;

ALTER TABLE attendance_sessions
    DROP COLUMN IF EXISTS totp_secret;

COMMIT;
