// An HTML <-> Quill codec that keeps iframes, tables, video and any tag Quill has no tool for.
//
import 'dart:convert' show HtmlEscape, HtmlEscapeMode;

import 'package:flutter_quill/flutter_quill.dart' show BlockEmbed, CustomBlockEmbed;
import 'package:flutter_quill/quill_delta.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Custom Quill embed types used by the codec.
///
/// Each one stores the element's original HTML as its data, so what the editor
/// cannot edit as rich text still goes back to the backend unchanged.
abstract final class HtmlEmbedType {
  /// An `<iframe>`: uploaded PDFs, Google Calendar, YouTube, any embed code.
  static const String iframe = 'iframe';

  /// A `<table>`, edited with the table dialog when it is a simple grid.
  static const String table = 'table';

  /// Any other HTML the editor has no tool for (`<video>`, `<audio>`, `<hr>`, `<svg>`,
  /// `<form>`, `<script>`, `<style>`…), kept as written.
  static const String html = 'html';

  static const List<String> all = [iframe, table, html];
}

/// Converts saved HTML to a Quill [Delta] and back.
///
/// Both directions are written here, for the HTML these editors produce (the old
/// Summernote editor's output and this codec's own), so a document survives any number
/// of round trips. The HTML → Delta converter shipped with `flutter_quill`
/// (`flutter_quill_delta_from_html`) is not used: it joins consecutive `<p>` into one
/// line and drops iframes and tables.
///
/// Elements the editor has no rich-text tool for (iframes, tables and the tags in
/// [HtmlEmbedType.html]) become block embeds holding their original HTML
/// (`{"iframe": "<iframe …>"}`), each on a line of its own, and are written back
/// verbatim. They are plain embed types rather than Quill's `custom` wrapper: the
/// editor rebuilds a `custom` embed as a detached node, so its card could not find its
/// own position to edit or remove it.
abstract final class HtmlQuillCodec {
  /// Elements kept verbatim as embeds, with the embed type they become.
  static const Map<String, String> rawElements = {
    'iframe': HtmlEmbedType.iframe,
    'table': HtmlEmbedType.table,
    'video': HtmlEmbedType.html,
    'audio': HtmlEmbedType.html,
    'object': HtmlEmbedType.html,
    'embed': HtmlEmbedType.html,
    'svg': HtmlEmbedType.html,
    'canvas': HtmlEmbedType.html,
    'form': HtmlEmbedType.html,
    'button': HtmlEmbedType.html,
    'select': HtmlEmbedType.html,
    'textarea': HtmlEmbedType.html,
    'script': HtmlEmbedType.html,
    'style': HtmlEmbedType.html,
    'math': HtmlEmbedType.html,
    'details': HtmlEmbedType.html,
    'hr': HtmlEmbedType.html,
  };

  /// Line-level Quill attributes (the rest are inline).
  static const Set<String> _blockKeys = {'header', 'list', 'blockquote', 'code-block', 'align', 'direction', 'indent'};

  /// The insert value of an embed of [type] holding [html].
  static Map<String, dynamic> embedInsert(String type, String html) => BlockEmbed(type, html).toJson();

