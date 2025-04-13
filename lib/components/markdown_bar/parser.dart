import 'package:flutter/widgets.dart';

enum MarkdownToolbarOption {
  bold,
  italic,
  strikethrough,
  heading,
  link,
  image,
  code,
  unorderedList,
  orderedList,
  checkbox,
  quote,
  horizontalRule,
}

enum FormatOption { formatStartEnd, formatStart, formatList, formatAddNew }

enum TextApplyOption {
  selectionHasCharacter,
  outsideSelectionHasCharacter,
  noneAddNew,
}

class Format {
  Format({
    required this.formatOption,
    required this.controller,
    required this.selection,
    this.character,
    this.newLine,
    this.placeholder = 'Text',
    this.multipleCharacters,
    this.multipleCharactersOption,
    this.orderedList,
  });

  FormatOption formatOption;
  TextEditingController controller;
  TextSelection selection;
  String? character;
  bool? newLine;
  String placeholder = 'Text';
  List<String>? multipleCharacters;
  int? multipleCharactersOption;
  bool? orderedList;
  late String newText;
  late String beforeText;
  late String afterText;
  late String reversedBeforeText;
  late String reversedAfterText;
  late TextApplyOption textApplyOption;

  static void toolbarItemPressed({
    required MarkdownToolbarOption markdownToolbarOption,
    required TextEditingController controller,
    required TextSelection selection,
    int? option,
    String? customBoldCharacter,
    String? customItalicCharacter,
    String? customCodeCharacter,
    String? customBulletedListCharacter,
    String? customHorizontalRuleCharacter,
    String? mediaPath,
  }) {
    switch (markdownToolbarOption) {
      case MarkdownToolbarOption.bold:
        Format(
          formatOption: FormatOption.formatStartEnd,
          controller: controller,
          selection: selection,
          character: customBoldCharacter ?? '**',
          placeholder: 'Bold',
        ).format();
        break;
      case MarkdownToolbarOption.italic:
        Format(
          formatOption: FormatOption.formatStartEnd,
          controller: controller,
          selection: selection,
          character: customItalicCharacter ?? '*',
          placeholder: 'Italic',
        ).format();
        break;
      case MarkdownToolbarOption.strikethrough:
        Format(
          formatOption: FormatOption.formatStartEnd,
          controller: controller,
          selection: selection,
          character: '~~',
          placeholder: 'Strikethrough',
        ).format();
        break;
      case MarkdownToolbarOption.code:
        Format(
          formatOption: FormatOption.formatStartEnd,
          controller: controller,
          selection: selection,
          character: customCodeCharacter ?? '```',
          placeholder: 'Code',
          newLine: true,
        ).format();
        break;
      case MarkdownToolbarOption.heading:
        Format(
          formatOption: FormatOption.formatStart,
          controller: controller,
          selection: selection,
          multipleCharacters: [
            '# ',
            '## ',
            '### ',
            '#### ',
            '##### ',
            '###### ',
          ],
          multipleCharactersOption: option,
          newLine: true,
          placeholder: 'Heading',
        ).format();
        break;
      case MarkdownToolbarOption.quote:
        Format(
          formatOption: FormatOption.formatStart,
          controller: controller,
          selection: selection,
          character: '> ',
          newLine: true,
          placeholder: 'Quote',
        ).format();
        break;
      case MarkdownToolbarOption.unorderedList:
        Format(
          formatOption: FormatOption.formatList,
          controller: controller,
          selection: selection,
          character:
              customBulletedListCharacter != null
                  ? '$customBulletedListCharacter '
                  : '- ',
          placeholder: 'Bulleted list',
        ).format();
        break;
      case MarkdownToolbarOption.orderedList:
        Format(
          formatOption: FormatOption.formatList,
          controller: controller,
          selection: selection,
          orderedList: true,
          placeholder: 'Numbered list',
        ).format();
        break;
      case MarkdownToolbarOption.checkbox:
        Format(
          formatOption: FormatOption.formatList,
          controller: controller,
          selection: selection,
          placeholder: 'Checkbox',
          multipleCharacters: ['- [ ] ', '- [x] '],
          multipleCharactersOption: option,
        ).format();
        break;
      case MarkdownToolbarOption.link:
        formatTextLink(controller: controller, selection: selection);
        break;
      case MarkdownToolbarOption.image:
        formatImage(
          controller: controller,
          selection: selection,
          imgPath: mediaPath,
        );
        break;
      case MarkdownToolbarOption.horizontalRule:
        Format(
          formatOption: FormatOption.formatAddNew,
          controller: controller,
          selection: selection,
          //newLine: true,
          character: customHorizontalRuleCharacter ?? '---',
        ).format();
        break;
    }
  }

