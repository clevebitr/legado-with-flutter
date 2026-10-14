// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '阅读';

  @override
  String get bookSourceListTitle => '书源列表';

  @override
  String get actionRetry => '重试';

  @override
  String get actionImport => '导入';

  @override
  String get bookSourceSearchTitle => '搜索';

  @override
  String get bookSourceSearchHint => '书名或作者';

  @override
  String get bookSourceSearchAction => '搜索';

  @override
  String get bookSourceSearchPrompt => '输入关键词开始搜索该书源。';

  @override
  String get bookSourceSearchEmpty => '没有匹配该关键词的书。';

  @override
  String get bookSourceMissingSource => '还没有导入任何书源。导入书源后即可开始阅读。';

  @override
  String get bookSourceDetailTitle => '书籍详情';

  @override
  String get bookSourceTocTitle => '目录';

  @override
  String get bookSourceReaderTitle => '正文';

  @override
  String bookSourceAuthorLine(String author) {
    return '作者：$author';
  }

  @override
  String bookSourceKindLine(String kind) {
    return '分类：$kind';
  }

  @override
  String bookSourceLastChapterLine(String chapter) {
    return '最新章节：$chapter';
  }

  @override
  String get failureNetworkTimeout => '请求超时，请稍后重试。';

  @override
  String get failureNetworkFailed => '连接失败，请检查网络后重试。';

  @override
  String get failureNetworkForbidden => '站点拒绝访问（403），书源可能需要更新。';

  @override
  String get failureNotFound => '请求的页面不存在（404），书源可能已失效。';

  @override
  String get failureEncodingFailed => '无法识别页面编码。';

  @override
  String get failureParseFailed => '解析失败，书源规则可能已失效。';

  @override
  String get failureInvalidBookSource => '该文件不是有效的书源。';

  @override
  String get legalNoticesTitle => '法律声明';

  @override
  String get legalNoticesCopyright => 'flutter_reader，版权所有 (C) 2026 Clevebitr。';

  @override
  String get legalNoticesNoWarranty =>
      '本程序不提供任何担保。它是以 GNU GPL-3.0 许可发布的自由软件，你可以在特定条件下自由再分发。';

  @override
  String get legalNoticesViewLicense => '查看完整许可证';

  @override
  String get legalNoticesCorrespondingSource => '对应源代码';

  @override
  String get legalNoticesProhibitedUse =>
      '禁止将本应用用于侵犯著作权。通过书源抓取、聚合或传播未经授权的内容属被禁止用途，实施者自行承担全部法律责任。';

  @override
  String get failureUnsupportedRule => '该书源使用了暂不支持的规则类型。';

  @override
  String get bookSourceExploreTitle => '发现';

  @override
  String get bookSourceExploreAction => '发现页';

  @override
  String get bookSourceExplorePrompt => '选择一个分类开始浏览';

  @override
  String get bookSourceExploreEmpty => '这本书源没有发现页分类';

  @override
  String get bookSourceExploreEmptyCategory => '这个分类下没有书目。';

  @override
  String bookSourceImportSucceeded(int count) {
    return '已导入 $count 个书源。';
  }

  @override
  String bookSourceImportPartiallySkipped(int count, int skipped) {
    return '已导入 $count 个书源，跳过 $skipped 条无效条目。';
  }

  @override
  String get actionCancel => '取消';

  @override
  String get actionDelete => '删除';

  @override
  String get bookSourceMissingSourceAction => '管理书源';

  @override
  String get bookSourceListEmpty => '还没有导入任何书源。';

  @override
  String get bookSourceListLoadFailed => '读取已导入的书源失败。';

  @override
  String get bookSourceCurrentLabel => '当前书源';

  @override
  String get bookSourceVariantLabel => '同站点的另一份规则';

  @override
  String get bookSourceListDeleteTitle => '删除这个书源？';

  @override
  String bookSourceListDeleteBody(String name) {
    return '将删除 $name 及其已存的规则。';
  }

  @override
  String get bookSourceImportTitle => '导入书源';

  @override
  String get bookSourceImportTextLabel => '书源 JSON';

  @override
  String get bookSourceImportTextHint => '在这里粘贴导出的书源文件';

  @override
  String get bookSourceImportUrlLabel => '或一个 URL';

  @override
  String get bookSourceImportUrlHint => 'https://example.com/sources.json';
}
