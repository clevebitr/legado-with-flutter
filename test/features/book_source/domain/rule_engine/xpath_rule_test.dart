import 'package:flutter_reader/features/book_source/domain/rule_engine/xpath_rule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// The page the cases run against: 眼镜式的小站点，但每个断言都抄自 2026-10-27 的真实语料
/// （`engine-parity.md` §9.2 的 XPath 行）。
const String _page = '''
<html><head>
  <meta property="og:title" content="书名" />
  <meta property="og:image" content="https://img.test/cover.jpg" />
</head><body>
  <div id="content">
    <div class="desc">简介第一段</div>
    <div class="blue">该删掉的</div>
    <p class="author">作者：<span><a href="/a/1">甲</a></span></p>
  </div>
  <div class="tb_con" id="nav">
    <p class="curr">当前</p>
    <a href="/1.html">上一页</a>
    <a href="/2.html">下一页</a>
  </div>
  <div class="tb_con" id="toc">
    <table><tbody>
      <tr><td>a</td><td>b</td></tr>
      <tr><td>c</td><td>d</td></tr>
    </tbody></table>
  </div>
  <div id="novelMain"><div><table><tbody><tr><td><div><h2>卷二标题</h2></div></td></tr></tbody></table></div></div>
  <table><tbody><tr><td id="text"><p>第一段</p><p>第二段</p><p>第三段</p><p>末段</p></td></tr></tbody></table>
  <div class="catalog_box"><div class="volume_box"><ul>
    <li>空条目</li>
    <li><a href="/c/1">有链接</a></li>
  </ul></div></div>
  <div id="tag"><span rel="tag">一</span><span rel="tag">二</span><span rel="tag">三</span></div>
  <div id="a">甲<div>A1</div><div>A2</div></div>
  <div id="b">乙<div>B1</div></div>
  <h2><a href="/x"><b>粗体标题</b>尾巴</a></h2>
  <select><option value="1">选项一</option><option value="2">选项二</option></select>
  <div style="color:red;"></div>
</body></html>
''';

Document get _document => html_parser.parse(_page);

/// The string values one rule selects.
List<String> _values(String rule) {
  final XPathCompilation compiled = compileXPath(rule);
  expect(compiled, isA<XPathCompiled>(), reason: 'compiling: $rule');
  final XPathExpression expression = (compiled as XPathCompiled).expression;

  return <String>[
    for (final XPathMatch match in expression.select(_document))
      match.stringValue,
  ];
}

/// The elements one rule selects.
List<Element> _elements(String rule) => <Element>[
  for (final XPathMatch match
      in (compileXPath(rule) as XPathCompiled).expression.select(_document))
    if (match is XPathElementMatch) match.element,
];

