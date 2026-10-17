import 'dart:convert';
import 'dart:io';

import 'package:forge_core/forge_core.dart';

final class ForgeReport {
  const ForgeReport({
    required this.status,
    required this.idea,
    required this.milestoneNumber,
    required this.issues,
  });

  final String status;
  final String idea;
  final int milestoneNumber;
  final List<PlannedIssue> issues;

  static ForgeReport parse(Map<String, Object?> json) {
    final milestone = json['milestone'];
    if (milestone is! Map) {
      throw const FormatException('report.milestone is missing');
    }
    final milestoneMap = Map<String, Object?>.from(milestone);
    final number = milestoneMap['number'];
    if (number is! int) {
      throw const FormatException('report.milestone.number is missing');
    }
    final rawIssues = json['issues'];
    if (rawIssues is! List) {
      throw const FormatException('report.issues is missing');
    }
    final issues = <PlannedIssue>[];
    for (final raw in rawIssues) {
      if (raw is! Map) {
        throw const FormatException('report issue is not an object');
      }
      final issue = Map<String, Object?>.from(raw);
      final localId = issue['local_id'];
      final issueNumber = issue['number'];
      final blocked = issue['blocked_by'];
      if (localId is! String || issueNumber is! int || blocked is! List) {
        throw const FormatException('report issue is incomplete');
      }
      issues.add(
        PlannedIssue(
          localId: localId,
          number: issueNumber,
          blockedBy: [
            for (final id in blocked)
              if (id is String) id,
          ],
        ),
      );
      if (issues.last.blockedBy.length != blocked.length) {
        throw const FormatException('report blocked_by must be strings');
      }
    }
    final status = json['status'];
    final idea = json['idea'];
    if (status is! String || idea is! String) {
      throw const FormatException('report status or idea is missing');
    }
    return ForgeReport(
      status: status,
      idea: idea,
      milestoneNumber: number,
      issues: issues,
    );
  }
}

final class PullRequestRecord {
  const PullRequestRecord({
    required this.number,
    required this.body,
    required this.createdAt,
    required this.mergedAt,
    required this.mergeCommit,
  });

  final int number;
  final String body;
  final DateTime? createdAt;
  final DateTime? mergedAt;
  final String? mergeCommit;
}

bool closesIssue(String body, int issueNumber) {
  final needle = 'Closes #$issueNumber';
  var start = 0;
  while (true) {
    final index = body.indexOf(needle, start);
    if (index < 0) {
      return false;
    }
    final end = index + needle.length;
    if (end >= body.length || !_isDigit(body.codeUnitAt(end))) {
      return true;
    }
    start = end;
  }
}

PullRequestRecord? pullRequestClosing(
  List<PullRequestRecord> pullRequests,
  int issueNumber,
) {
  PullRequestRecord? chosen;
  for (final pullRequest in pullRequests) {
    if (!closesIssue(pullRequest.body, issueNumber)) {
      continue;
    }
    final merged = pullRequest.mergedAt;
    final chosenMerged = chosen?.mergedAt;
    if (chosen == null ||
        (merged != null &&
            (chosenMerged == null || merged.isAfter(chosenMerged)))) {
      chosen = pullRequest;
    }
  }
  return chosen;
}

List<int> blockedByNumbers(Object? json) {
  if (json is! List) {
    throw const FormatException('blocked_by response is not a list');
  }
  final numbers = <int>[];
  for (final item in json) {
    if (item is! Map) {
      throw const FormatException('blocked_by item is not an object');
    }
    final number = Map<String, Object?>.from(item)['number'];
    if (number is! int) {
      throw const FormatException('blocked_by item has no number');
    }
    numbers.add(number);
  }
  return numbers;
}

String? testConclusion(Object? json) {
  if (json is! Map) {
    throw const FormatException('check-runs response is not an object');
  }
  final runs = Map<String, Object?>.from(json)['check_runs'];
  if (runs is! List) {
    throw const FormatException('check_runs is missing');
  }
  String? conclusion;
  for (final run in runs) {
    if (run is! Map) {
      continue;
    }
    final map = Map<String, Object?>.from(run);
    if (map['name'] == 'test') {
      final value = map['conclusion'];
      conclusion = value is String ? value : null;
    }
  }
  return conclusion;
}

final class GhSnapshot {
  const GhSnapshot({
    required this.milestoneTitle,
    required this.milestoneClosed,
    required this.observed,
  });

  final String milestoneTitle;
  final bool milestoneClosed;
  final List<ObservedIssue> observed;
}

