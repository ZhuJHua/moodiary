import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../common/values/border.dart';
import '../../router/app_routes.dart';

class MediaImageComponent extends StatelessWidget {
  final DateTime dateTime;
  final List<String> imageList;

  const MediaImageComponent(
      {super.key, required this.dateTime, required this.imageList});

  void _toPhotoView(int index, List<String> filePath) {
    Get.toNamed(AppRoutes.photoPage, arguments: [filePath, index]);
  }

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final textStyle = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            DateFormat.yMMMEd().format(dateTime),
            style: textStyle.titleSmall,
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
                _toPhotoView(index, imageList);
              },
              child: Card(
                clipBehavior: Clip.hardEdge,
                child: Image.file(
                  File(imageList[index]),
                  fit: BoxFit.cover,
                  cacheWidth: 120 * pixelRatio.toInt(),
                ),
              ),
            );
          },
          itemCount: imageList.length,
        ),
      ],
    );
  }
}
