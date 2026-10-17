import 'package:forge_core/forge_core.dart';
import 'package:test/test.dart';

void main() {
  test('accepts a short outcome title', () {
    expect(
      acceptMilestoneTitle('Add left and right', idea: 'ship the helpers'),
      'Add left and right',
    );
  });

  test('rejects an empty title, a long title, and a copy of the idea', () {
    expect(acceptMilestoneTitle('   ', idea: 'idea'), isNull);
    expect(acceptMilestoneTitle('x' * 81, idea: 'idea'), isNull);
    expect(
      acceptMilestoneTitle('  ship the helpers  ', idea: 'ship the helpers'),
      isNull,
    );
  });
}
