import 'package:forge_core/forge_core.dart';
import 'package:test/test.dart';

void main() {
  const today = '2026-10-18';

  test('accepts a calendar date and a GitHub timestamp', () {
    expect(acceptDueDate('2026-10-18'), '2026-10-18');
    expect(acceptDueDate(' 2024-02-29T00:00:00Z '), '2024-02-29');
    expect(acceptDueDate('2000-02-29'), '2000-02-29');
    expect(acceptDueDate('2025-02-29'), isNull);
    expect(acceptDueDate('1900-02-29'), isNull);
    expect(acceptDueDate('2026-13-01'), isNull);
    expect(acceptDueDate('2026-10-18T'), isNull);
    expect(acceptDueDate('soon'), isNull);
  });

  test('ranks the furthest overdue milestone ahead of a nearer due date', () {
    final ranked = rankMilestones(const [
      MilestoneSchedule(number: 4, dueOn: '2026-12-01'),
      MilestoneSchedule(number: 3, dueOn: '2026-10-19'),
      MilestoneSchedule(number: 8, dueOn: null),
      MilestoneSchedule(number: 2, dueOn: '2026-10-18'),
      MilestoneSchedule(number: 7, dueOn: '2026-10-17'),
      MilestoneSchedule(number: 1, dueOn: '2026-09-01'),
      MilestoneSchedule(number: 9, dueOn: null),
      MilestoneSchedule(number: 6, dueOn: '2026-10-17'),
    ], today: today);

    expect(ranked.map((milestone) => milestone.number), [
      1,
      6,
      7,
      2,
      3,
      4,
      8,
      9,
    ]);
  });

  test('starts ready issues from the most overdue milestone first', () {
    const overdue = MilestoneSchedule(number: 1, dueOn: '2026-09-01');
    const upcoming = MilestoneSchedule(number: 2, dueOn: '2026-10-19');
    const undated = MilestoneSchedule(number: 3, dueOn: null);
    const issues = [
      TrackedIssue(
        milestoneNumber: 1,
        localId: 'both',
        number: 30,
        open: true,
        blockedBy: [10],
      ),
      TrackedIssue(
        milestoneNumber: 2,
        localId: 'later',
        number: 40,
        open: true,
        blockedBy: [],
      ),
      TrackedIssue(
        milestoneNumber: 1,
        localId: 'left',
        number: 10,
        open: true,
        blockedBy: [],
      ),
      TrackedIssue(
        milestoneNumber: 3,
        localId: 'note',
        number: 50,
        open: true,
        blockedBy: [],
      ),
    ];

    final firstWave = selectReadyIssues(
      milestones: const [upcoming, undated, overdue],
      issues: issues,
      openPullRequestIssues: const {},
      today: today,
    );
    expect(firstWave.map((issue) => issue.localId), ['left', 'later', 'note']);

    final afterLeft = selectReadyIssues(
      milestones: const [overdue, upcoming],
      issues: issues,
      openPullRequestIssues: const {10},
      today: today,
    );
    expect(afterLeft.map((issue) => issue.localId), ['later']);

    final unblocked = selectReadyIssues(
      milestones: const [overdue, upcoming],
      issues: [
        const TrackedIssue(
          milestoneNumber: 1,
          localId: 'both',
          number: 30,
          open: true,
          blockedBy: [10],
        ),
        const TrackedIssue(
          milestoneNumber: 1,
          localId: 'left',
          number: 10,
          open: false,
          blockedBy: [],
        ),
        issues[1],
      ],
      openPullRequestIssues: const {},
      today: today,
    );
    expect(unblocked.map((issue) => issue.localId), ['both', 'later']);

    expect(
      selectReadyIssues(
        milestones: const [overdue],
        issues: issues,
        openPullRequestIssues: const {},
        today: today,
        openPullRequestCount: 4,
      ),
      isEmpty,
    );
  });
}
