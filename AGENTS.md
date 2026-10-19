# Forge

Monorepo Dart en pub workspaces. Flutter est épinglé dans `.fvmrc` (3.47.5). Toute commande Dart ou Flutter passe par `fvm dart` ou `fvm flutter`.

- `packages/forge_core` porte le graphe d’issues, le titre de milestone, l’ordre des échéances et le score.
- `packages/forge_eval` se lance avec `fvm dart run forge_eval --milestone N --report report.json`.
- `/forge` dépose une idée en un ou plusieurs milestones, puis leurs issues. Il ne les implémente pas. Un milestone porte un résultat, pas un quota d’issues. Un bloqueur doit être dans le même milestone ou dans un milestone précédent. `args.due_on` est une date `YYYY-MM-DD` facultative appliquée à chaque milestone de l’idée. Sans date, le milestone passe après ceux qui en ont une.
- `/forge-build` implémente. Il peut tourner pendant qu’un `/forge` dépose d’autres milestones. Il prend le milestone ouvert dont l’échéance est la plus ancienne : le retard le plus loin d’aujourd’hui d’abord, puis l’échéance future la plus proche. À date égale, le plus petit numéro gagne. Au plus quatre PR ouvertes, en suivant cet ordre.
- Une branche est en retard sur `main` quand `gh api repos/kevin-sakemaer/k.dart/compare/main...<branche>` a `behind_by` supérieur à 0, même si le check `test` est vert. Le ruleset bloque alors le merge. Un conflit est `mergeable: CONFLICTING`.

Vérifier depuis la racine : `fvm dart analyze --fatal-infos` puis `fvm dart test packages/forge_core/test packages/forge_eval/test`.

Les opérations GitHub passent par `gh` sur `kevin-sakemaer/k.dart`. L’ordre des issues est le blocked-by GitHub. Une PR se merge automatiquement : le dev active `gh pr merge --auto --squash`, les checks requis doivent être verts, la branche doit contenir `main`, et le Reviewer pose `review:approved`. GitHub fusionne alors seul. Personne ne fusionne à la main. Au plus quatre PR ouvertes en même temps. Pas de `.fvmrc` dans un paquet. Ne pas modifier un test pour le faire passer.

## Flux de contribution et de merge

1. Créer une branche dédiée depuis `main`, puis ouvrir une PR et activer l'auto-merge en squash : `gh pr merge --auto --squash`. Personne ne merge à la main.
2. Les checks qualité doivent tous être verts : format, analyse stricte, tests, couverture et contrôle des éditeurs des dépendances (`dart run tool/check_publishers.dart`).
3. Le Reviewer donne son verdict par un commentaire sur la PR, puis pose le label `review:approved` ou `review:changes-requested`.
4. Le check `review-gate` échoue tant que la PR n'a pas `review:approved`, et aussi dès qu'elle porte `review:changes-requested`.
5. Chaque nouveau push (`synchronize`) retire automatiquement `review:approved` et fait échouer `review-gate` : il faut une nouvelle review.
6. Quand tous les checks requis sont verts et que le label est posé, GitHub merge automatiquement en squash.
7. Les éditeurs de dépendances autorisés sont `dart.dev`, `tools.dart.dev` et `labs.dart.dev`. Toute exception doit être validée par Grok Bot.
