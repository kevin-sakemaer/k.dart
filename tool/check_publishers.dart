// Vérifie que chaque dépendance directe hébergée est publiée par un éditeur
// vérifié autorisé sur pub.dev.
//
// Les dépendances directes sont les clés `dependencies` et `dev_dependencies`
// du pubspec.yaml racine et de chaque packages/*/pubspec.yaml. Une entrée est
// retenue si elle n'a ni `path`, ni `git`, ni `sdk` et si pubspec.lock la
// résout en `source: hosted`, ce qui exclut les packages du workspace. Les
// dépendances transitives ne sont pas contrôlées.
//
// Le pubspec.lock d'un workspace marque toutes ses entrées en `transitive`.
// C'est pourquoi la liste des dépendances directes est lue dans les pubspec.yaml.
//
// Usage : dart run tool/check_publishers.dart (depuis la racine du dépôt)
//
// Aucune dépendance externe : uniquement dart:io et dart:convert.
import 'dart:convert';
import 'dart:io';

/// Éditeurs vérifiés autorisés.
const allowedPublishers = {'dart.dev', 'tools.dart.dev', 'labs.dart.dev'};

Future<void> main() async {
  final lockFile = File('pubspec.lock');
  if (!lockFile.existsSync()) {
    stderr.writeln('Erreur : pubspec.lock introuvable à la racine.');
    exit(2);
  }
  final hostedInLock = _hostedInLock(lockFile.readAsLinesSync());

  final pubspecs = <File>[
    File('pubspec.yaml'),
    ...Directory('packages')
        .listSync()
        .whereType<Directory>()
        .map((d) => File('${d.path}/pubspec.yaml'))
        .where((f) => f.existsSync()),
  ];
  final direct = <String>{};
  for (final pubspec in pubspecs) {
    direct.addAll(_directDependencies(pubspec.readAsLinesSync()));
  }
  final hosted = direct.where(hostedInLock.contains).toList()..sort();

  final client = HttpClient();
  final offenders = <String, String>{};
  final errors = <String>[];
  try {
    for (final name in hosted) {
      try {
        final publisher = await _publisherOf(client, name);
        if (publisher == null || !allowedPublishers.contains(publisher)) {
          offenders[name] = publisher ?? '(aucun éditeur)';
        }
      } on Object catch (e) {
        errors.add('$name : $e');
      }
    }
  } finally {
    client.close(force: true);
  }

  stdout.writeln(
    '${hosted.length} dépendance(s) directe(s) hébergée(s) vérifiée(s) : '
    '${hosted.join(', ')}',
  );
  if (errors.isNotEmpty) {
    stderr.writeln('Impossible de vérifier ${errors.length} package(s) :');
    for (final e in errors) {
      stderr.writeln('  - $e');
    }
  }
  if (offenders.isNotEmpty) {
    stderr.writeln(
      '${offenders.length} package(s) non publiés par '
      '${allowedPublishers.join(', ')} :',
    );
    for (final entry in offenders.entries) {
      stderr.writeln('  - ${entry.key} : ${entry.value}');
    }
  }
  if (errors.isNotEmpty || offenders.isNotEmpty) exit(1);
  stdout.writeln(
    'OK : toutes les dépendances directes ont un éditeur autorisé.',
  );
}

/// Noms des dépendances directes non path, git ni sdk d'un pubspec.yaml.
Set<String> _directDependencies(List<String> lines) {
  final result = <String>{};
  var inSection = false;
  String? current;
  var excluded = false;
  void flush() {
    if (current != null && !excluded) result.add(current!);
    current = null;
  }

  for (final raw in lines) {
    final line = raw.replaceFirst(RegExp(r'\s+#.*$'), '');
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    if (!line.startsWith(' ')) {
      flush();
      inSection = RegExp(r'^(dependencies|dev_dependencies):').hasMatch(line);
      continue;
    }
    if (!inSection) continue;
    final entry = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
    if (entry != null) {
      flush();
      current = entry.group(1);
      excluded = false;
    } else if (RegExp(r'^\s{4,}(path|git|sdk):').hasMatch(line)) {
      excluded = true;
    }
  }
  flush();
  return result;
}

/// Noms des packages résolus en `source: hosted` dans pubspec.lock.
Set<String> _hostedInLock(List<String> lines) {
  final result = <String>{};
  var inPackages = false;
  String? current;
  for (final line in lines) {
    if (line.startsWith('packages:')) {
      inPackages = true;
      continue;
    }
    if (!inPackages) continue;
    if (line.isNotEmpty && !line.startsWith(' ')) break;
    final pkg = RegExp(r'^  ([A-Za-z0-9_]+):\s*$').firstMatch(line);
    if (pkg != null) {
      current = pkg.group(1);
    } else if (current != null &&
        RegExp(r'^    source:\s*hosted\s*$').hasMatch(line)) {
      result.add(current);
    }
  }
  return result;
}

/// Retourne l'identifiant de l'éditeur, ou `null` s'il n'y en a pas.
Future<String?> _publisherOf(HttpClient client, String name) async {
  final uri = Uri.https('pub.dev', '/api/packages/$name/publisher');
  final request = await client.getUrl(uri);
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode != 200) {
    throw HttpException('HTTP ${response.statusCode} pour $uri');
  }
  final json = jsonDecode(body) as Map<String, Object?>;
  return json['publisherId'] as String?;
}
