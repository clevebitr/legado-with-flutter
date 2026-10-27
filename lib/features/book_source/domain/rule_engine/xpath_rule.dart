import 'package:html/dom.dart';

// XPath 的三类拒绝都是「这条规则用到了本仓没实现的东西」，名字要能进 `rulePath`：
// 语法名（`xpath:ancestor::`）比一个泛化的 `unsupportedRule` 有用得多（C-SRC-4）。
/// Syntax this repository names but does not implement.
final class _UnsupportedXPath implements Exception {
  const _UnsupportedXPath(this.syntax);

  /// What the rule path reports, e.g. `xpath:ancestor::`.
  final String syntax;
}

/// Whitespace runs, collapsed the way the rest of the engine normalises text.
final RegExp _whitespace = RegExp(r'\s+');

String _collapse(String text) => text.replaceAll(_whitespace, ' ').trim();

/// The outcome of compiling one XPath rule.
sealed class XPathCompilation {
  const XPathCompilation();
}

/// A rule that compiled.
final class XPathCompiled extends XPathCompilation {
  /// Wraps [expression].
  const XPathCompiled(this.expression);

  /// The compiled expression.
  final XPathExpression expression;
}

/// A rule that uses syntax this repository names but does not implement.
final class XPathUnsupported extends XPathCompilation {
  /// Names [syntax], e.g. `xpath:ancestor::`.
  const XPathUnsupported(this.syntax);

  /// What the rule path reports.
  final String syntax;
}

/// A rule that is not an XPath expression at all.
final class XPathMalformed extends XPathCompilation {
  /// Creates the rejection of an unreadable rule.
  const XPathMalformed();
}

/// Compiles [rule] — an XPath 1.0 subset — or answers why it cannot be compiled.
XPathCompilation compileXPath(String rule) {
  final String text = rule.trim();
  if (text.isEmpty) {
    return const XPathMalformed();
  }
  try {
    return XPathCompiled(XPathExpression(_Parser(text).parseRule()));
  } on _UnsupportedXPath catch (error) {
    return XPathUnsupported(error.syntax);
  } on FormatException {
    return const XPathMalformed();
  }
}

/// One node an expression selected.
sealed class XPathMatch {
  const XPathMatch();

  /// The node's XPath **string value**, whitespace-collapsed.
  ///
  /// Elements answer their whole text (jsoup's `Element.text()`), text nodes their data,
  /// attributes their value — the same normalisation `text` extraction uses, so an XPath rule and
  /// a default rule describing the same field answer the same bytes.
  String get stringValue;
}

/// An element match, which a list rule can scope into.
final class XPathElementMatch extends XPathMatch {
  /// Wraps [element].
  const XPathElementMatch(this.element);

  /// The matched element.
  final Element element;

  @override
  String get stringValue => _collapse(element.text);
}

/// A text-node or attribute match: a value, with nothing to scope into.
final class XPathValueMatch extends XPathMatch {
  /// Wraps the string [stringValue].
  const XPathValueMatch(this.stringValue);

  @override
  final String stringValue;
}

/// One compiled XPath expression: a union of location paths.
final class XPathExpression {
  /// Wraps the parsed union.
  const XPathExpression(this._unions);

  final List<_LocationPath> _unions;

  /// Selects from [root], in document order as far as the union allows.
  ///
  /// A node reached by two branches of a union answers once (XPath node-sets are sets).
  List<XPathMatch> select(Node root) {
    final _Node start = _wrap(root);
    final List<_Node> selected = <_Node>[];
    final Set<_Node> seen = <_Node>{};
    for (final _LocationPath path in _unions) {
      for (final _Node node in path.evaluate(start)) {
        if (seen.add(node) && !node.isDocument) {
          selected.add(node);
        }
      }
    }

    // 结果是集合，但顺序必须是**文档顺序**：`//h2/a//text()` 的文本节点按元素在后代里的位置
    // 排队，而不是按步展开的顺序（否则 `<b>粗体</b>尾巴` 会先答「尾巴」）。
    final Map<_Node, int> order = _documentOrder(start);
    final List<({_Node node, int order, int index})> decorated =
        <({_Node node, int order, int index})>[
          for (var index = 0; index < selected.length; index++)
            (
              node: selected[index],
              order: order[selected[index]] ?? 0,
              index: index,
            ),
        ]..sort(
          (
            ({_Node node, int order, int index}) a,
            ({_Node node, int order, int index}) b,
          ) => a.order != b.order
              ? a.order.compareTo(b.order)
              : a.index.compareTo(b.index),
        );

    return <XPathMatch>[
      for (final ({_Node node, int order, int index}) entry in decorated)
        entry.node.match,
    ];
  }
}