Future<ForgeScore> scoreMilestone({
  required String reportPath,
  required int milestone,
  String repo = 'kevin-sakemaer/k.dart',
  Future<Object?> Function(List<String> args)? runGh,
}) async {
  final raw = jsonDecode(await File(reportPath).readAsString());
  if (raw is! Map) {
    throw const FormatException('report is not an object');
  }
  final report = ForgeReport.parse(Map<String, Object?>.from(raw));
  if (report.milestoneNumber != milestone) {
    return const ForgeScore(
      pass: false,
      falseDone: false,
      failures: ['report milestone does not match --milestone'],
    );
  }
  final gh = runGh ?? _runGh;
  final snapshot = await _loadSnapshot(
    gh: gh,
    repo: repo,
    milestone: milestone,
    planned: report.issues,
  );
  return scoreRun(
    ScoreInput(
      idea: report.idea,
      milestoneTitle: snapshot.milestoneTitle,
      milestoneClosed: snapshot.milestoneClosed,
      workflowStatus: report.status,
      planned: report.issues,
      observed: snapshot.observed,
    ),
  );
}

Future<GhSnapshot> _loadSnapshot({
  required Future<Object?> Function(List<String> args) gh,
  required String repo,
  required int milestone,
  required List<PlannedIssue> planned,
}) async {
  final milestoneJson = await _decode(gh, [
    'api',
    'repos/$repo/milestones/$milestone',
  ]);
  if (milestoneJson is! Map) {
    throw const FormatException('milestone response is not an object');
  }
  final milestoneMap = Map<String, Object?>.from(milestoneJson);
  final title = milestoneMap['title'];
  if (title is! String) {
    throw const FormatException('milestone title is missing');
  }

  final pullRequestJson = await _decode(gh, [
    'pr',
    'list',
    '--repo',
    repo,
    '--state',
    'merged',
    '--limit',
    '100',
    '--json',
    'number,body,createdAt,mergedAt,mergeCommit',
  ]);
  if (pullRequestJson is! List) {
    throw const FormatException('pull request list is not a list');
  }
  final pullRequests = [
    for (final item in pullRequestJson)
      if (item is Map) _pullRequest(Map<String, Object?>.from(item)),
  ];

  final observed = <ObservedIssue>[];
  for (final issue in planned) {
    final view = await _decode(gh, [
      'issue',
      'view',
      '${issue.number}',
      '--repo',
      repo,
      '--json',
      'number,state,milestone',
    ]);
    if (view is! Map) {
      throw FormatException('issue ${issue.number} view is not an object');
    }
    final viewMap = Map<String, Object?>.from(view);
    final milestoneField = viewMap['milestone'];
    var onMilestone = false;
    if (milestoneField is Map) {
      onMilestone =
          Map<String, Object?>.from(milestoneField)['number'] == milestone;
    }
    final blocked = blockedByNumbers(
      await _decode(gh, [
        'api',
        'repos/$repo/issues/${issue.number}/dependencies/blocked_by',
      ]),
    );
    final pullRequest = pullRequestClosing(pullRequests, issue.number);
    String? conclusion;
    final sha = pullRequest?.mergeCommit;
    if (sha != null) {
      conclusion = testConclusion(
        await _decode(gh, ['api', 'repos/$repo/commits/$sha/check-runs']),
      );
    }
    observed.add(
      ObservedIssue(
        number: issue.number,
        onMilestone: onMilestone,
        closed: viewMap['state'] == 'CLOSED',
        blockedBy: blocked,
        prOpenedAt: pullRequest?.createdAt,
        prMergedAt: pullRequest?.mergedAt,
        testConclusion: conclusion,
      ),
    );
  }

  return GhSnapshot(
    milestoneTitle: title,
    milestoneClosed: milestoneMap['state'] == 'closed',
    observed: observed,
  );
}

PullRequestRecord _pullRequest(Map<String, Object?> json) {
  final number = json['number'];
  final body = json['body'];
  if (number is! int || body is! String) {
    throw const FormatException('pull request record is incomplete');
  }
  String? sha;
  final mergeCommit = json['mergeCommit'];
  if (mergeCommit is Map) {
    final oid = Map<String, Object?>.from(mergeCommit)['oid'];
    if (oid is String && oid.isNotEmpty) {
      sha = oid;
    }
  }
  return PullRequestRecord(
    number: number,
    body: body,
    createdAt: _time(json['createdAt']),
    mergedAt: _time(json['mergedAt']),
    mergeCommit: sha,
  );
}

DateTime? _time(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.parse(value);
}

Future<Object?> _decode(
  Future<Object?> Function(List<String> args) gh,
  List<String> args,
) async {
  final raw = await gh(args);
  if (raw is String) {
    if (raw.trim().isEmpty) {
      return null;
    }
    return jsonDecode(raw);
  }
  return raw;
}

Future<Object?> _runGh(List<String> args) async {
  final result = await Process.run('gh', args);
  if (result.exitCode != 0) {
    final error = result.stderr.toString().trim();
    throw StateError('gh ${args.join(' ')} failed: $error');
  }
  return result.stdout.toString();
}

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;
