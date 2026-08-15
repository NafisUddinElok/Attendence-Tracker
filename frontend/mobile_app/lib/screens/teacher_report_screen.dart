// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/app_config.dart';

class TeacherReportScreen extends StatefulWidget {
  final String courseId;
  final String courseCode;
  final String courseTitle;

  const TeacherReportScreen({
    super.key,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
  });

  @override
  State<TeacherReportScreen> createState() => _TeacherReportScreenState();
}

class _TeacherReportScreenState extends State<TeacherReportScreen> {
  final _storage = const FlutterSecureStorage();

  bool _isLoading = true;
  bool _isExporting = false;
  String _searchQuery = '';
  List<dynamic> _enrolledStudents = [];
  int _totalEnrolled = 0;

  @override
  void initState() {
    super.initState();
    _fetchEnrolledStudents();
  }

  Future<void> _fetchEnrolledStudents([String query = '']) async {
    setState(() => _isLoading = true);

    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('$baseUrl/api/courses/${widget.courseId}/students?search=$query'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _enrolledStudents = data['students'] ?? [];
          _totalEnrolled = data['totalEnrolled'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportAttendanceReport() async {
    setState(() => _isExporting = true);
    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/reports/course/${widget.courseId}/csv'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final fileName = '${widget.courseCode}_Attendance_Report.csv';
        final file = File('${Directory.systemTemp.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Report saved: ${file.path}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String msg = 'Export failed (${response.statusCode})';
        try {
          msg = jsonDecode(response.body)['message'] ?? msg;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('${widget.courseCode} - Attendance Report'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          _isExporting
              ? const Padding(
                  padding: EdgeInsets.all(14.0),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: 'Export CSV',
                  onPressed: _exportAttendanceReport,
                ),
        ],
      ),
      body: Column(
        children: [
          // Header Stats
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.courseTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Enrolled Students: $_totalEnrolled',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                // Search Bar
                TextField(
                  onChanged: (value) {
                    _searchQuery = value;
                    _fetchEnrolledStudents(value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by Reg No or Name...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Students Enrolled List with Biometrics Status
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _enrolledStudents.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No students enrolled yet.'
                              : 'No students match "$_searchQuery"',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _enrolledStudents.length,
                        itemBuilder: (context, index) {
                          final student = _enrolledStudents[index];
                          final regNo = student['registration_no'] ?? 'N/A';
                          final name = student['full_name'] ?? 'Unnamed';
                          final dept = student['department'] ?? 'SUST';

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo.shade50,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('$regNo • $dept', style: const TextStyle(fontSize: 12)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Enrolled',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}