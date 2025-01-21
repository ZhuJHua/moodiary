import 'package:flutter/material.dart';

import 'parser.dart';

class MarkdownToolbar extends StatefulWidget {
  /// Creates a [MarkdownToolbar] widget.
  ///
  /// The following field is necessary: [useIncludedTextField] (bool)
  ///
  /// If you set [useIncludedTextField] to `true`, you are ready to use the Widget with its included TextField.
  ///
  /// If you set [useIncludedTextField] to `false`, you need a [TextField] widget outside of
  /// the [MarkdownToolbar] which has the same [controller] and [focusNode] set as the [MarkdownToolbar] (see below).
  ///
  /// Remember: In this case, you have to set the [controller] and [focusNode] fields in your
  /// [MarkdownToolbar]. Hover over each field for more details on implementing your own TextField correctly.
  const MarkdownToolbar({
    super.key,
    required this.useIncludedTextField,
    this.controller,
    this.focusNode,
    this.collapsable = true,
    this.alignCollapseButtonEnd = false,
    this.flipCollapseButtonIcon = false,
    this.backgroundColor = const Color(0xFFEEEEEE),
    this.dropdownTextColor = Colors.blue,
    this.iconColor = const Color(0xFF303030),
    this.iconSize = 24.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(6.0)),
    this.width = 60.0,
    this.height = 40.0,
    this.spacing = 4.0,
    this.runSpacing = 4.0,
    this.alignment = WrapAlignment.end,
    this.boldCharacter = '**',
    this.italicCharacter = '*',
    this.codeCharacter = '```',
    this.bulletedListCharacter = '-',
    this.horizontalRuleCharacter = '---',
    this.hideHeading = false,
    this.hideBold = false,
    this.hideItalic = false,
    this.hideStrikethrough = false,
    this.hideLink = false,
    this.hideImage = false,
    this.hideCode = false,
    this.hideBulletedList = false,
    this.hideNumberedList = false,
    this.hideCheckbox = false,
    this.hideQuote = false,
    this.hideHorizontalRule = false,
    this.showTooltips = true,
    this.headingTooltip = 'Heading',
    this.boldTooltip = 'Bold',
    this.italicTooltip = 'Italic',
    this.strikethroughTooltip = 'Strikethrough',
    this.linkTooltip = 'Link',
    this.imageTooltip = 'Image',
    this.codeTooltip = 'Code',
    this.bulletedListTooltip = 'Bulleted list',
    this.numberedListTooltip = 'Numbered list',
    this.checkboxTooltip = 'Checkbox',
    this.quoteTooltip = 'Quote',
    this.horizontalRuleTooltip = 'Horizontal rule',
  });

  /// It is recommended that you use your own TextField outside this widget for more customization.
  /// To do that, set [useIncludedTextField] to `false` and implement your own TextField outside.
  /// IMPORTANT: Remember to set the same [controller] and [focusNode] in the TextField as the ones in your [MarkdownToolbar].
  /// Hover over the 2 fields for more details.
  ///
  /// If you want to use the included TextField as a quick solution, set [useIncludedTextField] to `true` and you are ready to go.
  final bool useIncludedTextField;

  /// In order to use a custom TextField, assign a [TextEditingController] to the [controller] field.
  /// ```
  /// final TextEditingController _controller = TextEditingController(); //Declare the TextEditingController
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   _controller.addListener(() => setState(() {})); //To update the text inside the [controller] add a listener and call setState()
  /// }
  /// @override
  /// void dispose() {
  ///   _controller.dispose(); //Dispose the TextEditingController in dispose()
  ///   super.dispose();
  /// }
  /// MarkdownToolbar(controller: _controller, ...), //Set the TextEditingController in the toolbar
  /// TextField(controller: _controller, ...), //Set the same _controller in your TextField
  /// ```
  final TextEditingController? controller;

  /// If using a custom TextField, set the [focusNode] to a [FocusNode] Widget in order
  /// to focus the text after clicking a button. Use the FocusNode like this:
  /// ```
  /// late final FocusNode _focusNode; //Declare the FocusNode
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   _focusNode = FocusNode(); //Assign a new FocusNode in initState()
  /// }
  /// @override
  /// void dispose() {
  ///   _focusNode.dispose(); //Dispose the FocusNode in dispose()
  ///   super.dispose();
  /// }
  /// MarkdownToolbar(focusNode: _focusNode, ...), //Set the FocusNode in the toolbar
  /// TextField(focusNode: _focusNode, ...), //Set the same _focusNode in your TextField
  /// ```
  final FocusNode? focusNode;

  /// Make the toolbar collapsable with a button by setting [collapsable] to `true`.
  final bool collapsable;

  /// Align the collapse button at the end. Default: `false`.
  final bool alignCollapseButtonEnd;

  /// Flip the collapse button icon. Default: `false`.
  final bool flipCollapseButtonIcon;

  /// Set the [backgroundColor] of the buttons. Default: `Colors.grey[200]`
  final Color backgroundColor;

  /// Set the [dropdownTextColor] of the buttons. Default: `Colors.blue`
  final Color dropdownTextColor;

  /// Set the [iconColor] of the buttons. Default: `Colors.grey[850]`
  final Color iconColor;

  /// Set the [iconSize] of the buttons. Default: `24`
  final double iconSize;

  /// Set the [borderRadius] of the buttons. Default: `BorderRadius.all(Radius.circular(6.0))`
  final BorderRadius borderRadius;

  /// Set the [width] of the buttons. Default: `60`.
  final double width;

  /// Set the [height] of the buttons. Default: `40`.
  final double height;

  /// Set the horizontal [spacing] of the buttons. Default: `4.0`.
  final double spacing;

  /// Set the vertical [runSpacing] of the buttons. Default: `4.0`.
  final double runSpacing;

  /// Set the [WrapAlignment] of the buttons. Default: `WrapAlignment.end`.
  final WrapAlignment alignment;

  /// If you want to use an alternative bold character (Default: `**`),
  /// assign a custom [String] to [boldCharacter]. For example `__`
  final String boldCharacter;

  /// If you want to use an alternative italic character (Default: `*`),
  /// assign a custom [String] to [italicCharacter]. For example `_`
  final String italicCharacter;

  /// If you want to use an alternative code character (Default: `` ``` ``),
  /// assign a custom [String] to [codeCharacter]. For example ``` ` ```
  final String codeCharacter;

  /// If you want to use an alternative bulleted list character (Default: `-`),
  /// assign a custom [String] to [bulletedListCharacter]. For example `*`
  final String bulletedListCharacter;

  /// If you want to use an alternative horizontal rule character (Default: `---`),
  /// assign a custom [String] to [horizontalRuleCharacter]. For example `***`
  final String horizontalRuleCharacter;

  /// Hide the heading button by setting [hideHeading] to `true`.
  final bool hideHeading;

  /// Hide the bold button by setting [hideBold] to `true`.
  final bool hideBold;

  /// Hide the italic button by setting [hideItalic] to `true`.
  final bool hideItalic;

  /// Hide the strikethrough button by setting [hideStrikethrough] to `true`.
  final bool hideStrikethrough;

  /// Hide the link button by setting [hideLink] to `true`.
  final bool hideLink;

  /// Hide the image button by setting [hideImage] to `true`.
  final bool hideImage;

  /// Hide the code button by setting [hideCode] to `true`.
  final bool hideCode;

  /// Hide the bulleted list button by setting [hideBulletedList] to `true`.
  final bool hideBulletedList;

  /// Hide the numbered list button by setting [hideNumberedList] to `true`.
  final bool hideNumberedList;

  /// Hide the checkbox button by setting [hideCheckbox] to `true`.
  final bool hideCheckbox;

  /// Hide the quote button by setting [hideQuote] to `true`.
  final bool hideQuote;

  /// Disable all tooltips by setting [showTooltips] to `false`. Default: `true`.
  final bool showTooltips;

  /// Hide the horizontal rule button by setting [hideHorizontalRule] to `true`.
  final bool hideHorizontalRule;

  /// Set a custom tooltip [String] for the heading button. Leave blank `''` to disable tooltip.
  final String headingTooltip;

  /// Set a custom tooltip [String] for the bold button. Leave blank `''` to disable tooltip.
  final String boldTooltip;

  /// Set a custom tooltip [String] for the italic button. Leave blank `''` to disable tooltip.
  final String italicTooltip;

  /// Set a custom tooltip [String] for the strikethrough button. Leave blank `''` to disable tooltip.
  final String strikethroughTooltip;

  /// Set a custom tooltip [String] for the link button. Leave blank `''` to disable tooltip.
  final String linkTooltip;

  /// Set a custom tooltip [String] for the image button. Leave blank `''` to disable tooltip.
  final String imageTooltip;

  /// Set a custom tooltip [String] for the code button. Leave blank `''` to disable tooltip.
  final String codeTooltip;

  /// Set a custom tooltip [String] for the bulleted list button. Leave blank `''` to disable tooltip.
  final String bulletedListTooltip;

  /// Set a custom tooltip [String] for the numbered list button. Leave blank `''` to disable tooltip.
  final String numberedListTooltip;

  /// Set a custom tooltip [String] for the checkbox button. Leave blank `''` to disable tooltip.
  final String checkboxTooltip;

  /// Set a custom tooltip [String] for the quote button. Leave blank `''` to disable tooltip.
  final String quoteTooltip;

  /// Set a custom tooltip [String] for the horizontal rule button. Leave blank `''` to disable tooltip.
  final String horizontalRuleTooltip;

  @override
  State<MarkdownToolbar> createState() => MarkdownToolbarState();
}

