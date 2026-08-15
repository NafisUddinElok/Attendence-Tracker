// backend/test_export.js
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://localhost:5000';

async function testExportEndpoints() {
  console.log('\n📊 --- TESTING TEACHER EXCEL & CSV REPORT EXPORTS ---\n');

  try {
    // 1. Teacher Login
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
    console.log('1. ✅ Teacher Authenticated');

    // 2. Fetch Course
    const coursesRes = await fetch(`${BASE_URL}/api/courses`, {
      headers: { Authorization: `Bearer ${teacherToken}` },
    }).then((r) => r.json());

    const course = coursesRes.courses[0];
    const courseId = course.id;
    console.log(`2. ✅ Target Course: ${course.course_code} - ${course.title} (ID: ${courseId})`);

    // 3. Test CSV Export
    console.log('3. 📥 Downloading CSV Attendance Sheet...');
    const csvRes = await fetch(`${BASE_URL}/api/reports/course/${courseId}/csv`, {
      headers: { Authorization: `Bearer ${teacherToken}` },
    });

    if (csvRes.status !== 200) {
      throw new Error(`CSV Export failed with status ${csvRes.status}`);
    }

    const csvText = await csvRes.text();
    const csvPath = path.join(__dirname, `${course.course_code}_Report.csv`);
    fs.writeFileSync(csvPath, csvText);
    console.log(`   ✅ CSV saved successfully to: ${csvPath}`);
    console.log(`   📄 Preview:\n${csvText.split('\n').slice(0, 5).join('\n')}\n`);

    // 4. Test Excel Export
    console.log('4. 📥 Downloading Formatted Excel Sheet (.xlsx)...');
    const excelRes = await fetch(`${BASE_URL}/api/reports/course/${courseId}/excel`, {
      headers: { Authorization: `Bearer ${teacherToken}` },
    });

    if (excelRes.status !== 200) {
      throw new Error(`Excel Export failed with status ${excelRes.status}`);
    }

    const arrayBuffer = await excelRes.arrayBuffer();
    const excelBuffer = Buffer.from(arrayBuffer);
    const excelPath = path.join(__dirname, `${course.course_code}_Report.xlsx`);
    fs.writeFileSync(excelPath, excelBuffer);
    console.log(`   ✅ Formatted Excel workbook saved successfully to: ${excelPath} (${excelBuffer.length} bytes)`);

    console.log('\n🎉 --- EXPORT ENGINE TEST COMPLETED SUCCESSFULLY! ---\n');
  } catch (err) {
    console.error('\n❌ Export Test Failed:', err.message || err);
  }
}

testExportEndpoints();