/// Moodiary 日记包：自洽的日记 feature。
///
/// 详情/编辑页（基于 moodiary_editor）、搜索/分类/统计/地图/回收站/管理页、日记选择器，
/// 时间线视图主体、[ViewModeSheet]、[CategoryFilterBar]/[CategorySwitcherSheet]
/// 等可复用主体，以及 [diaryRoutes]。首页壳与 sync 状态由 app 侧组合（本包不依赖
/// moodiary_sync）。
library;

export 'src/routes.dart' show diaryRoutes;
export 'src/application/diary_selection.dart'
    show diarySelectionProvider, DiarySelectionNotifier;
export 'src/presentation/diary_select_page.dart' show DiarySelectPage;
export 'src/presentation/widget/timeline_view.dart' show DiaryTimelineView;
export 'src/presentation/widget/view_mode_sheet.dart' show ViewModeSheet;
export 'src/presentation/widget/category_filter_bar.dart'
    show CategoryFilterBar;
export 'src/presentation/widget/category_switcher_sheet.dart'
    show CategorySwitcherSheet, CategorySelection;
