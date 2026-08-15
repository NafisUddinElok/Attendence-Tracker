const db = require('../config/db');
const ExcelJS = require('exceljs');

// Helper: Query aggregate course & attendance data
async function getCourseAttendanceData(courseId, teacherId) {
  // 1. Verify Course Ownership & Teacher Details
  const courseQuery = await db.query(
    `SELECT c.id, c.course_code, c.title, c.department, t.full_name AS teacher_name, t.email AS teacher_email
     FROM courses c
     JOIN teachers t ON c.teacher_id = t.id
     WHERE c.id = $1 AND c.teacher_id = $2`,
    [courseId, teacherId]
  );

  if (courseQuery.rows.length === 0) {
    return { error: 'Course not found or unauthorized', status: 404 };
  }

  const course = courseQuery.rows[0];

  // 2. Count Total Sessions Conducted for this Course
  const sessionCountQuery = await db.query(
    'SELECT COUNT(*)::int AS total_sessions FROM attendance_sessions WHERE course_id = $1',
    [courseId]
  );
  const totalSessions = sessionCountQuery.rows[0].total_sessions || 0;

  // 3. Aggregate Student Attendance Count & Calculate SUST Eligibility
  const studentsQuery = await db.query(
    `SELECT 
       st.id,
       st.registration_no,
       st.full_name,
       st.department,
       st.session,
       COUNT(DISTINCT a.session_id)::int AS attended_sessions
     FROM enrollments e
     JOIN students st ON e.student_id = st.id
     LEFT JOIN attendance_records a 
       ON a.student_id = st.id 
      AND a.session_id IN (SELECT id FROM attendance_sessions WHERE course_id = $1)
     WHERE e.course_id = $1
     GROUP BY st.id, st.registration_no, st.full_name, st.department, st.session
     ORDER BY st.registration_no ASC`,
    [courseId]
  );

  const studentRecords = studentsQuery.rows.map((student) => {
    const attended = student.attended_sessions;
    const percentage = totalSessions > 0 ? parseFloat(((attended / totalSessions) * 100).toFixed(2)) : 0.0;

    let eligibility = 'Discollegiate (Ineligible)';
    if (totalSessions === 0) {
      eligibility = 'N/A';
    } else if (percentage >= 75.0) {
      eligibility = 'Collegiate (Eligible)';
    } else if (percentage >= 60.0) {
      eligibility = 'Non-Collegiate (Fine Required)';
    }

    return {
      registrationNo: student.registration_no,
      fullName: student.full_name,
      department: student.department || 'SUST',
      session: student.session || 'N/A',
      attendedSessions: attended,
      totalSessions: totalSessions,
      percentage: percentage,
      eligibility: eligibility,
    };
  });

  return {
    course,
    totalSessions,
    totalStudents: studentRecords.length,
    students: studentRecords,
  };
}