// ─── nodes ────────────────────────────────────────────────────────────────────────────────────────

/// What an expression walks over: the parsed HTML, never the raw string.
///
/// Equality is by the wrapped DOM node, because a union must answer a node once even when two
/// branches reach it through different wrappers.
sealed class _Node {
  const _Node();

  /// The identity the node is deduplicated on.
  Object get identity;

  /// The node's string value.
  String get stringValue;

  /// The match this node becomes.
  XPathMatch get match;

  /// Whether this is the document node (never a rule's answer).
  bool get isDocument => false;

  @override
  bool operator ==(Object other) =>
      other is _Node && other.identity == identity;

  @override
  int get hashCode => identity.hashCode;
}

final class _DocumentNode extends _Node {
  const _DocumentNode(this.node);

  final Document node;

  @override
  Object get identity => node;

  @override
  bool get isDocument => true;

  @override
  String get stringValue => _collapse(node.text ?? '');

  @override
  XPathMatch get match => XPathValueMatch(stringValue);
}

final class _ElementNode extends _Node {
  const _ElementNode(this.element);

  final Element element;

  @override
  Object get identity => element;

  @override
  String get stringValue => _collapse(element.text);

  @override
  XPathMatch get match => XPathElementMatch(element);
}

final class _TextNode extends _Node {
  const _TextNode(this.node);

  final Text node;

  @override
  Object get identity => node;

  @override
  String get stringValue => _collapse(node.data);

  @override
  XPathMatch get match => XPathValueMatch(stringValue);
}

/// Any other node the DOM hands out (comments, doctypes).
///
/// They exist so `descendant-or-self::node()` can walk through them; no node test this repository
/// implements selects them (`node()` / `comment()` are named rejections).
final class _OtherNode extends _Node {
  const _OtherNode(this.node);

  final Node node;

  @override
  Object get identity => node;

  @override
  String get stringValue => '';

  @override
  XPathMatch get match => const XPathValueMatch('');
}

final class _AttributeNode extends _Node {
  const _AttributeNode(this.owner, this.name, this.value);

  final Element owner;
  final String name;
  final String value;

  @override
  Object get identity => (owner, name);

  @override
  String get stringValue => value;

  @override
  XPathMatch get match => XPathValueMatch(value);
}

_Node _wrap(Node node) => switch (node) {
  final Document document => _DocumentNode(document),
  final Element element => _ElementNode(element),
  final Text text => _TextNode(text),
  _ => _OtherNode(node),
};

// ─── steps and axes ──────────────────────────────────────────────────────────────────────────────

enum _Axis {
  child,
  descendant,
  descendantOrSelf,
  self,
  parent,
  followingSibling,
  precedingSibling,
  attribute,
}

/// One `轴::节点测试[谓词]…` step.
final class _Step {
  const _Step(this.axis, this.test, {this.predicates = const <_Expression>[]});

  factory _Step.self() => const _Step(_Axis.self, _NodeTest.anyNode);

  factory _Step.parent() => const _Step(_Axis.parent, _NodeTest.anyNode);

  factory _Step.descendantOrSelf() =>
      const _Step(_Axis.descendantOrSelf, _NodeTest.anyNode);

  final _Axis axis;
  final _NodeTest test;
  final List<_Expression> predicates;

