// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BookSource _$BookSourceFromJson(Map<String, dynamic> json) => $checkedCreate(
  '_BookSource',
  json,
  ($checkedConvert) {
    final val = _BookSource(
      name: $checkedConvert('bookSourceName', (v) => v as String),
      url: $checkedConvert('bookSourceUrl', (v) => v as String),
      group: $checkedConvert('bookSourceGroup', (v) => v as String?),
      sourceType: $checkedConvert(
        'bookSourceType',
        (v) =>
            $enumDecodeNullable(_$BookSourceTypeEnumMap, v) ??
            BookSourceType.text,
      ),
      isEnabled: $checkedConvert('enabled', (v) => v as bool? ?? true),
      headers: $checkedConvert(
        'header',
        (v) => const _HeaderJsonConverter().fromJson(v),
      ),
      searchUrl: $checkedConvert('searchUrl', (v) => v as String?),
      searchRule: $checkedConvert(
        'ruleSearch',
        (v) => SearchRule.fromJson(v as Map<String, dynamic>),
      ),
      bookInfoRule: $checkedConvert(
        'ruleBookInfo',
        (v) =>
            v == null ? null : BookInfoRule.fromJson(v as Map<String, dynamic>),
      ),
      tocRule: $checkedConvert(
        'ruleToc',
        (v) => TocRule.fromJson(v as Map<String, dynamic>),
      ),
      contentRule: $checkedConvert(
        'ruleContent',
        (v) => ContentRule.fromJson(v as Map<String, dynamic>),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'name': 'bookSourceName',
    'url': 'bookSourceUrl',
    'group': 'bookSourceGroup',
    'sourceType': 'bookSourceType',
    'isEnabled': 'enabled',
    'headers': 'header',
    'searchRule': 'ruleSearch',
    'bookInfoRule': 'ruleBookInfo',
    'tocRule': 'ruleToc',
    'contentRule': 'ruleContent',
  },
);

Map<String, dynamic> _$BookSourceToJson(_BookSource instance) =>
    <String, dynamic>{
      'bookSourceName': instance.name,
      'bookSourceUrl': instance.url,
      'bookSourceGroup': instance.group,
      'bookSourceType': _$BookSourceTypeEnumMap[instance.sourceType]!,
      'enabled': instance.isEnabled,
      'header': const _HeaderJsonConverter().toJson(instance.headers),
      'searchUrl': instance.searchUrl,
      'ruleSearch': instance.searchRule,
      'ruleBookInfo': instance.bookInfoRule,
      'ruleToc': instance.tocRule,
      'ruleContent': instance.contentRule,
    };

const _$BookSourceTypeEnumMap = {
  BookSourceType.text: 0,
  BookSourceType.audio: 1,
  BookSourceType.image: 2,
  BookSourceType.file: 3,
};

_SearchRule _$SearchRuleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_SearchRule', json, ($checkedConvert) {
      final val = _SearchRule(
        bookList: $checkedConvert('bookList', (v) => v as String?),
        name: $checkedConvert('name', (v) => v as String?),
        author: $checkedConvert('author', (v) => v as String?),
        kind: $checkedConvert('kind', (v) => v as String?),
        wordCount: $checkedConvert('wordCount', (v) => v as String?),
        lastChapter: $checkedConvert('lastChapter', (v) => v as String?),
        intro: $checkedConvert('intro', (v) => v as String?),
        coverUrl: $checkedConvert('coverUrl', (v) => v as String?),
        bookUrl: $checkedConvert('bookUrl', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$SearchRuleToJson(_SearchRule instance) =>
    <String, dynamic>{
      'bookList': instance.bookList,
      'name': instance.name,
      'author': instance.author,
      'kind': instance.kind,
      'wordCount': instance.wordCount,
      'lastChapter': instance.lastChapter,
      'intro': instance.intro,
      'coverUrl': instance.coverUrl,
      'bookUrl': instance.bookUrl,
    };

_BookInfoRule _$BookInfoRuleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_BookInfoRule', json, ($checkedConvert) {
      final val = _BookInfoRule(
        init: $checkedConvert('init', (v) => v as String?),
        name: $checkedConvert('name', (v) => v as String?),
        author: $checkedConvert('author', (v) => v as String?),
        kind: $checkedConvert('kind', (v) => v as String?),
        lastChapter: $checkedConvert('lastChapter', (v) => v as String?),
        intro: $checkedConvert('intro', (v) => v as String?),
        coverUrl: $checkedConvert('coverUrl', (v) => v as String?),
        tocUrl: $checkedConvert('tocUrl', (v) => v as String?),
        wordCount: $checkedConvert('wordCount', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$BookInfoRuleToJson(_BookInfoRule instance) =>
    <String, dynamic>{
      'init': instance.init,
      'name': instance.name,
      'author': instance.author,
      'kind': instance.kind,
      'lastChapter': instance.lastChapter,
      'intro': instance.intro,
      'coverUrl': instance.coverUrl,
      'tocUrl': instance.tocUrl,
      'wordCount': instance.wordCount,
    };

_TocRule _$TocRuleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_TocRule', json, ($checkedConvert) {
      final val = _TocRule(
        chapterList: $checkedConvert('chapterList', (v) => v as String?),
        chapterName: $checkedConvert('chapterName', (v) => v as String?),
        chapterUrl: $checkedConvert('chapterUrl', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$TocRuleToJson(_TocRule instance) => <String, dynamic>{
  'chapterList': instance.chapterList,
  'chapterName': instance.chapterName,
  'chapterUrl': instance.chapterUrl,
};

_ContentRule _$ContentRuleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_ContentRule', json, ($checkedConvert) {
      final val = _ContentRule(
        content: $checkedConvert('content', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ContentRuleToJson(_ContentRule instance) =>
    <String, dynamic>{'content': instance.content};
