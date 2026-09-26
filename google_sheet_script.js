// ===================================================================
// GOOGLE APPS SCRIPT: CLASS REGISTER STYLE ATTENDANCE
// প্রতি ছাত্রের জন্য ১টি মাত্র নির্দিষ্ট রো থাকবে (নাম ও রোল)।
// প্রতিটি নতুন ক্লাসের হাজিরা ডানে নতুন কলাম হিসেবে P/A যোগ হবে।
// একই দিনে একাধিক ক্লাস নিলে (Class 1), (Class 2) ইত্যাদি কলাম তৈরি হবে।
// এবং Attended, Total, %, Marks সবসময় সেই রো তেই অটো আপডেট হবে।
// ===================================================================

function getSheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getActiveSheet();
  
  // যদি শিট সম্পূর্ণ খালি হয়, তবে সুন্দর হেডার তৈরি করা
  if (sheet.getLastRow() === 0) {
    sheet.appendRow([
      "Roll",
      "Name",
      "Attended Classes",
      "Total Classes",
      "Attendance %",
      "Marks (0-10)"
    ]);
    sheet.getRange(1, 1, 1, 6)
      .setFontWeight("bold")
      .setBackground("#E8EAED")
      .setHorizontalAlignment("center");
  }
  return sheet;
}

// ১. ক্লাউড থেকে সব ডাটা অ্যাপে আনা (GET ও POST get_data)
function getStudentsData() {
  var sheet = getSheet();
  var values = sheet.getDataRange().getValues();
  
  var students = [];
  var totalClasses = 0;
  
  // রো ২ থেকে পড়া শুরু (রো ১ হলো হেডার)
  for (var i = 1; i < values.length; i++) {
    var roll = values[i][0].toString().trim();
    var name = values[i][1].toString().trim();
    var attended = parseInt(values[i][2]) || 0;
    var classes = parseInt(values[i][3]) || 0;
    
    if (classes > totalClasses) {
      totalClasses = classes;
    }
    
    if (roll && name) {
      students.push({
        "roll": roll,
        "name": name,
        "attendedClasses": attended
      });
    }
  }
  
  // কলাম সংখ্যা থেকেও মোট ক্লাসের সংখ্যা যাচাই করা
  var lastCol = sheet.getLastColumn();
  if (lastCol > 6) {
    var dateColCount = lastCol - 6;
    if (dateColCount > totalClasses) {
      totalClasses = dateColCount;
    }
  }
  
  return {
    "status": "success",
    "totalClasses": totalClasses,
    "students": students
  };
}