  /// Applies this step to every [nodes], then its predicates in order.
  ///
  /// XPath applies each predicate to the node list the previous one left, with `position()`
  /// relative to that list — which is why `[2][@class='x']` means the second item, if it has the
  /// class, not the second matching item.
  List<_Node> apply(List<_Node> nodes) {
    final List<_Node> out = <_Node>[];
    for (final _Node node in nodes) {
      List<_Node> matched = <_Node>[
        for (final _Node candidate in _axisNodes(node, axis))
          if (test.matches(candidate)) candidate,
      ];
      for (final _Expression predicate in predicates) {
        matched = _filterByPredicate(matched, predicate);
      }
      out.addAll(matched);
    }

    return out;
  }

  static List<_Node> _filterByPredicate(
    List<_Node> nodes,
    _Expression predicate,
  ) {
    final List<_Node> out = <_Node>[];
    for (var index = 0; index < nodes.length; index++) {
      final _Value value = predicate.evaluate(
        _PredicateContext(nodes[index], index + 1, nodes.length),
      );
      // 数值谓词按位置选（`[2]` 就是第二项），其余按布尔值选（XPath 1.0 §2.4）。
      if (value is _ValueNumber) {
        if (value.value == (index + 1).toDouble()) {
          out.add(nodes[index]);
        }
      } else if (value.toBoolean()) {
        out.add(nodes[index]);
      }
    }

    return out;
  }
}

final class _NodeTest {
  const _NodeTest._(this.kind, [this.name = '']);

  static const _NodeTest anyNode = _NodeTest._(_TestKind.anyNode);
  static const _NodeTest anyElement = _NodeTest._(_TestKind.anyElement);
  static const _NodeTest text = _NodeTest._(_TestKind.text);

  factory _NodeTest.tag(String name) =>
      _NodeTest._(_TestKind.tag, name.toLowerCase());

  factory _NodeTest.attribute(String name) =>
      _NodeTest._(_TestKind.attribute, name.toLowerCase());

  final _TestKind kind;
  final String name;

  bool matches(_Node node) => switch (kind) {
    _TestKind.anyNode => true,
    _TestKind.anyElement => node is _ElementNode,
    _TestKind.text => node is _TextNode,
    _TestKind.tag =>
      node is _ElementNode && node.element.localName?.toLowerCase() == name,
    _TestKind.attribute => node is _AttributeNode && node.name == name,
  };
}

enum _TestKind { anyNode, anyElement, text, tag, attribute }

List<_Node> _axisNodes(_Node node, _Axis axis) => switch (axis) {
  _Axis.self => <_Node>[node],
  _Axis.child => <_Node>[
    for (final Node child in _childrenOf(node)) _wrap(child),
  ],
  _Axis.descendant => _descendantsOf(node),
  _Axis.descendantOrSelf => <_Node>[node, ..._descendantsOf(node)],
  _Axis.parent => switch (_parentOf(node)) {
    final Node parent => <_Node>[_wrap(parent)],
    null => const <_Node>[],
  },
  _Axis.followingSibling => _siblingsOf(node, after: true),
  _Axis.precedingSibling => _siblingsOf(node, after: false),
  _Axis.attribute => switch (node) {
    _ElementNode(:final Element element) => <_Node>[
      for (final MapEntry<Object, String> entry in element.attributes.entries)
        _AttributeNode(element, '${entry.key}', entry.value),
    ],
    _ => const <_Node>[],
  },
};

Iterable<Node> _childrenOf(_Node node) => switch (node) {
  _DocumentNode(:final Document node) => node.nodes,
  _ElementNode(:final Element element) => element.nodes,
  _ => const <Node>[],
};

Node? _parentOf(_Node node) => switch (node) {
  _DocumentNode() => null,
  _ElementNode(:final Element element) => element.parentNode,
  _TextNode(:final Text node) => node.parentNode,
  _OtherNode(:final Node node) => node.parentNode,
  _AttributeNode(:final Element owner) => owner,
};

List<_Node> _descendantsOf(_Node node) {
  final List<_Node> out = <_Node>[];
  // 迭代而不是递归：深层嵌套的页面不能把栈打穿（C-SRC-9）。
  final List<Node> pending = <Node>[..._childrenOf(node).toList().reversed];
  while (pending.isNotEmpty) {
    final Node child = pending.removeLast();
    out.add(_wrap(child));
    // 逆序压栈 + 从尾部取，出来的就是**文档顺序**（`//text()` 的先后有意义）。
    pending.addAll(child.nodes.toList().reversed);
  }

  return out;
}