  /// The `(type, html)` of one of these embeds (or of a Quill `custom` embed holding
  /// one), or `null`.
  static (String, String)? readEmbed(Object? data) {
    if (data is! Map || data.length != 1) return null;
    final Object? key = data.keys.first;
    final Object? value = data.values.first;
    if (HtmlEmbedType.all.contains(key) && value is String) return (key as String, value);
    if (key == BlockEmbed.customType && value is String) {
      try {
        final CustomBlockEmbed embed = CustomBlockEmbed.fromJsonString(value);
        if (embed.data is String) return (embed.type, embed.data as String);
      } catch (_) {}
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // HTML → Delta
  // ---------------------------------------------------------------------------

  /// The document for [source]. Never throws: HTML that cannot be read is kept whole
  /// as one [HtmlEmbedType.html] block, so nothing is lost.
  static Delta htmlToDelta(String? source) {
    final String html = (source ?? '').trim();
    if (html.isEmpty) return Delta()..insert('\n');
    try {
      final dom.DocumentFragment fragment = html_parser.parseFragment(html, container: 'div');
      final _HtmlReader reader = _HtmlReader();
      for (final node in fragment.nodes) {
        reader.visit(node, const {}, const {}, 0);
      }
      return reader.finish();
    } catch (_) {
      return Delta()
        ..insert(embedInsert(HtmlEmbedType.html, html))
        ..insert('\n');
    }
  }

  // ---------------------------------------------------------------------------
  // Delta → HTML
  // ---------------------------------------------------------------------------

  /// The HTML for [delta]; an empty document gives an empty string.
  static String deltaToHtml(Delta delta) {
    final List<_Line> lines = _splitLines(delta);
    // Blank lines at the end are noise (the editor always keeps one).
    while (lines.isNotEmpty && lines.last.isEmpty && lines.last.attrs.isEmpty) {
      lines.removeLast();
    }
    if (lines.isEmpty) return '';

    final StringBuffer out = StringBuffer();
    int i = 0;
    while (i < lines.length) {
      final _Line line = lines[i];
      if (line.attrs['list'] != null) {
        i = _writeList(lines, i, out);
      } else if (line.attrs['code-block'] != null) {
        final List<String> code = [];
        while (i < lines.length && lines[i].attrs['code-block'] != null) {
          code.add(_escape(lines[i].plainText));
          i++;
        }
        out.write('<pre>${code.join('\n')}</pre>');
      } else {
        out.write(_blockLine(line));
        i++;
      }
    }
    return out.toString();
  }

  static List<_Line> _splitLines(Delta delta) {
    final List<_Line> lines = [];
    List<Operation> current = [];
    for (final Operation op in delta.toList()) {
      final Object? data = op.data;
      if (data is String) {
        final List<String> parts = data.split('\n');
        for (int p = 0; p < parts.length; p++) {
          if (parts[p].isNotEmpty) current.add(Operation.insert(parts[p], op.attributes));
          if (p < parts.length - 1) {
            final Map<String, dynamic> attrs = {
              for (final e in (op.attributes ?? const <String, dynamic>{}).entries)
                if (_blockKeys.contains(e.key) && e.value != null) e.key: e.value,
            };
            lines.add(_Line(current, attrs));
            current = [];
          }
        }
      } else if (data != null) {
        current.add(op);
      }
    }
    if (current.isNotEmpty) lines.add(_Line(current, const {}));
    return lines;
  }

  /// A paragraph, heading, blockquote line or a lone raw embed.
  static String _blockLine(_Line line) {
    if (line.ops.length == 1) {
      final (String, String)? embed = readEmbed(line.ops.single.data);
      if (embed != null) return embed.$2;
    }
    final Map<String, dynamic> a = line.attrs;
    final int? header = _asInt(a['header']);
    final String tag = a['blockquote'] != null
        ? 'blockquote'
        : (header != null && header >= 1 && header <= 6)
            ? 'h$header'
            : 'p';
    final String content = line.isEmpty ? '<br>' : _inline(line.ops);
    return '<$tag${_lineAttributes(a)}>$content</$tag>';
  }

  /// `style` / `dir` for a line: alignment, indent and direction.
  static String _lineAttributes(Map<String, dynamic> a, {bool includeIndent = true}) {
    final List<String> style = [];
    final Object? align = a['align'];
    if (align is String && align != 'left') style.add('text-align: $align;');
    final int? indent = _asInt(a['indent']);
    if (includeIndent && indent != null && indent > 0) style.add('padding-left: ${indent * 2}em;');
    final StringBuffer attrs = StringBuffer();
    if (style.isNotEmpty) attrs.write(' style="${style.join(' ')}"');
    if (a['direction'] == 'rtl') attrs.write(' dir="rtl"');
    return attrs.toString();
  }

  /// Writes the list starting at [start] (nesting levels come from `indent`) and
  /// returns the index of the first line after it.
  static int _writeList(List<_Line> lines, int start, StringBuffer out) {
    final int level = _asInt(lines[start].attrs['indent']) ?? 0;
    int i = start;
    String? openTag;
    bool openIsCheck = false;
    bool liOpen = false;

    void closeList() {
      if (liOpen) out.write('</li>');
      liOpen = false;
      if (openTag != null) out.write('</$openTag>');
      openTag = null;
    }

    while (i < lines.length) {
      final _Line line = lines[i];
      final Object? list = line.attrs['list'];
      if (list is! String) break;
      final int indent = _asInt(line.attrs['indent']) ?? 0;
      if (indent < level) break;
      if (indent > level) {
        // A deeper level goes inside the open item.
        if (openTag == null) {
          out.write('<ul>');
          openTag = 'ul';
        }
        if (!liOpen) {
          out.write('<li>');
          liOpen = true;
        }
        i = _writeList(lines, i, out);
        continue;
      }

      final String tag = list == 'ordered' ? 'ol' : 'ul';
      final bool isCheck = list == 'checked' || list == 'unchecked';
      if (openTag != tag || openIsCheck != isCheck) {
        closeList();
        out.write(isCheck ? '<$tag data-checked="true">' : '<$tag>');
        openTag = tag;
        openIsCheck = isCheck;
      } else if (liOpen) {
        out.write('</li>');
      }
      final String checkedAttr = isCheck ? ' data-checked="${list == 'checked'}"' : '';
      out.write('<li$checkedAttr${_lineAttributes(line.attrs, includeIndent: false)}>');
      out.write(line.isEmpty ? '<br>' : _inline(line.ops));
      liOpen = true;
      i++;
    }
    closeList();
    return i;
  }

  static String _inline(List<Operation> ops) {
    final StringBuffer out = StringBuffer();
    for (final Operation op in ops) {
      final Object? data = op.data;
      if (data is String) {
        out.write(_wrapInline(_escape(data), op.attributes ?? const {}));
      } else if (data is Map) {
        out.write(_embedHtml(data, op.attributes ?? const {}));
      }
    }
    return out.toString();
  }

  static String _wrapInline(String text, Map<String, dynamic> a) {
    String html = text;
    if (a['code'] == true) html = '<code>$html</code>';
    if (a['script'] == 'sub') html = '<sub>$html</sub>';
    if (a['script'] == 'super') html = '<sup>$html</sup>';
    if (a['strike'] == true) html = '<s>$html</s>';
    if (a['underline'] == true) html = '<u>$html</u>';
    if (a['italic'] == true) html = '<em>$html</em>';
    if (a['bold'] == true) html = '<strong>$html</strong>';

    final List<String> style = [];
    final Object? font = a['font'];
    if (font is String && font.isNotEmpty) style.add('font-family: ${_escapeAttr(font)};');
    final String? size = _cssFontSize(a['size']);
    if (size != null) style.add('font-size: $size;');
    final String? color = _cssColor(a['color']);
    if (color != null) style.add('color: $color;');
    final String? background = _cssColor(a['background']);
    if (background != null) style.add('background-color: $background;');
    if (style.isNotEmpty) html = '<span style="${style.join(' ')}">$html</span>';

    final Object? link = a['link'];
    if (link is String && link.isNotEmpty) {
      html = '<a href="${_escapeAttr(link)}" target="_blank" rel="noopener noreferrer">$html</a>';
    }
    return html;
  }

  static String _embedHtml(Map data, Map<String, dynamic> attributes) {
    if (data['image'] is String) {
      final Object? style = attributes['style'];
      final String styleAttr = style is String && style.isNotEmpty ? ' style="${_escapeAttr(style)}"' : '';
      return '<img src="${_escapeAttr(data['image'] as String)}" alt=""$styleAttr/>';
    }
    if (data['video'] is String) {
      return '<video src="${_escapeAttr(data['video'] as String)}" controls style="max-width: 100%;"></video>';
    }
    return readEmbed(data)?.$2 ?? '';
  }

  /// Quill sizes: `small` / `large` / `huge` or a number of pixels.
  static String? _cssFontSize(Object? size) {
    if (size == null) return null;
    final String value = size.toString().trim();
    switch (value) {
      case '':
      case '0':
        return null;
      case 'small':
        return '0.75em';
      case 'large':
        return '1.5em';
      case 'huge':
        return '2.5em';
    }
    final double? px = double.tryParse(value);
    if (px == null || px <= 0) return null;
    return '${px == px.roundToDouble() ? px.round() : px}px';
  }

  /// Quill colors are `#AARRGGBB` (the color picker writes that); CSS reads 8 hex
  /// digits as `#RRGGBBAA`, so convert.
  static String? _cssColor(Object? color) {
    if (color is! String || color.trim().isEmpty) return null;
    final String value = color.trim();
    final Match? m = RegExp(r'^#([0-9a-fA-F]{2})([0-9a-fA-F]{6})$').firstMatch(value);
    if (m == null) return _escapeAttr(value);
    final int alpha = int.parse(m.group(1)!, radix: 16);
    final String rgb = m.group(2)!.toUpperCase();
    if (alpha == 0xFF) return '#$rgb';
    final int r = int.parse(rgb.substring(0, 2), radix: 16);
    final int g = int.parse(rgb.substring(2, 4), radix: 16);
    final int b = int.parse(rgb.substring(4, 6), radix: 16);
    return 'rgba($r, $g, $b, ${(alpha / 255).toStringAsFixed(2)})';
  }

  static const HtmlEscape _textEscape = HtmlEscape(HtmlEscapeMode.element);
  static const HtmlEscape _attrEscape = HtmlEscape(HtmlEscapeMode.attribute);
  static String _escape(String text) => _textEscape.convert(text);
  static String _escapeAttr(String text) => _attrEscape.convert(text);
}

int? _asInt(Object? value) => value is int ? value : int.tryParse('${value ?? ''}');

/// One document line: its inline operations and its line attributes.
class _Line {
  _Line(this.ops, this.attrs);

  final List<Operation> ops;
  final Map<String, dynamic> attrs;

  bool get isEmpty => ops.isEmpty;

  String get plainText => ops.map((o) => o.data is String ? o.data as String : '').join();
}

/// Walks the parsed HTML and writes the Delta, one line per block.
class _HtmlReader {
  final Delta _out = Delta();

  /// Whether text or an embed was written since the last newline.
  bool _lineOpen = false;

  static const Set<String> _blockTags = {
    'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'blockquote', 'pre', 'ul', 'ol', 'dl', 'dd', 'dt', //
    'section', 'article', 'header', 'footer', 'main', 'aside', 'nav', 'figure', 'figcaption', 'address', 'center',
  };
  static const Set<String> _skippedTags = {'head', 'meta', 'title', 'link', 'base', 'noscript', 'template'};
  static final RegExp _spaces = RegExp(r'[ \t\r\n\f]+');

  Delta finish() {
    if (_lineOpen) _newline(const {});
    if (_out.isEmpty) _out.insert('\n');
    return _out;
  }

  void _newline(Map<String, dynamic> line) {
    _out.insert('\n', line.isEmpty ? null : Map<String, dynamic>.from(line));
    _lineOpen = false;
  }

  void _text(String text, Map<String, dynamic> inline) {
    if (text.isEmpty) return;
    _out.insert(text, inline.isEmpty ? null : Map<String, dynamic>.from(inline));
    _lineOpen = true;
  }

  /// [inline] are the text attributes in effect, [line] the attributes of the line
  /// being written, [listLevel] the depth of `<ul>` / `<ol>` nesting.
  void visit(dom.Node node, Map<String, dynamic> inline, Map<String, dynamic> line, int listLevel, {bool inPre = false}) {
    if (node is dom.Text) {
      _visitText(node.text, inline, line, inPre);
      return;
    }
    if (node is! dom.Element) return; // comments, doctype
    final String tag = node.localName ?? '';
    if (_skippedTags.contains(tag)) return;

    final String? rawType = HtmlQuillCodec.rawElements[tag];
    if (rawType != null) {
      // On a line of its own.
      if (_lineOpen) _newline(line);
      _out.insert(HtmlQuillCodec.embedInsert(rawType, node.outerHtml));
      _lineOpen = true;
      _newline(line);
      return;
    }

    switch (tag) {
      case 'br':
        _newline(line);
        return;
      case 'img':
        final String src = node.attributes['src']?.trim() ?? '';
        if (src.isEmpty) return;
        final String? style = _imageStyle(node);
        _out.insert({'image': src}, style == null ? null : {'style': style});
        _lineOpen = true;
        return;
      case 'input':
        return; // Check-list boxes: the state is read from the <li>.
    }

    final Map<String, dynamic> childInline = _inlineAttributes(node, inline);

    if (!_blockTags.contains(tag)) {
      for (final child in node.nodes) {
        visit(child, childInline, line, listLevel, inPre: inPre);
      }
      return;
    }

    // A block: text written before it ends its own line.
    if (_lineOpen) _newline(line);

    int childLevel = listLevel;
    final Map<String, dynamic> blockLine = Map<String, dynamic>.from(line);
    switch (tag) {
      case 'ul':
      case 'ol':
        childLevel = listLevel + 1;
        break;
      case 'li':
        blockLine['list'] = _listType(node);
        if (listLevel > 1) {
          blockLine['indent'] = listLevel - 1;
        } else {
          blockLine.remove('indent');
        }
        break;
      case 'blockquote':
        blockLine['blockquote'] = true;
        break;
      case 'pre':
        blockLine['code-block'] = true;
        break;
      default:
        final Match? h = RegExp(r'^h([1-6])$').firstMatch(tag);
        if (h != null) blockLine['header'] = int.parse(h.group(1)!);
    }
    _lineStyle(node, blockLine, isListItem: tag == 'li');

    final bool pre = inPre || tag == 'pre';
    for (final child in node.nodes) {
      visit(child, childInline, blockLine, childLevel, inPre: pre);
    }
    if (_lineOpen) _newline(blockLine);
  }

  void _visitText(String raw, Map<String, dynamic> inline, Map<String, dynamic> line, bool inPre) {
    if (inPre) {
      final List<String> parts = raw.split('\n');
      for (int i = 0; i < parts.length; i++) {
        _text(parts[i], inline);
        if (i < parts.length - 1) _newline(line);
      }
      return;
    }
    String text = raw.replaceAll(_spaces, ' ');
    if (!_lineOpen) text = text.trimLeft();
    _text(text, inline);
  }

  String _listType(dom.Element li) {
    final dom.Element? parent = li.parent;
    final String? checked = li.attributes['data-checked'] ?? parent?.attributes['data-checked'];
    final dom.Element? box = li.querySelector('input[type="checkbox"]');
    if (box != null) return box.attributes.containsKey('checked') ? 'checked' : 'unchecked';
    if (li.attributes.containsKey('data-checked')) return checked == 'true' ? 'checked' : 'unchecked';
    if (parent?.localName == 'ol') return 'ordered';
    return 'bullet';
  }

  /// Alignment, direction and (outside lists) indentation of a block.
  void _lineStyle(dom.Element node, Map<String, dynamic> line, {required bool isListItem}) {
    final Map<String, String> style = _parseStyle(node.attributes['style']);
    final String? align = (style['text-align'] ?? node.attributes['align'])?.toLowerCase();
    if (align == 'center' || align == 'right' || align == 'justify') {
      line['align'] = align;
    } else if (align == 'left') {
      line.remove('align');
    }
    final String? dir = (node.attributes['dir'] ?? style['direction'])?.toLowerCase();
    if (dir == 'rtl') {
      line['direction'] = 'rtl';
    } else if (dir == 'ltr') {
      line.remove('direction');
    }
    if (!isListItem) {
      final String? pad = style['padding-left'] ?? style['margin-left'] ?? style['padding-inline-start'] ?? style['margin-inline-start'];
      final int? indent = _indentLevel(pad);
      if (indent != null) line['indent'] = indent;
    }
  }

  /// One Quill indent level per 2em (32px) — what [HtmlQuillCodec] writes.
  int? _indentLevel(String? value) {
    if (value == null) return null;
    final double? px = _toPx(value);
    if (px == null || px <= 0) return null;
    return (px / 32).round().clamp(1, 8);
  }

  Map<String, dynamic> _inlineAttributes(dom.Element node, Map<String, dynamic> inherited) {
    final Map<String, dynamic> a = Map<String, dynamic>.from(inherited);
    switch (node.localName) {
      case 'b':
      case 'strong':
        a['bold'] = true;
        break;
      case 'i':
      case 'em':
      case 'cite':
        a['italic'] = true;
        break;
      case 'u':
      case 'ins':
        a['underline'] = true;
        break;
      case 's':
      case 'strike':
      case 'del':
        a['strike'] = true;
        break;
      case 'sub':
        a['script'] = 'sub';
        break;
      case 'sup':
        a['script'] = 'super';
        break;
      case 'code':
        if (node.parent?.localName != 'pre') a['code'] = true;
        break;
      case 'a':
        final String? href = node.attributes['href']?.trim();
        if (href != null && href.isNotEmpty) a['link'] = href;
        break;
      case 'font':
        const Map<String, String> sizes = {'1': '10', '2': '13', '3': '16', '4': '18', '5': '24', '6': '32', '7': '48'};
        final String? color = _quillColor(node.attributes['color']);
        if (color != null) a['color'] = color;
        final String? face = node.attributes['face']?.trim();
        if (face != null && face.isNotEmpty) a['font'] = _fontFamily(face);
        final String? size = sizes[node.attributes['size']?.trim()];
        if (size != null) a['size'] = size;
        break;
    }

    final Map<String, String> style = _parseStyle(node.attributes['style']);
    if (style.isEmpty) return a;
    final String? weight = style['font-weight'];
    if (weight != null) {
      final int? w = int.tryParse(weight);
      if (weight == 'bold' || weight == 'bolder' || (w != null && w >= 600)) a['bold'] = true;
      if (weight == 'normal' || (w != null && w < 600)) a.remove('bold');
    }
    if (style['font-style'] == 'italic') a['italic'] = true;
    final String decoration = '${style['text-decoration'] ?? ''} ${style['text-decoration-line'] ?? ''}';
    if (decoration.contains('underline')) a['underline'] = true;
    if (decoration.contains('line-through')) a['strike'] = true;
    final String? color = _quillColor(style['color']);
    if (color != null) a['color'] = color;
    final String? background = _quillColor(style['background-color'] ?? style['background']);
    if (background != null) a['background'] = background;
    final String? family = style['font-family'];
    if (family != null && family.isNotEmpty) a['font'] = _fontFamily(family);
    final String? size = _quillSize(style['font-size']);
    if (size != null) a['size'] = size;
    return a;
  }

  String? _imageStyle(dom.Element img) {
    final Map<String, String> style = _parseStyle(img.attributes['style']);
    final List<String> parts = [];
    final String? width = style['width'] ?? _pxAttr(img.attributes['width']);
    final String? height = style['height'] ?? _pxAttr(img.attributes['height']);
    if (width != null) parts.add('width: $width');
    if (height != null) parts.add('height: $height');
    for (final key in ['max-width', 'float', 'margin']) {
      if (style[key] != null) parts.add('$key: ${style[key]}');
    }
    return parts.isEmpty ? null : parts.join('; ');
  }

  String? _pxAttr(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final String v = value.trim();
    return double.tryParse(v) != null ? '${v}px' : v;
  }

  static Map<String, String> _parseStyle(String? style) {
    final Map<String, String> out = {};
    if (style == null || style.trim().isEmpty) return out;
    for (final String declaration in style.split(';')) {
      final int colon = declaration.indexOf(':');
      if (colon <= 0) continue;
      final String key = declaration.substring(0, colon).trim().toLowerCase();
      String value = declaration.substring(colon + 1).trim();
      value = value.replaceAll(RegExp(r'\s*!important$'), '');
      if (key.isNotEmpty && value.isNotEmpty) out[key] = value;
    }
    return out;
  }

  static String _fontFamily(String value) => value.replaceAll('"', '').replaceAll("'", '').trim();

  /// `0.75em` / `1.5em` / `2.5em` are the named Quill sizes ([HtmlQuillCodec] writes
  /// them); other lengths become a number of pixels.
  static String? _quillSize(String? value) {
    if (value == null) return null;
    final String v = value.trim().toLowerCase();
    switch (v) {
      case '0.75em':
      case 'small':
      case 'x-small':
        return 'small';
      case '1.5em':
      case 'large':
      case 'x-large':
        return 'large';
      case '2.5em':
      case 'xx-large':
        return 'huge';
    }
    final double? px = _toPx(v);
    if (px == null || px <= 0) return null;
    return '${px.round()}';
  }

  static double? _toPx(String value) {
    final Match? m = RegExp(r'^(-?[0-9]*\.?[0-9]+)\s*(px|pt|em|rem)?$').firstMatch(value.trim().toLowerCase());
    if (m == null) return null;
    final double n = double.parse(m.group(1)!);
    switch (m.group(2)) {
      case 'pt':
        return n * 4 / 3;
      case 'em':
      case 'rem':
        return n * 16;
      default:
        return n;
    }
  }

  /// A CSS color as Quill's `#AARRGGBB`, or `null` when it can't be read.
  static String? _quillColor(String? value) {
    if (value == null) return null;
    final String v = value.trim().toLowerCase();
    if (v.isEmpty || v == 'transparent' || v == 'inherit' || v == 'initial' || v == 'currentcolor') return null;

    int? r, g, b;
    double alpha = 1;
    final Match? hex = RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$').firstMatch(v);
    final Match? fn = RegExp(r'^rgba?\(\s*([0-9.]+)[\s,]+([0-9.]+)[\s,]+([0-9.]+)(?:[\s,/]+([0-9.]+%?))?\s*\)$').firstMatch(v);
    if (hex != null) {
      String h = hex.group(1)!;
      if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
      r = int.parse(h.substring(0, 2), radix: 16);
      g = int.parse(h.substring(2, 4), radix: 16);
      b = int.parse(h.substring(4, 6), radix: 16);
      if (h.length == 8) alpha = int.parse(h.substring(6, 8), radix: 16) / 255;
    } else if (fn != null) {
      r = double.parse(fn.group(1)!).round();
      g = double.parse(fn.group(2)!).round();
      b = double.parse(fn.group(3)!).round();
      final String? a = fn.group(4);
      if (a != null) {
        alpha = a.endsWith('%') ? double.parse(a.substring(0, a.length - 1)) / 100 : double.parse(a);
      }
    } else {
      final String? named = _namedColors[v];
      if (named == null) return null;
      return named;
    }
    String two(int x) => x.clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${two((alpha.clamp(0, 1) * 255).round())}${two(r)}${two(g)}${two(b)}'.toUpperCase();
  }

  static const Map<String, String> _namedColors = {
    'black': '#FF000000',
    'white': '#FFFFFFFF',
    'red': '#FFFF0000',
    'green': '#FF008000',
    'blue': '#FF0000FF',
    'yellow': '#FFFFFF00',
    'orange': '#FFFFA500',
    'purple': '#FF800080',
    'gray': '#FF808080',
    'grey': '#FF808080',
    'silver': '#FFC0C0C0',
    'maroon': '#FF800000',
    'navy': '#FF000080',
    'teal': '#FF008080',
    'olive': '#FF808000',
    'lime': '#FF00FF00',
    'aqua': '#FF00FFFF',
    'cyan': '#FF00FFFF',
    'fuchsia': '#FFFF00FF',
    'magenta': '#FFFF00FF',
    'pink': '#FFFFC0CB',
    'brown': '#FFA52A2A',
  };
}