function doGet(e) {
  try {
    var result = getStudentsData();
    return ContentService.createTextOutput(JSON.stringify(result))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      "status": "error",
      "message": error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

function doPost(e) {
  try {
    var sheet = getSheet();
    var data = JSON.parse(e.postData.contents);
    var action = data.action || "submit_attendance";
    
    // ডাটা পড়ার রিকোয়েস্ট
    if (action === "get_data") {
      var result = getStudentsData();
      return ContentService.createTextOutput(JSON.stringify(result))
        .setMimeType(ContentService.MimeType.JSON);
    }
    
    // হাজিরা সাবমিট করা (Register Style)
    if (action === "submit_attendance") {
      var dateStr = data.date || "Class";
      var totalClasses = parseInt(data.totalClasses) || 1;
      var records = data.records;
      
      // ১. প্রতিটি ক্লাসের জন্য সবসময় ডানে একটি নতুন কলাম তৈরি করা
      var lastCol = sheet.getLastColumn();
      var headerValues = lastCol >= 7 ? sheet.getRange(1, 1, 1, lastCol).getValues()[0] : [];
      
      // একই তারিখের কয়টি ক্লাস আগে হয়েছে তা গোনা
      var matchingColIndexes = [];
      for (var c = 6; c < headerValues.length; c++) {
        var h = headerValues[c] ? headerValues[c].toString().trim() : "";
        if (h === dateStr.trim() || h.indexOf(dateStr.trim() + " (Class ") === 0) {
          matchingColIndexes.push(c + 1); // ১-ভিত্তিক ইনডেক্স
        }
      }
      
      var dateColIndex = lastCol + 1;
      var colHeader = dateStr;
      
      // যদি একই দিনে ২য় বা ৩য় ক্লাস নেওয়া হয়:
      if (matchingColIndexes.length > 0) {
        // প্রথম ক্লাসটিকে (Class 1) নাম দেওয়া
        if (matchingColIndexes.length === 1) {
          sheet.getRange(1, matchingColIndexes[0]).setValue(dateStr + " (Class 1)");
        }
        // বর্তমান ক্লাসটিকে (Class 2), (Class 3) ইত্যাদি নাম দেওয়া
        colHeader = dateStr + " (Class " + (matchingColIndexes.length + 1) + ")";
      }
      
      // নতুন কলামের হেডার সেট করা
      sheet.getRange(1, dateColIndex).setValue(colHeader)
        .setFontWeight("bold")
        .setBackground("#E8F0FE")
        .setHorizontalAlignment("center");
      
      // ২. শিটের বর্তমান স্টুডেন্টদের রো ম্যাপ তৈরি করা (Roll -> Row Number)
      var sheetValues = sheet.getDataRange().getValues();
      var rollToRowMap = {};
      for (var r = 1; r < sheetValues.length; r++) {
        var existingRoll = sheetValues[r][0].toString().trim();
        if (existingRoll) {
          rollToRowMap[existingRoll] = r + 1; // ১-ভিত্তিক রো নম্বর
        }
      }
      
      // ৩. প্রতিটি ছাত্রের একই রো-তে ডাটা আপডেট করা
      for (var i = 0; i < records.length; i++) {
        var rec = records[i];
        var roll = rec.roll.toString().trim();
        var targetRow = rollToRowMap[roll];
        
        // ছাত্র যদি শিটে আগে থেকে না থাকে, নতুন রো যোগ করা
        if (!targetRow) {
          targetRow = sheet.getLastRow() + 1;
          rollToRowMap[roll] = targetRow;
          sheet.getRange(targetRow, 1).setValue(roll).setHorizontalAlignment("center");
          sheet.getRange(targetRow, 2).setValue(rec.name);
        }
        
        // সামারি কলাম আপডেট (Col C, D, E, F)
        sheet.getRange(targetRow, 3).setValue(rec.attendedClasses).setHorizontalAlignment("center"); // Attended
        sheet.getRange(targetRow, 4).setValue(totalClasses).setHorizontalAlignment("center");       // Total Classes
        sheet.getRange(targetRow, 5).setValue(rec.percentage + "%").setHorizontalAlignment("center"); // %
        sheet.getRange(targetRow, 6).setValue(rec.marks).setHorizontalAlignment("center");          // Marks (0-10)
        
        // নতুন ক্লাসের কলামে P অথবা A বসানো (সবুজ/লাল হাইলাইট)
        var statusLetter = (rec.status === "Present") ? "P" : "A";
        var cell = sheet.getRange(targetRow, dateColIndex);
        cell.setValue(statusLetter).setHorizontalAlignment("center");
        if (statusLetter === "P") {
          cell.setFontColor("#0B8043").setFontWeight("bold").setBackground("#E6F4EA");
        } else {
          cell.setFontColor("#C5221F").setFontWeight("bold").setBackground("#FCE8E6");
        }
      }
      
      return ContentService.createTextOutput(JSON.stringify({
        "status": "success",
        "message": "Class attendance saved to new column successfully"
      })).setMimeType(ContentService.MimeType.JSON);
    }
    
    // নতুন ছাত্র যোগ করা
    if (action === "add_student") {
      var newRoll = data.roll.toString().trim();
      var newName = data.name.toString().trim();
      var total = parseInt(data.totalClasses) || 0;
      
      var targetRow = sheet.getLastRow() + 1;
      sheet.getRange(targetRow, 1).setValue(newRoll).setHorizontalAlignment("center");
      sheet.getRange(targetRow, 2).setValue(newName);
      sheet.getRange(targetRow, 3).setValue(0).setHorizontalAlignment("center");
      sheet.getRange(targetRow, 4).setValue(total).setHorizontalAlignment("center");
      sheet.getRange(targetRow, 5).setValue("0%").setHorizontalAlignment("center");
      sheet.getRange(targetRow, 6).setValue(0).setHorizontalAlignment("center");
      
      return ContentService.createTextOutput(JSON.stringify({
        "status": "success",
        "message": "Student added"
      })).setMimeType(ContentService.MimeType.JSON);
    }
    
    // ছাত্র মুছে ফেলা
    if (action === "delete_student") {
      var delRoll = data.roll.toString().trim();
      var vals = sheet.getDataRange().getValues();
      for (var d = 1; d < vals.length; d++) {
        if (vals[d][0].toString().trim() === delRoll) {
          sheet.deleteRow(d + 1);
          break;
        }
      }
      return ContentService.createTextOutput(JSON.stringify({
        "status": "success",
        "message": "Student deleted"
      })).setMimeType(ContentService.MimeType.JSON);
    }
    
    // মোট ক্লাস সংখ্যা সরাসরি পরিবর্তন করা
    if (action === "update_total_classes") {
      var total = parseInt(data.totalClasses) || 0;
      var vals = sheet.getDataRange().getValues();
      for (var r = 1; r < vals.length; r++) {
        var attended = parseInt(vals[r][2]) || 0;
        var pct = total > 0 ? Math.round((attended / total) * 100) : 0;
        var mark = Math.min(10, Math.floor(pct / 10));
        sheet.getRange(r + 1, 4).setValue(total).setHorizontalAlignment("center");
        sheet.getRange(r + 1, 5).setValue(pct + "%").setHorizontalAlignment("center");
        sheet.getRange(r + 1, 6).setValue(mark).setHorizontalAlignment("center");
      }
      return ContentService.createTextOutput(JSON.stringify({
        "status": "success",
        "message": "Total classes updated"
      })).setMimeType(ContentService.MimeType.JSON);
    }
    
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      "status": "error",
      "message": error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}
