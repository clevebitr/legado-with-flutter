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

  @override
  String get bookSourceImportFileAction => '选择 JSON 文件';

  @override
  String get shelfTitle => '书架';

  @override
  String get shelfEmpty => '书架是空的。打开书籍详情，点「加入书架」把书放进来。';

  @override
  String get shelfLoadFailed => '读取书架失败。';

  @override
  String get shelfStatusTracking => '在追';

  @override
  String get shelfStatusRead => '已读';

  @override
  String get shelfActionPin => '置顶';

  @override
  String get shelfActionUnpin => '取消置顶';

  @override
  String get shelfActionMarkRead => '标记为已读';

  @override
  String get shelfActionMarkTracking => '标记为在追';

  @override
  String get shelfActionRemove => '从书架删除';

  @override
  String get shelfRemoveTitle => '从书架删除这本书？';

  @override
  String get shelfRemoveBody => '阅读进度会一起删除。';

  @override
  String shelfProgressLine(String chapter) {
    return '读至：$chapter';
  }

  @override
  String get shelfAddAction => '加入书架';

  @override
  String get shelfAddSucceeded => '已加入书架。';

  @override
  String get shelfAddFailed => '加入书架失败。';

  @override
  String get shelfWriteFailed => '书架更新失败。';

  @override
  String get actionDecrease => '减少';

  @override
  String get actionIncrease => '增加';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsLoadFailed => '读取设置失败。';

  @override
  String get settingsThemeMode => '主题';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsFontScale => '字号';

  @override
  String settingsFontScaleValue(int percent) {
    return '$percent%';
  }

  @override
  String get settingsConcurrency => '同一书源并发上限';

  @override
  String get settingsConcurrencyHint => '1–8。越大越快，对站点也越不客气。';

  @override
  String get settingsCache => '缓存';

  @override
  String get settingsClearCache => '清空缓存';

  @override
  String get settingsClearCacheTitle => '清空全部缓存？';

  @override
  String get settingsClearCacheBody => '缓存的页面与正文会在需要时重新下载。';

  @override
  String settingsCacheCleared(int count) {
    return '已清空 $count 条缓存。';
  }

  @override
  String get bookSourceCheckTitle => '书源校验';

  @override
  String get bookSourceCheckIntro => '逐条跑搜索、发现、详情、目录与正文。';

  @override
  String get bookSourceCheckStages => '校验阶段';

  @override
  String get bookSourceCheckStageSearch => '搜索';

  @override
  String get bookSourceCheckStageExplore => '发现';

  @override
  String get bookSourceCheckStageInfo => '详情';

  @override
  String get bookSourceCheckStageToc => '目录';

  @override
  String get bookSourceCheckStageContent => '正文';

  @override
  String get bookSourceCheckKeyword => '关键词';

  @override
  String get bookSourceCheckKeywordHint => '发给每个被校验书源的搜索词';

  @override
  String get bookSourceCheckTimeout => '单源超时';

  @override
  String get bookSourceCheckStart => '开始校验';

  @override
  String get bookSourceCheckStop => '取消';

  @override
  String get bookSourceCheckEmpty => '还没有导入任何书源。导入后再校验。';

  @override
  String get bookSourceCheckSelectionEmpty => '至少选择一条书源。';

  @override
  String get bookSourceCheckStatusPending => '等待';

  @override
  String get bookSourceCheckStatusRunning => '校验中';

  @override
  String get bookSourceCheckStatusSucceeded => '通过';

  @override
  String get bookSourceCheckStatusFailed => '失败';

  @override
  String get bookSourceCheckStatusCancelled => '已取消';

  @override
  String get bookSourceCheckFailureCheckFailed => '校验发现了问题。';

  @override
  String get bookSourceCheckFailureSourceMissing => '该书源在此期间被删除了。';

  @override
  String get bookSourceCheckFailureSaveFailed => '结果没能写回书源。';

  @override
  String bookSourceCheckFailedAt(String rulePath) {
    return '失败于 $rulePath';
  }

  @override
  String bookSourceCheckElapsed(int millis) {
    return '耗时 $millis 毫秒';
  }

  @override
  String get bookSourceCheckOpenDebug => '调试该书源';

  @override
  String get bookSourceCheckSelectAll => '全选';

  @override
  String get bookSourceCheckSelectNone => '全不选';

  @override
  String get bookSourceDebugTitle => '书源调试';

  @override
  String get bookSourceDebugTarget => '目标';

  @override
  String get bookSourceDebugTargetSearch => '搜索';

  @override
  String get bookSourceDebugTargetExplore => '发现';

  @override
  String get bookSourceDebugTargetInfo => '详情';

  @override
  String get bookSourceDebugTargetToc => '目录';

  @override
  String get bookSourceDebugTargetContent => '正文';

  @override
  String get bookSourceDebugQuery => '调试内容';

  @override
  String get bookSourceDebugQueryKeywordHint => '要搜索的关键词';

  @override
  String get bookSourceDebugQueryUrlHint => '页面地址';

  @override
  String get bookSourceDebugExamples => '示例';

  @override
  String get bookSourceDebugStart => '运行';

  @override
  String get bookSourceDebugStop => '停止';

  @override
  String get bookSourceDebugClear => '清空';

  @override
  String get bookSourceDebugEmpty => '还没有事件。运行一个目标就能看到链路。';

  @override
  String get bookSourceDebugStatusRunning => '运行中';

  @override
  String get bookSourceDebugStatusSucceeded => '完成';

  @override
  String get bookSourceDebugStatusFailed => '失败';

  @override
  String get bookSourceDebugStatusCancelled => '已取消';

  @override
  String get bookSourceDebugEventMessage => '消息';

  @override
  String get bookSourceDebugEventSource => '来源';

  @override
  String get bookSourceDebugEventError => '错误';

  @override
  String get bookSourceDebugMissingSource => '请先在书源列表里选择一个书源。';

  @override
  String get bookSourceDebugStatusIdle => '尚未运行';

  @override
  String get readerTocAction => '目录';

  @override
  String get readerSettingsAction => '阅读设置';

  @override
  String get readerFontSize => '字号';

  @override
  String get readerLineHeight => '行距';

  @override
  String get readerBackground => '背景';

  @override
  String get readerBackgroundSystem => '跟随主题';

  @override
  String get readerBackgroundPaper => '纸张';

  @override
  String get readerBackgroundSepia => '护眼';

  @override
  String get readerBackgroundDark => '夜间';

  @override
  String get readerPageMode => '翻页方式';

  @override
  String get readerPageModeScroll => '滚动';

  @override
  String get readerPageModePaged => '分页';

  @override
  String get readerPreviousChapter => '上一章';

  @override
  String get readerNextChapter => '下一章';

  @override
  String get readerChapterEnd => '本章读完';

  @override
  String get readerLastChapter => '已是最后一章';

  @override
  String get readerNoChapter => '这本书没有可读的章节。';

  @override
  String bookSourceUpdateTimeLine(String value) {
    return '更新于：$value';
  }

  @override
  String get bookSourceListSortLabel => '排序';

  @override
  String get bookSourceListSortDefault => '手动排序';

  @override
  String get bookSourceListSortWeight => '权重';

  @override
  String get bookSourceListSortRespondTime => '响应耗时';

  @override
  String get bookSourceListSortName => '名称';

  @override
  String get bookSourceListGroupAll => '全部分组';

  @override
  String bookSourceListRespondTimeLine(int millis) {
    return '$millis 毫秒';
  }

  @override
  String get bookSourceListCommentTitle => '校验注释';

  @override
  String get bookSourceListCommentAction => '查看注释';

  @override
  String get bookSourceListNoMatch => '这个分组下没有书源。';

  @override
  String get searchScopeLabel => '搜索范围';

  @override
  String get searchScopeAll => '全部启用源';

  @override
  String get searchScopeNamed => '指定书源';

  @override
  String get searchFilterLabel => '筛选';

  @override
  String get searchTypeLabel => '书源类型';

  @override
  String get searchTypeText => '文本';

  @override
  String get searchTypeAudio => '音频';

  @override
  String get searchTypeImage => '图片';

  @override
  String get searchTypeFile => '文件';

  @override
  String get searchMatchLabel => '匹配';

  @override
  String get searchMatchDefault => '模糊';

  @override
  String get searchMatchExact => '精确（书名或作者）';

  @override
  String searchProgress(int done, int total) {
    return '$done/$total 个源';
  }

  @override
  String searchPartialFailed(int failed) {
    return '$failed 个源失败';
  }

  @override
  String get searchPause => '暂停';

  @override
  String get searchResume => '继续';

  @override
  String get searchStop => '停止';

  @override
  String get searchLoadMore => '加载更多';

  @override
  String searchOriginsLine(int count) {
    return '$count 个来源';
  }

  @override
  String get searchNoSources => '当前范围内没有可搜索的书源。';

  @override
  String get searchTypeVideo => '视频';

  @override
  String get bookSourceStartReading => '开始阅读';

  @override
  String get bookSourceContinueReading => '继续阅读';

  @override
  String get bookSourceIntroExpand => '展开简介';

  @override
  String get bookSourceIntroCollapse => '收起简介';

  @override
  String get bookSourceListSearchHint => '搜索名称、URL 或分组';

  @override
  String get bookSourceListSelectAll => '全选';

  @override
  String get bookSourceListInvertSelection => '反选';

  @override
  String bookSourceListSelectedCount(int count) {
    return '已选 $count 项';
  }

  @override
  String get bookSourceListBatchEnable => '启用';

  @override
  String get bookSourceListBatchDisable => '禁用';

  @override
  String get bookSourceListBatchDelete => '删除';

  @override
  String bookSourceListBatchDeleteTitle(int count) {
    return '删除 $count 个书源？';
  }

  @override
  String get bookSourceListBatchDeleteBody => '从它们加入书架的书仍会保留。';

  @override
  String get bookSourceListBatchGroup => '分组';

  @override
  String get bookSourceListGroupNone => '不分组';

  @override
  String get bookSourceListGroupNew => '新建分组…';

  @override
  String get bookSourceListGroupNameHint => '分组名称';

  @override
  String get bookSourceCheckFilterLabel => '校验状态';

  @override
  String get bookSourceCheckFilterAll => '全部';

  @override
  String get bookSourceCheckFilterHealthy => '全正常';

  @override
  String get bookSourceCheckFilterFailing => '有失效';

  @override
  String get bookSourceRowCheck => '校验该书源';

  @override
  String get bookSourceRowEdit => '编辑';

  @override
  String get bookSourceRowExport => '导出';

  @override
  String get bookSourceCheckPassed => '校验通过';

  @override
  String bookSourceCheckFound(String groups) {
    return '校验结果：$groups';
  }

  @override
  String get bookSourceExportCopied => '书源 JSON 已复制';

  @override
  String get bookSourceExportSaved => '已保存';

  @override
  String get bookSourceExportFailed => '无法导出该书源';

  @override
  String get bookSourceEditTitle => '编辑书源';

  @override
  String get bookSourceEditSaved => '已保存';

  @override
  String get bookSourceEditInvalidFields => '请先修正标红的字段';

  @override
  String get bookSourceEditIdentityConflict => '另一个书源已经完全相同';

  @override
  String get bookSourceEditUrlHint => '修改 URL 等于换源：书架保留旧的那一个。';

  @override
  String get bookSourceFieldName => '名称';

  @override
  String get bookSourceFieldUrl => '书源 URL';

  @override
  String get bookSourceFieldGroup => '分组';

  @override
  String get bookSourceFieldType => '类型';

  @override
  String get bookSourceFieldWeight => '权重';

  @override
  String get bookSourceFieldHeader => '请求头（JSON）';

  @override
  String get bookSourceFieldSearchRule => '搜索规则';

  @override
  String get bookSourceFieldBookInfoRule => '详情规则';

  @override
  String get bookSourceFieldTocRule => '目录规则';

  @override
  String get bookSourceFieldContentRule => '正文规则';

  @override
  String get actionSave => '保存';

  @override
  String get bookSourceRowCheckRunning => '正在校验…';

  @override
  String get readerFontFamily => '字体';

  @override
  String get readerFontFamilyTheme => '跟随主题';

  @override
  String get readerFontFamilySerif => '衬线';

  @override
  String get readerFontFamilySans => '无衬线';

  @override
  String get readerFontFamilyMono => '等宽';

  @override
  String get readerParagraphSpacing => '段间距';

  @override
  String get readerFirstLineIndent => '首行缩进';

  @override
  String get readerPagePadding => '页边距';

  @override
  String get readerPaddingNarrow => '窄';

  @override
  String get readerPaddingMedium => '中';

  @override
  String get readerPaddingWide => '宽';

  @override
  String readerChapterProgress(int current, int total) {
    return '第 $current/$total 章';
  }

  @override
  String readerChapterPercent(int percent) {
    return '本章 $percent%';
  }

  @override
  String get readerChangeSource => '换源';

  @override
  String get readerBrightness => '亮度';

  @override
  String get readerTocSort => '倒序';

  @override
  String get readerTocSearchHint => '搜索章节';

  @override
  String get readerSourceTitle => '换源';

  @override
  String get readerSourceEmpty => '其它书源里没有这本书。';

  @override
  String get readerSourceSearching => '正在搜索其它书源…';

  @override
  String readerSourceChapters(int count) {
    return '$count 章';
  }

  @override
  String get readerSourceFailed => '换源失败';

  @override
  String readerSourceAligned(String chapter) {
    return '对齐到：$chapter';
  }
}
