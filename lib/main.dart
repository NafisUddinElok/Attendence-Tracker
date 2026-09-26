import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AttendanceApp());
}

// -------------------------------------------------------------
// ১. স্টুডেন্ট ডাটা মডেল (কোড সহজ ও পরিষ্কার রাখার জন্য)
// -------------------------------------------------------------
class Student {
  String roll;
  String name;
  int attended;
  bool isPresent;

  Student({
    required this.roll,
    required this.name,
    this.attended = 0,
    this.isPresent = false,
  });

  Map<String, dynamic> toJson() => {
    'roll': roll,
    'name': name,
    'attended': attended,
  };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    roll: json['roll']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    attended: json['attended'] ?? json['attendedClasses'] ?? 0,
  );
}

// -------------------------------------------------------------
// ২. মেইন অ্যাপ
// -------------------------------------------------------------
class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teacher Attendance Register',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: const AttendanceHomePage(),
    );
  }
}

class AttendanceHomePage extends StatefulWidget {
  const AttendanceHomePage({super.key});

  @override
  State<AttendanceHomePage> createState() => _AttendanceHomePageState();
}

class _AttendanceHomePageState extends State<AttendanceHomePage> {
  // গুগল শিট Web App URL (সরাসরি ক্লাউড ব্যাকএন্ড)
  final String _googleSheetApiUrl =
      'https://script.google.com/macros/s/AKfycbxHCBksRQSjzjvuEnByA_rwffFmXHJ8o0wDYwy4Z3n0alrVCwyKzdLvAxbyeG973x4NGg/exec';

  int _totalClassesHeld = 0;
  List<Student> _students = [];
  bool _isSyncing = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollController = TextEditingController();
  final TextEditingController _classesController = TextEditingController();

  // আজকের তারিখ (ডিভাইসের ক্যালেন্ডার থেকে অটোমেটিক)
  String get _todayDate {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sept',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${now.day} ${months[now.month - 1]}, ${now.year}';
  }

  @override
  void initState() {
    super.initState();
    _loadFromLocalCache();
    _fetchFromCloud(silent: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _classesController.dispose();
    super.dispose();
  }

  // শিটে POST রিকোয়েস্ট পাঠানোর সাধারণ ফাংশন
  Future<http.Response> _postToSheet(Map<String, dynamic> data) {
    return http.post(
      Uri.parse(_googleSheetApiUrl),
      headers: {'Content-Type': 'text/plain;charset=utf-8'},
      body: jsonEncode(data),
    );
  }

  // -----------------------------------------------------------
  // স্টোরেজ ও ক্লাউড সিঙ্ক
  // -----------------------------------------------------------

  // লোকাল মেমোরি থেকে ডাটা লোড
  Future<void> _loadFromLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('saved_students_list');
    final classes = prefs.getInt('total_classes_held');

    setState(() {
      _totalClassesHeld = classes ?? 0;
      if (saved != null && saved.isNotEmpty) {
        final List list = jsonDecode(saved);
        _students = list.map((e) => Student.fromJson(e)).toList();
      }
      // else {
      //   _students = [
      //     Student(roll: '101', name: 'Rahim Ahmed'),
      //     Student(roll: '102', name: 'Karim Hassan'),
      //   ];
      // }
    });
  }

