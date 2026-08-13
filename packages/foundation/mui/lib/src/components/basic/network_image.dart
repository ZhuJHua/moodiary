import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CachedImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? svgColor;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = .contain,
    this.svgColor,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder == null ? null : (_, _) => placeholder!,
      errorBuilder: errorWidget == null ? null : (_, _, _) => errorWidget!,
      unsupportedImageBuilder: (_, _, bytes) => SvgPicture.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        colorFilter: svgColor == null ? null : .mode(svgColor!, .srcIn),
      ),
    );
  }
}
