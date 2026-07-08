import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_diary/src/application/calendar_controller.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_card.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_nav.dart';

/// 首页的日历视图（与列表 / 网格并列），非独立页面；可按 [categoryId] 过滤。
class CalendarView extends ConsumerStatefulWidget {
  final String? categoryId;

  const CalendarView({super.key, this.categoryId});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  double _dayHeat(int count) {
    if (count == 0) return 0;
    if (count >= 5) return 1;
    return count / 5;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scheme = context.colorScheme;
    final async = ref.watch(
      monthDiariesProvider(
        month: _currentMonth,
        categoryId: widget.categoryId,
      ),
    );

    final calendar = async.maybeWhen(
      data: (list) => _buildDatePicker(context, list),
      orElse: () => _buildDatePicker(context, const <Diary>[]),
    );

    final diaryBody = ClipRRect(
      borderRadius: AppBorderRadius.mediumBorderRadius,
      child: async.buildLoading(
        data: (diaries) {
          if (diaries.isEmpty) {
            return Center(
              child: FaIcon(
                FontAwesomeIcons.boxOpen,
                color: scheme.onSurface,
                size: 56,
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              0,
              4,
              0,
              4 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: diaries.length,
            itemBuilder: (context, i) {
              final d = diaries[i];
              return TimeLineComponent(
                actionColor: Color.lerp(
                  AppColor.emoColorList.first,
                  AppColor.emoColorList.last,
                  d.mood,
                )!,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: i == 0 ? 0 : 4,
                    bottom: i == diaries.length - 1 ? 0 : 4,
                  ),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final category = ref.watch(
                        categoryByIdProvider(d.categoryId),
                      );
                      return CalendarDiaryCard(
                        diary: d,
                        category: category,
                        onTap: () => openDiaryDetail(context, d),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );

    // 不包 SafeArea：底部安全区 + FAB 让位空间由外层注入到 MediaQuery.padding.bottom，
    // 由日记列表（唯一贴底的可滚动元素）作为滚动内边距吸收，内容从 FAB 下方滚过。
    // 若在此消费该 padding 会把整个视图顶起、留出只放 FAB 的死区，挤压日历列表高度。
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: size.width >= 600
          ? Row(
              children: [
                Expanded(child: diaryBody),
                const SizedBox(width: 8),
                SizedBox(width: 320, child: calendar),
              ],
            )
          : Column(
              children: [
                calendar,
                const SizedBox(height: 8),
                Expanded(child: diaryBody),
              ],
            ),
    );
  }

  Widget _buildDatePicker(BuildContext context, List<Diary> diaries) {
    final scheme = context.colorScheme;
    final allDate = <DateTime>[];
    final dateWithDiary = <DateTime>{};
    for (final d in diaries) {
      final t = DateTime(d.time.year, d.time.month, d.time.day);
      allDate.add(t);
      dateWithDiary.add(t);
    }
    final dateCountMap = ArrayUtil.countList(allDate);

    return Stack(
      children: [
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: CalendarDatePicker2(
            displayedMonthDate: _currentMonth,
            config: CalendarDatePicker2Config(
              calendarViewMode: CalendarDatePicker2Mode.day,
              calendarType: CalendarDatePicker2Type.single,
              hideMonthPickerDividers: true,
              hideYearPickerDividers: true,
              useAbbrLabelForMonthModePicker: true,
              allowSameValueSelection: true,
              dayBuilder:
                  ({
                    required DateTime date,
                    TextStyle? textStyle,
                    BoxDecoration? decoration,
                    bool? isSelected,
                    bool? isDisabled,
                    bool? isToday,
                  }) {
                    final contains = dateWithDiary.contains(date);
                    final bgColor = contains
                        ? Color.lerp(
                            scheme.surfaceContainer,
                            scheme.primary,
                            _dayHeat(dateCountMap[date] ?? 0),
                          )
                        : null;
                    return Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bgColor,
                        ),
                        child: Center(
                          child: Text(
                            date.day.toString(),
                            style: textStyle?.copyWith(
                              color: contains
                                  ? (ThemeData.estimateBrightnessForColor(
                                              bgColor!,
                                            ) ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
              selectableDayPredicate: (date) => dateWithDiary.contains(date),
            ),
            value: const [],
            onDisplayedMonthChanged: (value) {
              setState(() {
                _currentMonth = DateTime(value.year, value.month);
              });
            },
          ),
        ),
        Positioned(bottom: 4, right: 4, child: _buildHeatLegend(context)),
      ],
    );
  }

  Widget _buildHeatLegend(BuildContext context) {
    final scheme = context.colorScheme;
    final style = context.textTheme.labelSmall?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.8),
    );
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('少', style: style),
          const SizedBox(width: 2),
          ...List.generate(5, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    scheme.surfaceContainer,
                    scheme.primary,
                    (i + 1) / 5,
                  ),
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
            );
          }),
          const SizedBox(width: 2),
          Text('多', style: style),
        ],
      ),
    );
  }
}
