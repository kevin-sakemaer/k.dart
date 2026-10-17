import 'package:forge_core/forge_core.dart';
import 'package:test/test.dart';

IssueDraft issue(
  String id,
  List<String> blockedBy, {
  String acceptance = 'fvm dart test passes',
}) {
  return IssueDraft(
    id: id,
    title: id,
    acceptance: acceptance,
    blockedBy: blockedBy,
  );
}

void main() {
  test(
    'rejects a cycle, an unknown edge, a self edge, and an empty criterion',
    () {
      final cycle = validateGraph([
        issue('a', ['b']),
        issue('b', ['a']),
      ]);
      expect(cycle.accepted, isFalse);
      expect(cycle.drops.map((drop) => drop.reason), contains('cycle'));

      final unknown = validateGraph([
        issue('a', ['missing']),
      ]);
      expect(unknown.accepted, isFalse);
      expect(unknown.drops.single.reason, 'unknown blocker missing');

      final self = validateGraph([
        issue('a', ['a']),
      ]);
      expect(self.accepted, isFalse);
      expect(self.drops.single.reason, 'blocked by itself');

      final empty = validateGraph([issue('a', [], acceptance: '  ')]);
      expect(empty.accepted, isFalse);
      expect(
        empty.drops.map((drop) => drop.reason),
        contains('empty acceptance'),
      );
    },
  );

  test('orders a wave of independent issues before the issue they block', () {
    final graph = validateGraph([
      issue('c', ['b', 'a']),
      issue('a', []),
      issue('b', []),
    ]);
    expect(graph.accepted, isTrue);
    expect(
      waves(graph.issues).map((wave) => wave.map((item) => item.id).toList()),
      [
        ['a', 'b'],
        ['c'],
      ],
    );
  });

  test('accepts a graph with more than twelve issues', () {
    final issues = [for (var i = 0; i < 13; i++) issue('n$i', [])];
    final graph = validateGraph(issues);
    expect(graph.accepted, isTrue);
    expect(graph.issues, hasLength(13));
  });

  test('ready batch keeps four issues sorted by id', () {
    final issues = [
      'e',
      'd',
      'c',
      'b',
      'a',
    ].map((id) => issue(id, [])).toList();
    expect(readyBatch(issues, {}).map((item) => item.id), ['a', 'b', 'c', 'd']);
  });
}
