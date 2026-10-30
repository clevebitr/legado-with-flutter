import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/widgets/cover_image.dart';
import 'package:flutter_reader/features/bookshelf/data/shelf_cover_picker_impl.dart';
import 'package:flutter_reader/features/bookshelf/di.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';
import 'package:flutter_reader/features/bookshelf/presentation/notifiers/bookshelf_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Edits the details the user owns on one shelf entry (`docs/dev/roadmap.md` §3.12, ADR-0092).
///
/// A book source gets a title, an author and an introduction wrong often enough that the only
/// remedy used to be “delete the book and add it again”. These four fields are the ones the user
/// can fix: title, author, cover and their own introduction. The **cover** keeps its own write path
/// (`saveCustomCover`) because it also moves a file; the other three go through `updateDetails`.
///
/// Everything else on the row is the source's snapshot or user state with its own action (status,
/// pin, group, reading progress) and is deliberately absent here: this page is not a second
/// metadata editor for the book source.
class ShelfBookEditPage extends ConsumerStatefulWidget {
  /// Creates the editor for [book].
  const ShelfBookEditPage({required this.book, super.key});

  /// The shelf entry being edited.
  final ShelvedBook book;

  @override
  ConsumerState<ShelfBookEditPage> createState() => _ShelfBookEditPageState();
}

class _ShelfBookEditPageState extends ConsumerState<ShelfBookEditPage> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.book.name,
  );
  late final TextEditingController _author = TextEditingController(
    text: widget.book.author ?? '',
  );
  late final TextEditingController _intro = TextEditingController(
    text: widget.book.customIntro ?? '',
  );

  /// Absolute path of the cover, or `null` for the source's own cover.
  late String? _customCoverPath = widget.book.customCoverPath;

  /// Whether a save is in flight; the button spins and the form is disabled.
  bool _isSaving = false;

  @override
  void dispose() {
    _name.dispose();
    _author.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.shelfEditTitle)),
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.all(tokens.spacing.lg),
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CoverImage(
                  url: widget.book.coverUrl,
                  localPath: _customCoverPath,
                  width: tokens.spacing.xxl * 2,
                  height: tokens.spacing.xxl * 2.7,
                ),
                SizedBox(width: tokens.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : _pickCover,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(l10n.shelfEditCoverPick),
                      ),
                      if (_customCoverPath != null)
                        TextButton.icon(
                          onPressed: _isSaving ? null : _resetCover,
                          icon: const Icon(Icons.restart_alt),
                          label: Text(l10n.shelfEditCoverReset),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.lg),
            TextFormField(
              controller: _name,
              enabled: !_isSaving,
              decoration: InputDecoration(labelText: l10n.shelfEditName),
              // 空书名会让书架出现一行「没有名字」，与「书源抓不到标题」是同一个坑。
              validator: (String? value) => (value ?? '').trim().isEmpty
                  ? l10n.shelfEditNameRequired
                  : null,
            ),
            SizedBox(height: tokens.spacing.md),
            TextFormField(
              controller: _author,
              enabled: !_isSaving,
              decoration: InputDecoration(labelText: l10n.shelfEditAuthor),
            ),
            SizedBox(height: tokens.spacing.md),
            TextFormField(
              controller: _intro,
              enabled: !_isSaving,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: l10n.shelfEditIntro,
                helperText: l10n.shelfEditIntroHint,
              ),
            ),
            SizedBox(height: tokens.spacing.lg),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(l10n.shelfEditSave),
            ),
          ],
        ),
      ),
    );
  }

  /// Writes the three text fields and returns to the shelf.
  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isSaving = true);
    final String intro = _intro.text.trim();
    await ref
        .read(bookshelfRepositoryProvider)
        .updateDetails(
          id: widget.book.id,
          name: _name.text.trim(),
          author: _author.text.trim().isEmpty ? null : _author.text.trim(),
          // 空简介 = 回到书源快照：存 null 而不是空串。
          customIntro: intro.isEmpty ? null : intro,
        );
    if (!mounted) {
      return;
    }
    // 书架是 keepAlive 的：不失效就会一直显示旧标题。
    ref.invalidate(bookshelfProvider);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).shelfEditSaved)),
    );
  }

  /// Asks the platform picker for one image and remembers its stored path.
  Future<void> _pickCover() async {
    final String? path = await ref
        .read(shelfCoverPickerProvider)
        .pickAndStore();
    if (path == null || !mounted) {
      // 取消不是失败（platform.md §2）。
      return;
    }
    // 立刻落盘：用户可能直接返回，书封面不该只活在这一次会话里。
    await ref
        .read(bookshelfRepositoryProvider)
        .saveCustomCover(id: widget.book.id, path: path);
    if (!mounted) {
      return;
    }
    ref.invalidate(bookshelfProvider);
    setState(() => _customCoverPath = path);
  }

  /// Drops the user's cover and deletes its file.
  Future<void> _resetCover() async {
    final String? path = _customCoverPath;
    if (path == null) {
      return;
    }
    await ref.read(shelfCoverPickerProvider).delete(path);
    await ref
        .read(bookshelfRepositoryProvider)
        .saveCustomCover(id: widget.book.id, path: null);
    if (!mounted) {
      return;
    }
    ref.invalidate(bookshelfProvider);
    setState(() => _customCoverPath = null);
  }
}
