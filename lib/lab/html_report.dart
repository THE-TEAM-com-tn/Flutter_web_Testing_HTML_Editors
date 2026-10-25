import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// How one tag (or attribute) count changed between the input and the output HTML.
class TagChange {
  const TagChange(this.name, this.input, this.output);

  /// A tag name (`iframe`) or an attribute in brackets (`[style]`).
  final String name;
  final int input;
  final int output;

  bool get lost => output < input;
  bool get added => output > input;
}

/// Compares the HTML an editor was given with the HTML it gave back.
class HtmlReport {
  HtmlReport._(this.changes, this.inputWords, this.keptWords);

  /// Builds the report for one round trip.
  factory HtmlReport.compare(String input, String output) {
    final Map<String, int> before = countMarkup(input);
    final Map<String, int> after = countMarkup(output);
    final List<String> names = {...before.keys, ...after.keys}.toList()..sort();
    final List<TagChange> changes = [for (final String n in names) TagChange(n, before[n] ?? 0, after[n] ?? 0)];

    final List<String> wordsIn = _words(input);
    final Map<String, int> pool = {};
    for (final String w in _words(output)) {
      pool[w] = (pool[w] ?? 0) + 1;
    }
    int kept = 0;
    for (final String w in wordsIn) {
      final int left = pool[w] ?? 0;
      if (left > 0) {
        kept++;
        pool[w] = left - 1;
      }
    }
    return HtmlReport._(changes, wordsIn.length, kept);
  }

  /// Attributes worth tracking: they carry the LMS's formatting and media.
  static const List<String> trackedAttributes = ['style', 'class', 'dir', 'href', 'src', 'colspan', 'target'];

  /// Tags that mean the same thing, counted under one name, so that an editor writing
  /// `<strong>` for `<b>` is not reported as losing `<b>`.
  static const Map<String, String> synonyms = {
    'b': 'b|strong',
    'strong': 'b|strong',
    'i': 'i|em',
    'em': 'i|em',
    's': 's|strike|del',
    'strike': 's|strike|del',
    'del': 's|strike|del',
  };

  /// Every tag and tracked attribute in [html], with how many times it appears.
  static Map<String, int> countMarkup(String html) {
    final Map<String, int> counts = {};
    void visit(dom.Node node) {
      if (node is dom.Element) {
        final String tag = node.localName ?? '?';
        final String name = synonyms[tag] ?? tag;
        counts[name] = (counts[name] ?? 0) + 1;
        for (final String attribute in trackedAttributes) {
          if (node.attributes.containsKey(attribute)) {
            counts['[$attribute]'] = (counts['[$attribute]'] ?? 0) + 1;
          }
        }
      }
      node.nodes.forEach(visit);
    }

    html_parser.parseFragment(html).nodes.forEach(visit);
    return counts;
  }

  /// The words of [html], each text node read on its own: `.text` would glue
  /// `</h2><p>Next` into one word when an editor writes blocks without a newline.
  static List<String> _words(String html) {
    final List<String> words = [];
    void visit(dom.Node node) {
      if (node is dom.Text) {
        words.addAll(node.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty));
      }
      node.nodes.forEach(visit);
    }

    html_parser.parseFragment(html).nodes.forEach(visit);
    return words;
  }

  final List<TagChange> changes;
  final int inputWords;
  final int keptWords;

  List<TagChange> get lost => changes.where((c) => c.lost).toList();
  List<TagChange> get added => changes.where((c) => c.added).toList();

  /// Share of the input's words found again in the output (1.0 when the input is empty).
  double get textKept => inputWords == 0 ? 1 : keptWords / inputWords;

  /// One line for a table cell: "kept everything" or the lost tags and attributes.
  String get summary {
    final List<TagChange> lostTags = lost;
    if (lostTags.isEmpty) return 'Kept every tag';
    return 'Lost ${lostTags.map((c) => '${c.name}×${c.input - c.output}').join(', ')}';
  }
}

/// A light pretty-printer: one block element per line, indented, inline content untouched.
String prettyHtml(String html) {
  const Set<String> blocks = {
    'address', 'article', 'aside', 'blockquote', 'body', 'dd', 'details', 'div', 'dl', 'dt', 'figcaption', //
    'figure', 'footer', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'hr', 'li', 'main', 'nav', 'ol',
    'p', 'pre', 'section', 'table', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr', 'ul', 'colgroup', 'col',
  };
  final StringBuffer out = StringBuffer();

  bool hasBlockChild(dom.Element e) => e.children.any((c) => blocks.contains(c.localName));

  void write(dom.Node node, int depth) {
    final String pad = '  ' * depth;
    if (node is dom.Element && blocks.contains(node.localName) && node.localName != 'pre' && hasBlockChild(node)) {
      final String outer = node.outerHtml;
      final String open = outer.substring(0, outer.indexOf('>') + 1);
      out.writeln('$pad$open');
      for (final dom.Node child in node.nodes) {
        write(child, depth + 1);
      }
      out.writeln('$pad</${node.localName}>');
    } else if (node is dom.Element) {
      out.writeln('$pad${node.outerHtml}');
    } else if (node is dom.Text) {
      final String text = node.text.trim();
      if (text.isNotEmpty) out.writeln('$pad$text');
    } else if (node is dom.Comment) {
      out.writeln('$pad<!--${node.data}-->');
    }
  }

  for (final dom.Node node in html_parser.parseFragment(html).nodes) {
    write(node, 0);
  }
  return out.toString().trimRight();
}
