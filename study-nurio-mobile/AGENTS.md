# AGENTS.md

## Scope (Required)
- `flutter_app/` is not the primary customer app for this repository.
- The production mobile apps are the Hotwire Native iOS and Android apps.
- Ignore this Flutter tree by default.
- Only modify files under `flutter_app/` when the user explicitly asks for Flutter-specific work.

## Behavior
- Do not treat Flutter as the default implementation target for mobile App Store or Play Store fixes.
- Route normal mobile product work toward the Hotwire Native clients and the Rails/Hotwire screens they render.
- If a task can be completed in either Flutter or Hotwire Native, prefer Hotwire Native unless the user says otherwise.
