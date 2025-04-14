import 'package:flutter/material.dart';
import 'package:moodiary/components/base/text.dart';

class AdaptiveTitleTile extends StatelessWidget {
  const AdaptiveTitleTile({super.key, required this.title, this.subtitle});

  final dynamic title;

  final dynamic subtitle;

  @override
  Widget build(BuildContext context) {
    assert(
      title is String || title is Widget,
      'title must be a String or a Widget',
    );
    assert(
      subtitle == null || subtitle is String || subtitle is Widget,
      'subtitle must be a String or a Widget',
    );
    return ListTile(
      title:
          (title is String) ? AdaptiveText(title, isPrimaryTitle: true) : title,
      subtitle:
          (subtitle is String)
              ? AdaptiveText(subtitle!, isTileSubtitle: true)
              : subtitle,
    );
  }
}

class AdaptiveListTile extends StatelessWidget {
  const AdaptiveListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.leading,
    this.isFirst,
    this.isLast,
    this.contentPadding,
    this.tileColor,
    this.shape,
  });

  final dynamic title;

  final dynamic subtitle;

  final Widget? trailing;

  final Widget? leading;

  final VoidCallback? onTap;

  final bool? isFirst;

  final bool? isLast;

  final EdgeInsets? contentPadding;

  final Color? tileColor;

  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) {
    assert(
      title is String || title is Widget,
      'title must be a String or a Widget',
    );
    assert(
      subtitle == null || subtitle is String || subtitle is Widget,
      'subtitle must be a String or a Widget',
    );
    var realTitle = title;
    var realSubtitle = subtitle;
    if (title is Text) {
      realTitle = (title as Text).data;
    }
    if (subtitle is Text) {
      realSubtitle = (subtitle as Text).data;
    }
    return ListTile(
      tileColor: tileColor,
      title:
          (realTitle is String)
              ? AdaptiveText(realTitle, isTileTitle: true)
              : realTitle,
      shape:
          shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: isFirst == true ? const Radius.circular(12) : Radius.zero,
              bottom: isLast == true ? const Radius.circular(12) : Radius.zero,
            ),
          ),
      contentPadding: contentPadding,
      subtitle:
          (realSubtitle is String)
              ? AdaptiveText(realSubtitle, isTileSubtitle: true)
              : realSubtitle,
      trailing: trailing,
      leading: leading,
      onTap: onTap,
    );
  }
}

class AdaptiveSwitchListTile extends StatelessWidget {
  const AdaptiveSwitchListTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.isFirst,
    this.isLast,
    this.secondary,
    this.isSingle,
  });

  final dynamic title;

  final dynamic subtitle;

  final bool value;

  final ValueChanged<bool>? onChanged;

  final Widget? secondary;

  final bool? isFirst;

  final bool? isLast;

  final bool? isSingle;

  @override
  Widget build(BuildContext context) {
    assert(
      title is String || title is Widget,
      'title must be a String or a Widget',
    );
    assert(
      subtitle == null || subtitle is String || subtitle is Widget,
      'subtitle must be a String or a Widget',
    );
    var realTitle = title;
    var realSubtitle = subtitle;
    if (title is Text) {
      realTitle = (title as Text).data;
    }
    if (subtitle is Text) {
      realSubtitle = (subtitle as Text).data;
    }
    return SwitchListTile(
      title:
          (realTitle is String)
              ? AdaptiveText(realTitle, isTileTitle: true)
              : realTitle,
      secondary: secondary,
      shape: RoundedRectangleBorder(
        borderRadius:
            isSingle == true
                ? BorderRadius.circular(12)
                : BorderRadius.vertical(
                  top:
                      isFirst == true ? const Radius.circular(12) : Radius.zero,
                  bottom:
                      isLast == true ? const Radius.circular(12) : Radius.zero,
                ),
      ),
      subtitle:
          (realSubtitle is String)
              ? AdaptiveText(realSubtitle, isTileSubtitle: true)
              : realSubtitle,
      value: value,
      onChanged: onChanged,
    );
  }
}