// -------------------------------------------------------------
// 1. EXPORT AS FORMATTED EXCEL (.XLSX)
// -------------------------------------------------------------
exports.exportCourseExcel = async (req, res) => {
  const { courseId } = req.params;
  const teacherId = req.user.id;

  try {
    const reportData = await getCourseAttendanceData(courseId, teacherId);
    if (reportData.error) {
      return res.status(reportData.status).json({ message: reportData.error });
    }

    const { course, totalSessions, totalStudents, students } = reportData;

    // Create Excel Workbook
    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'SUST Smart Attendance Engine';
    workbook.created = new Date();

    const sheet = workbook.addWorksheet(`${course.course_code} Attendance`, {
      views: [{ showGridLines: true }],
    });

    // --- Header Branding ---
    sheet.mergeCells('A1:G1');
    sheet.getCell('A1').value = 'SHAHJALAL UNIVERSITY OF SCIENCE AND TECHNOLOGY';
    sheet.getCell('A1').font = { name: 'Arial', size: 14, bold: true, color: { argb: 'FFFFFFFF' } };
    sheet.getCell('A1').fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1A237E' } }; // Indigo
    sheet.getCell('A1').alignment = { horizontal: 'center', vertical: 'middle' };
    sheet.getRow(1).height = 30;

    sheet.mergeCells('A2:G2');
    sheet.getCell('A2').value = `Course: ${course.course_code} - ${course.title} | Teacher: ${course.teacher_name}`;
    sheet.getCell('A2').font = { name: 'Arial', size: 11, italic: true, color: { argb: 'FF333333' } };
    sheet.getCell('A2').alignment = { horizontal: 'center', vertical: 'middle' };
    sheet.getRow(2).height = 22;

    sheet.mergeCells('A3:G3');
    sheet.getCell('A3').value = `Total Classes Held: ${totalSessions} | Total Enrolled Students: ${totalStudents} | Generated: ${new Date().toLocaleDateString()}`;
    sheet.getCell('A3').font = { name: 'Arial', size: 10, color: { argb: 'FF666666' } };
    sheet.getCell('A3').alignment = { horizontal: 'center', vertical: 'middle' };
    sheet.getRow(3).height = 20;

    sheet.addRow([]); // Blank row spacer

    // --- Table Column Headers ---
    const headers = [
      'Registration No',
      'Student Name',
      'Department',
      'Attended',
      'Total Classes',
      'Percentage (%)',
      'SUST 75% Eligibility Status',
    ];

    const headerRow = sheet.addRow(headers);
    headerRow.height = 25;
    headerRow.eachCell((cell) => {
      cell.font = { name: 'Arial', size: 11, bold: true, color: { argb: 'FFFFFFFF' } };
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF283593' } };
      cell.alignment = { horizontal: 'center', vertical: 'middle' };
      cell.border = {
        top: { style: 'thin', color: { argb: 'FFB0BEC5' } },
        bottom: { style: 'medium', color: { argb: 'FF000000' } },
      };
    });

    // --- Student Rows & Color-coded Eligibility ---
    students.forEach((st) => {
      const row = sheet.addRow([
        st.registrationNo,
        st.fullName,
        st.department,
        st.attendedSessions,
        st.totalSessions,
        `${st.percentage.toFixed(1)}%`,
        st.eligibility,
      ]);

      row.height = 22;

      // Center-align numeric & code cells
      row.getCell(1).alignment = { horizontal: 'center', vertical: 'middle' };
      row.getCell(3).alignment = { horizontal: 'center', vertical: 'middle' };
      row.getCell(4).alignment = { horizontal: 'center', vertical: 'middle' };
      row.getCell(5).alignment = { horizontal: 'center', vertical: 'middle' };
      row.getCell(6).alignment = { horizontal: 'center', vertical: 'middle' };
      row.getCell(7).alignment = { horizontal: 'center', vertical: 'middle' };

      // Color-code the Eligibility Status Cell
      const statusCell = row.getCell(7);
      if (st.eligibility.includes('Collegiate (Eligible)')) {
        statusCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE8F5E9' } }; // Light green
        statusCell.font = { color: { argb: 'FF2E7D32' }, bold: true };
      } else if (st.eligibility.includes('Non-Collegiate')) {
        statusCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFF3E0' } }; // Light orange
        statusCell.font = { color: { argb: 'FFE65100' }, bold: true };
      } else {
        statusCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFEBEE' } }; // Light red
        statusCell.font = { color: { argb: 'FFC62828' }, bold: true };
      }

      // Add light borders to row
      row.eachCell((cell) => {
        cell.border = {
          bottom: { style: 'thin', color: { argb: 'FFE0E0E0' } },
        };
      });
    });

    // Auto-fit Column Widths
    sheet.columns.forEach((column) => {
      let maxLen = 15;
      column.eachCell({ includeEmpty: true }, (cell) => {
        const val = cell.value ? cell.value.toString() : '';
        if (val.length > maxLen) maxLen = Math.min(val.length + 3, 35);
      });
      column.width = maxLen;
    });

    // Set Response Headers for Download
    const fileName = `${course.course_code}_Attendance_Report.xlsx`;
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);

    await workbook.xlsx.write(res);
    res.end();
  } catch (error) {
    console.error('Export Excel Error:', error);
    res.status(500).json({ message: 'Failed to generate Excel report.' });
  }
};

// -------------------------------------------------------------
// 2. EXPORT AS CSV (.CSV)
// -------------------------------------------------------------
exports.exportCourseCSV = async (req, res) => {
  const { courseId } = req.params;
  const teacherId = req.user.id;

  try {
    const reportData = await getCourseAttendanceData(courseId, teacherId);
    if (reportData.error) {
      return res.status(reportData.status).json({ message: reportData.error });
    }

    const { course, totalSessions, students } = reportData;

    // Construct CSV Header Lines
    let csvContent = `SUST Attendance Report - Course: ${course.course_code} (${course.title})\n`;
    csvContent += `Teacher: ${course.teacher_name},Total Classes: ${totalSessions},Export Date: ${new Date().toLocaleDateString()}\n\n`;

    // Columns
    csvContent += 'Registration No,Student Name,Department,Attended Classes,Total Classes,Percentage,SUST Status\n';

    // Rows
    students.forEach((st) => {
      const sanitizedName = `"${st.fullName.replace(/"/g, '""')}"`;
      csvContent += `${st.registrationNo},${sanitizedName},${st.department},${st.attendedSessions},${st.totalSessions},${st.percentage}%,${st.eligibility}\n`;
    });

    const fileName = `${course.course_code}_Attendance_Report.csv`;
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);

    // UTF-8 BOM for accurate opening in Excel
    res.write('\uFEFF');
    res.write(csvContent);
    res.end();
  } catch (error) {
    console.error('Export CSV Error:', error);
    res.status(500).json({ message: 'Failed to generate CSV report.' });
  }
};