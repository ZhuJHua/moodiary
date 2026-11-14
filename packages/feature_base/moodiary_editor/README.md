# moodiary_editor

Moodiary’s Flutter diary editor, shared toolbar and legacy format migration service.

`MoodiaryEditor` uses `flutter_tiptap` for virtualised rendering, editing and selection. Documents retain the existing Tiptap JSON format. `MoodiaryEditorController` exposes commands, focus, search and document swapping to the host.

The host supplies font and media resolvers, metadata and navigation callbacks. Audio and video use Flutter media controls. Native clipboard and image transfer APIs live in `moodiary_native` and use Pigeon.

`EditorMigrationService` converts legacy Quill and Markdown entries to Tiptap JSON. Dividers, media, attachments and diary links retain their JSON and HTML representations.

Run `fvm dart tool/task.dart analyze` and `fvm dart tool/task.dart test --all` from the repository root.