class MarkdownToolbarState extends State<MarkdownToolbar> {
  var isCollapsed = false;

  final TextEditingController _includedController = TextEditingController();
  late final FocusNode _includedFocusNode;

  @override
  void initState() {
    if (widget.useIncludedTextField) {
      _includedController.addListener(() => setState(() {}));
      _includedFocusNode = FocusNode();
    }

    super.initState();
  }

  @override
  void dispose() {
    if (widget.useIncludedTextField) {
      _includedController.dispose();
      _includedFocusNode.dispose();
    }

    super.dispose();
  }

  Widget _buildToolbarItem({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool dropdown = false,
    List<DropdownMenuItem<int>> dropdownItems = const [],
    String? dropdownString,
    Function(int)? onDropdownButtonSelect,
  }) {
    return Tooltip(
      message: tooltip,
      child: dropdown
          ? SizedBox(
              width: widget.width,
              height: widget.height,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: widget.backgroundColor,
                  padding: const EdgeInsets.all(0),
                  shape:
                      RoundedRectangleBorder(borderRadius: widget.borderRadius),
                ),
                onPressed: () {},
                icon: Stack(
                  alignment: AlignmentDirectional.center,
                  children: [
                    dropdownString != null
                        ? Text(
                            dropdownString,
                            style: TextStyle(
                                color: widget.iconColor,
                                fontSize: 16.0 * widget.iconSize / 20),
                          )
                        : Icon(
                            icon,
                            color: widget.iconColor,
                            size: widget.iconSize,
                          ),
                    ClipRRect(
                      borderRadius: widget.borderRadius,
                      child: Material(
                        color: Colors.transparent,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton(
                            isExpanded: true,
                            items: dropdownItems,
                            onChanged: (option) {
                              if (onDropdownButtonSelect != null) {
                                onDropdownButtonSelect(option ?? 0);
                              }
                            },
                            icon: Container(),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            )
          : SizedBox(
              width: widget.width,
              height: widget.height,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: widget.backgroundColor,
                  foregroundColor: widget.iconColor,
                  padding: const EdgeInsets.all(0),
                  shape:
                      RoundedRectangleBorder(borderRadius: widget.borderRadius),
                ),
                onPressed: dropdown ? null : onPressed,
                icon: Icon(
                  icon,
                  color: widget.iconColor,
                  size: widget.iconSize,
                ),
              ),
            ),
    );
  }

  Widget _buildCollapseItem() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: IconButton(
        style: IconButton.styleFrom(
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.iconColor,
          padding: const EdgeInsets.all(0),
          shape: RoundedRectangleBorder(borderRadius: widget.borderRadius),
        ),
        onPressed: () => setState(() {
          isCollapsed = !isCollapsed;
        }),
        icon: RotatedBox(
          quarterTurns: widget.flipCollapseButtonIcon == true ? 3 : 1,
          child: Icon(
            isCollapsed ? Icons.expand_more : Icons.expand_less,
            color: widget.iconColor,
            size: widget.iconSize + 4,
          ),
        ),
      ),
    );
  }

