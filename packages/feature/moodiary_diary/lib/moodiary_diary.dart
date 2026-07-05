/// Moodiary 日记包：自洽的日记 feature。
///
/// 详情/编辑页（基于 moodiary_editor）、搜索/分类/统计/地图/回收站/管理页、日记选择器，
/// 列表/瀑布/日历视图主体、[ViewModeSheet]、[CategoryFilterBar]/[CategorySwitcherSheet]
/// 等可复用主体，以及 [diaryRoutes]。首页壳与 sync 状态由 app 侧组合（本包不依赖
/// moodiary_sync）。
library;

export 'src/routes.dart' show diaryRoutes;
export 'src/application/diary_selection.dart'
    show diarySelectionProvider, DiarySelectionNotifier;
export 'src/presentation/diary_select_page.dart' show DiarySelectPage;
export 'src/presentation/calendar/calendar_page.dart' show CalendarView;
export 'src/presentation/widget/listview.dart' show DiaryListView;
export 'src/presentation/widget/waterfall_view.dart' show DiaryWaterFallView;
export 'src/presentation/widget/view_mode_sheet.dart' show ViewModeSheet;
export 'src/presentation/widget/category_filter_bar.dart'
    show CategoryFilterBar;
export 'src/presentation/widget/category_switcher_sheet.dart'
    show CategorySwitcherSheet, CategorySelection;
