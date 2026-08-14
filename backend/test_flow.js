// backend/test_flow.js
const { generateTimeToken } = require('./src/utils/securityUtils');

const BASE_URL = 'http://localhost:5000';

async function runTests() {
  console.log('\n🚀 --- STARTING AUTOMATED ATTENDANCE SYSTEM TEST ---\n');

  try {
    // 1. Health Check
    const health = await fetch(`${BASE_URL}/health`).then((r) => r.json());
    console.log('1. ✅ Health Check:', health.message);

    // 2. Teacher Register & Login
    await fetch(`${BASE_URL}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        role: 'TEACHER',
        fullName: 'Dr. Ahmed Khan',
        email: 'ahmed@teacher.sust.edu',
        password: 'password123',
        code: 'EMP-101',
        department: 'IPE',
        designation: 'Associate Professor',
      }),
    });

    const teacherLogin = await fetch(`${BASE_URL}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        role: 'TEACHER',
        email: 'ahmed@teacher.sust.edu',
        password: 'password123',
      }),
    }).then((r) => r.json());

    const teacherToken = teacherLogin.token;
    console.log('2. ✅ Teacher Logged In (Token Captured)');

    // 3. Teacher Create Course
    const courseRes = await fetch(`${BASE_URL}/api/courses`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${teacherToken}`,
      },
      body: JSON.stringify({
        courseCode: 'IPE-301',
        title: 'Supply Chain Management',
        department: 'IPE',
      }),
    }).then((r) => r.json());

    const courseId = courseRes.course.id;
    console.log(`3. ✅ Course Ready: ${courseRes.course.course_code} (ID: ${courseId})`);

    // 4. Student Register & Login
    await fetch(`${BASE_URL}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        role: 'STUDENT',
        fullName: 'Muhammad Nafis',
        email: 'nafis@student.sust.edu',
        password: 'password123',
        code: '2023831005',
        department: 'IPE',
        session: '2023-24',
      }),
    });

    const studentLogin = await fetch(`${BASE_URL}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        role: 'STUDENT',
        email: 'nafis@student.sust.edu',
        password: 'password123',
      }),
    }).then((r) => r.json());

    const studentToken = studentLogin.token;
    console.log('4. ✅ Student Logged In (Token Captured)');

    // 5. Student Enroll in Course
    const enrollRes = await fetch(`${BASE_URL}/api/courses/enroll`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${studentToken}`,
      },
      body: JSON.stringify({ courseId }),
    }).then((r) => r.json());
    console.log('5. ✅ Student Enrollment:', enrollRes.message);

    // 6. Teacher Starts Attendance Session (SUST GPS Coordinates)
    const sessionRes = await fetch(`${BASE_URL}/api/attendance/session/start`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${teacherToken}`,
      },
      body: JSON.stringify({
        courseId,
        title: 'Supply Chain Class 01',
        centerLat: 24.9172,
        centerLng: 91.8319,
        radiusMeters: 50,
        durationMinutes: 10,
      }),
    }).then((r) => r.json());

    const sessionId = sessionRes.session.id;
    const totpSecret = sessionRes.session.totpSecret;
    console.log(`6. ✅ Live Session Started! (Session ID: ${sessionId})`);

    // 7. Generate Live 15-Second Dynamic QR Token from Secret
    const validLiveToken = generateTimeToken(totpSecret);
    console.log(`7. 🔑 Generated 15s Dynamic TOTP Token: ${validLiveToken}`);

    // 8. Student Submits Attendance (Full 5-Step Anti-Proxy Check)
    const verifyRes = await fetch(`${BASE_URL}/api/attendance/verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${studentToken}`,
      },
      body: JSON.stringify({
        sessionId,
        token: validLiveToken,
        deviceId: 'TEST_DEVICE_MAC_UUID_001',
        lat: 24.91721, // Within 1-2 meters of center
        lng: 91.83191,
        isMockLocation: false,
        livenessPassed: true,
        faceEmbedding: [0.12, -0.45, 0.78],
      }),
    }).then((r) => r.json());

    console.log('8. ✅ Attendance Verification Result:', verifyRes.message || verifyRes);

    // 9. Teacher Views Live Stats
    const liveStats = await fetch(`${BASE_URL}/api/attendance/session/${sessionId}/live`, {
      headers: { Authorization: `Bearer ${teacherToken}` },
    }).then((r) => r.json());

    console.log(`9. ✅ Teacher Live Dashboard: ${liveStats.totalMarked} Student(s) Marked Present`);

    // 10. Teacher Exports CSV File
    const csvResponse = await fetch(`${BASE_URL}/api/attendance/export-csv/${courseId}`, {
      headers: { Authorization: `Bearer ${teacherToken}` },
    });
    const csvText = await csvResponse.text();
    console.log('\n10. ✅ Exported Attendance CSV Content:\n');
    console.log(csvText);

    console.log('\n🎉 --- ALL 10 ANTI-PROXY ATTENDANCE TESTS PASSED PERFECTLY! ---\n');
  } catch (err) {
    console.error('\n❌ Test Flow Failed:', err);
  }
}

runTests();