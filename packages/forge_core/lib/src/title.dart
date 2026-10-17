const maxMilestoneTitleLength = 80;

/// A milestone title names the outcome. Empty, too long, or a copy of the
/// idea is rejected.
String? acceptMilestoneTitle(String raw, {required String idea}) {
  final title = raw.trim();
  if (title.isEmpty || title.length > maxMilestoneTitleLength) {
    return null;
  }
  if (title == idea.trim()) {
    return null;
  }
  return title;
}