  List<Widget> _toolbarItems({
    required bool useIncludedTextField,
    required bool collapsable,
    required bool showTooltips,
    required bool hideHeading,
    required bool hideBold,
    required bool hideItalic,
    required bool hideStrikethrough,
    required bool hideLink,
    required bool hideImage,
    required bool hideCode,
    required bool hideBulletedList,
    required bool hideNumberedList,
    required bool hideCheckbox,
    required bool hideQuote,
    required bool hideHorizontalRule,
    required String headingTooltip,
    required String boldTooltip,
    required String italicTooltip,
    required String strikethroughTooltip,
    required String linkTooltip,
    required String imageTooltip,
    required String codeTooltip,
    required String bulletedListTooltip,
    required String numberedListTooltip,
    required String checkboxTooltip,
    required String quoteTooltip,
    required String horizontalRuleTooltip,
  }) {
    if (collapsable && isCollapsed) {
      return [
        _buildCollapseItem(),
      ];
    } else {
      return [
        if (collapsable && !widget.alignCollapseButtonEnd) _buildCollapseItem(),
        if (!hideHeading)
          _buildToolbarItem(
            icon: Icons.h_mobiledata,
            tooltip: showTooltips == true ? headingTooltip : '',
            onPressed: () => onToolbarItemPressed(
              markdownToolbarOption: MarkdownToolbarOption.heading,
            ),
            onDropdownButtonSelect: (int option) => onHeadingPressed(option),
            dropdown: true,
            dropdownItems: [
              DropdownMenuItem<int>(
                value: 0,
                child: Text(
                  'H1',
                  style: TextStyle(
                    color: widget.dropdownTextColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 20.0,
                  ),
                ),
              ),
              DropdownMenuItem<int>(
                value: 1,
                child: Text(
                  'H2',
                  style: TextStyle(
                    color: widget.dropdownTextColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 19.0,
                  ),
                ),
              ),
              DropdownMenuItem<int>(
                value: 2,
                child: Text(
                  'H3',
                  style: TextStyle(
                    color: widget.dropdownTextColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 18.0,
                  ),
                ),
              ),
              DropdownMenuItem<int>(
                value: 3,
                child: Text(
                  'H4',
                  style: TextStyle(
                    color: widget.dropdownTextColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 17.0,
                  ),
                ),
              ),
              DropdownMenuItem<int>(
                value: 4,
                child: Text(
                  'H5',
                  style: TextStyle(
                    color: widget.dropdownTextColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 16.0,
                  ),
                ),
              ),
              DropdownMenuItem<int>(
                value: 5,
                child: Text(
                  'H6',
                  style: TextStyle(
                    color: widget.dropdownTextColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 15.0,
                  ),
                ),
              ),
            ],
            dropdownString: 'H1',
          ),
        if (!hideBold)
          _buildToolbarItem(
            icon: Icons.format_bold,
            tooltip: showTooltips == true ? boldTooltip : '',
            onPressed: () => onBoldPressed(),
          ),
        if (!hideItalic)
          _buildToolbarItem(
            icon: Icons.format_italic,
            tooltip: showTooltips == true ? italicTooltip : '',
            onPressed: () => onItalicPressed(),
          ),
        if (!hideStrikethrough)
          _buildToolbarItem(
            icon: Icons.format_strikethrough,
            tooltip: showTooltips == true ? strikethroughTooltip : '',
            onPressed: () => onStrikethroughPressed(),
          ),
        if (!hideLink)
          _buildToolbarItem(
            icon: Icons.link,
            tooltip: showTooltips == true ? linkTooltip : '',
            onPressed: () => onLinkPressed(),
          ),
        if (!hideImage)
          _buildToolbarItem(
            icon: Icons.image,
            tooltip: showTooltips == true ? imageTooltip : '',
            onPressed: () => onImagePressed(),
          ),
        if (!hideCode)
          _buildToolbarItem(
            icon: Icons.code,
            tooltip: showTooltips == true ? codeTooltip : '',
            onPressed: () => onCodePressed(),
          ),
        if (!hideBulletedList)
          _buildToolbarItem(
            icon: Icons.format_list_bulleted,
            tooltip: showTooltips == true ? bulletedListTooltip : '',
            onPressed: () => onUnorderedListPressed(),
          ),
        if (!hideNumberedList)
          _buildToolbarItem(
            icon: Icons.format_list_numbered,
            tooltip: showTooltips == true ? numberedListTooltip : '',
            onPressed: () => onOrderedListPressed(),
          ),
        if (!hideCheckbox)
          _buildToolbarItem(
            icon: Icons.check_box,
            tooltip: showTooltips == true ? checkboxTooltip : '',
            onPressed: () => onToolbarItemPressed(
              markdownToolbarOption: MarkdownToolbarOption.checkbox,
            ),
            onDropdownButtonSelect: (int option) => onCheckboxPressed(option),
            dropdown: true,
            dropdownItems: [
              DropdownMenuItem<int>(
                value: 0,
                child: Icon(
                  Icons.check_box_outline_blank,
                  color: widget.dropdownTextColor,
                ),
              ),
              DropdownMenuItem<int>(
                value: 1,
                child: Icon(
                  Icons.check_box,
                  color: widget.dropdownTextColor,
                ),
              ),
            ],
          ),
        if (!hideQuote)
          _buildToolbarItem(
            icon: Icons.format_quote,
            tooltip: showTooltips == true ? quoteTooltip : '',
            onPressed: () => onQuotePressed(),
          ),
        if (!hideHorizontalRule)
          _buildToolbarItem(
            icon: Icons.horizontal_rule,
            tooltip: showTooltips == true ? horizontalRuleTooltip : '',
            onPressed: () => onHorizontalRulePressed(),
          ),
        if (collapsable && widget.alignCollapseButtonEnd) _buildCollapseItem(),
      ];
    }
  }