void main() {
  group('XPath select (corpus expressions)', () {
    test('xpath_givenAChildChain_answersTheText', () {
      // 语料：`//div[@class="desc"]/text()`。
      expect(_values('//div[@class="desc"]/text()'), <String>['简介第一段']);
    });

    test('xpath_givenPositionalSteps_walksTheChain', () {
      // 语料：`//*[@id="novelMain"]/div[1]/table/tbody/tr/td[1]/div[1]/h2/text()`。
      expect(
        _values(
          '//*[@id="novelMain"]/div[1]/table/tbody/tr/td[1]/div[1]/h2/text()',
        ),
        <String>['卷二标题'],
      );
    });

    test('xpath_givenAnAttributeStep_answersItsValue', () {
      // 语料：`//meta[@property='og:title']/@content`（封面 / 书名都是这个形状）。
      expect(_values('//meta[@property=\'og:title\']/@content'), <String>[
        '书名',
      ]);
      expect(_values('//meta[@property="og:image"]/@content'), <String>[
        'https://img.test/cover.jpg',
      ]);
    });

    test('xpath_givenContainsOnText_selectsTheParagraph', () {
      // 语料：`//p[contains(text(),'作者：')]/text()`。`text()` 只答 p 的**直接**文本子节点，
      // 所以 `<span><a>甲</a></span>` 里的名字不在这条规则里（源上就是这么写的）。
      expect(_values('//p[contains(text(),\'作者：\')]/text()'), <String>['作者：']);
      expect(_values('//p[contains(text(),\'作者：\')]//text()'), <String>[
        '作者：',
        '甲',
      ]);
    });

    test('xpath_givenContainsOnAnAttribute_matchesItsSubstring', () {
      // 语料：`//div[contains(@class,'container')]//a[contains(@class,'group')]`。
      expect(_elements('//div[contains(@class,\'tb_con\')]').length, 2);
    });

    test('xpath_givenNot_selectsTheComplement', () {
      // 语料：`//*[not(@class='blue')]/text()`。
      expect(
        _values('//div[@id="content"]/*[not(@class=\'blue\')]/text()'),
        contains('简介第一段'),
      );
      expect(
        _values('//div[@id="content"]/*[not(@class=\'blue\')]/text()'),
        isNot(contains('该删掉的')),
      );
    });

    test('xpath_givenPositionAndLast_selectsAllButTheLastTwo', () {
      // 语料：`//td[@id='text']/p[position() < last()-1]`。
      expect(_values('//td[@id=\'text\']/p[position() < last()-1]'), <String>[
        '第一段',
        '第二段',
      ]);
    });

    test('xpath_givenPositionOnAStep_skipsTheFirstMatch', () {
      // 语料：`//div[@class="tb_con"][position()>1]//tr`。
      expect(_elements('//div[@class="tb_con"][position()>1]//tr').length, 2);
    });

    test('xpath_givenAnIndexAfterAPredicate_usesTheFilteredList', () {
      // 语料：`//*[@rel="tag"][3]/text()`：先按属性筛，再取第三项。
      expect(_values('//*[@rel="tag"][3]/text()'), <String>['三']);
    });

    test('xpath_givenARelativePathPredicate_checksExistence', () {
      // 语料：`//div[@class='catalog_box']/div[@class='volume_box']/ul/li[.//a]`。
      // 它是**列表**规则（答元素），而 `text()` 只答直接文本子节点，所以 `<li><a>…</a></li>`
      // 没有文本子节点——与上游一致，不是缺口。
      expect(
        _elements('//div[@class=\'catalog_box\']//li[.//a]')
            .map((Element element) => element.text),
        <String>['有链接'],
      );
      expect(
        _values('//div[@class=\'catalog_box\']//li[.//a]/a/text()'),
        <String>['有链接'],
      );
    });

    test('xpath_givenAUnion_answersBothBranchesOnce', () {
      // 语料：`//div[@id='a']//div/text()|//div[@id='b']//div/text()`。
      expect(
        _values('//div[@id=\'a\']//div/text()|//div[@id=\'b\']//div/text()'),
        <String>['A1', 'A2', 'B1'],
      );
    });

    test('xpath_givenDescendantText_collectsEveryTextNode', () {
      // 语料：`//h2/a//text()`：`<b>` 里的文本也算。
      expect(_values('//h2/a//text()'), <String>['粗体标题', '尾巴']);
    });

    test('xpath_givenATagStep_answersElements', () {
      // 语料：`//option`（目录列表规则）。
      expect(
        _elements('//select/option').map((Element element) => element.text),
        <String>['选项一', '选项二'],
      );
    });

    test('xpath_givenFollowingSibling_answersTheNextAnchor', () {
      // 语料：`//*[@class="curr"]/following-sibling::a[1]/@href`（nextTocUrl）。
      expect(
        _values('//*[@class="curr"]/following-sibling::a[1]/@href'),
        <String>['/1.html'],
      );
    });

    test('xpath_givenAnElementMatch_carriesTheElementItself', () {
      // 列表规则要拿到元素才能继续往下读字段，所以元素匹配必须带元素本身。
      final List<XPathMatch> matches = (compileXPath(
        '//select/option',
      ) as XPathCompiled).expression.select(_document);

      expect(matches, everyElement(isA<XPathElementMatch>()));
      expect(matches.first.stringValue, '选项一');
    });

    test('xpath_givenWhitespaceInTheText_collapsesIt', () {
      // 文本节点里的换行与缩进不该漏进字段值（与 `text` 提取同一口径）。
      final Document document = html_parser.parse(
        '<div id="x">\n  <p>  标题  </p>\n</div>',
      );
      final XPathExpression expression =
          (compileXPath('//p/text()') as XPathCompiled).expression;

      expect(expression.select(document).single.stringValue, '标题');
    });
  });

  group('XPath predicates', () {
    test('xpath_givenAndOrAndStartsWith_evaluatesThem', () {
      expect(
        _values('//div[@class="desc" and starts-with(text(),"简介")]/text()'),
        <String>['简介第一段'],
      );
      expect(_values('//div[@class="desc" or @class="blue"]/text()'), <String>[
        '简介第一段',
        '该删掉的',
      ]);
    });

    test('xpath_givenATextNodeEquality_comparesItsValue', () {
      expect(_values('//span[text()="二"]/text()'), <String>['二']);
    });

    test('xpath_givenPositionOnTheRoot_keepsTheDocumentOut', () {
      // 文档节点永远不是规则的答案：`//*` 只答元素。
      expect(
        _elements('//*').every((Element element) => element.localName != null),
        isTrue,
      );
      expect(
        (compileXPath('//*') as XPathCompiled).expression
            .select(_document)
            .every((XPathMatch match) => match is XPathElementMatch),
        isTrue,
      );
    });

    test('xpath_givenAParentStep_walksUp', () {
      expect(_values('//div[@class="desc"]/../@id'), <String>['content']);
    });
  });

  group('XPath rejections', () {
    test('compileXPath_givenAnUnsupportedAxis_namesIt', () {
      for (final String axis in <String>[
        'ancestor',
        'ancestor-or-self',
        'following',
        'preceding',
      ]) {
        expect(
          compileXPath('//div/$axis::p'),
          isA<XPathUnsupported>().having(
            (XPathUnsupported rejection) => rejection.syntax,
            'syntax',
            'xpath:$axis::',
          ),
        );
      }
    });

    test('compileXPath_givenAnUnsupportedFunction_namesIt', () {
      // 语料里没有这些，但真实源随时会写；名字进 rulePath 才能一眼看出缺什么。
      expect(
        compileXPath('//div[count(.//a)>0]'),
        isA<XPathUnsupported>().having(
          (XPathUnsupported rejection) => rejection.syntax,
          'syntax',
          'xpath:count()',
        ),
      );
      expect(
        compileXPath('//div[normalize-space(text())="x"]'),
        isA<XPathUnsupported>().having(
          (XPathUnsupported rejection) => rejection.syntax,
          'syntax',
          'xpath:normalize-space()',
        ),
      );
    });

    test('compileXPath_givenAnUnsupportedNodeTest_namesIt', () {
      expect(
        compileXPath('//node()'),
        isA<XPathUnsupported>().having(
          (XPathUnsupported rejection) => rejection.syntax,
          'syntax',
          'xpath:node()',
        ),
      );
      expect(
        compileXPath('//comment()'),
        isA<XPathUnsupported>().having(
          (XPathUnsupported rejection) => rejection.syntax,
          'syntax',
          'xpath:comment()',
        ),
      );
    });

    test('compileXPath_givenAWildcardAttribute_namesIt', () {
      expect(
        compileXPath('//a/@*'),
        isA<XPathUnsupported>().having(
          (XPathUnsupported rejection) => rejection.syntax,
          'syntax',
          'xpath:@*',
        ),
      );
    });

    test('compileXPath_givenAMalformedRule_answersMalformed', () {
      for (final String rule in <String>[
        '',
        '   ',
        '//div[',
        '//div[@class=]',
        '//div[@class="x"',
        '//',
        '//div]',
        "//div[@class='x']/@",
      ]) {
        expect(
          compileXPath(rule),
          isA<XPathMalformed>(),
          reason: 'rule: $rule',
        );
      }
    });
  });
}
