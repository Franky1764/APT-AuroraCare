import '../entities/progress_report.dart';

abstract class ReportRepository {
  Future<ProgressReport> generate(List<ReportDomain> domains);
}
