import 'dart:typed_data';

import 'package:flutter/rendering.dart'
    show
        SliverConstraints,
        SliverGridDelegate,
        SliverGridGeometry,
        SliverGridLayout;
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';

sealed class MediaEntry {
  const MediaEntry();
}

class MediaHeader extends MediaEntry {
  final int group;

  const MediaHeader(this.group);
}

class MediaCell extends MediaEntry {
  final int group;
  final int index;

  const MediaCell(this.group, this.index);
}

class MediaFlat {
  final List<MediaEntry> entries;
  final List<DateTime> dates;
  final List<List<String>> groups;
  final List<Key> keys;
  final Map<Key, int> _indexOf;

  MediaFlat._(this.entries, this.dates, this.groups, this.keys)
    : _indexOf = {for (var i = 0; i < keys.length; i++) keys[i]: i};

  bool get isEmpty => entries.isEmpty;

  int? indexOfKey(Key key) => _indexOf[key];

  factory MediaFlat.of(List<MediaItem> items) {
    final entries = <MediaEntry>[];
    final dates = <DateTime>[];
    final groups = <List<String>>[];
    final keys = <Key>[];
    DateTime? current;
    for (final item in items) {
      final t = item.time.toLocal();
      final day = DateTime(t.year, t.month, t.day);
      if (day != current) {
        current = day;
        dates.add(day);
        groups.add(<String>[]);
        entries.add(MediaHeader(groups.length - 1));
        keys.add(ValueKey('h:${day.millisecondsSinceEpoch}'));
      }
      final g = groups.length - 1;
      groups[g].add(item.fileName);
      entries.add(MediaCell(g, groups[g].length - 1));
      keys.add(ValueKey('${item.diaryId}:${item.fileName}'));
    }
    return MediaFlat._(entries, dates, groups, keys);
  }
}

class GroupedGridDelegate extends SliverGridDelegate {
  final List<MediaEntry> entries;
  final int columns;
  final double spacing;
  final double headerExtent;
  final double? tileMainExtent;

  GroupedGridDelegate({
    required this.entries,
    required this.columns,
    required this.spacing,
    required this.headerExtent,
    this.tileMainExtent,
  });

  GroupedGridLayout? _cache;
  double _cacheCross = -1;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final cross = constraints.crossAxisExtent;
    if (_cache != null && _cacheCross == cross) return _cache!;
    _cacheCross = cross;
    return _cache = GroupedGridLayout.compute(
      entries: entries,
      crossAxisExtent: cross,
      columns: columns,
      spacing: spacing,
      headerExtent: headerExtent,
      tileMainExtent: tileMainExtent,
    );
  }

  @override
  bool shouldRelayout(GroupedGridDelegate oldDelegate) =>
      !identical(oldDelegate.entries, entries) ||
      oldDelegate.columns != columns ||
      oldDelegate.spacing != spacing ||
      oldDelegate.headerExtent != headerExtent ||
      oldDelegate.tileMainExtent != tileMainExtent;
}

class GroupedGridLayout extends SliverGridLayout {
  final Float64List _starts;
  final Float64List _ends;
  final Float64List _crossStarts;
  final Float64List _crossExtents;
  final double totalExtent;

  const GroupedGridLayout._(
    this._starts,
    this._ends,
    this._crossStarts,
    this._crossExtents,
    this.totalExtent,
  );

  factory GroupedGridLayout.compute({
    required List<MediaEntry> entries,
    required double crossAxisExtent,
    required int columns,
    required double spacing,
    required double headerExtent,
    double? tileMainExtent,
  }) {
    final n = entries.length;
    final starts = Float64List(n);
    final ends = Float64List(n);
    final crossStarts = Float64List(n);
    final crossExtents = Float64List(n);
    final tileCross = ((crossAxisExtent - spacing * (columns - 1)) / columns)
        .clamp(0.0, double.infinity);
    final tileMain = tileMainExtent ?? tileCross;
    var cursor = 0.0;
    var col = 0;
    for (var i = 0; i < n; i++) {
      final entry = entries[i];
      if (entry is MediaHeader) {
        if (col > 0) {
          cursor += tileMain + spacing;
          col = 0;
        }
        starts[i] = cursor;
        ends[i] = cursor + headerExtent;
        crossStarts[i] = 0;
        crossExtents[i] = crossAxisExtent;
        cursor += headerExtent;
      } else {
        if (col == columns) {
          cursor += tileMain + spacing;
          col = 0;
        }
        starts[i] = cursor;
        ends[i] = cursor + tileMain;
        crossStarts[i] = col * (tileCross + spacing);
        crossExtents[i] = tileCross;
        col++;
      }
    }
    if (col > 0) cursor += tileMain;
    return GroupedGridLayout._(starts, ends, crossStarts, crossExtents, cursor);
  }

  int get childCount => _starts.length;

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) => SliverGridGeometry(
    scrollOffset: _starts[index],
    crossAxisOffset: _crossStarts[index],
    mainAxisExtent: _ends[index] - _starts[index],
    crossAxisExtent: _crossExtents[index],
  );

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    var lo = 0;
    var hi = _ends.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_ends[mid] > scrollOffset) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    var lo = 0;
    var hi = _starts.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_starts[mid] < scrollOffset) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo > 0 ? lo - 1 : 0;
  }

  @override
  double computeMaxScrollOffset(int childCount) {
    if (childCount <= 0) return 0;
    if (childCount >= _ends.length) return totalExtent;
    return _ends[childCount - 1];
  }
}
