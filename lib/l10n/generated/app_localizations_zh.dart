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
  String get failureUnsupportedRule => '该书源使用了暂不支持的规则类型。';
}
