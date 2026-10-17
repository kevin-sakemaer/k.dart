# Forge

Monorepo Dart en pub workspaces. Flutter est épinglé dans `.fvmrc` (3.47.5). Toute commande Dart ou Flutter passe par `fvm dart` ou `fvm flutter`.

- `packages/forge_core` porte le graphe d’issues, le titre de milestone et le score.
- `packages/forge_eval` se lance avec `fvm dart run forge_eval --milestone N --report report.json`.

Vérifier depuis la racine : `fvm dart analyze --fatal-infos` puis `fvm dart test packages/forge_core/test packages/forge_eval/test`.

Les opérations GitHub passent par `gh` sur `kevin-sakemaer/k.dart`. L’ordre des issues est le blocked-by GitHub. Une PR se merge quand le check `test` est vert et que la branche contient `main`. Au plus quatre PR ouvertes en même temps. Pas de `.fvmrc` dans un paquet. Ne pas modifier un test pour le faire passer.
