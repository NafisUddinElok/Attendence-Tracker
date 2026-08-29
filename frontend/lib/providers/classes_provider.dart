import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import 'auth_provider.dart';

/// Provider for admin classes list
final adminClassesProvider =
    FutureProvider.autoDispose<List<ClassModel>>((ref) async {
  return ref.watch(apiClientProvider).getAdminClasses();
});

/// Provider for teacher assigned classes
final teacherClassesProvider =
    FutureProvider.autoDispose<List<ClassModel>>((ref) async {
  return ref.watch(apiClientProvider).getTeacherClasses();
});

/// Provider for student enrolled classes
final studentClassesProvider =
    FutureProvider.autoDispose<List<ClassModel>>((ref) async {
  return ref.watch(apiClientProvider).getStudentClasses();
});
