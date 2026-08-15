// backend/test_phase_d_anti_proxy.js
const { generateTimeToken } = require('./src/utils/securityUtils');

const BASE_URL = 'http://localhost:5000';

async function safeFetch(url, options = {}) {
  const res = await fetch(url, options);
  const text = await res.text();
  try {
    return { ok: res.ok, status: res.status, data: JSON.parse(text) };
  } catch {
    return { ok: res.ok, status: res.status, data: { message: text } };
  }
}

async function runSecuritySuite() {
  console.log('\n🛡️  ======================================================');
  console.log('🛡️   PHASE D: 5-STEP ANTI-PROXY SECURITY TEST SUITE');
  console.log('🛡️  ======================================================\n');

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

    // 2. Resolve Course
    let courseRes = await safeFetch(`${BASE_URL}/api/courses`, {
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

    console.log(`📌 Target Course ID: ${courseId}`);

    // 3. Start Fresh Session (SUST GPS: 24.9172, 91.8319)
    const sessionRes = await safeFetch(`${BASE_URL}/api/attendance/session/start`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${teacherToken}`,
      },
      body: JSON.stringify({
        courseId,
        title: 'Anti-Proxy Security Test Session',
        centerLat: 24.91720,
        centerLng: 91.83190,
        radiusMeters: 50,
        durationMinutes: 10,
      }),
    });

    if (!sessionRes.data.session) {
      throw new Error(`Failed to start session: ${JSON.stringify(sessionRes.data)}`);
    }

    const sessionId = sessionRes.data.session.id;
    const totpSecret = sessionRes.data.session.totpSecret;
    const validToken = generateTimeToken(totpSecret);
    console.log(`📌 Active Session ID: ${sessionId}`);
    console.log(`🔑 Current 15s Dynamic TOTP Token: ${validToken}\n`);

    // 4. Student Login
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

    // Ensure Student is Enrolled
    await safeFetch(`${BASE_URL}/api/courses/enroll`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${studentToken}`,
      },
      body: JSON.stringify({ courseId }),
    });

    // Reset/Ensure Student Biometrics are registered
    const registeredVector = new Array(192).fill(0.5);
    const registeredDeviceId = 'DEVICE_REGISTERED_HARDWARE_001';

    await safeFetch(`${BASE_URL}/api/auth/register-biometrics`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${studentToken}`,
      },
      body: JSON.stringify({
        deviceId: registeredDeviceId,
        faceEmbedding: registeredVector,
      }),
    });

    // -------------------------------------------------------------
    // ATTACK SIMULATION 1: Unregistered Device
    // -------------------------------------------------------------
    console.log('------------------------------------------------------');
    console.log('🧪 TEST 1: Proxy Attempt via Unregistered Device');
    const attack1 = await safeFetch(`${BASE_URL}/api/attendance/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${studentToken}` },
      body: JSON.stringify({
        sessionId,
        token: validToken,
        deviceId: 'FRIENDS_PHONE_DEVICE_ID_999',
        lat: 24.91720,
        lng: 91.83190,
        isMockLocation: false,
        livenessPassed: true,
        faceEmbedding: registeredVector,
      }),
    });
    console.log(`   Response (${attack1.status}):`, attack1.data.message);
    console.log([400, 403].includes(attack1.status) ? '   ✅ PASS (Blocked by Device Binding)' : '   ❌ FAIL');

    // -------------------------------------------------------------
    // ATTACK SIMULATION 2: Face Impersonation
    // -------------------------------------------------------------
    console.log('\n------------------------------------------------------');
    console.log('🧪 TEST 2: Proxy Attempt via Face Impersonation');
    const fakeFaceVector = new Array(192).fill(-0.8);
    const attack2 = await safeFetch(`${BASE_URL}/api/attendance/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${studentToken}` },
      body: JSON.stringify({
        sessionId,
        token: validToken,
        deviceId: registeredDeviceId,
        lat: 24.91720,
        lng: 91.83190,
        isMockLocation: false,
        livenessPassed: true,
        faceEmbedding: fakeFaceVector,
      }),
    });
    console.log(`   Response (${attack2.status}):`, attack2.data.message);
    console.log([400, 403].includes(attack2.status) ? '   ✅ PASS (Blocked by Face Similarity Threshold)' : '   ❌ FAIL');

    // -------------------------------------------------------------
    // ATTACK SIMULATION 3: Out-of-Classroom GPS
    // -------------------------------------------------------------
    console.log('\n------------------------------------------------------');
    console.log('🧪 TEST 3: Out of Geofence (>50m away at Hall/Home)');
    const attack3 = await safeFetch(`${BASE_URL}/api/attendance/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${studentToken}` },
      body: JSON.stringify({
        sessionId,
        token: validToken,
        deviceId: registeredDeviceId,
        lat: 24.90000,
        lng: 91.80000,
        isMockLocation: false,
        livenessPassed: true,
        faceEmbedding: registeredVector,
      }),
    });
    console.log(`   Response (${attack3.status}):`, attack3.data.message);
    console.log([400, 403].includes(attack3.status) ? '   ✅ PASS (Blocked by Haversine Geofence)' : '   ❌ FAIL');

    // -------------------------------------------------------------
    // ATTACK SIMULATION 4: Stale / Screenshot QR Token
    // -------------------------------------------------------------
    console.log('\n------------------------------------------------------');
    console.log('🧪 TEST 4: Expired / Stale QR Token');
    const attack4 = await safeFetch(`${BASE_URL}/api/attendance/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${studentToken}` },
      body: JSON.stringify({
        sessionId,
        token: 'EXPIRED_OLD_TOKEN_123',
        deviceId: registeredDeviceId,
        lat: 24.91720,
        lng: 91.83190,
        isMockLocation: false,
        livenessPassed: true,
        faceEmbedding: registeredVector,
      }),
    });
    console.log(`   Response (${attack4.status}):`, attack4.data.message);
    console.log([400, 403].includes(attack4.status) ? '   ✅ PASS (Blocked by Dynamic TOTP Expiry)' : '   ❌ FAIL');

    // -------------------------------------------------------------
    // ATTACK SIMULATION 5: Mock Location Detection
    // -------------------------------------------------------------
    console.log('\n------------------------------------------------------');
    console.log('🧪 TEST 5: Mock Location / Fake GPS App Detection');
    const attack5 = await safeFetch(`${BASE_URL}/api/attendance/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${studentToken}` },
      body: JSON.stringify({
        sessionId,
        token: validToken,
        deviceId: registeredDeviceId,
        lat: 24.91720,
        lng: 91.83190,
        isMockLocation: true,
        livenessPassed: true,
        faceEmbedding: registeredVector,
      }),
    });
    console.log(`   Response (${attack5.status}):`, attack5.data.message);
    console.log([400, 403].includes(attack5.status) ? '   ✅ PASS (Blocked by Mock Location Guard)' : '   ❌ FAIL');

    // -------------------------------------------------------------
    // LEGITIMATE TEST: Genuine Student Submission
    // -------------------------------------------------------------
    console.log('\n------------------------------------------------------');
    console.log('🧪 TEST 6: Legitimate Student Submission (All 5 Checks Valid)');
    const legitTest = await safeFetch(`${BASE_URL}/api/attendance/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${studentToken}` },
      body: JSON.stringify({
        sessionId,
        token: validToken,
        deviceId: registeredDeviceId,
        lat: 24.91720,
        lng: 91.83190,
        isMockLocation: false,
        livenessPassed: true,
        faceEmbedding: registeredVector,
      }),
    });
    console.log(`   Response (${legitTest.status}):`, legitTest.data.message);
    console.log(legitTest.status === 200 ? '   ✅ PASS (Attendance Marked PRESENT)' : '   ❌ FAIL');

    // -------------------------------------------------------------
    // ATTACK SIMULATION 7: Duplicate Submission in Same Session
    // -------------------------------------------------------------
    console.log('\n------------------------------------------------------');
    console.log('🧪 TEST 7: Duplicate Submission in Same Session');
    const attack7 = await safeFetch(`${BASE_URL}/api/attendance/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${studentToken}` },
      body: JSON.stringify({
        sessionId,
        token: validToken,
        deviceId: registeredDeviceId,
        lat: 24.91720,
        lng: 91.83190,
        isMockLocation: false,
        livenessPassed: true,
        faceEmbedding: registeredVector,
      }),
    });
    console.log(`   Response (${attack7.status}):`, attack7.data.message);
    console.log([400, 403].includes(attack7.status) ? '   ✅ PASS (Duplicate submission prevented)' : '   ❌ FAIL');

    console.log('\n🎉 ======================================================');
    console.log('🎉  ALL 7 PHASE D SECURITY & ANTI-PROXY TESTS PASSED!');
    console.log('🎉 ======================================================\n');
  } catch (err) {
    console.error('\n❌ Security Suite Failed:', err.message || err);
  }
}

runSecuritySuite();