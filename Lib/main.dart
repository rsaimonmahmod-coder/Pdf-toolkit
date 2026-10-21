import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pc;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

const storage = FlutterSecureStorage();

void main() => runApp(const PdfToolkitApp());

class PdfToolkitApp extends StatelessWidget {
  const PdfToolkitApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Toolkit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
      ),
      home: const Home(),
    );
  }
}

// ---------------------------------------------------------------- helpers

Future<List<File>> pickPdfs({bool multi = false}) async {
  final r = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    allowMultiple: multi,
  );
  if (r == null) return [];
  return r.paths.whereType<String>().map((p) => File(p)).toList();
}

Future<List<File>> pickImages() async {
  final r = await FilePicker.platform
      .pickFiles(type: FileType.image, allowMultiple: true);
  if (r == null) return [];
  return r.paths.whereType<String>().map((p) => File(p)).toList();
}

String stamp() => DateTime.now().millisecondsSinceEpoch.toString();
String fileName(File f) => f.path.split('/').last;

Future<File> saveBytes(List<int> bytes, String name) async {
  final dir = await getApplicationDocumentsDirectory();
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(bytes);
  return f;
}

Future<File> textToPdf(String title, String body) async {
  final doc = pw.Document();
  doc.addPage(pw.MultiPage(
    pageFormat: pc.PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    build: (_) => [
      if (title.isNotEmpty) pw.Header(level: 0, text: title),
      ...body.split('\n').map((l) => pw.Text(l.isEmpty ? ' ' : l)),
    ],
  ));
  return saveBytes(await doc.save(), 'text_${stamp()}.pdf');
}

void appendPage(sf.PdfDocument out, sf.PdfPage p) {
  out.pageSettings.margins.all = 0;
  out.pageSettings.size = p.size;
  out.pages.add().graphics.drawPdfTemplate(p.createTemplate(), Offset.zero);
}

List<int> parseRange(String s, int max) {
  final out = <int>[];
  for (final part in s.split(',')) {
    final t = part.trim();
    if (t.isEmpty) continue;
    if (t.contains('-')) {
      final a = t.split('-');
      final x = int.parse(a[0].trim());
      final y = int.parse(a[1].trim());
      for (var i = x; i <= y; i++) {
        out.add(i);
      }
    } else {
      out.add(int.parse(t));
    }
  }
  return out.where((i) => i >= 1 && i <= max).toList();
}

Future<void> showResult(BuildContext context, List<File> files) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Done ✅'),
      content: Text(files.length == 1
          ? 'Saved: ${fileName(files.first)}'
          : '${files.length} files created.'),
      actions: [
        if (files.length == 1)
          TextButton(
            onPressed: () => OpenFilex.open(files.first.path),
            child: const Text('Open'),
          ),
        TextButton(
          onPressed: () =>
              Share.shareXFiles(files.map((f) => XFile(f.path)).toList()),
          child: const Text('Share / Save'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> withBusy(
    BuildContext context, Future<List<File>> Function() job) async {
  final nav = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  List<File>? result;
  String? error;
  try {
    result = await job();
  } catch (e) {
    error = e.toString();
  }
  nav.pop();
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text('Error: $error')));
    return;
  }
  if (result != null && result.isNotEmpty && context.mounted) {
    await showResult(context, result);
  }
}

// ------------------------------------------------------------------- home

class Tool {
  final String title;
  final IconData icon;
  final Widget Function() page;
  Tool(this.title, this.icon, this.page);
}

