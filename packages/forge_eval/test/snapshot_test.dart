import 'package:forge_eval/forge_eval.dart';
import 'package:test/test.dart';

void main() {
  test('Closes #12 does not match Closes #120', () {
    expect(closesIssue('Closes #12', 12), isTrue);
    expect(closesIssue('See Closes #120 for context', 12), isFalse);
    expect(closesIssue('Closes #2 and Closes #12', 12), isTrue);
  });

  test('reads blocked-by numbers and the test check', () {
    expect(
      blockedByNumbers([
        {'number': 4},
        {'number': 9},
      ]),
      [4, 9],
    );
    expect(
      testConclusion({
        'check_runs': [
          {'name': 'lint', 'conclusion': 'success'},
          {'name': 'test', 'conclusion': 'failure'},
        ],
      }),
      'failure',
    );
  });

  test('picks the latest merged pull request that closes the issue', () {
    final chosen = pullRequestClosing([
      PullRequestRecord(
        number: 1,
        body: 'Closes #3',
        createdAt: DateTime.utc(2026, 1, 1),
        mergedAt: DateTime.utc(2026, 1, 2),
        mergeCommit: 'aaa',
      ),
      PullRequestRecord(
        number: 2,
        body: 'Closes #3\n',
        createdAt: DateTime.utc(2026, 1, 3),
        mergedAt: DateTime.utc(2026, 1, 4),
        mergeCommit: 'bbb',
      ),
    ], 3);
    expect(chosen?.number, 2);
  });

  test('parses a workflow report', () {
    final report = ForgeReport.parse({
      'status': 'done',
      'idea': 'ship it',
      'milestone': {'number': 7, 'title': 'Ship it'},
      'issues': [
        {'local_id': 'a', 'number': 1, 'blocked_by': <String>[]},
        {
          'local_id': 'c',
          'number': 3,
          'blocked_by': ['a'],
        },
      ],
    });
    expect(report.milestoneNumber, 7);
    expect(report.issues[1].blockedBy, ['a']);
  });
}
