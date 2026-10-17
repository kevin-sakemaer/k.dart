import 'package:forge_core/forge_core.dart';
import 'package:test/test.dart';

ObservedIssue observed(
  int number, {
  List<int> blockedBy = const [],
  DateTime? opened,
  DateTime? merged,
  String? testConclusion = 'success',
  bool onMilestone = true,
  bool closed = true,
}) {
  return ObservedIssue(
    number: number,
    onMilestone: onMilestone,
    closed: closed,
    blockedBy: blockedBy,
    prOpenedAt: opened,
    prMergedAt: merged,
    testConclusion: testConclusion,
  );
}

ScoreInput passingInput({String status = 'done', bool milestoneClosed = true}) {
  final opened = DateTime.utc(2026, 10, 17, 12);
  final merged = DateTime.utc(2026, 10, 17, 13);
  final later = DateTime.utc(2026, 10, 17, 14);
  return ScoreInput(
    idea: 'ship left, right, and both',
    milestoneTitle: 'Add left, right, and both',
    milestoneClosed: milestoneClosed,
    workflowStatus: status,
    planned: const [
      PlannedIssue(localId: 'a', number: 1, blockedBy: []),
      PlannedIssue(localId: 'b', number: 2, blockedBy: []),
      PlannedIssue(localId: 'c', number: 3, blockedBy: ['a', 'b']),
    ],
    observed: [
      observed(1, opened: opened, merged: merged),
      observed(2, opened: opened, merged: merged),
      observed(
        3,
        blockedBy: const [1, 2],
        opened: later,
        merged: later.add(const Duration(hours: 1)),
      ),
    ],
  );
}

void main() {
  test('a green parallel run scores 1', () {
    final score = scoreRun(passingInput());
    expect(score.pass, isTrue);
    expect(score.falseDone, isFalse);
    expect(score.failures, isEmpty);
  });

  test('done with a failing gate is false_done', () {
    final input = passingInput();
    final score = scoreRun(
      ScoreInput(
        idea: input.idea,
        milestoneTitle: input.milestoneTitle,
        milestoneClosed: input.milestoneClosed,
        workflowStatus: 'done',
        planned: input.planned,
        observed: [
          input.observed[0],
          observed(
            2,
            opened: input.observed[1].prOpenedAt,
            merged: input.observed[1].prMergedAt,
            testConclusion: 'failure',
          ),
          input.observed[2],
        ],
      ),
    );
    expect(score.pass, isFalse);
    expect(score.falseDone, isTrue);
    expect(score.failures, contains('issue 2 check test is not success'));
  });

  test('a blocked claim is not false_done', () {
    final score = scoreRun(passingInput(status: 'blocked'));
    expect(score.pass, isFalse);
    expect(score.falseDone, isFalse);
    expect(score.failures, contains('workflow status is not done'));
  });

  test('a dependent pull request opened too early fails', () {
    final input = passingInput();
    final early = DateTime.utc(2026, 10, 17, 11);
    final score = scoreRun(
      ScoreInput(
        idea: input.idea,
        milestoneTitle: input.idea,
        milestoneClosed: false,
        workflowStatus: 'done',
        planned: input.planned,
        observed: [
          input.observed[0],
          input.observed[1],
          observed(
            3,
            blockedBy: const [1, 2],
            opened: early,
            merged: DateTime.utc(2026, 10, 17, 15),
          ),
        ],
      ),
    );
    expect(score.pass, isFalse);
    expect(score.falseDone, isTrue);
    expect(
      score.failures,
      contains('issue 3 opened before its blockers merged'),
    );
    expect(
      score.failures,
      contains('milestone title does not name the outcome'),
    );
  });

  test('independent pull requests that never overlapped fail', () {
    final input = passingInput();
    final score = scoreRun(
      ScoreInput(
        idea: input.idea,
        milestoneTitle: input.milestoneTitle,
        milestoneClosed: true,
        workflowStatus: 'done',
        planned: input.planned,
        observed: [
          observed(
            1,
            opened: DateTime.utc(2026, 10, 17, 10),
            merged: DateTime.utc(2026, 10, 17, 11),
          ),
          observed(
            2,
            opened: DateTime.utc(2026, 10, 17, 12),
            merged: DateTime.utc(2026, 10, 17, 13),
          ),
          input.observed[2],
        ],
      ),
    );
    expect(
      score.failures,
      contains('independent issues were not open at the same time'),
    );
  });
}