  // লোকাল মেমোরিতে ডাটা সেভ
  Future<void> _saveToLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'saved_students_list',
      jsonEncode(_students.map((s) => s.toJson()).toList()),
    );
    await prefs.setInt('total_classes_held', _totalClassesHeld);
  }

  // গুগল শিট থেকে সর্বশেষ ডাটা আনা
  Future<void> _fetchFromCloud({bool silent = false}) async {
    if (!silent) setState(() => _isSyncing = true);

    try {
      final response = await _postToSheet({'action': 'get_data'});
      String body = response.body;

      if (response.statusCode == 302 && response.headers['location'] != null) {
        final redirect = await http.get(
          Uri.parse(response.headers['location']!),
        );
        body = redirect.body;
      }

      if ((response.statusCode == 200 || response.statusCode == 302) &&
          body.trim().startsWith('{')) {
        final data = jsonDecode(body);
        if (data['status'] == 'success') {
          final List list = data['students'] ?? [];
          setState(() {
            _totalClassesHeld = data['totalClasses'] ?? _totalClassesHeld;
            if (list.isNotEmpty) {
              _students = list.map((item) => Student.fromJson(item)).toList();
            }
          });
          _saveToLocalCache();
          if (!silent && mounted) {
            _showMessage('✅ Synced with Google Sheet!', Colors.green);
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ০-১০ মার্কস বের করার নিয়ম (৯০-১০০% = ১০, ৮০-৮৯% = ৮...)
  int _calculateMark(double pct) =>
      pct >= 90 ? 10 : (pct / 10).floor().clamp(0, 10);

  // -----------------------------------------------------------
  // হাজিরা সাবমিট করা
  // -----------------------------------------------------------
  Future<void> _submitAttendance() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Saving to Google Sheet...'),
          ],
        ),
      ),
    );

    int newTotal = _totalClassesHeld + 1;
    List<Map<String, dynamic>> records = _students.map((s) {
      int attended = s.attended + (s.isPresent ? 1 : 0);
      double pct = (attended / newTotal) * 100;
      return {
        'roll': s.roll,
        'name': s.name,
        'status': s.isPresent ? 'Present' : 'Absent',
        'attendedClasses': attended,
        'percentage': pct.toStringAsFixed(0),
        'marks': _calculateMark(pct),
      };
    }).toList();

    try {
      final response = await _postToSheet({
        'action': 'submit_attendance',
        'date': _todayDate,
        'totalClasses': newTotal,
        'records': records,
      });

      if (!mounted) return;
      Navigator.pop(context); // ডায়ালগ বন্ধ করা

      if (response.statusCode == 200 || response.statusCode == 302) {
        setState(() {
          _totalClassesHeld = newTotal;
          for (var s in _students) {
            if (s.isPresent) s.attended += 1;
            s.isPresent = false; // পরের ক্লাসের জন্য আনচেক
          }
        });
        _saveToLocalCache();
        _showMessage(
          '✅ Class #$_totalClassesHeld saved to Google Sheet!',
          Colors.green.shade700,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showMessage('Failed: $e', Colors.red);
    }
  }

  // নতুন ছাত্র যোগ করা
  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _rollController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Roll'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              final roll = _rollController.text.trim();
              if (name.isNotEmpty && roll.isNotEmpty) {
                setState(() {
                  _students.add(Student(roll: roll, name: name));
                });
                _saveToLocalCache();
                _postToSheet({
                  'action': 'add_student',
                  'roll': roll,
                  'name': name,
                  'totalClasses': _totalClassesHeld,
                });
                _nameController.clear();
                _rollController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ছাত্র মুছে ফেলা
  void _deleteStudent(int index) {
    final roll = _students[index].roll;
    setState(() => _students.removeAt(index));
    _saveToLocalCache();
    _postToSheet({'action': 'delete_student', 'roll': roll});
  }

  // মোট ক্লাস সংখ্যা সরাসরি পরিবর্তন করা
  void _showEditClassesDialog() {
    _classesController.text = '$_totalClassesHeld';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Total Classes'),
        content: TextField(
          controller: _classesController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Total Classes Held',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              int? val = int.tryParse(_classesController.text);
              if (val != null && val >= 0) {
                setState(() => _totalClassesHeld = val);
                _saveToLocalCache();
                _postToSheet({
                  'action': 'update_total_classes',
                  'totalClasses': val,
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String text, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  // -----------------------------------------------------------
  // ইউজার ইন্টারফেস (UI)
  // -----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    int todayPresent = _students.where((s) => s.isPresent).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Teacher Attendance Register',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
        actions: [
          _isSyncing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.cloud_sync_outlined),
                  tooltip: 'Sync with Sheet',
                  onPressed: () => _fetchFromCloud(),
                ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Student',
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // তারিখ ও মোট ক্লাসের বার
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 160, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Total Classes: $_totalClassesHeld',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.blueGrey,
                      ),
                      tooltip: 'Edit Total Classes',
                      onPressed: _showEditClassesDialog,
                    ),
                  ],
                ),
                Text(
                  _todayDate,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // সামারি কাউন্টার
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('Total Students', '${_students.length}', Colors.black87),
                _stat('Present Today', '$todayPresent', Colors.green.shade700),
                _stat(
                  'Absent Today',
                  '${_students.length - todayPresent}',
                  Colors.red.shade700,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Students (${_students.length}):',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          // ছাত্র তালিকা
          Expanded(
            child: _students.isEmpty
                ? const Center(child: Text('No students yet. Click + to add.'))
                : ListView.builder(
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final s = _students[index];
                      int previewAttended = s.attended + (s.isPresent ? 1 : 0);
                      int previewTotal =
                          _totalClassesHeld +
                          (s.isPresent || s.attended > 0 ? 1 : 0);
                      if (previewTotal == 0 && _totalClassesHeld > 0) {
                        previewTotal = _totalClassesHeld;
                      }

                      double pct = previewTotal > 0
                          ? (previewAttended / previewTotal) * 100
                          : 0.0;
                      int mark = _calculateMark(pct);

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey.shade100,
                            foregroundColor: Colors.blueGrey.shade800,
                            radius: 20,
                            child: Text(
                              s.roll,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            s.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Attended: ${s.attended}/$_totalClassesHeld  •  ${pct.toStringAsFixed(0)}%  •  Marks: $mark/10',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: s.isPresent,
                                activeColor: Colors.green.shade600,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (val) {
                                  setState(() => s.isPresent = val ?? false);
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Delete',
                                onPressed: () => _deleteStudent(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // সাবমিট বাটন
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitAttendance,
              icon: const Icon(Icons.cloud_upload_outlined, size: 20),
              label: const Text(
                'Submit Attendance to Google Sheet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey.shade800,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}
