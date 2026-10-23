import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:m3e_design/m3e_design.dart';

/// A book cover with a placeholder, an error state and a bounded decode size.
///
/// The image is decorative and excluded from semantics; a `null` or empty URL
/// renders the same placeholder as an unreachable one.
class CoverImage extends StatelessWidget {
  /// Creates a cover of [width] × [height] logical pixels.
  const CoverImage({
    required this.url,
    required this.width,
    required this.height,
    this.localPath,
    this.borderRadius,
    this.image,
    super.key,
  });

  /// The absolute cover URL, or `null` when the source declared none.
  final String? url;

  /// Path of a locally picked cover, which wins over [url] when set.
  final String? localPath;

  /// Logical width; also drives the decode size.
  final double width;

  /// Logical height.
  final double height;

  /// Corner radius; defaults to the theme's small square radius.
  final BorderRadius? borderRadius;

  /// Overrides the image source; `null` loads [url] through the network cache.
  ///
  /// Exists so tests can reach the loaded and failed branches.
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final M3ETheme tokens = context.m3e;
    // 书封用直角族的小圆角；round 族在 xs 已是胶囊形。
    final BorderRadius radius = borderRadius ?? tokens.shapes.square.sm;

    final String? local = localPath;
    final String? source = url;
    final ImageProvider? provider =
        image ??
        (local == null || local.isEmpty
            ? (source == null || source.isEmpty
                  ? null
                  : ResizeImage(
                      CachedNetworkImageProvider(source),
                      width: _pixels(context),
                      policy: ResizeImagePolicy.fit,
                    ))
            : ResizeImage(
                FileImage(File(local)),
                width: _pixels(context),
                policy: ResizeImagePolicy.fit,
              ));
    if (provider == null) {
      return _placeholder(radius, tokens);
    }

    // 封面是装饰：书名就在旁边，再报一遍「图片」只会让读屏重复。
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: radius,
        child: Image(
          image: provider,
          width: width,
          height: height,
          fit: BoxFit.cover,
          // 首帧未解出时画占位块；不画图标，避免被误认为封面。
          frameBuilder:
              (
                BuildContext context,
                Widget child,
                int? frame,
                bool wasSynchronouslyLoaded,
              ) => frame == null && !wasSynchronouslyLoaded
              ? _placeholder(radius, tokens, showIcon: false)
              : child,
          // 加载失败与「没有封面」共用同一占位。
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) => _placeholder(radius, tokens),
        ),
      ),
    );
  }

  // 按设备像素比放大，让缩略图只解码到实际需要的尺寸。
  int _pixels(BuildContext context) =>
      (width * MediaQuery.devicePixelRatioOf(context)).round();

  // 空、加载中与失败三种状态共用：表面色块加可选书本图标。
  Widget _placeholder(
    BorderRadius radius,
    M3ETheme tokens, {
    bool showIcon = true,
  }) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: tokens.colors.surfaceContainerHighest,
      borderRadius: radius,
    ),
    alignment: Alignment.center,
    child: showIcon
        ? Icon(
            Icons.menu_book_outlined,
            size: width * 0.4,
            color: tokens.colors.onSurfaceVariant,
          )
        : null,
  );
}