  void format() {
    final String selectionText = controller.text.substring(
      selection.start,
      selection.end,
    );

    beforeText = controller.text.substring(0, selection.start);
    afterText = controller.text.substring(
      selection.end,
      controller.text.length,
    );
    reversedBeforeText = String.fromCharCodes(
      beforeText.runes.toList().reversed,
    );
    reversedAfterText = String.fromCharCodes(afterText.runes.toList().reversed);

    character =
        multipleCharacters != null
            ? multipleCharacters![multipleCharactersOption ?? 0]
            : character ?? '';

    if (controller.text.isNotEmpty && selectionText.isNotEmpty) {
      newText = selectionText;

      if (selectionCharacterBool(
        formatOption: formatOption,
        selectionText: selectionText,
      )) {
        selectionHasCharacterFunction(formatOption: formatOption);
      } else if (outsideSelectionHasCharacterBool(formatOption: formatOption)) {
        outsideHasCharacterFunction(formatOption: formatOption);
      } else {
        addFunction(formatOption: formatOption);
      }

      applyFunction(formatOption: formatOption);
    } else {
      emptyAddNewFunction(formatOption: formatOption);
    }
  }

  bool selectionCharacterBool({
    required FormatOption formatOption,
    required String selectionText,
  }) {
    switch (formatOption) {
      case FormatOption.formatStartEnd:
        return selectionText.contains(character!, 0) &&
            selectionText.contains(character!, 1);
      case FormatOption.formatStart:
        //TODO if same -> remove /// if other -> remove AND add new
        if (multipleCharacters != null) {
          for (var i = 0; i < multipleCharacters!.length; i++) {
            if (selectionText.contains(multipleCharacters![i])) {
              return true;
            }
          }
        }
        return selectionText.contains(character!);
      case FormatOption.formatList:
        final exp = RegExp(r'[0-9]. ');
        //TODO if same -> remove /// if other -> remove AND add new
        if (multipleCharacters != null) {
          for (var i = 0; i < multipleCharacters!.length; i++) {
            if (selectionText.contains(multipleCharacters![i])) {
              return true;
            } else {
              //return false;
            }
          }
        }
        return selectionText.contains(orderedList == true ? exp : character!);
      case FormatOption.formatAddNew:
        return selectionText.contains(character!);
    }
  }

  bool outsideSelectionHasCharacterBool({required FormatOption formatOption}) {
    if (formatOption == FormatOption.formatStartEnd) {
      return beforeText.isNotEmpty &&
          reversedBeforeText[0] != ' ' &&
          reversedBeforeText.contains(character!) &&
          afterText.isNotEmpty &&
          reversedAfterText[0] != ' ' &&
          reversedAfterText.contains(character!);
    } else {
      return false;
    }
  }

