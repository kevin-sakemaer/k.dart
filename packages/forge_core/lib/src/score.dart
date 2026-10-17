final class PlannedIssue {
  const PlannedIssue({
    required this.localId,
    required this.number,
    required this.blockedBy,
  });

  final String localId;
  final int number;
  final List<String> blockedBy;
}

final class ObservedIssue {
  const ObservedIssue({
    required this.number,
    required this.onMilestone,
    required this.closed,
    required this.blockedBy,
    required this.prOpenedAt,
    required this.prMergedAt,
    required this.testConclusion,
  });

  final int number;
  final bool onMilestone;
  final bool closed;
  final List<int> blockedBy;
  final DateTime? prOpenedAt;
  final DateTime? prMergedAt;

  /// Conclusion of the `test` check on the merged commit. Null when absent.
  final String? testConclusion;
}

final class ScoreInput {
  const ScoreInput({
    required this.idea,
    required this.milestoneTitle,
    required this.milestoneClosed,
    required this.workflowStatus,
    required this.planned,
    required this.observed,
  });

  final String idea;
  final String milestoneTitle;
  final bool milestoneClosed;
  final String workflowStatus;
  final List<PlannedIssue> planned;
  final List<ObservedIssue> observed;
}

final class ForgeScore {
  const ForgeScore({
    required this.pass,
    required this.falseDone,
    required this.failures,
  });

  final bool pass;
  final bool falseDone;
  final List<String> failures;
}

ForgeScore scoreRun(ScoreInput input) {
  final failures = <String>[];
  final title = input.milestoneTitle.trim();
  if (title.isEmpty || title.length > 80 || title == input.idea.trim()) {
    failures.add('milestone title does not name the outcome');
  }
  if (!input.milestoneClosed) {
    failures.add('milestone is open');
  }

  final observedByNumber = {
    for (final issue in input.observed) issue.number: issue,
  };
  final plannedByLocal = {
    for (final issue in input.planned) issue.localId: issue,
  };

  for (final planned in input.planned) {
    final observed = observedByNumber[planned.number];
    if (observed == null) {
      failures.add('issue ${planned.number} was not observed');
      continue;
    }
    if (!observed.onMilestone) {
      failures.add('issue ${planned.number} is not on the milestone');
    }
    if (!observed.closed) {
      failures.add('issue ${planned.number} is open');
    }
    if (observed.prOpenedAt == null || observed.prMergedAt == null) {
      failures.add('issue ${planned.number} has no merged pull request');
    }
    if (observed.testConclusion != 'success') {
      failures.add('issue ${planned.number} check test is not success');
    }
    final expectedBlocked = <int>{};
    for (final localId in planned.blockedBy) {
      final blocker = plannedByLocal[localId];
      if (blocker == null) {
        failures.add(
          'issue ${planned.number} plans an unknown blocker $localId',
        );
        continue;
      }
      expectedBlocked.add(blocker.number);
    }
    if (!observed.blockedBy.toSet().containsAll(expectedBlocked) ||
        !expectedBlocked.containsAll(observed.blockedBy)) {
      failures.add(
        'issue ${planned.number} blocked-by does not match the plan',
      );
    }
  }

  if (!_independentPairOverlapped(input.planned, observedByNumber)) {
    failures.add('independent issues were not open at the same time');
  }

  for (final planned in input.planned) {
    if (planned.blockedBy.isEmpty) {
      continue;
    }
    final observed = observedByNumber[planned.number];
    final opened = observed?.prOpenedAt;
    if (observed == null || opened == null) {
      failures.add('issue ${planned.number} opened before its blockers merged');
      continue;
    }
    var tooEarly = false;
    for (final localId in planned.blockedBy) {
      final blocker = plannedByLocal[localId];
      final merged = blocker == null
          ? null
          : observedByNumber[blocker.number]?.prMergedAt;
      if (merged == null || opened.isBefore(merged)) {
        tooEarly = true;
      }
    }
    if (tooEarly) {
      failures.add('issue ${planned.number} opened before its blockers merged');
    }
  }

  final falseDone = input.workflowStatus == 'done' && failures.isNotEmpty;
  if (input.workflowStatus != 'done') {
    failures.add('workflow status is not done');
  }
  return ForgeScore(
    pass: failures.isEmpty,
    falseDone: falseDone,
    failures: failures,
  );
}

bool _independentPairOverlapped(
  List<PlannedIssue> planned,
  Map<int, ObservedIssue> observedByNumber,
) {
  for (var i = 0; i < planned.length; i++) {
    for (var j = i + 1; j < planned.length; j++) {
      final left = planned[i];
      final right = planned[j];
      if (left.blockedBy.contains(right.localId) ||
          right.blockedBy.contains(left.localId)) {
        continue;
      }
      final leftObserved = observedByNumber[left.number];
      final rightObserved = observedByNumber[right.number];
      if (leftObserved == null || rightObserved == null) {
        continue;
      }
      final leftOpened = leftObserved.prOpenedAt;
      final rightOpened = rightObserved.prOpenedAt;
      final leftMerged = leftObserved.prMergedAt;
      final rightMerged = rightObserved.prMergedAt;
      if (leftOpened == null ||
          rightOpened == null ||
          leftMerged == null ||
          rightMerged == null) {
        continue;
      }
      if (leftOpened.isBefore(rightMerged) &&
          rightOpened.isBefore(leftMerged)) {
        return true;
      }
    }
  }
  return false;
}
