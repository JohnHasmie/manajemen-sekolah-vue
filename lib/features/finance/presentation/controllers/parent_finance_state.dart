import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

part 'parent_finance_state.freezed.dart';

@freezed
class ParentFinanceState with _$ParentFinanceState {
  const factory ParentFinanceState({
    @Default([]) List<Student> students,
    Student? selectedStudent,
    @Default([]) List<dynamic> billingItems,
    @Default(true) bool isLoading,
    @Default('') String errorMessage,
    @Default('') String searchQuery,
    String? statusFilter, // 'unpaid', 'pending', 'verified'
    String? periodFilter, // 'bulanan', 'tahunan'
    @Default({}) Set<String> processedReadIds,
    @Default({}) Set<String> pendingReadIds,
  }) = _ParentFinanceState;
}
