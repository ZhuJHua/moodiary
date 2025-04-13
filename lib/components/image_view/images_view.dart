import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moodiary/pages/image/image_view.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:uuid/uuid.dart';

class ImagesView extends StatefulWidget {
  final List<String> imageName;

  final ColorScheme? customColorScheme;

  const ImagesView({
    super.key,
    required this.imageName,
    this.customColorScheme,
  });

  @override
  State<ImagesView> createState() => _ImagesViewState();
}

class _ImagesViewState extends State<ImagesView> {
  late final PageController _pageController;

  List<String> get imageName => widget.imageName;

  ColorScheme get colorScheme =>
      widget.customColorScheme ?? Theme.of(context).colorScheme;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  late final heroPrefix = const Uuid().v4();

  Future<void> _toPhotoView(
    List<String> imagePathList,
    int index,
    BuildContext context,
    String heroPrefix,
  ) async {
    HapticFeedback.selectionClick();
    await showImageView(
      context,
      imagePathList,
      index,
      heroTagPrefix: heroPrefix,
    );
  }

  Future<void> _jumpToPage(int index) async {
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageName.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        PageView.builder(
          controller: _pageController,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () async {
                await _toPhotoView(
                  List.generate(imageName.length, (i) {
                    return FileUtil.getRealPath('image', imageName[i]);
                  }),
                  index,
                  context,
                  heroPrefix,
                );
              },
              child: Hero(
                tag: '$heroPrefix$index',
                child: Image.file(
                  File(FileUtil.getRealPath('image', imageName[index])),
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
          itemCount: imageName.length,
        ),
        Positioned(
          bottom: 0,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: ShapeDecoration(
                shape: const StadiumBorder(side: BorderSide.none),
                color: colorScheme.surfaceContainer.withAlpha(100),
              ),
              padding:
                  imageName.length > 9
                      ? const EdgeInsets.fromLTRB(6.0, 2.0, 6.0, 2.0)
                      : const EdgeInsets.all(2.0),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: imageName.length,
                effect:
                    imageName.length > 9
                        ? ScrollingDotsEffect(
                          activeDotColor: colorScheme.tertiary,
                          dotColor: colorScheme.surfaceContainerLow.withAlpha(
                            200,
                          ),
                          dotWidth: 8,
                          dotHeight: 8,
                          maxVisibleDots: 9,
                        )
                        : WormEffect(
                          activeDotColor: colorScheme.tertiary,
                          dotColor: colorScheme.surfaceContainerLow.withAlpha(
                            200,
                          ),
                          dotWidth: 8,
                          dotHeight: 8,
                        ),
                onDotClicked: _jumpToPage,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
