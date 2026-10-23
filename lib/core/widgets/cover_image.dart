import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:m3e_design/m3e_design.dart';

/// The width/height ratio of a book cover, used when one side is derived from the other.
///
/// Real covers are close to 3:4 (a paperback), and keeping the ratio in one place is what stops
/// the four lists from showing four slightly different rectangles.
const double bookCoverAspectRatio = 3 / 4;

/// A book cover with a placeholder, an error state and a bounded decode size
/// (`docs/dev/roadmap.md` §3.9-S1).
///
/// Four decisions are worth knowing:
///
/// * **it is decorative**: a row already names the book next to the cover, so announcing “image”
///   again would only make a screen reader repeat itself. The image is excluded from semantics and
///   the caller owns the label (C-UI-7);
/// * **the decode is bounded** by [width] × the device's pixel ratio, because a cover is a
///   thumbnail: decoding a 1200 px JPEG into a 48 px box is the kind of work C-PERF-5 keeps out of
///   the list;
/// * **a missing URL is a state, not an error**: `null` / empty renders the same placeholder an
///   unreachable image does, so a source without a `coverUrl` rule looks intentional instead of
///   broken;
/// * **the source is an `ImageProvider`**, not a URL: production always builds a
///   `CachedNetworkImageProvider` (the disk/memory cache policy belongs to that package and is not
///   re-implemented here), while a test can hand in a `MemoryImage` and exercise the loaded and
///   failed branches without a network stack or a fake cache manager.
class CoverImage extends StatelessWidget {
  /// Creates a cover of [width] × [height] logical pixels.
  const CoverImage({
    required this.url,
    required this.width,
    required this.height,
    this.borderRadius,
    this.image,
    super.key,
  });

  /// The absolute cover URL, or `null` when the source declared none.
  final String? url;

  /// Logical width; the decode size derives from it and the device pixel ratio.
  final double width;

  /// Logical height.
  final double height;

  /// Corner radius; defaults to the theme's small square radius.
  final BorderRadius? borderRadius;

  /// Overrides the image source; `null` means “use [url] through the network cache”.
  ///
  /// It exists so the loaded and failed branches are reachable in a widget test. Production never
  /// passes it: every list hands over a URL only.
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final M3ETheme tokens = context.m3e;
    // 直角族的小圆角（8）= 书封，不是胶囊：`round` 族在 xs 就已经是 999。
    final BorderRadius radius = borderRadius ?? tokens.shapes.square.sm;

    final String? source = url;
    final ImageProvider? provider =
        image ??
        (source == null || source.isEmpty
            ? null
            : ResizeImage(
                CachedNetworkImageProvider(source),
                width: _pixels(context),
                policy: ResizeImagePolicy.fit,
              ));
    if (provider == null) {
      return _placeholder(radius, tokens);
    }

    // 封面是装饰：书名就在旁边，再报一遍「图片」只会让读屏重复（C-UI-7）。
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: radius,
        child: Image(
          image: provider,
          width: width,
          height: height,
          fit: BoxFit.cover,
          // 还没解出第一帧时画占位块；不画图标，一闪而过的书本形状会被当成封面。
          frameBuilder:
              (
                BuildContext context,
                Widget child,
                int? frame,
                bool wasSynchronouslyLoaded,
              ) => frame == null && !wasSynchronouslyLoaded
              ? _placeholder(radius, tokens, showIcon: false)
              : child,
          // 加载失败与「没有封面」画同一个占位：站点 404 与规则没给封面是同一件事。
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) => _placeholder(radius, tokens),
        ),
      ),
    );
  }

  /// The decode width in physical pixels, bounded so a thumbnail stays a thumbnail.
  int _pixels(BuildContext context) =>
      (width * MediaQuery.devicePixelRatioOf(context)).round();

  /// The empty / loading / failed state: the surface tint plus an optional book glyph.
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
