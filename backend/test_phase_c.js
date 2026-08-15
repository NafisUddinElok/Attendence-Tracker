// backend/test_phase_c.js
const { io } = require('socket.io-client');
const { generateTimeToken } = require('./src/utils/securityUtils');

const BASE_URL = 'http://localhost:5000';

// Safe Fetch Helper (Catches HTML / 404 / 500 cleanly)
async function safeFetch(url, options = {}) {
  const res = await fetch(url, options);
  const text = await res.text();
  try {
    return { ok: res.ok, status: res.status, data: JSON.parse(text) };
  } catch {
    throw new Error(`Server returned non-JSON (${res.status}): ${text.substring(0, 100)}`);
  }
}

async function testPhaseC() {
  console.log('\n🚀 --- STARTING PHASE C (TEACHER LIVE DASHBOARD & WEBSOCKET) TEST ---\n');

  try {
    // 1. Teacher Login
    const teacherLogin = await safeFetch(`${BASE_URL}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        role: 'TEACHER',
        email: 'ahmed@teacher.sust.edu',
        password: 'password123',
      }),
    });

    const teacherToken = teacherLogin.data.token;
    console.log('1. ✅ Teacher Logged In (Token Captured)');

    // 2. Course Creation / Resolution
    const courseRes = await safeFetch(`${BASE_URL}/api/courses`, {
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
    });

    let courseId = courseRes.data?.course?.id;

    if (!courseId) {
      const getCoursesRes = await safeFetch(`${BASE_URL}/api/courses`, {
        headers: { Authorization: `Bearer ${teacherToken}` },
      });
      courseId = getCoursesRes.data?.courses?.[0]?.id;
    }

    console.log(`2. ✅ Course Resolved (ID: ${courseId})`);

    // 3. Teacher Starts Session (GPS center: SUST)
    const sessionRes = await safeFetch(`${BASE_URL}/api/attendance/session/start`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${teacherToken}`,
      },
      body: JSON.stringify({
        courseId,
        title: 'Live Lab Session 01',
        centerLat: 24.9172,
        centerLng: 91.8319,
        radiusMeters: 50,
        durationMinutes: 15,
      }),
    });

    const sessionId = sessionRes.data.session.id;
    const totpSecret = sessionRes.data.session.totpSecret;
    console.log(`3. ✅ Live Session Created (ID: ${sessionId})`);
    console.log(`   🔑 TOTP Rolling Secret: ${totpSecret}`);

    // 4. Connect Teacher App to WebSocket
    const socket = io(BASE_URL, { transports: ['websocket'] });

    await new Promise((resolve, reject) => {
      socket.on('connect', () => {
        console.log('4. ⚡ Teacher WebSocket Connected to Server');
        socket.emit('join_session', sessionId);
        console.log(`   📡 Joined Room: session_${sessionId}`);
        resolve();
      });
      socket.on('connect_error', (err) => reject(err));
    });

    // Setup listener for real-time attendance event
    const attendanceReceived = new Promise((resolve) => {
      socket.on('attendance_marked', (data) => {
        console.log('\n🔔 [REAL-TIME WEBSOCKET EVENT RECEIVED IN TEACHER DASHBOARD]');
        console.log(`   👤 Student: ${data.fullName} (Reg: ${data.registrationNo})`);
        console.log(`   ⏰ Marked At: ${data.markedAt}\n`);
        resolve(data);
      });
    });

    // 5. Student Login & Enroll
    const studentLogin = await safeFetch(`${BASE_URL}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        role: 'STUDENT',
        email: 'nafis@student.sust.edu',
        password: 'password123',
      }),
    });

    const studentToken = studentLogin.data.token;

    await safeFetch(`${BASE_URL}/api/courses/enroll`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${studentToken}`,
      },
      body: JSON.stringify({ courseId }),
    });

    // Generate Current Live Dynamic Token
    const currentRollingToken = generateTimeToken(totpSecret);
    console.log(`5. 📲 Student Scanned Live QR Token: ${currentRollingToken}`);

    // 6. Submit Attendance
    const verifyRes = await safeFetch(`${BASE_URL}/api/attendance/verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${studentToken}`,
      },
      body: JSON.stringify({
        sessionId,
        token: currentRollingToken,
        deviceId: 'DEVICE_MAC_TEST_UUID_001',
        lat: 24.91721,
        lng: 91.83191,
        isMockLocation: false,
        livenessPassed: true,
        faceEmbedding: [
          0.045, -0.123, 0.789, 0.012, -0.567, 0.234, 0.891, -0.045,
          0.112, 0.456, -0.321, 0.654, -0.098, 0.876, -0.543, 0.210
        ],
      }),
    });

    console.log('6. ✅ Student Submission Status:', verifyRes.data.message);

    // 7. Wait for WebSocket push event
    await attendanceReceived;

    // 8. Check Live Stats from API
    const liveStats = await safeFetch(`${BASE_URL}/api/attendance/session/${sessionId}/live`, {
      headers: { Authorization: `Bearer ${teacherToken}` },
    });

    console.log(`7. 📊 Dashboard Live Attendees Count: ${liveStats.data.totalMarked}`);

    // 9. End Session
    const endRes = await safeFetch(`${BASE_URL}/api/attendance/session/${sessionId}/end`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${teacherToken}` },
    });

    console.log(`8. 🛑 Session Terminated: ${endRes.data.message}`);

    socket.disconnect();
    console.log('\n🎉 --- PHASE C FULL TEST COMPLETED SUCCESSFULLY! ---\n');
    process.exit(0);
  } catch (err) {
    console.error('\n❌ Phase C Test Failed:', err.message || err);
    process.exit(1);
  }
}

testPhaseC();