import 'package:lms_testing_html_editors/editors/js/js_frame_editor.dart';
import 'package:lms_testing_html_editors/editors/quill_lab_editor.dart';
import 'package:lms_testing_html_editors/editors/summernote_lab_editors.dart';
import 'package:lms_testing_html_editors/lab/lab_editor.dart';

/// How an editor is built, which decides where it runs and how it handles HTML.
enum EditorFamily {
  flutter(
    'Drawn by Flutter',
    'Pure Dart editors painted by Flutter (CanvasKit on web). Same code on web, Android, iOS and desktop. '
        'They keep their own document model, so HTML goes through a converter. Only the custom codec used here '
        'keeps iframes and video; the others were removed after losing them.',
  ),
  summernote(
    'Summernote in a web view',
    'Dart packages that embed the Summernote JavaScript editor: an iframe on web, a WebView on Android/iOS. '
        'The browser edits real HTML.',
  ),
  javascript(
    'Browser JavaScript editors (web only)',
    'No Dart package at all: the editor is loaded from jsDelivr into an iframe (web/editors/*.html) and talks to '
        'Flutter through postMessage. Real HTML in and out; on mobile they would need a WebView.',
  );

  const EditorFamily(this.title, this.description);

  final String title;
  final String description;
}

/// Release activity, as checked on pub.dev / npm / GitHub on 25 Oct 2026.
enum Health {
  active('Active'),
  slow('Slow releases'),
  stale('Stale');

  const Health(this.label);

  final String label;
}

/// One editor in the lab, with what was found about it.
class EditorInfo {
  const EditorInfo({
    required this.id,
    required this.name,
    required this.family,
    required this.package,
    required this.released,
    required this.license,
    required this.platforms,
    required this.htmlModel,
    required this.popularity,
    required this.health,
    required this.summary,
    required this.pros,
    required this.cons,
    required this.link,
    required this.builder,
    this.tip,
  });

  final String id;
  final String name;
  final EditorFamily family;

  /// Package (or npm module) and version tested.
  final String package;

  /// Date of that version.
  final String released;
  final String license;
  final String platforms;

  /// How HTML gets in and out.
  final String htmlModel;
  final String popularity;
  final Health health;
  final String summary;
  final List<String> pros;
  final List<String> cons;
  final String link;

  /// A usage hint shown above the editor.
  final String? tip;
  final LabEditorBuilder builder;
}

LabEditorBuilder _js(String page, String label) => (context, html, handle) =>
    JsFrameEditor(page: page, label: label, initialHtml: html, handle: handle);