  void selectionHasCharacterFunction({required FormatOption formatOption}) {
    textApplyOption = TextApplyOption.selectionHasCharacter;
    switch (formatOption) {
      case FormatOption.formatStartEnd:
        newText = controller.text.substring(selection.start, selection.end);
        newText = newText.replaceAll(character!, '');
        break;
      case FormatOption.formatStart:
        newText = controller.text.substring(selection.start, selection.end);
        if (multipleCharacters != null) {
          for (var i = 0; i < multipleCharacters!.length; i++) {
            if (newText.contains(multipleCharacters![i])) {
              newText = newText.replaceAll(character![0], '');
            } else {
              newText = newText.replaceAll(character!, '');
              break;
            }
          }
        } else {
          newText = newText.replaceAll(character!, '');
        }
        //newText = newText.replaceAll(character!, '');
        break;
      case FormatOption.formatList:
        newText = controller.text.substring(selection.start, selection.end);
        final exp = RegExp(r'[0-9]. ');

        final lines = newText.split('\n');
        var orderedIndex =
            int.tryParse(lines[0].substring(0, lines[0].indexOf(exp) + 1)) ?? 0;

        if (orderedList == true) {
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].isNotEmpty) {
              lines[i] = lines[i].replaceAll('$orderedIndex. ', '');
              orderedIndex++;
            }
          }
        } else {
          if (multipleCharacters != null) {
            for (var i = 0; i < multipleCharacters!.length; i++) {
              for (var j = 0; j < lines.length; j++) {
                if (lines[j].contains(multipleCharacters![i])) {
                  lines[j] = lines[j].replaceAll(multipleCharacters![i], '');
                } else {
                  for (var i = 0; i < lines.length; i++) {
                    lines[i] = lines[i].replaceAll(character!, '');
                  }
                }
              }
            }
          } else {
            for (var i = 0; i < lines.length; i++) {
              lines[i] = lines[i].replaceAll(character!, '');
            }
          }
        }

        newText = lines.join('\n');
        break;
      case FormatOption.formatAddNew:
        newText = controller.text.substring(selection.start, selection.end);
        newText = newText.replaceAll(character!, '');
        break;
    }
  }

  void outsideHasCharacterFunction({required FormatOption formatOption}) {
    textApplyOption = TextApplyOption.outsideSelectionHasCharacter;
    if (formatOption == FormatOption.formatStartEnd) {
      reversedBeforeText = reversedBeforeText.replaceFirst(character!, '');
      beforeText = String.fromCharCodes(
        reversedBeforeText.runes.toList().reversed,
      );
      afterText = afterText.replaceFirst(character!, '');
    }
  }

  void addFunction({required FormatOption formatOption}) {
    textApplyOption = TextApplyOption.noneAddNew;
    switch (formatOption) {
      case FormatOption.formatStartEnd:
        newText = controller.text.substring(selection.start, selection.end);
        newLine == true
            ? newText = '\n$character\n$newText\n$character'
            : newText = '$character$newText$character';
        break;
      case FormatOption.formatStart:
        newText = controller.text.substring(selection.start, selection.end);
        newLine == true
            ? newText = '$character$newText'
            : newText = '$character$newText';
        break;
      case FormatOption.formatList:
        newText = controller.text.substring(selection.start, selection.end);
        final lines = newText.split('\n');
        var orderedIndex = 0;

        for (var i = 0; i < lines.length; i++) {
          if (lines[i].isNotEmpty) {
            if (orderedList == true) {
              lines[i] = '${orderedIndex + 1}. ${lines[i]}';
              orderedIndex++;
            } else {
              lines[i] = '$character${lines[i]}';
            }
          }
        }

        newText = lines.join('\n');
        break;
      case FormatOption.formatAddNew:
        newLine == true
            ? newText = '\n$character$newText\n'
            : newText = '$character$newText';
        newText = character!;
        break;
    }
  }

  void applyFunction({required FormatOption formatOption}) {
    var baseOffset = 0;
    var extentOffset = 0;
    switch (formatOption) {
      case FormatOption.formatStartEnd:
        newText = '$beforeText$newText$afterText';
        controller.text = newText;

        if (textApplyOption == TextApplyOption.selectionHasCharacter ||
            textApplyOption == TextApplyOption.outsideSelectionHasCharacter) {
          baseOffset = selection.start - character!.length;
          extentOffset = selection.end - character!.length;
        } else if (textApplyOption == TextApplyOption.noneAddNew) {
          baseOffset = selection.start + character!.length;
          extentOffset = selection.end + character!.length;
          if (newLine != null) {
            baseOffset += 2;
            extentOffset += 2;
          }
        }
        break;
      case FormatOption.formatStart:
        newText = '$beforeText$newText$afterText';
        controller.text = newText;
        if (textApplyOption == TextApplyOption.selectionHasCharacter ||
            textApplyOption == TextApplyOption.outsideSelectionHasCharacter) {
          baseOffset = selection.start - character!.length;
          extentOffset = selection.end - character!.length;
        } else if (textApplyOption == TextApplyOption.noneAddNew) {
          baseOffset = selection.start + character!.length;
          extentOffset = selection.end + character!.length;
        }
        break;
      case FormatOption.formatList:
        final lines = newText.split('\n');
        var index = 0;
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].isNotEmpty) {
            index++;
          }
        }
        if (textApplyOption == TextApplyOption.selectionHasCharacter ||
            textApplyOption == TextApplyOption.outsideSelectionHasCharacter) {
          if (orderedList == true) {
            baseOffset = selection.end - 3 * index;
            extentOffset = selection.end - 3 * index;
          } else {
            baseOffset = selection.end - 2 * index;
            extentOffset = selection.end - 2 * index;
          }
        } else if (textApplyOption == TextApplyOption.noneAddNew) {
          if (orderedList == true) {
            baseOffset = selection.end + 3 * index;
            extentOffset = selection.end + 3 * index;
          } else {
            baseOffset = selection.end + 2 * index;
            extentOffset = selection.end + 2 * index;
          }
        }
        newText = '$beforeText$newText$afterText';
        controller.text = newText;
        break;
      case FormatOption.formatAddNew:
        newText = '$beforeText$newText$afterText';
        controller.text = newText;

        if (textApplyOption == TextApplyOption.selectionHasCharacter ||
            textApplyOption == TextApplyOption.outsideSelectionHasCharacter) {
          baseOffset = selection.start - character!.length;
          extentOffset = selection.start - character!.length;
        } else if (textApplyOption == TextApplyOption.noneAddNew) {
          baseOffset = selection.start + character!.length;
          extentOffset = selection.start + character!.length;
        }
        break;
    }

    if (baseOffset >= controller.text.length) {
      baseOffset = controller.text.length;
    }
    if (extentOffset >= controller.text.length) {
      extentOffset = controller.text.length;
    }
    if (baseOffset <= 0) baseOffset = 0;
    if (extentOffset <= 0) extentOffset = 0;
    controller.selection = TextSelection(
      baseOffset: baseOffset,
      extentOffset: extentOffset,
    );
  }

  void emptyAddNewFunction({required FormatOption formatOption}) {
    var baseOffset = 0;
    var extentOffset = 0;
    switch (formatOption) {
      case FormatOption.formatStartEnd:
        final newText = character;
        final beforeText = controller.text.substring(0, selection.start);
        final afterText = controller.text.substring(
          selection.end,
          controller.text.length,
        );
        controller.text = '$beforeText$newText$placeholder$newText$afterText';
        baseOffset = selection.start + character!.length;
        extentOffset = selection.end + placeholder.length + character!.length;
        break;
      case FormatOption.formatStart:
        final newText = character;
        final beforeText = controller.text.substring(0, selection.start);
        final afterText = controller.text.substring(
          selection.end,
          controller.text.length,
        );
        controller.text = '$beforeText$newText$placeholder$afterText';

        baseOffset = selection.start + character!.length;
        extentOffset = selection.end + placeholder.length + character!.length;
        break;
      case FormatOption.formatList:
        final newText = orderedList == true ? '1. ' : character;
        final beforeText = controller.text.substring(0, selection.start);
        final afterText = controller.text.substring(
          selection.end,
          controller.text.length,
        );
        controller.text = '$beforeText$newText$placeholder$afterText';
        baseOffset = selection.start + newText!.length;
        extentOffset = selection.end + placeholder.length + newText.length;
        break;
      case FormatOption.formatAddNew:
        newLine == true ? newText = '\n$character\n' : newText = character!;
        controller.text = '$beforeText$newText$afterText';
        baseOffset = selection.start + character!.length + 1;
        extentOffset = selection.start + character!.length + 1;
        break;
    }
    if (baseOffset >= controller.text.length) {
      baseOffset = controller.text.length;
    }
    if (extentOffset >= controller.text.length) {
      extentOffset = controller.text.length;
    }
    if (baseOffset <= 0) baseOffset = 0;
    if (extentOffset <= 0) extentOffset = 0;
    controller.selection = TextSelection(
      baseOffset: baseOffset,
      extentOffset: extentOffset,
    );
  }
}

