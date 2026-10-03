import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards two compounding bugs that made a freshly-registered household
/// show up as 0 in the Summary Report for a Registrar:
///
/// 1. `_loadSummaryReportData` (project.dart) only synced the server-side
///    summary snapshot for Distributors (`if (isDistributor == false)
///    return;`), a leftover from before the report became role-specific.
///    Registrars never got any server baseline, so their count relied
///    entirely on the local supplement below.
/// 2. That local supplement (summary_report.dart) only counted households/
///    tasks still "pending up-sync" (`getItemsToBeSyncedUp`, which filters
///    on `syncedUp == false`). As soon as a household synced - which can
///    happen within seconds on an online device, well before the server's
///    own cached summary snapshot is next refreshed - it dropped out of
///    both the local count and the (never-refreshed) server count, landing
///    on zero either way.
void main() {
  late String loadSummaryReportDataBlock;
  late String summaryReportLoadDataSource;

  setUpAll(() {
    final projectFile =
        File('${Directory.current.path}/lib/blocs/project/project.dart');
    final projectSource = projectFile.readAsStringSync();

    final start = projectSource.indexOf('_loadSummaryReportData({');
    final end = projectSource.indexOf(
      '_loadProjectFacilities(ProjectModel project)',
      start,
    );
    expect(start, greaterThanOrEqualTo(0),
        reason: 'Could not locate _loadSummaryReportData');
    expect(end, greaterThan(start),
        reason: 'Could not locate the next method after it');
    loadSummaryReportDataBlock = projectSource.substring(start, end);

    summaryReportLoadDataSource = File(
      '${Directory.current.path}/lib/pages/reports/summary/summary_report.dart',
    ).readAsStringSync();
  });

  test(
      '_loadSummaryReportData syncs for Registrar too, not just Distributor',
      () {
    expect(loadSummaryReportDataBlock.contains('isRegistrar'), isTrue);
    expect(
      loadSummaryReportDataBlock.contains('if (isDistributor == false) return;'),
      isFalse,
      reason: 'Should no longer gate the sync on Distributor alone',
    );
  });

  test(
      'summary report no longer gates local household/task counts on up-sync status',
      () {
    expect(
      summaryReportLoadDataSource.contains('getItemsToBeSyncedUp'),
      isFalse,
      reason:
          'Counting households/tasks registered should not depend on whether '
          'they have already been uploaded to the server',
    );
  });
}
