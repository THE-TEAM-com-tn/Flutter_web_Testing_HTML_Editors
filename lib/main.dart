import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:lms_testing_html_editors/catalog.dart';
import 'package:lms_testing_html_editors/lab/editor_lab_page.dart';
import 'package:lms_testing_html_editors/lab/home_page.dart';
import 'package:lms_testing_html_editors/samples.dart';

void main() => runApp(const HtmlEditorLabApp());

/// A playground to compare maintained rich-text / HTML editors that run on Flutter web,
/// before picking one for LMS_Frontend.
///
/// Routes (also usable as web URLs, `#/editor/tinymce?sample=media`): `/`, and
/// `/editor/<id>` with an optional `?sample=<id>` from [HtmlSamples.all].
class HtmlEditorLabApp extends StatelessWidget {
  const HtmlEditorLabApp({super.key});

  static Route<void>? _route(RouteSettings settings) {
    final Uri uri = Uri.parse(settings.name ?? '/');
    final String path = uri.path;
    final HtmlSample sample =
        HtmlSamples.all.where((s) => s.id == uri.queryParameters['sample']).firstOrNull ?? HtmlSamples.lesson;
    final Widget? page = switch (path) {
      '/' => const HomePage(),
      _ when path.startsWith('/editor/') => editorCatalog
          .where((e) => e.id == path.substring('/editor/'.length))
          .map((e) => EditorLabPage(info: e, initialSample: sample))
          .firstOrNull,
      _ => null,
    };
    if (page == null) return null;
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTML editor lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3949AB)),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
      onGenerateRoute: _route,
    );
  }
}
