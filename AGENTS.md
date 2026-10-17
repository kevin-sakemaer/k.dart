# Forge

Monorepo Dart en pub workspaces. Flutter est épinglé dans `.fvmrc` (3.47.5). Toute commande Dart ou Flutter passe par `fvm dart` ou `fvm flutter`.

- `packages/forge_core` porte le graphe d’issues, le titre de milestone, l’ordre des échéances et le score.
- `packages/forge_eval` se lance avec `fvm dart run forge_eval --milestone N --report report.json`.
- `/forge` dépose un milestone et ses issues. Il ne les implémente pas. `args.due_on` est une date `YYYY-MM-DD` facultative. Sans date, le milestone passe après ceux qui en ont une.
- `/forge-build` implémente. Il peut tourner pendant qu’un `/forge` dépose d’autres milestones. Il prend le milestone ouvert dont l’échéance est la plus ancienne : le retard le plus loin d’aujourd’hui d’abord, puis l’échéance future la plus proche. À date égale, le plus petit numéro gagne. Au plus quatre PR ouvertes, en suivant cet ordre.

Vérifier depuis la racine : `fvm dart analyze --fatal-infos` puis `fvm dart test packages/forge_core/test packages/forge_eval/test`.

Les opérations GitHub passent par `gh` sur `kevin-sakemaer/k.dart`. L’ordre des issues est le blocked-by GitHub. Une PR se merge quand le check `test` est vert et que la branche contient `main`. Au plus quatre PR ouvertes en même temps. Pas de `.fvmrc` dans un paquet. Ne pas modifier un test pour le faire passer.