class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext context) {
    final tools = <Tool>[
      Tool('Image to PDF', Icons.image, () => const ImageToPdfScreen()),
      Tool('Photo to PDF', Icons.photo_camera,
          () => const ImageToPdfScreen(startWithCamera: true)),
      Tool('Text to PDF', Icons.text_snippet, () => const TextToPdfScreen()),
      Tool('Merge PDF', Icons.merge_type, () => const MergeScreen()),
      Tool('Split / Extract', Icons.call_split, () => const SplitScreen()),
      Tool('AI Tools', Icons.auto_awesome, () => const AiScreen()),
      Tool('API Key Settings', Icons.key, () => const SettingsScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Toolkit')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          for (final t in tools)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => t.page())),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t.icon,
                        size: 44, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 10),
                    Text(t.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------- image / photo to PDF

class ImageToPdfScreen extends StatefulWidget {
  final bool startWithCamera;
  const ImageToPdfScreen({super.key, this.startWithCamera = false});
  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfState();
}

class _ImageToPdfState extends State<ImageToPdfScreen> {
  final List<File> images = [];

  @override
  void initState() {
    super.initState();
    if (widget.startWithCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) => camera());
    }
  }

  Future<void> gallery() async {
    final f = await pickImages();
    setState(() => images.addAll(f));
  }

  Future<void> camera() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x != null) setState(() => images.add(File(x.path)));
  }

  Future<List<File>> create() async {
    final doc = pw.Document();
    for (final f in images) {
      final img = pw.MemoryImage(await f.readAsBytes());
      doc.addPage(pw.Page(
        pageFormat: pc.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (_) =>
            pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
      ));
    }
    return [await saveBytes(await doc.save(), 'images_${stamp()}.pdf')];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image / Photo to PDF')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: gallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: camera,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: images.isEmpty
                ? const Center(child: Text('No images yet'))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8),
                    itemCount: images.length,
                    itemBuilder: (_, i) => Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(images[i], fit: BoxFit.cover, cacheWidth: 300),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            style: IconButton.styleFrom(
                                backgroundColor: Colors.black54),
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 18),
                            onPressed: () =>
                                setState(() => images.removeAt(i)),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      images.isEmpty ? null : () => withBusy(context, create),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text('Create PDF (${images.length})'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- text to PDF

class TextToPdfScreen extends StatefulWidget {
  const TextToPdfScreen({super.key});
  @override
  State<TextToPdfScreen> createState() => _TextToPdfState();
}

class _TextToPdfState extends State<TextToPdfScreen> {
  final titleC = TextEditingController();
  final bodyC = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text to PDF')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: titleC,
              decoration: const InputDecoration(
                  labelText: 'Title (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: bodyC,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                    labelText: 'Write or paste your text',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Create PDF'),
                onPressed: () => withBusy(context, () async {
                  if (bodyC.text.trim().isEmpty) throw 'Please write some text';
                  return [await textToPdf(titleC.text.trim(), bodyC.text)];
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- merge PDF

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});
  @override
  State<MergeScreen> createState() => _MergeState();
}

class _MergeState extends State<MergeScreen> {
  final List<File> files = [];

  Future<List<File>> merge() async {
    final out = sf.PdfDocument();
    for (final f in files) {
      final src = sf.PdfDocument(inputBytes: await f.readAsBytes());
      for (var i = 0; i < src.pages.count; i++) {
        appendPage(out, src.pages[i]);
      }
      src.dispose();
    }
    final data = await out.save();
    out.dispose();
    return [await saveBytes(data, 'merged_${stamp()}.pdf')];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merge PDF')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add PDF files'),
                onPressed: () async {
                  final f = await pickPdfs(multi: true);
                  setState(() => files.addAll(f));
                },
              ),
            ),
          ),
          const Text('Hold and drag to change order'),
          Expanded(
            child: ReorderableListView(
              onReorder: (o, n) {
                setState(() {
                  if (n > o) n -= 1;
                  final f = files.removeAt(o);
                  files.insert(n, f);
                });
              },
              children: [
                for (final f in files)
                  ListTile(
                    key: ObjectKey(f),
                    leading: const Icon(Icons.picture_as_pdf),
                    title: Text(fileName(f), maxLines: 1),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => files.remove(f)),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.merge_type),
                  label: const Text('Merge'),
                  onPressed: files.length < 2
                      ? null
                      : () => withBusy(context, merge),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------ split / extract PDF

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});
  @override
  State<SplitScreen> createState() => _SplitState();
}

class _SplitState extends State<SplitScreen> {
  File? file;
  int pages = 0;
  final rangeC = TextEditingController();

