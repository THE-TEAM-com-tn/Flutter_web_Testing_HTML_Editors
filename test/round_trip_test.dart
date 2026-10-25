import 'package:flutter_quill/flutter_quill.dart' show Document;
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_testing_html_editors/editors/html_quill_codec.dart';
import 'package:lms_testing_html_editors/lab/html_report.dart';
import 'package:lms_testing_html_editors/samples.dart';

/// HTML → Quill document → HTML through the custom codec, as the "flutter_quill + HTML codec"
/// editor does it (the document normalises the Delta like the editor). `flutter test -r expanded`
/// prints what each sample lost.
///
/// The other editors in the lab are JavaScript (Summernote, TinyMCE, CKEditor, SunEditor) and only
/// run in a browser page: test them in the app with Export HTML.
String _roundTrip(String html) => HtmlQuillCodec.deltaToHtml(Document.fromDelta(HtmlQuillCodec.htmlToDelta(html)).toDelta());

void main() {
  for (final HtmlSample sample in HtmlSamples.all) {
    test('Quill HTML codec · ${sample.title}', () {
      final HtmlReport report = HtmlReport.compare(sample.html, _roundTrip(sample.html));
      // ignore: avoid_print
      print('Quill HTML codec | ${sample.id} | text ${(report.textKept * 100).round()}% | ${report.summary}');
      expect(report.textKept, 1);
    });
  }

  test('the Quill HTML codec keeps every iframe, video and table', () {
    for (final HtmlSample sample in [HtmlSamples.media, HtmlSamples.table]) {
      final HtmlReport report = HtmlReport.compare(sample.html, _roundTrip(sample.html));
      expect(report.lost.map((c) => c.name), isNot(contains(matches(r'^(iframe|video|table|td)$'))));
    }
  });
}
