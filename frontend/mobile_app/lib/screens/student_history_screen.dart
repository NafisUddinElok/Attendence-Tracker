import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/app_config.dart';

class StudentHistoryScreen extends StatefulWidget {
  const StudentHistoryScreen({super.key});

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  final _storage = const FlutterSecureStorage();

  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _historyList = [];

  @override
  void initState() {
    super.initState();
    _fetchAttendanceHistory();
  }

  Future<void> _fetchAttendanceHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('$baseUrl/api/attendance/history/student'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _historyList = data['attendanceHistory'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load records (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  // Group attended sessions by Course Code
  Map<String, List<dynamic>> _groupByCourse() {
    final Map<String, List<dynamic>> grouped = {};
    for (var item in _historyList) {
      final code = item['course_code'] ?? 'GENERAL';
      grouped.putIfAbsent(code, () => []).add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedCourses = _groupByCourse();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My Attendance History'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAttendanceHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchAttendanceHistory,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _historyList.isEmpty
                    ? const Center(
                        child: Text(
                          'No attendance records found.\nAttend classes to see your timeline here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          // Top Overview Header
                          _buildOverallHeader(_historyList.length, groupedCourses.length),
                          const SizedBox(height: 20),

                          // Course-Wise Progress Cards
                          const Text(
                            'Course-wise Performance',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          ...groupedCourses.entries.map((entry) {
                            // Assuming 20 total classes for demo computation
                            const int estimatedTotalClasses = 20;
                            final attendedCount = entry.value.length;
                            final percentage = (attendedCount / estimatedTotalClasses) * 100;
                            return _buildCourseCard(
                              courseCode: entry.key,
                              courseTitle: entry.value.first['course_title'] ?? '',
                              attended: attendedCount,
                              total: estimatedTotalClasses,
                              percentage: percentage.clamp(0.0, 100.0),
                            );
                          }),

                          const SizedBox(height: 20),

                          // Detailed Session-by-Session Timeline
                          const Text(
                            'Recent Check-in Timeline',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          ..._historyList.map((item) => _buildTimelineTile(item)),
                        ],
                      ),
      ),
    );
  }

  Widget _buildOverallHeader(int totalPresent, int totalCourses) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.indigo, Colors.deepPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '$totalPresent',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text('Total Attended', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Column(
            children: [
              Text(
                '$totalCourses',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text('Active Courses', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard({
    required String courseCode,
    required String courseTitle,
    required int attended,
    required int total,
    required double percentage,
  }) {
    // SUST 75% Attendance Rule Thresholds
    Color statusColor;
    String statusBadge;

    if (percentage >= 75.0) {
      statusColor = Colors.green;
      statusBadge = 'Collegiate (Eligible)';
    } else if (percentage >= 60.0) {
      statusColor = Colors.amber.shade800;
      statusBadge = 'Non-Collegiate (Fine Required)';
    } else {
      statusColor = Colors.redAccent;
      statusBadge = 'Discollegiate (Ineligible)';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  courseCode,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              courseTitle,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage / 100.0,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                color: statusColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$attended / $total Classes Attended',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusBadge,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineTile(dynamic item) {
    final DateTime markedAt = DateTime.tryParse(item['marked_at'] ?? '') ?? DateTime.now();
    final formattedTime = '${markedAt.hour.toString().padLeft(2, '0')}:${markedAt.minute.toString().padLeft(2, '0')}';
    final formattedDate = '${markedAt.day}/${markedAt.month}/${markedAt.year}';

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: 0.15),
          child: const Icon(Icons.check, color: Colors.green, size: 20),
        ),
        title: Text(
          item['session_title'] ?? 'Regular Class',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${item['course_code']} • $formattedDate at $formattedTime',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        trailing: const Text(
          'PRESENT',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}