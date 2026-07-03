/// Moodiary 编辑器包：完整的日记编辑能力。
///
/// 底层是可嵌入的 TipTap（webview）编辑器组件（[MoodiaryEditor]，通过 `seedResolver` /
/// `mediaResolver` / 各媒体回调注入解耦），其上是宿主层：[EditController]（自动保存到仓库）、
/// [EditorBody] / [MoodiaryEditorView]（阅读↔编辑复用同一实例）、录音/分类/地理天气等，
/// 供两端 app 直接组合使用。
library;

export 'src/moodiary_editor.dart'
    show
        MoodiaryEditor,
        MoodiaryEditorController,
        EditorSeed,
        EditorFont,
        DiaryLinkCandidate;
export 'src/editor_local_server.dart' show EditorLocalServer;
export 'src/media.dart'
    show MediaResolver, imageMimeOf, audioMimeOf, videoMimeOf;

export 'src/application/edit_controller.dart';
export 'src/presentation/widget/category_picker_sheet.dart';
export 'src/presentation/widget/draft_prompt.dart';
export 'src/presentation/widget/editor_body.dart';
export 'src/presentation/widget/moodiary_editor_view.dart';
export 'src/presentation/widget/record_sheet.dart';