/// Every editor in the lab. Versions, dates and counts were checked on 25 Oct 2026.
final List<EditorInfo> editorCatalog = [
  // ---------------------------------------------------------------------------
  // Drawn by Flutter
  // ---------------------------------------------------------------------------
  EditorInfo(
    id: 'flutter-quill',
    name: 'flutter_quill + HTML codec',
    family: EditorFamily.flutter,
    package: 'flutter_quill 11.6.0',
    released: '16 Sep 2026',
    license: 'MIT',
    platforms: 'Web · Android · iOS · desktop',
    htmlModel: 'Converted by a custom codec (lib/editors/html_quill_codec.dart)',
    popularity: '2.2k likes · 310k downloads/month',
    health: Health.active,
    summary: 'The most used Flutter editor, with a custom HTML codec. Iframes, tables and other HTML the editor has '
        'no tool for become cards that are saved back unchanged.',
    pros: [
      'Keeps iframes, tables, video and unknown tags verbatim',
      'Reads the old Summernote HTML',
      'flutter_quill is the most used Flutter editor, released often',
    ],
    cons: [
      'A 729-line codec the team has to maintain',
      'Tables and embeds are cards, not edited in place (you would add your own dialogs)',
    ],
    link: 'https://pub.dev/packages/flutter_quill',
    builder: (context, html, handle) =>
        QuillLabEditor(initialHtml: html, handle: handle),
  ),

  // ---------------------------------------------------------------------------
  // Summernote in a web view
  // ---------------------------------------------------------------------------
  EditorInfo(
    id: 'html-editor-enhanced',
    name: 'html_editor_enhanced',
    family: EditorFamily.summernote,
    package: 'html_editor_enhanced 2.7.1',
    released: '12 Jul 2025',
    license: 'MIT',
    platforms: 'Web · Android · iOS',
    htmlModel: 'Native HTML (Summernote edits the DOM)',
    popularity: '662 likes · 34k downloads/month',
    health: Health.stale,
    summary: 'The long-time go-to Summernote wrapper. A lot of existing HTML was written with it.',
    pros: ['Real HTML in and out', 'Big toolbar: tables, media, code view'],
    cons: [
      'No commit for 15 months, 243 open issues',
      'Default input processing removes newlines: <pre> code blocks collapse onto one line',
      'Built on dart:html (no wasm build); bundles Summernote 0.8.18 (May 2020) + jQuery',
    ],
    link: 'https://pub.dev/packages/html_editor_enhanced',
    builder: (context, html, handle) => HtmlEditorEnhancedLab(initialHtml: html, handle: handle),
  ),
  EditorInfo(
    id: 'html-editor-plus',
    name: 'html_editor_plus',
    family: EditorFamily.summernote,
    package: 'html_editor_plus 0.0.7',
    released: '27 Dec 2025',
    license: 'MIT',
    platforms: 'Web · Android · iOS',
    htmlModel: 'Native HTML (Summernote edits the DOM)',
    popularity: '14 likes · 700 downloads/month',
    health: Health.active,
    summary: 'A maintained fork of html_editor_enhanced with a rewritten "plus" API (repo active Sep 2026).',
    pros: ['Dart side kept up to date with Flutter', 'Cleaner controller (the HTML is its value)'],
    cons: [
      'Pre-1.0, small user base, README docs removed',
      'The new API has no formatting toolbar; its CSS even hides Summernote\'s (the lab switches it back on)',
      'Still bundles Summernote 0.8.18 (May 2020), like html_editor_enhanced',
      'Built on dart:html (no wasm build)',
    ],
    link: 'https://pub.dev/packages/html_editor_plus',
    builder: (context, html, handle) => HtmlEditorPlusLab(initialHtml: html, handle: handle),
  ),

  // ---------------------------------------------------------------------------
  // Browser JavaScript editors
  // ---------------------------------------------------------------------------
  EditorInfo(
    id: 'tinymce',
    name: 'TinyMCE',
    family: EditorFamily.javascript,
    package: 'tinymce 8.10.0 (npm)',
    released: '14 Oct 2026',
    license: 'GPL-2.0+ or commercial',
    platforms: 'Web (WebView on mobile)',
    htmlModel: 'Native HTML',
    popularity: '16k GitHub stars',
    health: Health.active,
    summary: 'The most complete classic WYSIWYG: tables, media, source code, paste from Word, RTL.',
    pros: ['Keeps existing HTML (iframes, tables, styles) almost unchanged', 'Everything built in, very mature'],
    cons: [
      'GPL: a closed-source SaaS normally needs a commercial licence',
      'Tiny Cloud CDN needs an API key (this lab self-hosts from jsDelivr with license_key "gpl")',
    ],
    link: 'https://www.tiny.cloud',
    builder: _js('tinymce', 'TinyMCE'),
  ),
  EditorInfo(
    id: 'ckeditor5',
    name: 'CKEditor 5',
    family: EditorFamily.javascript,
    package: 'ckeditor5 49.0.0 (npm)',
    released: '8 Oct 2026',
    license: 'GPL-2.0+ or commercial',
    platforms: 'Web (WebView on mobile)',
    htmlModel: 'Native HTML (with General HTML Support on)',
    popularity: '10k GitHub stars',
    health: Health.active,
    summary: 'A polished, schema-based editor. General HTML Support is enabled here so unknown markup survives.',
    pros: ['Excellent UX and accessibility', 'Strict schema produces clean, consistent HTML'],
    cons: [
      'GPL or commercial licence; cdn.ckeditor.com needs a key',
      'Rewrites some markup (tables in <figure class="table">, data-list-item-id on <li>)',
    ],
    link: 'https://ckeditor.com/ckeditor-5/',
    builder: _js('ckeditor5', 'CKEditor 5'),
  ),
  EditorInfo(
    id: 'suneditor',
    name: 'SunEditor',
    family: EditorFamily.javascript,
    package: 'suneditor 3.4.0 (npm)',
    released: '23 Oct 2026',
    license: 'MIT',
    platforms: 'Web (WebView on mobile)',
    htmlModel: 'Native HTML',
    popularity: '2k GitHub stars',
    health: Health.active,
    summary: 'An MIT, dependency-free WYSIWYG for CMS and admin forms. Version 3 is a recent rewrite.',
    pros: ['MIT licence, complete toolbar, no dependencies', 'Released very often'],
    cons: [
      'Wraps media and tables in its own <figure>/<div class="se-…"> markup',
      'v3 API is new: fewer examples online',
    ],
    link: 'https://suneditor.com',
    builder: _js('suneditor', 'SunEditor'),
  ),
];
