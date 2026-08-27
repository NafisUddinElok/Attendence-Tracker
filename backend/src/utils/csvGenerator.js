const { Parser } = require('json2csv');
const fs = require('fs');
const path = require('path');

const CSV_DIR = path.join(__dirname, '..', '..', 'generated_csv');
if (!fs.existsSync(CSV_DIR)) fs.mkdirSync(CSV_DIR, { recursive: true });

/**
 * Generates a CSV file from an array of plain objects and saves it to disk.
 * @param {Array<Object>} data - rows of data
 * @param {Array<String>} fields - column names (must match keys in data objects)
 * @param {String} fileName - e.g. "session_12_attendance.csv"
 * @returns {String} full file path of saved csv
 */
function generateCSV(data, fields, fileName) {
  const parser = new Parser({ fields });
  const csv = parser.parse(data);
  const filePath = path.join(CSV_DIR, fileName);
  fs.writeFileSync(filePath, csv);
  return filePath;
}

module.exports = { generateCSV, CSV_DIR };