  void onHeadingPressed(int option) => onToolbarItemPressed(
      option: option, markdownToolbarOption: MarkdownToolbarOption.heading);

  void onBoldPressed() =>
      onToolbarItemPressed(markdownToolbarOption: MarkdownToolbarOption.bold);

  void onItalicPressed() =>
      onToolbarItemPressed(markdownToolbarOption: MarkdownToolbarOption.italic);

  void onStrikethroughPressed() => onToolbarItemPressed(
      markdownToolbarOption: MarkdownToolbarOption.strikethrough);

  void onLinkPressed() =>
      onToolbarItemPressed(markdownToolbarOption: MarkdownToolbarOption.link);

  void onImagePressed() =>
      onToolbarItemPressed(markdownToolbarOption: MarkdownToolbarOption.image);

  void onCodePressed() =>
      onToolbarItemPressed(markdownToolbarOption: MarkdownToolbarOption.code);

  void onUnorderedListPressed() => onToolbarItemPressed(
      markdownToolbarOption: MarkdownToolbarOption.unorderedList);

  void onOrderedListPressed() => onToolbarItemPressed(
      markdownToolbarOption: MarkdownToolbarOption.orderedList);

  void onCheckboxPressed(int option) => onToolbarItemPressed(
      option: option, markdownToolbarOption: MarkdownToolbarOption.checkbox);

