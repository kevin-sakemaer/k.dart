import 'graph.dart';

const _datePattern = r'^(\d{4})-(\d{2})-(\d{2})$';

final _date = RegExp(_datePattern);

/// Calendar date `YYYY-MM-DD`, or the date prefix of a GitHub `due_on`
/// timestamp. Anything else is rejected.
String? acceptDueDate(String raw) {
  final trimmed = raw.trim();
  if (trimmed.length < 10) {
    return null;
  }
  final date = trimmed.substring(0, 10);
  if (trimmed.length != 10 && (trimmed.length < 12 || trimmed[10] != 'T')) {
    return null;
  }
  final match = _date.firstMatch(date);
  if (match == null) {
    return null;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > _daysInMonth(year, month)) {
    return null;
  }
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return date;
}

int _daysInMonth(int year, int month) {
  const lengths = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (month == 2 && _isLeap(year)) {
    return 29;
  }
  return lengths[month];
}

bool _isLeap(int year) {
  if (year % 400 == 0) {
    return true;
  }
  if (year % 100 == 0) {
    return false;
  }
  return year % 4 == 0;
}

/// An open milestone the build workflow can choose.
final class MilestoneSchedule {
  const MilestoneSchedule({required this.number, required this.dueOn});

  final int number;

  /// Canonical `YYYY-MM-DD`, or null when the milestone has no due date.
  final String? dueOn;
}

/// Dated milestones first, earliest due date first.
///
/// A due date further in the past sorts ahead of a more recent one. A future
/// due date closer to [today] sorts ahead of a later one. Undated milestones
/// sort last. Equal dates break ties by milestone number. [today] is the
/// clock the caller used to decide which dates are overdue.
List<MilestoneSchedule> rankMilestones(
  List<MilestoneSchedule> milestones, {
  required String today,
}) {
  if (acceptDueDate(today) != today) {
    throw ArgumentError.value(today, 'today', 'expected YYYY-MM-DD');
  }
  for (final milestone in milestones) {
    final dueOn = milestone.dueOn;
    if (dueOn != null && acceptDueDate(dueOn) != dueOn) {
      throw ArgumentError.value(dueOn, 'dueOn', 'expected YYYY-MM-DD');
    }
  }
  final ranked = [...milestones];
  ranked.sort((a, b) {
    final aDue = a.dueOn;
    final bDue = b.dueOn;
    if (aDue != null && bDue == null) {
      return -1;
    }
    if (aDue == null && bDue != null) {
      return 1;
    }
    if (aDue != null && bDue != null && aDue != bDue) {
      return aDue.compareTo(bDue);
    }
    return a.number.compareTo(b.number);
  });
  return ranked;
}

/// One issue on an open milestone, as read back from GitHub.
final class TrackedIssue {
  const TrackedIssue({
    required this.milestoneNumber,
    required this.localId,
    required this.number,
    required this.open,
    required this.blockedBy,
  });

  final int milestoneNumber;
  final String localId;
  final int number;
  final bool open;
  final List<int> blockedBy;
}

/// Ready issues in the order a build run should open pull requests.
///
/// Walks [rankMilestones] and, within a milestone, local id. An issue is
/// ready when it is open, no open pull request already closes it, and every
/// blocker is a known closed issue. Stops after [cap] minus the pull
/// requests already open.
List<TrackedIssue> selectReadyIssues({
  required List<MilestoneSchedule> milestones,
  required List<TrackedIssue> issues,
  required Set<int> openPullRequestIssues,
  required String today,
  int openPullRequestCount = 0,
  int cap = maxOpenPullRequests,
}) {
  final slots = cap - openPullRequestCount;
  if (slots <= 0) {
    rankMilestones(milestones, today: today);
    return const <TrackedIssue>[];
  }
  final byNumber = <int, TrackedIssue>{};
  for (final issue in issues) {
    byNumber.putIfAbsent(issue.number, () => issue);
  }
  final ranked = rankMilestones(milestones, today: today);
  final ready = <TrackedIssue>[];
  for (final milestone in ranked) {
    final owned =
        issues
            .where((issue) => issue.milestoneNumber == milestone.number)
            .toList()
          ..sort((a, b) => a.localId.compareTo(b.localId));
    for (final issue in owned) {
      if (ready.length == slots) {
        return ready;
      }
      if (!issue.open || openPullRequestIssues.contains(issue.number)) {
        continue;
      }
      if (byNumber[issue.number] != issue) {
        continue;
      }
      var blocked = false;
      for (final blocker in issue.blockedBy) {
        final blocking = byNumber[blocker];
        if (blocking == null || blocking.open) {
          blocked = true;
        }
      }
      if (!blocked) {
        ready.add(issue);
      }
    }
  }
  return ready;
}
