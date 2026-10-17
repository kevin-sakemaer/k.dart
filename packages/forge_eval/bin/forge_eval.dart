import 'dart:convert';
import 'dart:io';

import 'package:forge_eval/forge_eval.dart';

Future<void> main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed == null) {
    stderr.writeln(
      'Usage: forge_eval --milestone <n> --report <path> [--repo owner/name]',
    );
    exitCode = 2;
    return;
  }
  try {
    final score = await scoreMilestone(
      reportPath: parsed.report,
      milestone: parsed.milestone,
      repo: parsed.repo,
    );
    stdout.writeln(
      jsonEncode({
        'pass': score.pass,
        'false_done': score.falseDone,
        'failures': score.failures,
      }),
    );
    if (!score.pass) {
      exitCode = 1;
    }
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 2;
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 2;
  }
}

final class _Args {
  const _Args({
    required this.milestone,
    required this.report,
    required this.repo,
  });

  final int milestone;
  final String report;
  final String repo;
}

_Args? _parseArgs(List<String> args) {
  var milestone = -1;
  var report = '';
  var repo = 'kevin-sakemaer/k.dart';
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--milestone' && i + 1 < args.length) {
      milestone = int.tryParse(args[++i]) ?? -1;
    } else if (arg == '--report' && i + 1 < args.length) {
      report = args[++i];
    } else if (arg == '--repo' && i + 1 < args.length) {
      repo = args[++i];
    } else {
      return null;
    }
  }
  if (milestone < 1 || report.isEmpty) {
    return null;
  }
  return _Args(milestone: milestone, report: report, repo: repo);
}
