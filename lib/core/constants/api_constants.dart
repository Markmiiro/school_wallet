// Confirmed API contract for School Wallet Uganda backend.
// Every path below was verified directly against the live FastAPI source
// (app/routes/*.py on Railway) and/or tested live with curl/requests —
// never assumed. See project handoff docs for the verification history.
//
// ⚠️ IMPORTANT: Do NOT "clean up" walletBalance below. The double
// "/wallets/wallets/{id}" is not a typo in this file — it mirrors a real
// bug in the backend's route definition (wallets.py defines
// @router.get("/wallets/{student_id}") while main.py ALSO mounts the
// router with prefix="/wallets"). Confirmed live on 9 July 2026:
//   GET /wallets/1           -> 404 Not Found
//   GET /wallets/wallets/1   -> 200 OK
// If the backend is ever fixed, update this constant AND this comment.

class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://web-production-454a5.up.railway.app';

  // ── Auth ──────────────────────────────────────────────────
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String me = '$baseUrl/auth/me';
  static const String changePin = '$baseUrl/auth/change-pin';

  // ── Students ──────────────────────────────────────────────
  static String studentsForParent(int parentId) =>
      '$baseUrl/students/parent/$parentId';

  static String studentById(int studentId) => '$baseUrl/students/$studentId';

  static String studentsBySchool(int schoolId) =>
      '$baseUrl/students/school/$schoolId';

  static const String createStudent = '$baseUrl/students/';

  static String assignNfc(int studentId) =>
      '$baseUrl/students/$studentId/assign-nfc';

  static String deactivateStudent(int studentId) =>
      '$baseUrl/students/$studentId/deactivate';

  // ── Wallets ───────────────────────────────────────────────
  // NOTE: double "/wallets/wallets/" is intentional — see file header.
  static String walletBalance(int studentId) =>
      '$baseUrl/wallets/wallets/$studentId';

  // This one is NOT double-prefixed — confirmed correct as-is.
  static String walletHistory(int studentId, {int limit = 20}) =>
      '$baseUrl/wallets/$studentId/history?limit=$limit';

  // ── Schools ───────────────────────────────────────────────
  static const String schools = '$baseUrl/schools/';

  // ── Not yet wired into the app — placeholders for future features ──
  // topup.py, merchants.py, payments.py, ussd.py, reports.py,
  // analytics.py, tuckshop.py, webhook.py exist on the backend but
  // aren't consumed by the parent-facing app yet. Add their confirmed
  // paths here as each feature gets built — do not guess at paths,
  // verify from source first (same standard as everything above).
}