void formatTextLink({
  required TextEditingController controller,
  required TextSelection selection,
}) {
  final String selectionText = controller.text.substring(
    selection.start,
    selection.end,
  );
  const String placeholder = 'My Link text';
  const String placeholderEnd = 'https://example.com';

  if (controller.text.isNotEmpty && selectionText.isNotEmpty) {
    var newText = selectionText;

    final beforeText = controller.text.substring(0, selection.start);
    final afterText = controller.text.substring(
      selection.end,
      controller.text.length,
    );

    newText = '[$newText]($placeholderEnd)';
    newText = '$beforeText$newText$afterText';

    controller.text = newText;

    controller.selection = TextSelection(
      baseOffset:
          selection.start + 3 + selectionText.length + 'https://'.length,
      extentOffset: selection.end + placeholderEnd.length + 3,
    );
  } else {
    final beforeText = controller.text.substring(0, selection.start);
    final afterText = controller.text.substring(
      selection.end,
      controller.text.length,
    );
    controller.text = '$beforeText[$placeholder]($placeholderEnd)$afterText';

    controller.selection = TextSelection(
      baseOffset: selection.start + 3 + placeholder.length + 'https://'.length,
      extentOffset:
          selection.end + placeholder.length + 3 + placeholderEnd.length,
    );
  }
}

void formatImage({
  required TextEditingController controller,
  required TextSelection selection,
  required String? imgPath,
}) {
  const String altPlaceholder = '';
  const String linkPlaceholder = '';

  final beforeText = controller.text.substring(0, selection.start);
  final afterText = controller.text.substring(
    selection.end,
    controller.text.length,
  );
  controller.text =
      '$beforeText![$altPlaceholder](${imgPath ?? linkPlaceholder})$afterText';

  controller.selection = TextSelection(
    baseOffset: selection.start + 4 + altPlaceholder.length,
    extentOffset:
        selection.start +
        altPlaceholder.length +
        4 +
        (imgPath ?? linkPlaceholder).length,
  );
}