  void onQuotePressed() =>
      onToolbarItemPressed(markdownToolbarOption: MarkdownToolbarOption.quote);

  void onHorizontalRulePressed() => onToolbarItemPressed(
      markdownToolbarOption: MarkdownToolbarOption.horizontalRule);

  void onToolbarItemPressed({
    required MarkdownToolbarOption markdownToolbarOption,
    int? option,
  }) {
    widget.useIncludedTextField
        ? _includedFocusNode.requestFocus()
        : widget.focusNode?.requestFocus();
    Format.toolbarItemPressed(
      markdownToolbarOption: markdownToolbarOption,
      controller: widget.useIncludedTextField
          ? _includedController
          : widget.controller ?? _includedController,
      selection: widget.useIncludedTextField
          ? _includedController.selection
          : widget.controller?.selection ?? _includedController.selection,
      option: option,
      customBoldCharacter: widget.boldCharacter,
      customItalicCharacter: widget.italicCharacter,
      customCodeCharacter: widget.codeCharacter,
      customBulletedListCharacter: widget.bulletedListCharacter,
      customHorizontalRuleCharacter: widget.horizontalRuleCharacter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          alignment: widget.alignment,
          spacing: widget.spacing,
          runSpacing: widget.runSpacing,
          children: _toolbarItems(
            useIncludedTextField: widget.useIncludedTextField,
            collapsable: widget.collapsable,
            showTooltips: widget.showTooltips,
            hideHeading: widget.hideHeading,
            hideBold: widget.hideBold,
            hideItalic: widget.hideItalic,
            hideStrikethrough: widget.hideStrikethrough,
            hideLink: widget.hideLink,
            hideImage: widget.hideImage,
            hideCode: widget.hideCode,
            hideBulletedList: widget.hideBulletedList,
            hideNumberedList: widget.hideNumberedList,
            hideCheckbox: widget.hideCheckbox,
            hideQuote: widget.hideQuote,
            hideHorizontalRule: widget.hideHorizontalRule,
            headingTooltip: widget.headingTooltip,
            boldTooltip: widget.boldTooltip,
            italicTooltip: widget.italicTooltip,
            strikethroughTooltip: widget.strikethroughTooltip,
            linkTooltip: widget.linkTooltip,
            imageTooltip: widget.imageTooltip,
            codeTooltip: widget.codeTooltip,
            bulletedListTooltip: widget.bulletedListTooltip,
            numberedListTooltip: widget.numberedListTooltip,
            checkboxTooltip: widget.checkboxTooltip,
            quoteTooltip: widget.quoteTooltip,
            horizontalRuleTooltip: widget.horizontalRuleTooltip,
          ),
        ),
        if (widget.useIncludedTextField) const SizedBox(height: 4.0),
        if (widget.useIncludedTextField)
          TextField(
            controller: widget.useIncludedTextField
                ? _includedController
                : widget.controller,
            focusNode: widget.useIncludedTextField
                ? _includedFocusNode
                : widget.focusNode,
            minLines: 1,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'Your markdown text',
              labelText: 'Text field',
              border: OutlineInputBorder(),
            ),
          ),
      ],
    );
  }
}