/// The position of every node in document order, used to order a rule's answers.
///
/// Attributes are not part of the document tree; they inherit their owner element's position, so a
/// union mixing them keeps the order the branches produced (which is what a source means by
/// `//a/@href|//b/@href`).
Map<_Node, int> _documentOrder(_Node root) {
  final Map<_Node, int> order = <_Node, int>{};
  var next = 0;
  void visit(_Node node) {
    final int index = next++;
    order[node] = index;
    if (node is _ElementNode) {
      for (final MapEntry<Object, String> entry
          in node.element.attributes.entries) {
        order[_AttributeNode(node.element, '${entry.key}', entry.value)] =
            index;
      }
    }
    for (final Node child in _childrenOf(node)) {
      visit(_wrap(child));
    }
  }

  visit(root);

  return order;
}

List<_Node> _siblingsOf(_Node node, {required bool after}) {
  final Node? parent = _parentOf(node);
  final _Node? self = switch (node) {
    _DocumentNode() => null,
    _ElementNode(:final Element element) => _wrap(element),
    _TextNode(:final Text node) => _wrap(node),
    _OtherNode(:final Node node) => _wrap(node),
    _AttributeNode() => null,
  };
  if (parent == null || self == null) {
    return const <_Node>[];
  }
  final List<Node> siblings = <Node>[
    for (final Node candidate in _childrenOf(_wrap(parent)))
      if (after ? _isAfter(candidate, node) : _isBefore(candidate, node))
        candidate,
  ];
  // 文档顺序：`following-sibling` 从近到远，`preceding-sibling` 也是从近到远（XPath 1.0 §2.2）。
  if (!after) {
    siblings.sort(
      (Node a, Node b) => _indexIn(parent, b) - _indexIn(parent, a),
    );
  }

  return <_Node>[for (final Node sibling in siblings) _wrap(sibling)];
}

bool _isAfter(Node candidate, _Node node) {
  final Node? parent = _parentOf(node);
  if (parent == null) {
    return false;
  }
  final int self = _indexIn(parent, _domNodeOf(node));

  return self >= 0 && _indexIn(parent, candidate) > self;
}

bool _isBefore(Node candidate, _Node node) {
  final Node? parent = _parentOf(node);
  if (parent == null) {
    return false;
  }
  final int self = _indexIn(parent, _domNodeOf(node));

  return self >= 0 && _indexIn(parent, candidate) < self;
}

Node _domNodeOf(_Node node) => switch (node) {
  _ElementNode(:final Element element) => element,
  _TextNode(:final Text node) => node,
  _OtherNode(:final Node node) => node,
  _AttributeNode(:final Element owner) => owner,
  _DocumentNode(:final Document node) => node,
};

int _indexIn(Node parent, Node child) =>
    <Node>[..._childrenOf(_wrap(parent))].indexOf(child);

// ─── values and expressions ──────────────────────────────────────────────────────────────────────

final class _PredicateContext {
  const _PredicateContext(this.node, this.position, this.size);

  final _Node node;
  final int position;
  final int size;
}

sealed class _Value {
  const _Value();

  bool toBoolean();

  String toText();

  double toNumber();
}

final class _ValueNumber extends _Value {
  const _ValueNumber(this.value);

  final double value;

  @override
  bool toBoolean() => value != 0 && !value.isNaN;

  @override
  String toText() =>
      value == value.truncateToDouble() ? '${value.toInt()}' : '$value';

  @override
  double toNumber() => value;
}

final class _ValueText extends _Value {
  const _ValueText(this.value);

  final String value;

  @override
  bool toBoolean() => value.isNotEmpty;

  @override
  String toText() => value;

  @override
  double toNumber() => double.tryParse(value.trim()) ?? double.nan;
}

final class _ValueBoolean extends _Value {
  const _ValueBoolean(this.value);

  final bool value;

