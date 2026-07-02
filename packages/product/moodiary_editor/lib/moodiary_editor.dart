/// Moodiary 编辑器包：可嵌入的 TipTap（webview）编辑器组件。
///
/// 宿主 app 通过注入面接入：[MoodiaryEditor] 的 `seedResolver`（主题种子）、`mediaResolver`
/// （媒体磁盘解析）、`loadingBuilder`，以及各媒体选取/播放/存盘回调；与 app 完全解耦。
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
