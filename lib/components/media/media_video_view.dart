import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';

import '../../common/values/border.dart';
import '../../router/app_routes.dart';

class MediaVideoComponent extends StatelessWidget {
  final DateTime dateTime;
  final List<String> videoList;

  const MediaVideoComponent(
      {super.key, required this.dateTime, required this.videoList});

  //点击视频跳转到视频预览
  void _toVideoView(List<String> videoPathList, int index) {
    Get.toNamed(AppRoutes.videoPage, arguments: [videoPathList, index]);
  }

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final textStyle = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // 将视频路径转换为缩略图路径
    final thumbnailList = videoList.map((e) {
      final id = e.split('video-')[1].split('.')[0];
      return '${dirname(e)}/thumbnail-$id.jpeg';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            DateFormat.yMMMEd().format(dateTime),
            style: textStyle.titleSmall?.copyWith(color: colorScheme.secondary),
          ),
        ),
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            childAspectRatio: 1.0,
          ),
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemBuilder: (context, index) {
            return InkWell(
              borderRadius: AppBorderRadius.mediumBorderRadius,
              onTap: () {
                _toVideoView(videoList, index);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Card(
                      clipBehavior: Clip.hardEdge,
                      child: Image.file(
                        File(thumbnailList[index]),
                        fit: BoxFit.cover,
                        cacheWidth: 120 * pixelRatio.toInt(),
                      ),
                    ),
                  ),
                  const FaIcon(FontAwesomeIcons.play)
                ],
              ),
            );
          },
          itemCount: thumbnailList.length,
        ),
      ],
    );
  }
}