  Future<void> pick() async {
    final f = await pickPdfs();
    if (f.isEmpty) return;
    final d = sf.PdfDocument(inputBytes: await f.first.readAsBytes());
    final n = d.pages.count;
    d.dispose();
    setState(() {
      file = f.first;
      pages = n;
    });
  }

  Future<List<File>> splitAll() async {
    final src = sf.PdfDocument(inputBytes: await file!.readAsBytes());
    final out = <File>[];
    for (var i = 0; i < src.pages.count; i++) {
      final d = sf.PdfDocument();
      appendPage(d, src.pages[i]);
      out.add(await saveBytes(await d.save(), 'page_${i + 1}_${stamp()}.pdf'));
      d.dispose();
    }
    src.dispose();
    return out;
  }

  Future<List<File>> extract() async {
    final src = sf.PdfDocument(inputBytes: await file!.readAsBytes());
    final idx = parseRange(rangeC.text, src.pages.count);
    if (idx.isEmpty) throw 'Invalid page range';
    final d = sf.PdfDocument();
    for (final i in idx) {
      appendPage(d, src.pages[i - 1]);
    }
    final data = await d.save();
    d.dispose();
    src.dispose();
    return [await saveBytes(data, 'extract_${stamp()}.pdf')];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Split / Extract pages')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: Text(file == null
                  ? 'Choose PDF'
                  : '${fileName(file!)} ($pages pages)'),
              onPressed: pick,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.call_split),
              label: const Text('Split into single pages'),
              onPressed:
                  file == null ? null : () => withBusy(context, splitAll),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: rangeC,
              decoration: const InputDecoration(
                labelText: 'Pages to extract, e.g. 1-3,5,8',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.content_cut),
              label: const Text('Extract these pages'),
              onPressed: file == null ? null : () => withBusy(context, extract),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ AI core

class AiService {
  static const defaults = {
    'Claude': 'claude-sonnet-5-5',
    'OpenAI': 'gpt-4o-mini',
    'Gemini': 'gemini-2.5-flash',
  };

  static Future<String> ask(String prompt) async {
    final provider = await storage.read(key: 'provider') ?? 'Claude';
    final key = (await storage.read(key: 'apikey_$provider')) ?? '';
    var model = (await storage.read(key: 'model_$provider')) ?? '';
    if (key.isEmpty) {
      throw 'Add your $provider API key in "API Key Settings" first.';
    }
    if (model.isEmpty) model = defaults[provider]!;

    late http.Response res;
    if (provider == 'Claude') {
      res = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 4096,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );
    } else if (provider == 'OpenAI') {
      res = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $key',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );
    } else {
      res = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
        headers: {
          'x-goog-api-key': key,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
        }),
      );
    }

    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode != 200) {
      throw 'AI error ${res.statusCode}: $body';
    }
    final j = jsonDecode(body);
    if (provider == 'Claude') return j['content'][0]['text'] as String;
    if (provider == 'OpenAI') {
      return j['choices'][0]['message']['content'] as String;
    }
    return j['candidates'][0]['content']['parts'][0]['text'] as String;
  }
}

String buildPrompt(String action, String extra, String text) {
  String instruction;
  switch (action) {
    case 'Key points':
      instruction = 'Extract the key points of the document below as a clear bullet list.';
      break;
    case 'Translate':
      instruction =
          'Translate the text below into ${extra.isEmpty ? "English" : extra}. Output only the translation.';
      break;
    case 'Ask a question':
      instruction =
          'Answer this question using only the document below: $extra';
      break;
    case 'Rewrite':
      instruction =
          'Rewrite the text below so it is clearer and better written. $extra';
      break;
    default:
      instruction = 'Summarize the document below clearly and concisely.';
  }
  return '$instruction\n\n---\n$text';
}

