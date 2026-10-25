/// One static HTML document the editors are tested with.
class HtmlSample {
  const HtmlSample({required this.id, required this.title, required this.description, required this.html});

  final String id;
  final String title;
  final String description;
  final String html;
}

/// The built-in test documents, modelled on what the LMS saves for lessons and classrooms.
///
/// Images, videos and iframes point at public, CORS-friendly URLs so they load on `localhost`.
abstract final class HtmlSamples {
  static const HtmlSample lesson = HtmlSample(
    id: 'lesson',
    title: 'Lesson – formatted text',
    description: 'Headings, inline styles, colors, nested lists, quote, code, alignment, sub/sup, hr.',
    html: '''
<h1>Introduction to Project Management</h1>
<p>Welcome to <strong>Chapter 1</strong>. In this lesson you will learn the <em>five phases</em> of a project, from <u>initiation</u> to closure (<s>chaos</s>).</p>
<h2>Learning objectives</h2>
<ul>
  <li>Define what a project is</li>
  <li>Identify the <strong>stakeholders</strong>
    <ul>
      <li>Internal: team, sponsor</li>
      <li>External: client, suppliers</li>
    </ul>
  </li>
  <li>Build a simple schedule</li>
</ul>
<h3>The five phases</h3>
<ol>
  <li>Initiation</li>
  <li>Planning</li>
  <li>Execution</li>
  <li>Monitoring &amp; control</li>
  <li>Closure</li>
</ol>
<blockquote>“Plans are nothing; planning is everything.” — Dwight D. Eisenhower</blockquote>
<p style="text-align: center;"><span style="color: rgb(231, 76, 60);">Centered red text</span> and <span style="background-color: rgb(255, 235, 59);">highlighted text</span>.</p>
<p style="text-align: right;">Right-aligned paragraph.</p>
<p>Inline <code>code</code>, a <a href="https://theteam.com.tn" target="_blank">link to THE TEAM</a>, H<sub>2</sub>O and E = mc<sup>2</sup>.</p>
<pre><code>function duration(start, end) {
  return end - start;
}</code></pre>
<hr>
<p><span style="font-size: 20px;">Bigger text (20px)</span> and <span style="font-family: 'Courier New', monospace;">Courier New</span>.</p>''',
  );

  static const HtmlSample media = HtmlSample(
    id: 'media',
    title: 'Media & embeds',
    description: 'Image, the LMS PDF iframe, a YouTube iframe, a Google Calendar iframe and a <video>.',
    html: '''
<h2>Course material</h2>
<p>An uploaded image:</p>
<p><img src="https://picsum.photos/id/180/800/400" alt="Laptop on a desk" style="width: 100%; max-width: 640px;"></p>
<p>The lesson PDF (the same iframe the LMS inserts after a PDF upload):</p>
<iframe src="https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf#toolbar=0" type="application/pdf" width="95%" height="500px" style="border: none;" oncontextmenu="return false;"></iframe>
<p>A YouTube video:</p>
<iframe width="560" height="315" src="https://www.youtube.com/embed/fq4N0hgOWzU" title="Introducing Flutter" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
<p>The classroom calendar:</p>
<iframe src="https://calendar.google.com/calendar/embed?src=en.tn%23holiday%40group.v.calendar.google.com&amp;ctz=Africa%2FTunis" style="border: 0" width="800" height="600" frameborder="0" scrolling="no"></iframe>
<p>A video file:</p>
<video controls width="480" src="https://www.w3schools.com/html/mov_bbb.mp4"></video>
<p>End of the material.</p>''',
  );

  static const HtmlSample table = HtmlSample(
    id: 'table',
    title: 'Tables',
    description: 'A grading table with a header row, cell alignment, bold text and a colspan.',
    html: '''
<h2>Grading scheme</h2>
<p>Your final grade is made of four parts:</p>
<table style="width: 100%; border-collapse: collapse;" border="1">
  <thead>
    <tr><th>Assessment</th><th>Weight</th><th>Due</th></tr>
  </thead>
  <tbody>
    <tr><td>Quiz 1</td><td style="text-align: center;">10%</td><td>Week 2</td></tr>
    <tr><td>Midterm exam</td><td style="text-align: center;">30%</td><td>Week 6</td></tr>
    <tr><td>Project</td><td style="text-align: center;">40%</td><td>Week 10</td></tr>
    <tr><td colspan="2"><strong>Final exam</strong></td><td>Week 12 (20%)</td></tr>
  </tbody>
</table>
<p>Text after the table.</p>''',
  );

  static const HtmlSample rtl = HtmlSample(
    id: 'rtl',
    title: 'Arabic (RTL) + French',
    description: 'Right-to-left Arabic paragraphs and lists next to French text with accents.',
    html: '''
<h2 dir="rtl">مقدمة في إدارة المشاريع</h2>
<p dir="rtl">مرحبًا بكم في <strong>الفصل الأول</strong>. ستتعلمون في هذا الدرس <em>المراحل الخمس</em> لأي مشروع.</p>
<ul dir="rtl">
  <li>تحديد أهداف المشروع</li>
  <li>تحديد <u>أصحاب المصلحة</u></li>
</ul>
<p dir="rtl" style="text-align: right;">نص محاذى إلى اليمين.</p>
<h2>Introduction à la gestion de projet</h2>
<p>Bienvenue dans le <strong>chapitre 1</strong> : « Qu'est-ce qu'un projet ? » — on y parle d'échéances, de coûts &amp; de qualité.</p>''',
  );

  static const HtmlSample summernote = HtmlSample(
    id: 'summernote',
    title: 'Old Summernote output',
    description: 'What html_editor_enhanced used to save: <b>, <i>, <font color>, <strike>, <p><br></p>.',
    html: '''
<p>This lesson was written with the <b>old Summernote editor</b>.<br></p>
<p><b>Bold</b>, <i>italic</i>, <u>underline</u>, <strike>strike</strike>, <font color="#ff0000">red font tag</font>, <span style="background-color: rgb(255, 255, 0);">yellow background</span>.</p>
<p><span style="font-size: 24px;">Font size 24</span> · <span style="font-family: &quot;Comic Sans MS&quot;;">Comic Sans MS</span></p>
<p style="text-align: center; "><b>Centered bold</b></p>
<ol><li>First</li><li>Second</li></ol>
<p><br></p>
<p><a href="https://example.com" target="_blank">A link</a></p>
<p><br></p>''',
  );

  static const HtmlSample empty = HtmlSample(
    id: 'empty',
    title: 'Empty document',
    description: 'Start from nothing and type.',
    html: '',
  );

  static const List<HtmlSample> all = [lesson, media, table, rtl, summernote, empty];
}
