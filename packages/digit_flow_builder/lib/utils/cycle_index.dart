import 'package:digit_data_model/models/entities/project_type.dart';

/// Returns the id of the cycle a record saved at [timeMs] belongs to, for the
/// `cycleIndexStamp` every transformer-built record carries.
///
/// That is the cycle that started most recently at or before [timeMs], going
/// by start date rather than list order: a day between two cycles belongs to
/// the cycle that just ended, and a day after the last cycle to the last one.
/// Before the first cycle starts it is the first cycle, so no record is left
/// without one. Returns null only when there are no cycles.
int? cycleIndexStampAt(Iterable<ProjectCycle>? cycles, int timeMs) {
  ProjectCycle? first;
  ProjectCycle? latestStarted;
  for (final cycle in cycles ?? const <ProjectCycle>[]) {
    if (first == null || cycle.startDate < first.startDate) first = cycle;
    if (cycle.startDate <= timeMs &&
        (latestStarted == null || cycle.startDate > latestStarted.startDate)) {
      latestStarted = cycle;
    }
  }
  return (latestStarted ?? first)?.id;
}