// ---------------------------------------------------------------- AI screen

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final textC = TextEditingController();
  final extraC = TextEditingController();
  String action = 'Summarize';
  String result = '';
  bool busy = false;
  static const actions = [
    'Summarize',
    'Key points',
    'Translate',
    'Ask a question',
    'Rewrite'
  ];

  void snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> loadPdf() async {
    final f = await pickPdfs();
    if (f.isEmpty) return;
    try {
      final d = sf.PdfDocument(inputBytes: await f.first.readAsBytes());
      final t = sf.PdfTextExtractor(d).extractText();
      d.dispose();
      setState(() => textC.text = t);
      if (t.trim().isEmpty) {
        snack('No text found. This PDF may be a scanned image.');
      }
    } catch (e) {
      snack('Error: $e');
    }
  }

  Future<void> runAi() async {
    final text = textC.text.trim();
    if (text.isEmpty) {
      snack('Load a PDF or paste text first');
      return;
    }
    setState(() => busy = true);
    try {
      final cut = text.length > 60000 ? text.substring(0, 60000) : text;
      final out = await AiService.ask(buildPrompt(action, extraC.text.trim(), cut));
      setState(() => result = out);
    } catch (e) {
      snack('$e');
    }
    if (mounted) setState(() => busy = false);
  }

  String get extraHint {
    switch (action) {
      case 'Translate':
        return 'Language (e.g. Spanish, Hindi, Bangla)';
      case 'Ask a question':
        return 'Your question';
      case 'Rewrite':
        return 'Instructions (optional)';
      default:
        return 'Extra instructions (optional)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Tools')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Load text from a PDF'),
            onPressed: loadPdf,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: textC,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'PDF text (or paste your own text)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButton<String>(
            isExpanded: true,
            value: action,
            items: [
              for (final a in actions) DropdownMenuItem(value: a, child: Text(a))
            ],
            onChanged: (v) => setState(() => action = v ?? action),
          ),
          TextField(
            controller: extraC,
            decoration: InputDecoration(
                labelText: extraHint, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(busy ? 'Working...' : 'Run AI'),
            onPressed: busy ? null : runAi,
          ),
          if (result.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(result),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: result));
                      snack('Copied');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Save as PDF'),
                    onPressed: () => withBusy(context,
                        () async => [await textToPdf('AI Result', result)]),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- settings

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  String provider = 'Claude';
  final keyC = TextEditingController();
  final modelC = TextEditingController();
  bool hide = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    provider = await storage.read(key: 'provider') ?? 'Claude';
    await loadFields();
  }

  Future<void> loadFields() async {
    keyC.text = await storage.read(key: 'apikey_$provider') ?? '';
    modelC.text = await storage.read(key: 'model_$provider') ?? '';
    if (mounted) setState(() {});
  }

  Future<void> switchTo(String p) async {
    await storage.write(key: 'provider', value: p);
    provider = p;
    await loadFields();
  }

  Future<void> save() async {
    await storage.write(key: 'provider', value: provider);
    await storage.write(key: 'apikey_$provider', value: keyC.text.trim());
    await storage.write(key: 'model_$provider', value: modelC.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved securely ✅')));
    }
  }

  Future<void> clear() async {
    await storage.delete(key: 'apikey_$provider');
    keyC.clear();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Key removed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Key Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Choose your AI provider',
              style: TextStyle(fontWeight: FontWeight.w600)),
          DropdownButton<String>(
            isExpanded: true,
            value: provider,
            items: [
              for (final p in AiService.defaults.keys)
                DropdownMenuItem(value: p, child: Text(p))
            ],
            onChanged: (v) {
              if (v != null) switchTo(v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: keyC,
            obscureText: hide,
            decoration: InputDecoration(
              labelText: '$provider API key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => hide = !hide),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: modelC,
            decoration: InputDecoration(
              labelText: 'Model (leave empty for default)',
              helperText: 'Default: ${AiService.defaults[provider]}',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            onPressed: save,
          ),
          TextButton(onPressed: clear, child: const Text('Remove this key')),
          const SizedBox(height: 16),
          const Text(
            'Your key is stored encrypted on this phone only and is sent '
            'directly to the AI provider. Get a key at:\n'
            '• Claude: console.anthropic.com\n'
            '• OpenAI: platform.openai.com\n'
            '• Gemini: aistudio.google.com',
          ),
        ],
      ),
    );
  }
}
