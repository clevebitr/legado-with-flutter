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
  String get shellTabBookshelf => '书架';

  @override
  String get shellTabExplore => '发现';

  @override
  String get shellTabSearch => '搜索';

  @override
  String get shellTabMy => '我的';

  @override
  String get myTitle => '我的';

  @override
  String get mySectionContent => '内容';

  @override
  String get mySectionApp => '应用';

  @override
  String get myBookSources => '书源管理';

  @override
  String get myBookSourcesBody => '导入、校验与分组';

  @override
  String get aboutTitle => '关于';

  @override
  String aboutVersion(String version) {
    return '版本 $version';
  }

  @override
  String get aboutLicenses => '开源许可与法律声明';

  @override
  String get aboutSourceCode => '源代码';

  @override
  String get aboutCopySource => '复制地址';

  @override
  String get aboutCopied => '已复制';

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
  String get legalNoticesLicenseTitle => 'GNU GPL-3.0';

  @override
  String get legalNoticesLicenseFailed => '许可全文读取失败，请重新打开本页。';

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
  String bookSourceImportPreviewSummary(
    int newCount,
    int refreshCount,
    int rejected,
  ) {
    return '$newCount 条新增 · $refreshCount 条刷新 · $rejected 条被拒绝';
  }

  @override
  String get bookSourceImportEntryNew => '新增';

  @override
  String get bookSourceImportEntryRefresh => '已导入 · 将刷新';

  @override
  String bookSourceImportEntryUnknown(int index) {
    return '第 $index 条';
  }

  @override
  String get bookSourceImportRejectionMissingUrl => '缺少 bookSourceUrl';

  @override
  String get bookSourceImportRejectionMissingName => '缺少 bookSourceName';

  @override
  String get bookSourceImportRejectionUnreadable => '这条书源无法解析';

  @override
  String get bookSourceImportRejectionNotAnObject => '不是 JSON 对象';

  @override
  String bookSourceImportCommit(int count) {
    return '导入选中 $count 条';
  }

  @override
  String get bookSourceImportSelectAll => '全选';

  @override
  String get bookSourceImportDeselectAll => '取消全选';

  @override
  String get bookSourceImportBack => '返回修改';

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
  String mangaPageIndicator(int current, int total) {
    return '$current / $total';
  }

  @override
  String get mangaImageFailed => '这一页加载失败。';

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
  String get searchScopeFellBack => '所选范围已不存在，本次按全部启用书源搜索。';

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
  String get bookSourceListSelectMode => '多选';

  @override
  String get bookSourceListInvalidDisable => '禁用失效源';

  @override
  String get bookSourceListInvalidDelete => '删除失效源';

  @override
  String bookSourceListInvalidDisabled(int count) {
    return '已禁用 $count 个失效书源';
  }

  @override
  String bookSourceListInvalidDeleteTitle(int count) {
    return '删除 $count 个失效书源？';
  }

  @override
  String get bookSourceListGroupSelectSources => '选中该组全部书源';

  @override
  String get bookSourceListGroupDeleteSources => '删除该组全部书源';

  @override
  String bookSourceListGroupDeleteSourcesTitle(int count, String group) {
    return '删除「$group」的 $count 个书源？';
  }

  @override
  String bookSourceListSelectedCount(int count) {
    return '已选 $count 项';
  }

  @override
  String get bookSourceListBatchCheck => '校验';

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
  String get bookSourceCheckStatusPassed => '校验通过';

  @override
  String get bookSourceCheckStatusDegraded => '超时或 JS 失效';

  @override
  String get bookSourceCheckStatusUnchecked => '从未校验';

  @override
  String get bookSourceListLastCheckJustNow => '刚刚校验';

  @override
  String bookSourceListLastCheckMinutesAgo(int count) {
    return '$count 分钟前校验';
  }

  @override
  String bookSourceListLastCheckHoursAgo(int count) {
    return '$count 小时前校验';
  }

  @override
  String bookSourceListLastCheckDaysAgo(int count) {
    return '$count 天前校验';
  }

  @override
  String bookSourceListLastCheckOn(String date) {
    return '$date 校验';
  }

  @override
  String bookSourceListLastCheckLine(String when, int millis) {
    return '$when · $millis 毫秒';
  }

  @override
  String get bookSourceListBatchMoveTop => '置顶';

  @override
  String get bookSourceListBatchMoveBottom => '置底';

  @override
  String get bookSourceListBatchRemoveGroup => '移出分组';

  @override
  String get bookSourceListExploreOn => '已开发现';

  @override
  String get bookSourceListExploreOff => '未开发现';

  @override
  String get bookSourceExploreDisabled => '该源已关闭发现，可在书源列表里重新开启。';

  @override
  String get bookSourceRowExploreEnable => '开启发现';

  @override
  String get bookSourceRowExploreDisable => '关闭发现';

  @override
  String get bookSourceListSortAscending => '升序';

  @override
  String get bookSourceListSortDescending => '降序';

  @override
  String get bookSourceListGroupByDomain => '按域名分节';

  @override
  String get bookSourceListViewOptions => '视图';

  @override
  String get bookSourceListMoreActions => '更多操作';

  @override
  String get bookSourceListGroupManage => '管理分组';

  @override
  String get bookSourceListGroupRename => '重命名分组';

  @override
  String get bookSourceListGroupDelete => '删除分组';

  @override
  String bookSourceListGroupDeleteBody(String group) {
    return '所有书源都会移出「$group」，书源本身保留。';
  }

  @override
  String bookSourceListGroupRemoveFrom(String group) {
    return '移出「$group」';
  }

  @override
  String get bookSourceRowCheck => '校验该书源';

  @override
  String get bookSourceRowSignIn => '登录 / 过验证';

  @override
  String get bookSourceSignInDone => '已保存该站的 Cookie，可以重新校验了。';

  @override
  String get bookSourceSignInFailed => '登录 / 验证未完成。';

  @override
  String get bookSourceSignInUnsupported => '该平台没有可用的 WebView，请先在系统浏览器里完成验证。';

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

  @override
  String get readerTtsAction => '朗读';

  @override
  String get readerTtsTitle => '朗读';

  @override
  String get readerTtsStart => '开始朗读';

  @override
  String get readerTtsPause => '暂停';

  @override
  String get readerTtsResume => '继续';

  @override
  String get readerTtsStop => '停止';

  @override
  String get readerTtsRate => '语速';

  @override
  String get readerTtsPitch => '音高';

  @override
  String get readerTtsVoice => '音色';

  @override
  String readerTtsVoiceLabel(String name, String locale) {
    return '$name（$locale）';
  }

  @override
  String get readerTtsSystemVoice => '系统默认';

  @override
  String get readerTtsKeepOnExit => '离开阅读器后继续朗读';

  @override
  String get readerTtsFailed => '系统朗读引擎无法朗读本章。';

  @override
  String get readerAudioFailed => '这条音轨无法播放。';

  @override
  String get readerAudioPlay => '播放';

  @override
  String get readerAudioPause => '暂停';

  @override
  String get readerAudioReplay => '重新播放';

  @override
  String get readerAudioSpeed => '倍速';

  @override
  String readerAudioSpeedValue(String speed) {
    return '$speed×';
  }

  @override
  String readerAudioTrackCount(int index, int total) {
    return '第 $index 段，共 $total 段';
  }

  @override
  String get settingsNetwork => '网络';

  @override
  String get settingsPlainHttp => '允许明文 HTTP';

  @override
  String get settingsPlainHttpHint => '部分书源与音频流只提供 http:// 地址；页面请求也遵循此开关。';

  @override
  String get readerAudioPlainHttp => '这条音轨使用明文 HTTP。请在设置中开启「允许明文 HTTP」后播放。';

  @override
  String get bookmarkTitle => '书签';

  @override
  String get bookmarkEmpty => '还没有书签。阅读时点击工具条上的书签按钮即可标记当前位置。';

  @override
  String get bookmarkLoadFailed => '书签加载失败。';

  @override
  String get bookmarkAdd => '添加书签';

  @override
  String get bookmarkRemove => '取消书签';

  @override
  String get bookmarkAdded => '已添加书签';

  @override
  String get bookmarkRemoved => '已取消书签';

  @override
  String get bookmarkFailed => '书签操作失败。';

  @override
  String get bookmarkDeleteAction => '删除书签';

  @override
  String get bookSourceReadingRecords => '阅读记录';

  @override
  String get readingRecordsTitle => '阅读记录';

  @override
  String get readingRecordsEmpty => '还没有阅读记录。读满一分钟的会话才会记录。';

  @override
  String get readingRecordsLoadFailed => '阅读记录加载失败。';

  @override
  String bookReadingRecordsTitle(String book) {
    return '阅读记录 · $book';
  }

  @override
  String get bookReadingRecordsEmpty => '这本书还没有阅读记录。';

  @override
  String readingRecordMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String readingRecordHours(int hours) {
    return '$hours 小时';
  }

  @override
  String readingRecordHoursMinutes(int hours, int minutes) {
    return '$hours 小时 $minutes 分钟';
  }

  @override
  String get myBookmarks => '书签';

  @override
  String get myBookmarksBody => '全部标记过的位置';

  @override
  String get myReadingRecords => '阅读记录';

  @override
  String get myReadingRecordsBody => '按天查看读过的书';

  @override
  String get shelfManageGroups => '管理分组';

  @override
  String get shelfGroupAll => '全部';

  @override
  String get shelfGroupUngrouped => '未分组';

  @override
  String get shelfGroupEmpty => '这个分组里还没有书。';

  @override
  String get shelfGroupsTitle => '分组管理';

  @override
  String get shelfGroupsEmpty => '还没有分组。点右下角新建一个。';

  @override
  String get shelfGroupCreate => '新建分组';

  @override
  String get shelfGroupCreateAction => '新建';

  @override
  String get shelfGroupNameHint => '分组名称';

  @override
  String get shelfGroupRename => '重命名';

  @override
  String get shelfGroupRenameTitle => '重命名分组';

  @override
  String get shelfGroupDelete => '删除分组';

  @override
  String get shelfGroupDeleteTitle => '删除分组';

  @override
  String get shelfGroupDeleteBody => '组里的书会回到「未分组」，不会被删除。';

  @override
  String get shelfGroupNameTaken => '已经有同名分组了。';

  @override
  String get shelfSelectionExit => '退出多选';

  @override
  String shelfSelectionCount(int count) {
    return '已选 $count 本';
  }

  @override
  String get shelfSelectionClear => '取消全选';

  @override
  String get shelfSelectAll => '全选';

  @override
  String get shelfBatchAction => '批量操作';

  @override
  String get shelfBatchGroup => '改分组';

  @override
  String get bookSourceShelfGroup => '改分组';

  @override
  String get bookSourceShelfGroupHint => '加入书架后才能分组。';

  @override
  String get bookSourceChangeCover => '换封面';

  @override
  String get bookSourceResetCover => '恢复默认封面';

  @override
  String get bookSourceBookCache => '本书缓存';

  @override
  String bookSourceBookCacheCount(int count) {
    return '已缓存 $count 章';
  }

  @override
  String get bookSourceBookCacheClear => '清理本书缓存';

  @override
  String bookSourceBookCacheCleared(int count) {
    return '已清理 $count 项缓存';
  }

  @override
  String get bookSourceBookCacheFailed => '缓存操作失败。';

  @override
  String sourceVerificationTitle(String title, String source) {
    return '$title · $source';
  }

  @override
  String get sourceVerificationDone => '完成';

  @override
  String get sourceVerificationFailed => '验证未完成。';

  @override
  String sourceCaptchaTitle(String source) {
    return '图片验证码 · $source';
  }

  @override
  String get sourceCaptchaImage => '验证码图片';

  @override
  String get sourceCaptchaHint => '输入图中的字符';

  @override
  String get sourceCaptchaConfirm => '确定';

  @override
  String get failureLoginRequired => '该书源需要登录或重新完成人机验证，请先在书源管理里打开验证。';

  @override
  String get mySectionRules => '规则';

  @override
  String get rulesReplaceTitle => '替换净化';

  @override
  String get rulesTocTitle => '目录规则';

  @override
  String get rulesDictTitle => '字典规则';

  @override
  String get rulesHighlightTitle => '高亮标签';

  @override
  String get rulesAdd => '新增规则';

  @override
  String get rulesEditTitle => '编辑规则';

  @override
  String get rulesEmpty => '还没有规则';

  @override
  String get rulesLoadFailed => '规则读取失败。';

  @override
  String get rulesGone => '这条规则已经不存在了。';

  @override
  String get rulesBroken => '规则损坏';

  @override
  String get rulesBuiltIn => '内置';

  @override
  String get rulesBrokenNotice => '这条规则存的内容读不懂，原文见下方；保存会用它替换掉。';

  @override
  String get rulesReorderHandle => '调整顺序';

  @override
  String get rulesNameLabel => '名称';

  @override
  String get rulesPatternLabel => '查找内容（正则或文本）';

  @override
  String get rulesReplacementLabel => '替换为';

  @override
  String get rulesIsRegexLabel => '按正则处理';

  @override
  String get rulesRuleLabel => '章节标题规则';

  @override
  String get rulesSerialNumberLabel => '序号（可空）';

  @override
  String get rulesUrlRuleLabel => '查询地址';

  @override
  String get rulesShowRuleLabel => '提取规则';

  @override
  String get rulesColorLabel => '颜色，#AARRGGBB（可空）';

  @override
  String get rulesGroupLabel => '分组（可空）';

  @override
  String get rulesEnabledLabel => '启用';

  @override
  String get rulesRequired => '不能为空。';

  @override
  String get rulesInvalidRegex => '这不是合法的正则表达式。';

  @override
  String get rulesInvalidColor => '请写 #RRGGBB 或 #AARRGGBB。';

  @override
  String get readerSearchAction => '搜索本书';

  @override
  String get readerSearchHint => '在本机这本书里找';

  @override
  String get readerSearchStart => '搜索';

  @override
  String get readerSearchStop => '停止';

  @override
  String readerSearchProgress(int scanned, int total) {
    return '已搜 $scanned/$total 章';
  }

  @override
  String readerSearchStopped(int scanned, int total) {
    return '已停止，搜到 $scanned/$total 章。';
  }

  @override
  String readerSearchBudgetSpent(int scanned, int total) {
    return '时间用完，停在 $scanned/$total 章。';
  }

  @override
  String get readerSearchEmpty => '没有找到。';

  @override
  String readerSearchFailedChapters(int count) {
    return '有 $count 章读取失败。';
  }

  @override
  String get readerSearchUntitledChapter => '无标题章节';

  @override
  String get rulesImportTitle => '导入规则';

  @override
  String get rulesImportTextLabel => '规则 JSON';

  @override
  String get rulesImportTextHint => '粘贴净化规则 JSON 文件的内容';

  @override
  String get rulesImportUrlLabel => '或填写下载地址';

  @override
  String get rulesImportUrlHint => 'https://…/replaceRules.json';

  @override
  String get rulesImportFileAction => '选择 JSON 文件';

  @override
  String get rulesImportSelectAll => '全部导入';

  @override
  String rulesImportSelected(int selected, int usable) {
    return '已选 $selected/$usable';
  }

  @override
  String rulesImportCommit(int count) {
    return '导入选中（$count）';
  }

  @override
  String rulesImportSucceeded(int created, int updated) {
    return '新增 $created 条、更新 $updated 条。';
  }

  @override
  String rulesImportSucceededWithSkipped(
    int created,
    int updated,
    int skipped,
  ) {
    return '新增 $created 条、更新 $updated 条；$skipped 条读不懂已跳过。';
  }

  @override
  String get rulesImportUntitled => '无名规则';

  @override
  String get rulesImportUpdate => '更新';

  @override
  String get rulesImportProblemFormat => '不是规则对象';

  @override
  String get rulesImportProblemMissingPattern => '缺少 pattern';

  @override
  String get rulesExportAction => '导出';

  @override
  String get rulesExportEmpty => '没有可导出的规则。';

  @override
  String rulesExportSaved(int count) {
    return '已导出 $count 条规则。';
  }

  @override
  String rulesExportSavedWithSkipped(int count, int skipped) {
    return '已导出 $count 条；$skipped 条读不懂的没有导出。';
  }

  @override
  String get rulesExportFailed => '规则导出失败。';

  @override
  String get rulesScopeBoth => '标题 + 正文';

  @override
  String get rulesScopeContent => '只改正文';

  @override
  String get rulesScopeTitle => '只改标题';

  @override
  String get rulesScopeNone => '不生效';

  @override
  String get bookSourceExportAll => '导出全部';

  @override
  String bookSourceExportSelected(int count) {
    return '导出选中（$count）';
  }

  @override
  String bookSourceExportAllSaved(int count) {
    return '已导出 $count 个书源。';
  }

  @override
  String get bookSourceExportEmpty => '没有可导出的书源。';

  @override
  String get rulesListMenu => '更多';

  @override
  String get mySectionData => '数据';

  @override
  String get cacheManageTitle => '缓存管理';

  @override
  String get cacheManageMore => '更多';

  @override
  String cacheManageTotal(int count) {
    return '共 $count 章缓存';
  }

  @override
  String cacheManageSourceCount(int count) {
    return '$count 章';
  }

  @override
  String get cacheManageClearSource => '清理该源缓存';

  @override
  String get cacheManageClearExpired => '清理过期条目';

  @override
  String get cacheManageClearAll => '清空全部缓存';

  @override
  String get cacheManageClearAllTitle => '清空全部缓存？';

  @override
  String get cacheManageClearAllBody => '缓存下来的正文与探测结果会在需要时重新下载。';

  @override
  String get cacheManageEmpty => '还没有缓存。';

  @override
  String get cacheManageLoadFailed => '缓存读取失败。';

  @override
  String get myCookies => 'Cookie 管理';

  @override
  String get myCookiesBody => '站点为保持登录存下的凭据';

  @override
  String get cookieManageTitle => 'Cookie 管理';

  @override
  String get cookieManageMore => '更多';

  @override
  String get cookieManageSession => '关闭应用前有效';

  @override
  String cookieManageExpiresAt(String moment) {
    return '过期时间 $moment';
  }

  @override
  String get cookieManageDelete => '删除这条 Cookie';

  @override
  String get cookieManageClearDomain => '清空该域';

  @override
  String get cookieManageClearExpired => '清理过期 Cookie';

  @override
  String get cookieManageClearAll => '清空全部 Cookie';

  @override
  String get cookieManageClearAllTitle => '清空全部 Cookie？';

  @override
  String get cookieManageClearAllBody => '所有站点都会要求你重新登录。';

  @override
  String get cookieManageEmpty => '没有存下任何 Cookie。';

  @override
  String get cookieManageLoadFailed => 'Cookie 读取失败。';

  @override
  String get bookSourceLoginTitle => '登录';

  @override
  String get bookSourceLoginLoadFailed => '登录表单读取失败。';

  @override
  String get bookSourceLoginNoForm => '这个书源没有声明登录表单。';

  @override
  String get bookSourceLoginWorking => '登录中…';

  @override
  String get bookSourceLoginDone => '已提交，书源自己的脚本没有报错。';

  @override
  String get myBackup => '备份与恢复';

  @override
  String get myBackupBody => '打成一个 zip，或从 zip 恢复';

  @override
  String get backupTitle => '备份与恢复';

  @override
  String get backupExportTitle => '导出备份';

  @override
  String get backupExportBody => '书源、书架、分组、书签、阅读记录、四类规则与设置，打成一个 zip。';

  @override
  String get backupRestoreTitle => '从备份恢复';

  @override
  String get backupRestoreBody => '先看备份里有什么，确认后按自然键合并进本机。';

  @override
  String get backupIncludeSecretsHint => '备份是明文文件，包含书源登录信息。请放在自己信任的位置。';

  @override
  String get backupWorkingExporting => '正在打包…';

  @override
  String get backupWorkingReading => '正在读取备份…';

  @override
  String get backupWorkingRestoring => '正在恢复…';

  @override
  String get backupPreviewTitle => '备份内容';

  @override
  String get backupPreviewEmpty => '这份备份里没有任何记录。';

  @override
  String get backupConfirmRestore => '合并进本机';

  @override
  String get backupMergeHint => '恢复只合并、不删除：本机已有且备份里没有的内容都保留。';

  @override
  String get backupTableBookSources => '书源';

  @override
  String get backupTableBooks => '书架';

  @override
  String get backupTableReadingProgress => '阅读进度';

  @override
  String get backupTableBookGroups => '分组';

  @override
  String get backupTableBookmarks => '书签';

  @override
  String get backupTableReadRecords => '阅读记录';

  @override
  String get backupTableRules => '规则';

  @override
  String backupExported(String fileName, int count) {
    return '已保存 $fileName（$count 条记录）。';
  }

  @override
  String backupPreviewMeta(String createdAt, String appVersion) {
    return '备份于 $createdAt，写入版本 $appVersion。';
  }

  @override
  String backupPreviewPreferences(int count) {
    return '$count 项设置';
  }

  @override
  String backupRestored(int changed, int preferences) {
    return '已合并：写回 $changed 条记录、$preferences 项设置。';
  }

  @override
  String get backupAutoTitle => '自动备份';

  @override
  String get backupAutoBody => '启动时若距上次备份超过一天，就自动备份一次。';

  @override
  String get backupRetentionTitle => '保留份数';

  @override
  String get backupRetentionBody => '超出份数的旧备份会被删掉；只删本应用写的文件。';

  @override
  String backupRetentionValue(int count) {
    return '$count 份';
  }

  @override
  String get backupLocationTitle => '备份位置';

  @override
  String get backupLocationPrivate => '应用私有目录';

  @override
  String get backupLocationChoose => '选择文件夹';

  @override
  String get backupLocationReset => '恢复默认';

  @override
  String get backupLocationFallback => '选的文件夹不可用，暂时写到应用私有目录。';

  @override
  String get backupPasswordTitle => '备份口令';

  @override
  String get backupPasswordBody => '设置后备份整包加密（AES-256），口令存在系统密钥库。';

  @override
  String get backupPasswordChange => '修改口令';

  @override
  String get backupPasswordSet => '设置口令';

  @override
  String get backupPasswordClear => '清除口令';

  @override
  String get backupPasswordStored => '已设置（备份加密）';

  @override
  String get backupPasswordMissing => '未设置（备份不加密）';

  @override
  String get backupPasswordStoreFailed => '密钥库不可用，口令没存下：备份仍不加密。';

  @override
  String get backupSaveToLocation => '保存到备份位置';

  @override
  String get backupSaveAs => '另存为…';

  @override
  String get backupRestoreFromFile => '从文件恢复';

  @override
  String backupSavedTo(String path) {
    return '已保存到 $path';
  }

  @override
  String get backupRemoteTitle => '云端备份';

  @override
  String get backupRemoteEmpty => '云端没有备份文件。';

  @override
  String get backupRemoteRestore => '从云端恢复';

  @override
  String get backupRemoteDelete => '删除云端备份';

  @override
  String get backupCloudUpload => '上传当前备份';

  @override
  String get backupCloudRefresh => '刷新云端列表';

  @override
  String get backupWebDavTitle => 'WebDAV';

  @override
  String get backupWebDavUrl => '地址（集合目录）';

  @override
  String get backupWebDavUsername => '账号';

  @override
  String get backupWebDavPassword => '密码';

  @override
  String get backupWebDavSave => '保存 WebDAV 配置';

  @override
  String get backupWebDavNotConfigured => '还没配置 WebDAV。';

  @override
  String get backupPasswordRequired => '这份备份已加密，需要口令。';

  @override
  String get backupPasswordPrompt => '输入备份口令';

  @override
  String get backupPasswordWrong => '口令不对，请再试一次。';

  @override
  String get backupMergeMode => '合并';

  @override
  String get backupOverwriteMode => '覆盖';

  @override
  String get backupOverwriteWarning =>
      '覆盖会先清空本机的书源、书架、分组、书签、阅读记录与规则，再写入备份，并在恢复前自动保存一份安全副本。';

  @override
  String get backupOverwriteConfirm => '确认覆盖';

  @override
  String backupSafetyCopy(String name) {
    return '已先保存安全副本：$name';
  }

  @override
  String get backupWorkSavingAs => '正在另存…';

  @override
  String get backupWorkUploading => '正在上传…';

  @override
  String get backupWorkListingRemote => '正在读取云端列表…';

  @override
  String get backupWorkDownloading => '正在下载…';

  @override
  String get backupLocalTitle => '本机备份';

  @override
  String get settingsSeedColor => '配色';

  @override
  String get settingsSeedColorHint => '有动态取色时系统配色优先；这里决定没有动态取色的设备用哪套颜色。';

  @override
  String get settingsSeedColorDefault => '默认';

  @override
  String get settingsBackgroundImage => '背景图';

  @override
  String get settingsBackgroundImageNone => '未设置';

  @override
  String get settingsBackgroundImageChoose => '选择图片';

  @override
  String get settingsBackgroundImageRemove => '移除';

  @override
  String get settingsBackgroundImageHint => '图片会复制到应用目录，原图删除也不影响。';

  @override
  String get settingsBackgroundImageFailed => '背景图没能保存，请再试一次。';

  @override
  String get externalLinkTitle => '打开这个地址？';

  @override
  String externalLinkFrom(Object source) {
    return '$source 想在浏览器里打开这个地址：';
  }

  @override
  String get externalLinkOpen => '打开';

  @override
  String get externalLinkCancel => '取消';
}
