// Vérifie que chaque dépendance hébergée (`source: hosted`) de pubspec.lock
// est publiée par un éditeur vérifié autorisé sur pub.dev.
//
// Usage : dart run tool/check_publishers.dart [chemin/vers/pubspec.lock]
//
// Aucune dépendance externe : uniquement dart:io et dart:convert.
import 'dart:convert';
import 'dart:io';

/// Éditeurs vérifiés autorisés.
const allowedPublishers = {'dart.dev', 'tools.dart.dev', 'labs.dart.dev'};

/// Exceptions explicites : packages autorisés malgré un éditeur non listé.
///
/// Cette liste est vide par défaut. Toute exception ajoutée ici doit être
/// validée au préalable par Grok Bot, avec une justification en commentaire
/// à côté du nom du package.
const allowedExceptions = <String>{};

Future<void> main(List<String> args) async {
  final lockPath = args.isEmpty ? 'pubspec.lock' : args.first;
  final lockFile = File(lockPath);
  if (!lockFile.existsSync()) {
    stderr.writeln('Erreur : $lockPath introuvable.');
    exit(2);
  }

  final hosted = _hostedPackages(lockFile.readAsLinesSync());
  final client = HttpClient();
  final offenders = <String, String>{};
  final errors = <String>[];
  try {
    for (final name in hosted) {
      if (allowedExceptions.contains(name)) continue;
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

  stdout.writeln('${hosted.length} packages hébergés vérifiés.');
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
  stdout.writeln('OK : toutes les dépendances ont un éditeur autorisé.');
}

/// Extrait les noms des packages `source: hosted` d'un pubspec.lock.
List<String> _hostedPackages(List<String> lines) {
  final result = <String>[];
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