  @override
  bool toBoolean() => value;

  @override
  String toText() => value ? 'true' : 'false';

  @override
  double toNumber() => value ? 1 : 0;
}

final class _ValueNodes extends _Value {
  const _ValueNodes(this.nodes);

  final List<_Node> nodes;

  @override
  bool toBoolean() => nodes.isNotEmpty;

  @override
  String toText() => nodes.isEmpty ? '' : nodes.first.stringValue;

  @override
  double toNumber() => double.tryParse(toText().trim()) ?? double.nan;
}

sealed class _Expression {
  const _Expression();

  _Value evaluate(_PredicateContext context);
}

final class _LiteralExpression extends _Expression {
  const _LiteralExpression(this.value);

  final _Value value;

  @override
  _Value evaluate(_PredicateContext context) => value;
}

final class _PathExpression extends _Expression {
  const _PathExpression(this.path);

  final _LocationPath path;

  @override
  _Value evaluate(_PredicateContext context) =>
      _ValueNodes(path.evaluate(context.node));
}

final class _PositionExpression extends _Expression {
  const _PositionExpression();

  @override
  _Value evaluate(_PredicateContext context) =>
      _ValueNumber(context.position.toDouble());
}

final class _SizeExpression extends _Expression {
  const _SizeExpression();

  @override
  _Value evaluate(_PredicateContext context) =>
      _ValueNumber(context.size.toDouble());
}

final class _NegateExpression extends _Expression {
  const _NegateExpression(this.operand);

  final _Expression operand;

  @override
  _Value evaluate(_PredicateContext context) =>
      _ValueNumber(-operand.evaluate(context).toNumber());
}

final class _FunctionExpression extends _Expression {
  const _FunctionExpression(this.name, this.arguments);

  final String name;
  final List<_Expression> arguments;

  @override
  _Value evaluate(_PredicateContext context) {
    switch (name) {
      case 'contains':
        return _ValueBoolean(_text(0, context).contains(_text(1, context)));
      case 'starts-with':
        return _ValueBoolean(_text(0, context).startsWith(_text(1, context)));
      case 'not':
        return _ValueBoolean(!arguments[0].evaluate(context).toBoolean());
      default:
        // 解析阶段已经挡掉未知函数：这里只可能是上面这三个之一。
        throw const _UnsupportedXPath('xpath:function');
    }
  }

  String _text(int index, _PredicateContext context) =>
      arguments[index].evaluate(context).toText();
}

final class _BinaryExpression extends _Expression {
  const _BinaryExpression(this.operator, this.left, this.right);

  final String operator;
  final _Expression left;
  final _Expression right;

  @override
  _Value evaluate(_PredicateContext context) {
    switch (operator) {
      case 'or':
        return _ValueBoolean(
          left.evaluate(context).toBoolean() ||
              right.evaluate(context).toBoolean(),
        );
      case 'and':
        return _ValueBoolean(
          left.evaluate(context).toBoolean() &&
              right.evaluate(context).toBoolean(),
        );
      case '+':
        return _ValueNumber(
          left.evaluate(context).toNumber() +
              right.evaluate(context).toNumber(),
        );
      case '-':
        return _ValueNumber(
          left.evaluate(context).toNumber() -
              right.evaluate(context).toNumber(),
        );
      case '=':
        return _ValueBoolean(
          _equals(left.evaluate(context), right.evaluate(context)),
        );
      case '!=':
        return _ValueBoolean(
          _notEquals(left.evaluate(context), right.evaluate(context)),
        );
      default:
        return _ValueBoolean(
          _order(operator, left.evaluate(context), right.evaluate(context)),
        );
    }
  }

  // XPath 1.0 §3.4：一侧是节点集时按**字符串值**逐对比较（任一对成立即成立）。
  static bool _equals(_Value left, _Value right) {
    if (left is _ValueNodes || right is _ValueNodes) {
      return _anyPair(left, right, (String a, String b) => a == b);
    }
    if (left is _ValueNumber || right is _ValueNumber) {
      return left.toNumber() == right.toNumber();
    }
    if (left is _ValueBoolean || right is _ValueBoolean) {
      return left.toBoolean() == right.toBoolean();
    }

    return left.toText() == right.toText();
  }

