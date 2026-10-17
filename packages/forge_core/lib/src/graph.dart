const maxOpenPullRequests = 4;

final _idPattern = RegExp(r'^[a-z0-9][a-z0-9-]{0,30}$');

final class IssueDraft {
  const IssueDraft({
    required this.id,
    required this.title,
    required this.acceptance,
    required this.blockedBy,
  });

  final String id;
  final String title;
  final String acceptance;
  final List<String> blockedBy;
}

final class GraphDrop {
  const GraphDrop(this.id, this.reason);

  final String id;
  final String reason;
}

final class GraphValidation {
  const GraphValidation({required this.issues, required this.drops});

  final List<IssueDraft> issues;
  final List<GraphDrop> drops;

  bool get accepted => drops.isEmpty && issues.isNotEmpty;
}

/// [priorIds] are issue ids already accepted in an earlier milestone.
GraphValidation validateGraph(
  List<IssueDraft> input, {
  Set<String> priorIds = const {},
}) {
  final drops = <GraphDrop>[];
  final kept = <IssueDraft>[];
  final seen = <String>{};

  for (final issue in input) {
    if (!_idPattern.hasMatch(issue.id)) {
      drops.add(GraphDrop(issue.id, 'bad id'));
      continue;
    }
    if (priorIds.contains(issue.id) || !seen.add(issue.id)) {
      drops.add(GraphDrop(issue.id, 'duplicate id'));
      continue;
    }
    if (issue.title.trim().isEmpty) {
      drops.add(GraphDrop(issue.id, 'empty title'));
      continue;
    }
    if (issue.acceptance.trim().isEmpty) {
      drops.add(GraphDrop(issue.id, 'empty acceptance'));
      continue;
    }
    final blockers = <String>[];
    var badEdge = false;
    for (final blocker in issue.blockedBy) {
      if (blockers.contains(blocker)) {
        continue;
      }
      if (blocker == issue.id) {
        drops.add(GraphDrop(issue.id, 'blocked by itself'));
        badEdge = true;
        break;
      }
      blockers.add(blocker);
    }
    if (badEdge) {
      seen.remove(issue.id);
      continue;
    }
    kept.add(
      IssueDraft(
        id: issue.id,
        title: issue.title.trim(),
        acceptance: issue.acceptance.trim(),
        blockedBy: blockers,
      ),
    );
  }

  final ids = kept.map((issue) => issue.id).toSet();
  final filtered = <IssueDraft>[];
  for (final issue in kept) {
    final unknown = issue.blockedBy
        .where((id) => !ids.contains(id) && !priorIds.contains(id))
        .toList();
    if (unknown.isNotEmpty) {
      drops.add(GraphDrop(issue.id, 'unknown blocker ${unknown.first}'));
      continue;
    }
    filtered.add(issue);
  }

  if (filtered.isNotEmpty && _hasCycle(filtered)) {
    drops.add(const GraphDrop('', 'cycle'));
  }
  if (filtered.isEmpty && drops.isEmpty) {
    drops.add(const GraphDrop('', 'no issues'));
  }

  return GraphValidation(issues: filtered, drops: drops);
}

/// Waves of issues whose blockers are already done. Ids are sorted inside a wave.
List<List<IssueDraft>> waves(List<IssueDraft> issues) {
  final remaining = [...issues];
  final done = <String>{};
  final result = <List<IssueDraft>>[];
  while (remaining.isNotEmpty) {
    final ready =
        remaining
            .where((issue) => issue.blockedBy.every(done.contains))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    if (ready.isEmpty) {
      throw StateError('cycle');
    }
    result.add(ready);
    for (final issue in ready) {
      done.add(issue.id);
      remaining.remove(issue);
    }
  }
  return result;
}

/// Up to [cap] not-yet-done issues whose blockers are all in [done], sorted by id.
List<IssueDraft> readyBatch(
  List<IssueDraft> issues,
  Set<String> done, {
  int cap = maxOpenPullRequests,
}) {
  final ready =
      issues
          .where(
            (issue) =>
                !done.contains(issue.id) &&
                issue.blockedBy.every(done.contains),
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  if (ready.length <= cap) {
    return ready;
  }
  return ready.sublist(0, cap);
}

bool _hasCycle(List<IssueDraft> issues) {
  final indegree = {for (final issue in issues) issue.id: 0};
  final outgoing = {for (final issue in issues) issue.id: <String>[]};
  final ids = indegree.keys.toSet();
  for (final issue in issues) {
    for (final blocker in issue.blockedBy) {
      if (!ids.contains(blocker)) {
        continue;
      }
      outgoing[blocker]!.add(issue.id);
      indegree[issue.id] = indegree[issue.id]! + 1;
    }
  }
  final queue =
      indegree.entries
          .where((entry) => entry.value == 0)
          .map((entry) => entry.key)
          .toList()
        ..sort();
  var seen = 0;
  while (queue.isNotEmpty) {
    final id = queue.removeAt(0);
    seen += 1;
    final next = [...outgoing[id]!]..sort();
    for (final child in next) {
      final left = indegree[child]! - 1;
      indegree[child] = left;
      if (left == 0) {
        queue.add(child);
        queue.sort();
      }
    }
  }
  return seen != issues.length;
}