  static bool _notEquals(_Value left, _Value right) {
    if (left is _ValueNodes || right is _ValueNodes) {
      return _anyPair(left, right, (String a, String b) => a != b);
    }

    return !_equals(left, right);
  }

  static bool _anyPair(
    _Value left,
    _Value right,
    bool Function(String, String) test,
  ) {
    final Iterable<String> leftTexts = left is _ValueNodes
        ? left.nodes.map((_Node node) => node.stringValue)
        : <String>[left.toText()];
    final Iterable<String> rightTexts = right is _ValueNodes
        ? right.nodes.map((_Node node) => node.stringValue)
        : <String>[right.toText()];

    for (final String a in leftTexts) {
      for (final String b in rightTexts) {
        if (test(a, b)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _order(String operator, _Value left, _Value right) {
    final double a = left.toNumber();
    final double b = right.toNumber();

    return switch (operator) {
      '<' => a < b,
      '<=' => a <= b,
      '>' => a > b,
      _ => a >= b,
    };
  }
}

// ─── location paths ─────────────────────────────────────────────────────────────────────────────

final class _LocationPath {
  const _LocationPath(this.steps);

  final List<_Step> steps;

  List<_Node> evaluate(_Node root) {
    List<_Node> current = <_Node>[root];
    for (final _Step step in steps) {
      current = step.apply(current);
    }

    return current;
  }
}

// ─── parser ─────────────────────────────────────────────────────────────────────────────────────

const Map<String, _Axis> _axes = <String, _Axis>{
  'child': _Axis.child,
  'descendant': _Axis.descendant,
  'descendant-or-self': _Axis.descendantOrSelf,
  'self': _Axis.self,
  'parent': _Axis.parent,
  'following-sibling': _Axis.followingSibling,
  'preceding-sibling': _Axis.precedingSibling,
  'attribute': _Axis.attribute,
};

/// Axes upstream's lib supports and this repository names as missing.
const List<String> _rejectedAxes = <String>[
  'ancestor',
  'ancestor-or-self',
  'following',
  'preceding',
  'namespace',
];

/// The functions this repository implements, with the arity each one takes.
const Map<String, int> _supportedFunctions = <String, int>{
  'contains': 2,
  'not': 1,
  'starts-with': 2,
};

/// The node tests an expression may name (`contains(text(),…)`).
const Set<String> _nodeTests = <String>{'text', 'node', 'comment'};

final class _Parser {
  _Parser(this._source);

  final String _source;
  int _index = 0;

  /// Parses a rule: a union of location paths.
  List<_LocationPath> parseRule() {
    final List<_LocationPath> paths = <_LocationPath>[_parsePath()];
    while (true) {
      _skipWhitespace();
      if (!_peek('|')) {
        break;
      }
      _index++;
      paths.add(_parsePath());
    }
    _skipWhitespace();
    if (_index != _source.length) {
      throw const FormatException('trailing text in an XPath rule');
    }

    return paths;
  }

  _LocationPath _parsePath() {
    _skipWhitespace();
    final List<_Step> steps = <_Step>[];
    if (_peekString('//')) {
      _index += 2;
      steps.add(_Step.descendantOrSelf());
    } else if (_peekString('/')) {
      _index += 1;
    }
    steps.add(_parseStep());
    while (true) {
      _skipWhitespace();
      if (_peekString('//')) {
        _index += 2;
        steps.add(_Step.descendantOrSelf());
        steps.add(_parseStep());
      } else if (_peekString('/')) {
        _index += 1;
        steps.add(_parseStep());
      } else {
        break;
      }
    }

    return _LocationPath(steps);
  }

  _Step _parseStep() {
    _skipWhitespace();
    if (_peekString('..')) {
      _index += 2;

      return _Step.parent();
    }
    if (_peekString('.')) {
      _index += 1;

      return _Step.self();
    }
    if (_peekString('@')) {
      _index += 1;
      if (_peekString('*')) {
        throw const _UnsupportedXPath('xpath:@*');
      }
      final String name = _expectName();
      final List<_Expression> predicates = _parsePredicates();

      return _Step(
        _Axis.attribute,
        _NodeTest.attribute(name),
        predicates: predicates,
      );
    }

    final String? axisName = _peekAxisName();
    if (axisName != null) {
      final _Axis axis = _axisOf(axisName);

      return _parseNodeTest(axis);
    }

    return _parseNodeTest(_Axis.child);
  }

  String? _peekAxisName() {
    final int saved = _index;
    final String? name = _tryName();
    if (name != null && _peekString('::')) {
      _index = saved;

      return name.toLowerCase();
    }
    _index = saved;

    return null;
  }

  _Axis _axisOf(String name) {
    final _Axis? axis = _axes[name];
    if (axis == null) {
      if (_rejectedAxes.contains(name)) {
        throw _UnsupportedXPath('xpath:$name::');
      }
      throw const FormatException('unknown axis');
    }
    _index += name.length + 2;

    return axis;
  }

  _Step _parseNodeTest(_Axis axis) {
    _skipWhitespace();
    if (_peekString('*')) {
      _index += 1;
      final List<_Expression> predicates = _parsePredicates();

      return _Step(axis, _NodeTest.anyElement, predicates: predicates);
    }
    final String name = _expectName();
    _skipWhitespace();
    if (_peekString('(')) {
      _index += 1;
      _expect(')');
      final _NodeTest test = switch (name.toLowerCase()) {
        'text' => _NodeTest.text,
        'node' => throw const _UnsupportedXPath('xpath:node()'),
        'comment' => throw const _UnsupportedXPath('xpath:comment()'),
        _ => throw _UnsupportedXPath('xpath:$name()'),
      };
      final List<_Expression> predicates = _parsePredicates();

      return _Step(axis, test, predicates: predicates);
    }
    final List<_Expression> predicates = _parsePredicates();

    return _Step(axis, _NodeTest.tag(name), predicates: predicates);
  }

  List<_Expression> _parsePredicates() {
    final List<_Expression> predicates = <_Expression>[];
    while (true) {
      _skipWhitespace();
      if (!_peek('[')) {
        return predicates;
      }
      _index++;
      predicates.add(_parseOr());
      _skipWhitespace();
      _expect(']');
    }
  }

  _Expression _parseOr() {
    _Expression left = _parseAnd();
    while (_matchKeyword('or')) {
      left = _BinaryExpression('or', left, _parseAnd());
    }

    return left;
  }

  _Expression _parseAnd() {
    _Expression left = _parseComparison();
    while (_matchKeyword('and')) {
      left = _BinaryExpression('and', left, _parseComparison());
    }

    return left;
  }

  _Expression _parseComparison() {
    final _Expression left = _parseAdditive();
    _skipWhitespace();
    for (final String operator in <String>['!=', '<=', '>=', '=', '<', '>']) {
      if (_peekString(operator)) {
        _index += operator.length;

        return _BinaryExpression(operator, left, _parseAdditive());
      }
    }

    return left;
  }

  _Expression _parseAdditive() {
    _Expression left = _parseUnary();
    while (true) {
      _skipWhitespace();
      if (_peekString('+')) {
        _index++;
        left = _BinaryExpression('+', left, _parseUnary());
      } else if (_peekString('-')) {
        _index++;
        left = _BinaryExpression('-', left, _parseUnary());
      } else {
        return left;
      }
    }
  }

  _Expression _parseUnary() {
    _skipWhitespace();
    if (_peekString('-')) {
      _index++;

      return _NegateExpression(_parseUnary());
    }

    return _parsePrimary();
  }

  _Expression _parsePrimary() {
    _skipWhitespace();
    if (_peekString('(')) {
      _index++;
      final _Expression inner = _parseOr();
      _skipWhitespace();
      _expect(')');

      return inner;
    }
    final String? quote = _peekQuote();
    if (quote != null) {
      _index++;
      final int end = _source.indexOf(quote, _index);
      if (end < 0) {
        throw const FormatException('unterminated string literal');
      }
      final String value = _source.substring(_index, end);
      _index = end + 1;

      return _LiteralExpression(_ValueText(value));
    }
    if (_isDigit(_peekChar())) {
      final int start = _index;
      while (_isDigit(_peekChar()) || _peekChar() == '.') {
        _index++;
      }

      return _LiteralExpression(
        _ValueNumber(double.parse(_source.substring(start, _index))),
      );
    }

    final int saved = _index;
    final String? name = _tryName();
    if (name != null) {
      _skipWhitespace();
      if (_peekString('(')) {
        _index++;
        _skipWhitespace();
        final String lower = name.toLowerCase();
        // `text()` / `node()` 在表达式里是**节点测试**（`contains(text(),…)`），所以先让路径解析
        // 器接手；只有真正的函数名才继续往下。
        if (_nodeTests.contains(lower)) {
          _index = saved;

          return _PathExpression(_parsePath());
        }
        if (_peekString(')')) {
          _index++;
          if (lower == 'position') {
            return const _PositionExpression();
          }
          if (lower == 'last') {
            return const _SizeExpression();
          }
          throw _UnsupportedXPath('xpath:$lower()');
        }
        final int? arity = _supportedFunctions[lower];
        if (arity == null) {
          // 上游支持而本仓没有的函数在这里具名拒绝（`count()` / `normalize-space()` …）。
          throw _UnsupportedXPath('xpath:$lower()');
        }
        final List<_Expression> arguments = <_Expression>[_parseOr()];
        _skipWhitespace();
        while (_peekString(',')) {
          _index++;
          arguments.add(_parseOr());
          _skipWhitespace();
        }
        _expect(')');
        if (arguments.length != arity) {
          throw const FormatException('wrong arity');
        }

        return _FunctionExpression(lower, arguments);
      }
      // 一个名字就是相对路径的第一步：把读掉的名字还回去，交给路径解析。
      _index = saved;
    }

    return _PathExpression(_parsePath());
  }

  // ── scanner ───────────────────────────────────────────────────────────────────────────────────

  String? _peekChar() => _index < _source.length ? _source[_index] : null;

  bool _peek(String char) => _peekChar() == char;

  bool _peekString(String text) => _source.startsWith(text, _index);

  String? _peekQuote() {
    final String? char = _peekChar();

    return char == '"' || char == "'" ? char : null;
  }

  static bool _isDigit(String? char) =>
      char != null && char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39;

  static bool _isNameStart(String? char) {
    if (char == null) {
      return false;
    }
    final int code = char.codeUnitAt(0);

    return (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        char == '_' ||
        code > 0x7F;
  }

  static bool _isNamePart(String? char) {
    if (char == null) {
      return false;
    }
    final int code = char.codeUnitAt(0);

    return _isNameStart(char) ||
        (code >= 0x30 && code <= 0x39) ||
        char == '-' ||
        char == '.';
  }

  String? _tryName() {
    if (!_isNameStart(_peekChar())) {
      return null;
    }
    final int start = _index;
    while (_isNamePart(_peekChar())) {
      _index++;
    }

    return _source.substring(start, _index);
  }

  String _expectName() {
    final String? name = _tryName();
    if (name == null) {
      throw const FormatException('a node test was expected');
    }
    if (_peekString(':')) {
      throw const _UnsupportedXPath('xpath:namespace');
    }

    return name;
  }

  bool _matchKeyword(String keyword) {
    _skipWhitespace();
    if (!_source.startsWith(keyword, _index)) {
      return false;
    }
    final String? next = _index + keyword.length < _source.length
        ? _source[_index + keyword.length]
        : null;
    // `order` 不该被当成 `or` + `der`：关键字后面必须是边界。
    if (next != null && _isNamePart(next)) {
      return false;
    }
    _index += keyword.length;

    return true;
  }

  void _expect(String char) {
    _skipWhitespace();
    if (!_peek(char)) {
      throw FormatException('"$char" was expected');
    }
    _index++;
  }

  void _skipWhitespace() {
    while (_index < _source.length && _source[_index].trim().isEmpty) {
      _index++;
    }
  }
}
