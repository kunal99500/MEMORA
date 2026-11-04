import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../widgets/glass.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import '../widgets/ai_privacy.dart';

class RoomsScreen extends StatefulWidget {
  final Future<void> Function()? onMediaUploaded;
  final Future<bool> Function()? ensureAiConsent;
  const RoomsScreen(
      {super.key, this.onMediaUploaded, this.ensureAiConsent});
  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List spaces = const [];
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wid = Session.workspaceId;
    if (wid == null) {
      if (mounted) setState(() => loaded = true);
      return;
    }
    try {
      final s = await Api.roomsSummary(wid);
      if (mounted)
        setState(() {
          spaces = s;
          loaded = true;
        });
    } catch (_) {
      if (mounted) setState(() => loaded = true);
    }
  }

  Future<void> _newSpace() async {
    final name = await _promptName(
        context, 'New space', 'e.g. Living room, Garage, Pantry');
    if (name == null || name.trim().isEmpty) return;
    final wid = Session.workspaceId;
    if (wid == null) return;
    try {
      await Api.createSpace(wid, name.trim());
      await _load();
    } catch (e) {
      if (mounted) _toast(context, 'Could not create space');
    }
  }

  Future<void> _refreshAfterUpload() async {
    await _load();
    await widget.onMediaUploaded?.call();
  }

  void _open(String id, String name) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => _SpaceDetailScreen(
                spaceId: id,
                name: name,
                onMediaUploaded: _refreshAfterUpload,
                ensureAiConsent: widget.ensureAiConsent)))
        .then((_) => _load());
  }

  static const _icons = [
    Icons.weekend_outlined,
    Icons.bed_outlined,
    Icons.kitchen_outlined,
    Icons.desk_outlined,
    Icons.meeting_room_outlined,
  ];
  static const _colors = [
    MemoraColors.cyan,
    MemoraColors.violet,
    MemoraColors.gold,
    MemoraColors.success,
    MemoraColors.blue,
  ];

  @override
  Widget build(BuildContext context) => _PageFrame(
      title: 'Your spaces',
      eyebrow: 'SPACE MEMORY',
      subtitle:
          'Create a space for anything you want to remember \u2014 a room, a garage, a drawer \u2014 then scan it.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
            alignment: Alignment.centerLeft,
            child: GlowButton(
                label: 'New space',
                icon: Icons.add_rounded,
                onPressed: () {
                  _newSpace();
                })),
        const SizedBox(height: 16),
        Expanded(
          child: !loaded
              ? const Center(
                  child: CircularProgressIndicator(color: MemoraColors.gold))
              : spaces.isEmpty
                  ? _empty()
                  : SingleChildScrollView(
                      child: LayoutBuilder(
                          builder: (context, c) =>
                              Wrap(spacing: 12, runSpacing: 12, children: [
                                for (int i = 0; i < spaces.length; i++)
                                  _spaceTile(c.maxWidth, spaces[i], i),
                              ]))),
        ),
      ]));

  Widget _empty() => Center(
      child: GlassPanel(
          padding: const EdgeInsets.all(26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_home_outlined,
                color: MemoraColors.gold, size: 34),
            const SizedBox(height: 14),
            const Text('No spaces yet',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 7),
            const Text(
                'Create a space for anything \u2014 a room, a garage, a shelf \u2014 then scan it to start your memory.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: MemoraColors.muted, fontSize: 12, height: 1.5)),
            const SizedBox(height: 18),
            GlowButton(
                label: 'New space',
                icon: Icons.add_rounded,
                onPressed: () {
                  _newSpace();
                }),
          ])));

  Widget _spaceTile(double width, dynamic sp, int i) {
    final name = (sp['name'] ?? 'Space').toString();
    final count = sp['image_count'] ?? 0;
    final color = _colors[i % _colors.length];
    return SizedBox(
        width: width > 850
            ? (width - 24) / 3
            : width > 520
                ? (width - 12) / 2
                : width,
        child: GlassPanel(
            onTap: () => _open(sp['space_id'].toString(), name),
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: LinearGradient(colors: [
                        color.withOpacity(.23),
                        const Color(0xFF1F1F26)
                      ])),
                  child: Center(
                      child: Icon(_icons[i % _icons.length],
                          size: 48, color: color))),
              const SizedBox(height: 13),
              Text(name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              Text('$count objects',
                  style:
                      const TextStyle(color: MemoraColors.muted, fontSize: 10)),
              const SizedBox(height: 10),
              const Row(children: [
                Icon(Icons.document_scanner_outlined,
                    size: 14, color: MemoraColors.gold),
                SizedBox(width: 6),
                Text('Open to scan',
                    style: TextStyle(color: MemoraColors.muted, fontSize: 9)),
                Spacer(),
                Icon(Icons.arrow_forward, size: 15, color: MemoraColors.gold)
              ])
            ])));
  }
}

class _SpaceDetailScreen extends StatefulWidget {
  final String spaceId, name;
  final Future<void> Function()? onMediaUploaded;
  final Future<bool> Function()? ensureAiConsent;
  const _SpaceDetailScreen(
      {required this.spaceId,
      required this.name,
      this.onMediaUploaded,
      this.ensureAiConsent});
  @override
  State<_SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<_SpaceDetailScreen> {
  List objects = const [];
  List images = const [];
  bool loaded = false;
  bool scanning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await Api.objects(widget.spaceId);
      final im = await Api.scanImages(widget.spaceId);
      if (mounted)
        setState(() {
          objects = o;
          images = im;
          loaded = true;
        });
    } catch (_) {
      if (mounted) setState(() => loaded = true);
    }
  }

  Future<void> _scanBytes(Uint8List bytes, String filename,
      {bool gallerySaved = true}) async {
    setState(() => scanning = true);
    try {
      final res = await Api.scan(widget.spaceId, filename, bytes, filename);
      final n = (res['objects'] as List?)?.length ?? 0;
      await _load();
      await widget.onMediaUploaded?.call();
      if (mounted) {
        final result = n > 0
            ? 'Remembered $n objects in this room'
            : 'Scan done, but no objects detected - try a clearer photo';
        _toast(
            context,
            gallerySaved
                ? result
                : '$result. The original was not saved to your gallery.');
      }
    } catch (e) {
      if (mounted) _toast(context, 'Scan failed - is the backend running?');
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _pick(ImageSource src) async {
    if (widget.ensureAiConsent != null &&
        !await widget.ensureAiConsent!.call()) return;
    if (src == ImageSource.gallery) {
      try {
        final files = await ImagePicker().pickMultiImage(imageQuality: 100);
        if (files.isNotEmpty) await _uploadBatch(files, video: false);
      } catch (exception) {
        if (mounted) _toast(context, 'Could not open images: $exception');
      }
      return;
    }

    try {
      final x = await ImagePicker().pickImage(
        source: src,
      );
      if (x == null) return;
      final original = await x.readAsBytes();
      var gallerySaved = true;
      if (src == ImageSource.camera && !kIsWeb) {
        try {
          await Gal.putImage(x.path);
        } on GalException catch (e) {
          gallerySaved = false;
          if (mounted)
            _toast(context, 'Photo could not be saved: ${e.type.message}');
        }
      }
      await _scanBytes(_serverImageCopy(original), _jpegName(x.name),
          gallerySaved: gallerySaved);
    } catch (e) {
      if (mounted) _toast(context, 'Could not open: $e');
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (widget.ensureAiConsent != null &&
        !await widget.ensureAiConsent!.call()) return;
    if (source == ImageSource.gallery) {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          allowMultiple: true,
          withData: kIsWeb,
        );
        if (result != null && result.files.isNotEmpty) {
          await _uploadBatch(result.xFiles, video: true);
        }
      } catch (exception) {
        if (mounted) _toast(context, 'Could not open videos: $exception');
      }
      return;
    }

    try {
      final file = await ImagePicker().pickVideo(source: source);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 50 * 1024 * 1024) {
        throw const FormatException(
            'This video exceeds the 50 MB upload limit.');
      }

      var gallerySaved = true;
      final supportsGallerySave = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      if (source == ImageSource.camera && supportsGallerySave) {
        try {
          await Gal.putVideo(file.path);
        } on GalException catch (exception) {
          gallerySaved = false;
          if (mounted) {
            _toast(context,
                'Video could not be saved to your gallery: ${exception.type.message}');
          }
        }
      }

      if (mounted) setState(() => scanning = true);
      await Api.uploadSpaceMedia(
        locationId: widget.spaceId,
        name: widget.name,
        bytes: bytes,
        filename: file.name,
      );
      if (!mounted) return;
      _toast(
        context,
        gallerySaved
            ? 'Video added to ${widget.name}; processing has started.'
            : 'Video added to ${widget.name}; gallery save failed.',
      );
      await _load();
      await widget.onMediaUploaded?.call();
    } catch (exception) {
      if (mounted) _toast(context, 'Could not add video: $exception');
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _uploadBatch(List<XFile> files, {required bool video}) async {
    if (scanning) return;
    setState(() => scanning = true);
    var uploaded = 0;
    final failures = <String>[];
    try {
      for (final file in files) {
        try {
          final original = await file.readAsBytes();
          if (original.length > 50 * 1024 * 1024) {
            throw const FormatException('File exceeds the 50 MB upload limit.');
          }
          final bytes = video ? original : _serverImageCopy(original);
          if (bytes.length > 50 * 1024 * 1024) {
            throw const FormatException(
                'Processed image exceeds the 50 MB upload limit.');
          }
          await Api.uploadSpaceMedia(
            locationId: widget.spaceId,
            name: widget.name,
            bytes: bytes,
            filename: video ? file.name : _jpegName(file.name),
          );
          uploaded++;
        } catch (exception) {
          failures.add('${file.name}: $exception');
        }
      }
      await _load();
      if (uploaded > 0) await widget.onMediaUploaded?.call();
      if (!mounted) return;
      final mediaName = video ? 'video' : 'image';
      final successMessage = uploaded == 0
          ? 'No $mediaName files were uploaded.'
          : '$uploaded $mediaName${uploaded == 1 ? '' : 's'} added to ${widget.name}; processing has started.';
      final failureMessage = failures.isEmpty
          ? ''
          : ' ${failures.length} failed: ${failures.take(2).join('; ')}';
      _toast(context, '$successMessage$failureMessage');
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Uint8List _serverImageCopy(Uint8List original) {
    final decoded = img.decodeImage(original);
    if (decoded == null) {
      throw const FormatException('Selected file is not a supported image.');
    }
    final oriented = img.bakeOrientation(decoded);
    final longestSide =
        oriented.width > oriented.height ? oriented.width : oriented.height;
    final resized = longestSide > 1920
        ? img.copyResize(
            oriented,
            width: oriented.width >= oriented.height
                ? 1920
                : (oriented.width * 1920 / oriented.height).round(),
            height: oriented.height > oriented.width
                ? 1920
                : (oriented.height * 1920 / oriented.width).round(),
          )
        : oriented;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }

  String _jpegName(String name) => '${name.split('.').first}.jpg';

  void _addScan() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MemoraColors.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: MemoraColors.line,
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 12),
        ListTile(
            leading: const Icon(Icons.photo_camera_outlined,
                color: MemoraColors.gold),
            title: const Text('Capture image'),
            subtitle: const Text('MEMORA scans it live and remembers',
                style: TextStyle(fontSize: 11, color: MemoraColors.muted)),
            onTap: () {
              _pick(ImageSource.camera);
              Navigator.pop(sheetCtx);
            }),
        ListTile(
            leading: const Icon(Icons.photo_library_outlined,
                color: MemoraColors.cyan),
            title: const Text('Upload image'),
            subtitle: const Text('Choose one or more images for this space',
                style: TextStyle(fontSize: 11, color: MemoraColors.muted)),
            onTap: () {
              _pick(ImageSource.gallery);
              Navigator.pop(sheetCtx);
            }),
        ListTile(
            leading: const Icon(Icons.video_library_outlined,
                color: MemoraColors.cyan),
            title: const Text('Upload video'),
            subtitle: const Text('Choose one or more videos for this space',
                style: TextStyle(fontSize: 11, color: MemoraColors.muted)),
            onTap: () {
              _pickVideo(ImageSource.gallery);
              Navigator.pop(sheetCtx);
            }),
        ListTile(
            leading:
                const Icon(Icons.videocam_outlined, color: MemoraColors.gold),
            title: const Text('Record video'),
            subtitle: const Text('Record and add a video to this space',
                style: TextStyle(fontSize: 11, color: MemoraColors.muted)),
            onTap: () {
              _pickVideo(ImageSource.camera);
              Navigator.pop(sheetCtx);
            }),
        const SizedBox(height: 10),
      ])),
    );
  }

  Widget _scanCard(dynamic im) {
    final url = (im['image'] ?? '').toString();
    final cid = (im['capture_id'] ?? '').toString();
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Stack(children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(Api.frameUrl(url),
                          headers: Api.imageHeaders,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                              height: 140,
                              color: Colors.white10,
                              child: const Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      color: MemoraColors.muted))))),
                  Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                          color: Colors.black.withOpacity(.55),
                          shape: const CircleBorder(),
                          child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                _deleteScan(cid);
                              },
                              child: const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(Icons.delete_outline_rounded,
                                      color: Colors.white, size: 18))))),
                ]))));
  }

  Future<void> _deleteScan(String cid) async {
    if (cid.isEmpty) return;
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                backgroundColor: MemoraColors.panel,
                title: const Text('Delete this photo?'),
                content: const Text(
                    'MEMORA will forget what was in it. This cannot be undone.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete',
                          style: TextStyle(color: MemoraColors.danger))),
                ]));
    if (ok != true) return;
    try {
      await Api.deleteScan(cid);
    } catch (_) {}
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: MemoraColors.bg,
      appBar: AppBar(title: Text(widget.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GlassPanel(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.document_scanner_outlined,
                            color: MemoraColors.gold),
                        SizedBox(width: 12),
                        Expanded(
                            child: Text(
                                'Scan this room so MEMORA can remember what is in it.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: MemoraColors.muted,
                                    height: 1.4))),
                      ]),
                      const SizedBox(height: 14),
                      SizedBox(
                          width: double.infinity,
                          child: GlowButton(
                              label: scanning ? 'Scanning…' : 'Scan this space',
                              icon: Icons.add_a_photo_outlined,
                              onPressed: scanning
                                  ? () {}
                                  : () {
                                      _addScan();
                                    })),
                    ])),
            const SizedBox(height: 18),
            Expanded(
              child: !loaded
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: MemoraColors.gold))
                  : (images.isEmpty)
                      ? Center(
                          child: Text(
                              scanning
                                  ? 'Scanning…'
                                  : 'No scans yet. Upload a photo of this room.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: MemoraColors.muted,
                                  fontSize: 12,
                                  height: 1.5)))
                      : ListView(children: [
                          Text('Your photos (${images.length})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                          const SizedBox(height: 4),
                          const Text(
                              'MEMORA remembers what is in them. Ask about them in Ask AI.',
                              style: TextStyle(
                                  fontSize: 11, color: MemoraColors.muted)),
                          const SizedBox(height: 12),
                          for (final im in images) _scanCard(im),
                        ]),
            ),
          ]),
        ),
      ));
}

Future<String?> _promptName(BuildContext context, String title, String hint) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: MemoraColors.panel,
      title: Text(title),
      content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: MemoraColors.gold,
                foregroundColor: const Color(0xFF1C1403)),
            child: const Text('Create')),
      ],
    ),
  );
}

void _toast(BuildContext context, String s) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

class ObjectsScreen extends StatefulWidget {
  const ObjectsScreen({super.key});
  @override
  State<ObjectsScreen> createState() => _ObjectsScreenState();
}

class _ObjectsScreenState extends State<ObjectsScreen> {
  String query = '';
  String filter = 'All';
  final data = [
    (
      'Passport',
      'Bedroom drawer',
      'Today · 8:42 PM',
      Icons.badge_outlined,
      MemoraColors.gold
    ),
    (
      'Camera',
      'Office shelf',
      'Today · 10:42 AM',
      Icons.camera_alt_outlined,
      MemoraColors.cyan
    ),
    (
      'Keys',
      'Entryway table',
      'Yesterday · 7:10 PM',
      Icons.key_outlined,
      MemoraColors.violet
    ),
    (
      'Headphones',
      'Study desk',
      'Yesterday · 5:30 PM',
      Icons.headphones_outlined,
      MemoraColors.success
    ),
    (
      'Travel adapter',
      'Bedroom cabinet',
      'Oct 28 · 8:15 PM',
      Icons.power_outlined,
      MemoraColors.gold
    ),
    (
      'Wallet',
      'Living room',
      'Oct 27 · 9:05 PM',
      Icons.account_balance_wallet_outlined,
      MemoraColors.cyan
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final filtered = data
        .where((e) =>
            (filter == 'All' ||
                (filter == 'Recently seen' && e.$3.startsWith('Today'))) &&
            e.$1.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return _PageFrame(
        title: 'Objects',
        eyebrow: 'VISUAL INVENTORY',
        subtitle:
            'Search your belongings and see where they were last observed.',
        child: Column(children: [
          TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: 'Search objects…')),
          const SizedBox(height: 12),
          Wrap(
              spacing: 8,
              children: ['All', 'Recently seen']
                  .map((f) => ChoiceChip(
                      label: Text(f),
                      selected: filter == f,
                      onSelected: (_) => setState(() => filter = f),
                      selectedColor: MemoraColors.gold.withOpacity(.2)))
                  .toList()),
          const SizedBox(height: 12),
          ...filtered.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: GlassPanel(
                  padding: const EdgeInsets.all(13),
                  child: Row(children: [
                    Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                            color: e.$5.withOpacity(.13),
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(e.$4, color: e.$5)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(e.$1,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800)),
                          Text(e.$2,
                              style: const TextStyle(
                                  fontSize: 10, color: MemoraColors.muted)),
                          Text('Last seen · ${e.$3}',
                              style: const TextStyle(
                                  fontSize: 9, color: MemoraColors.gold))
                        ])),
                    const Icon(Icons.chevron_right, color: MemoraColors.muted)
                  ])))),
        ]));
  }
}

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});
  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List entries = const [];
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final e = await Api.timeline();
      if (mounted)
        setState(() {
          entries = e;
          loaded = true;
        });
    } catch (_) {
      if (mounted) setState(() => loaded = true);
    }
  }

  String _when(dynamic iso) {
    if (iso == null) return '';
    final t = DateTime.tryParse(iso.toString())?.toLocal();
    if (t == null) return '';
    final now = DateTime.now();
    final d = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour < 12 ? 'AM' : 'PM';
    final clock = '$h:$m $ap';
    if (diff == 0) return 'Today · $clock';
    if (diff == 1) return 'Yesterday · $clock';
    const mon = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${mon[t.month - 1]} ${t.day} · $clock';
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
      title: 'Timeline',
      eyebrow: 'YOUR WORLD OVER TIME',
      subtitle:
          'Every scan you add, newest first. Scan a space again later to see how it changed.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1D4568), Color(0xFF153653)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MemoraColors.line),
        ),
        child: !loaded
            ? const Center(
                child: Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: CircularProgressIndicator(color: MemoraColors.cyan)))
            : entries.isEmpty
                ? _empty()
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) =>
                        _entry(entries[index], index == entries.length - 1),
                  ),
      ));

  Widget _empty() => Center(
          child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: const Color(0xFF1D4568),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MemoraColors.line),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.history_rounded, color: MemoraColors.cyan, size: 34),
          SizedBox(height: 14),
          Text('Your timeline is empty',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          SizedBox(height: 7),
          Text(
              'Scan a space and every photo you add builds your memory here \u2014 in order, so you can look back and see what changed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: MemoraColors.muted, fontSize: 12, height: 1.5)),
        ]),
      ));

  Widget _entry(dynamic e, bool last) {
    final space = (e['space'] ?? '').toString();
    final label = (e['label'] ?? '').toString();
    final img = e['image'];
    final status = (e['status'] ?? '').toString();
    final warn = status.contains('warning') || status == 'failed';
    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: MemoraColors.cyan)),
        if (!last)
          Expanded(
              child: Container(
                  width: 2,
                  color: MemoraColors.line,
                  margin: const EdgeInsets.symmetric(vertical: 4))),
      ]),
      const SizedBox(width: 14),
      Expanded(
          child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF23527A), Color(0xFF1A4164)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MemoraColors.line),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_when(e['created_at']),
                            style: const TextStyle(
                                color: MemoraColors.blue,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(space.isEmpty ? 'Scan' : space,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14)),
                        if (label.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(label,
                              style: const TextStyle(
                                  color: MemoraColors.muted, fontSize: 11)),
                        ],
                        if (img != null) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 180,
                                height: 118,
                                color: MemoraColors.panel2,
                                child: Image.network(
                                  Api.frameUrl(img.toString()),
                                  headers: Api.imageHeaders,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: MemoraColors.muted),
                                  ),
                                ),
                              )),
                        ],
                        if (warn) ...[
                          const SizedBox(height: 8),
                          Text(
                              status == 'failed'
                                  ? 'Processing failed'
                                  : 'Saved with warnings',
                              style: const TextStyle(
                                  color: MemoraColors.muted, fontSize: 9)),
                        ],
                      ])))),
    ]));
  }
}

class AskMemoraScreen extends StatefulWidget {
  final Future<bool> Function()? ensureAiConsent;
  const AskMemoraScreen({super.key, this.ensureAiConsent});
  @override
  State<AskMemoraScreen> createState() => _AskMemoraScreenState();
}

class _Msg {
  final bool user;
  final String text;
  final List<String> evidence;
  final double confidence;
  final String language;
  _Msg(
      {required this.user,
      required this.text,
      this.evidence = const [],
      this.confidence = 0.0,
      this.language = ''});
}

class _AskMemoraScreenState extends State<AskMemoraScreen> {
  final controller = TextEditingController();
  final messages = <_Msg>[];
  List spaces = const [];
  List<Map<String, dynamic>> conversations = const [];
  String? sid;
  bool loadingSpaces = true;
  bool sending = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  List<stt.LocaleName> _voiceLocales = const [];
  List<String> _ttsLanguages = const [];
  String? _selectedLocaleId;
  bool _speakReplies = true;
  bool _listening = false;
  bool _speaking = false;
  final suggestions = [
    'Where is my passport?',
    'What changed recently?',
    'Where did I last see my camera?'
  ];

  @override
  void initState() {
    super.initState();
    _loadSpaces();
    _loadVoiceLocales();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    _tts.setStartHandler(() {
      if (mounted) setState(() => _speaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setErrorHandler((error) {
      if (!mounted) return;
      setState(() => _speaking = false);
      _toast(context, 'Could not play the spoken reply: $error');
    });
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.9);
      final languages = await _tts.getLanguages;
      if (!mounted || languages is! List) return;
      setState(() => _ttsLanguages = languages.whereType<String>().toList());
    } catch (error) {
      debugPrint('Could not initialize text-to-speech: $error');
    }
  }

  Future<void> _loadVoiceLocales() async {
    try {
      final locales = await _speech.locales();
      final systemLocale = await _speech.systemLocale();
      if (!mounted) return;
      setState(() {
        _voiceLocales = locales;
        _selectedLocaleId = systemLocale?.localeId;
      });
    } catch (error) {
      debugPrint('Could not load speech recognition locales: $error');
    }
  }

  Future<void> _loadSpaces() async {
    final wid = Session.workspaceId;
    if (wid == null) {
      setState(() => loadingSpaces = false);
      return;
    }
    try {
      final s = await Api.roomsSummary(wid);
      if (!mounted) return;
      setState(() {
        spaces = s;
        if (s.isNotEmpty) sid = s.first['space_id'].toString();
      });
    } catch (_) {
      // Chat history is still loaded even if the workspace has no spaces.
    } finally {
      if (mounted) setState(() => loadingSpaces = false);
    }

    try {
      final history = await Api.chatHistory(wid, Session.chatConversationId);
      final savedConversations = await Api.chatConversations(wid);
      if (!mounted) return;
      setState(() {
        conversations = savedConversations;
        messages
          ..clear()
          ..addAll(history.map((message) => _Msg(
                user: message['role'] == 'user',
                text: (message['content'] ?? '').toString().trim().isEmpty &&
                        message['role'] != 'user'
                    ? "I couldn't generate a reply this time. Please try asking again."
                    : (message['content'] ?? '').toString(),
                evidence: ((message['evidence'] as List?) ?? const [])
                    .map((item) => item.toString())
                    .toList(),
                confidence: (message['confidence'] is num)
                    ? (message['confidence'] as num).toDouble()
                    : 0.0,
                language: (message['language'] ?? '').toString(),
              )));
      });
    } catch (_) {
      // Keep the screen usable if a history request fails.
    }
  }

  String _createConversationId() {
    final random = math.Random.secure();
    final suffix =
        List.generate(24, (_) => random.nextInt(16).toRadixString(16)).join();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}$suffix';
  }

  Future<void> _newChat() async {
    if (sending) return;
    Session.chatConversationId = _createConversationId();
    await Session.save();
    if (!mounted) return;
    setState(() {
      messages.clear();
      controller.clear();
    });
  }

  Future<void> _clearChat() async {
    final wid = Session.workspaceId;
    if (wid == null || sending) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MemoraColors.panel,
        title: const Text('Clear this chat?'),
        content: const Text(
            'Messages in this conversation will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear chat')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await Api.clearChat(wid, Session.chatConversationId);
      if (!mounted) return;
      setState(messages.clear);
      try {
        final savedConversations = await Api.chatConversations(wid);
        if (mounted) setState(() => conversations = savedConversations);
      } catch (error) {
        debugPrint('Could not refresh chat list: $error');
      }
    } catch (error) {
      if (mounted) _toast(context, 'Could not clear chat: $error');
    }
  }

  Future<void> _openConversation(String conversationId) async {
    Session.chatConversationId =
        conversationId == 'legacy' ? null : conversationId;
    await Session.save();
    final wid = Session.workspaceId;
    if (wid == null || !mounted) return;
    try {
      final history = await Api.chatHistory(wid, Session.chatConversationId);
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(history.map((message) => _Msg(
                user: message['role'] == 'user',
                text: (message['content'] ?? '').toString(),
                evidence: ((message['evidence'] as List?) ?? const [])
                    .map((item) => item.toString())
                    .toList(),
                confidence: (message['confidence'] is num)
                    ? (message['confidence'] as num).toDouble()
                    : 0.0,
                language: (message['language'] ?? '').toString(),
              )));
      });
    } catch (error) {
      if (mounted) _toast(context, 'Could not load chat history: $error');
    }
  }

  Future<void> send([String? value, bool speakReply = false]) async {
    final q = (value ?? controller.text).trim();
    if (q.isEmpty) return;
    if (sid == null) {
      _toast(context, 'Scan a space first, then ask about it');
      return;
    }
    if (widget.ensureAiConsent != null &&
        !await widget.ensureAiConsent!.call()) return;
    setState(() {
      messages.add(_Msg(user: true, text: q));
      sending = true;
      controller.clear();
    });
    try {
      final res = await Api.ask(q, conversationId: Session.chatConversationId);
      final ev =
          (res['evidence'] as List?)?.map((e) => e.toString()).toList() ??
              <String>[];
      final conf = (res['confidence'] is num)
          ? (res['confidence'] as num).toDouble()
          : 0.0;
      if (!mounted) return;
      final reply = _Msg(
          user: false,
          text: (res['answer'] ?? '').toString().trim().isEmpty
              ? "I couldn't generate a reply this time. Please try asking again."
              : (res['answer'] ?? '').toString(),
          evidence: ev,
          confidence: conf,
          language: (res['language'] ?? '').toString());
      setState(() => messages.add(reply));
      final wid = Session.workspaceId;
      if (wid != null) {
        try {
          final savedConversations = await Api.chatConversations(wid);
          if (mounted) setState(() => conversations = savedConversations);
        } catch (error) {
          debugPrint('Could not refresh chat list: $error');
        }
      }
      if (_speakReplies || speakReply) await _speak(reply);
    } catch (e) {
      if (mounted) {
        setState(() => messages.add(_Msg(
            user: false,
            text:
                'I could not reach the reasoning model. Is the backend running?')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    bool ok = false;
    try {
      ok = await _speech.initialize(
          onStatus: (st) {
            if ((st == 'done' || st == 'notListening') && mounted) {
              setState(() => _listening = false);
            }
          },
          onError: (_) {});
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      if (mounted) _toast(context, 'Voice input is not available here');
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
        localeId: _selectedLocaleId,
        onResult: (r) {
          controller.text = r.recognizedWords;
          if (r.finalResult && mounted) {
            setState(() => _listening = false);
            if (r.recognizedWords.trim().isNotEmpty) {
              send(r.recognizedWords, true);
            }
          }
        });
  }

  String? _speechOutputLocale(String language) {
    final requested = language.trim().replaceAll('_', '-');
    if (requested.isEmpty || _ttsLanguages.isEmpty) return null;
    for (final available in _ttsLanguages) {
      if (available.toLowerCase() == requested.toLowerCase()) return available;
    }
    final baseLanguage = requested.split('-').first.toLowerCase();
    for (final available in _ttsLanguages) {
      if (available.toLowerCase().split('-').first == baseLanguage) {
        return available;
      }
    }
    return null;
  }

  Future<void> _speak(_Msg message) async {
    if (message.text.trim().isEmpty) return;
    try {
      await _tts.stop();
      final language = message.language.trim().isNotEmpty
          ? message.language.trim()
          : (_selectedLocaleId ?? '');
      final outputLocale = _speechOutputLocale(language);
      if (outputLocale != null) {
        await _tts.setLanguage(outputLocale);
      }
      final result = await _tts.speak(message.text);
      if (result == 0 && mounted) {
        setState(() => _speaking = false);
        _toast(
            context, 'Speech playback did not start. Check your device audio.');
      }
    } catch (error) {
      if (mounted) setState(() => _speaking = false);
      if (mounted) _toast(context, 'Speech playback failed: $error');
    }
  }

  @override
  void dispose() {
    controller.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
      title: 'Ask MEMORA',
      eyebrow: 'YOUR AI MEMORY',
      subtitle:
          'Ask where something is or what changed - answers come with the photo.',
      child: Column(children: [
        Row(children: [
          OutlinedButton.icon(
            onPressed: sending ? null : _newChat,
            icon: const Icon(Icons.add_comment_outlined, size: 17),
            label: const Text('New chat'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: sending || messages.isEmpty ? null : _clearChat,
            icon: const Icon(Icons.delete_outline, size: 17),
            label: const Text('Clear chat'),
          ),
          const Spacer(),
          if (conversations.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Chat history',
              icon: const Icon(Icons.history, color: MemoraColors.cyan),
              onSelected: _openConversation,
              itemBuilder: (context) => [
                for (final conversation in conversations)
                  PopupMenuItem(
                    value: conversation['id'].toString(),
                    child: SizedBox(
                      width: 220,
                      child: Text(
                        conversation['title'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
        ]),
        if (!loadingSpaces && spaces.isNotEmpty)
          Align(
              alignment: Alignment.centerLeft,
              child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MemoraColors.line)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.meeting_room_outlined,
                        size: 15, color: MemoraColors.gold),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                        value: sid,
                        underline: const SizedBox(),
                        dropdownColor: MemoraColors.panel,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.white),
                        items: [
                          for (final sp in spaces)
                            DropdownMenuItem(
                                value: sp['space_id'].toString(),
                                child: Text(sp['name'].toString()))
                        ],
                        onChanged: (v) => setState(() => sid = v)),
                  ]))),
        Expanded(
            child:
                ListView(padding: const EdgeInsets.only(bottom: 12), children: [
          GlassPanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Icon(Icons.auto_awesome,
                    color: MemoraColors.gold, size: 26),
                const SizedBox(height: 8),
                const Text('What would you like to remember?',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Ask about an item or room you have scanned.',
                    style: TextStyle(color: MemoraColors.muted, fontSize: 10)),
                const SizedBox(height: 13),
                Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: suggestions
                        .map((s) => ActionChip(
                            label: Text(s, style: const TextStyle(fontSize: 9)),
                            onPressed: () => send(s)))
                        .toList())
              ])),
          const SizedBox(height: 12),
          ...messages.map(_bubble),
          if (sending)
            const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 8),
                child: Row(children: [
                  SizedBox(width: 6),
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: MemoraColors.gold)),
                  SizedBox(width: 10),
                  Text('MEMORA is looking...',
                      style: TextStyle(color: MemoraColors.muted, fontSize: 11))
                ])),
        ])),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: controller,
                  onSubmitted: (v) => send(v),
                  decoration: const InputDecoration(
                      hintText: 'Ask about your space...',
                      prefixIcon: Icon(Icons.auto_awesome)))),
          IconButton(
              onPressed: () {
                _toggleMic();
              },
              icon: Icon(_listening ? Icons.mic : Icons.mic_none,
                  color: _listening ? MemoraColors.danger : MemoraColors.gold)),
          const SizedBox(width: 4),
          IconButton.filled(
              onPressed: sending
                  ? null
                  : () {
                      send();
                    },
              icon: const Icon(Icons.arrow_upward),
              style: IconButton.styleFrom(
                  backgroundColor: MemoraColors.gold,
                  foregroundColor: Colors.black))
        ]),
        Row(children: [
          const Icon(Icons.language, size: 16, color: MemoraColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButton<String>(
              value: _voiceLocales
                      .any((locale) => locale.localeId == _selectedLocaleId)
                  ? _selectedLocaleId
                  : null,
              hint: const Text('Speech language'),
              underline: const SizedBox(),
              isExpanded: true,
              dropdownColor: MemoraColors.panel,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: [
                for (final locale in _voiceLocales)
                  DropdownMenuItem(
                    value: locale.localeId,
                    child: Text('${locale.name} (${locale.localeId})',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (localeId) =>
                  setState(() => _selectedLocaleId = localeId),
            ),
          ),
          const SizedBox(width: 8),
          const Text('Speak replies',
              style: TextStyle(color: MemoraColors.muted, fontSize: 11)),
          if (_speaking)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.volume_up, color: MemoraColors.gold, size: 17),
            ),
          Switch.adaptive(
            value: _speakReplies,
            activeTrackColor: MemoraColors.gold,
            onChanged: (value) => setState(() => _speakReplies = value),
          ),
        ]),
      ]));

  Widget _bubble(_Msg m) {
    final text = m.text.trim().isEmpty && !m.user
        ? "I couldn't generate a reply this time. Please try asking again."
        : m.text;
    final maxBubbleWidth =
        (MediaQuery.sizeOf(context).width * .88).clamp(180.0, 520.0);
    return Align(
        alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(14),
            constraints: BoxConstraints(
                minWidth: 150, maxWidth: maxBubbleWidth, minHeight: 48),
            decoration: BoxDecoration(
                color:
                    m.user ? const Color(0xFF3A2E14) : const Color(0xFF303039),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: MemoraColors.line)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Arial',
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  if (!m.user)
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Speak reply',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _speak(m),
                        icon: const Icon(Icons.volume_up_outlined,
                            color: MemoraColors.gold, size: 19),
                      ),
                    ),
                  if (!m.user && m.evidence.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (var i = 0; i < m.evidence.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 300,
                          height: 190,
                          color: Colors.black26,
                          alignment: Alignment.center,
                          child: Image.network(
                            Api.frameUrl(m.evidence[i]),
                            headers: Api.imageHeaders,
                            key: ValueKey(m.evidence[i]),
                            width: 300,
                            height: 190,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox(
                                width: 300,
                                height: 190,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: MemoraColors.gold,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(
                              width: 300,
                              height: 190,
                              child: Center(
                                child: Text(
                                  'Image could not be loaded',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (!m.user && m.confidence > 0) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.verified_outlined,
                          size: 13, color: MemoraColors.success),
                      const SizedBox(width: 5),
                      Text('Confidence ${(m.confidence * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 10, color: MemoraColors.muted)),
                    ]),
                  ],
                ])));
  }
}

class MoveMateScreen extends StatelessWidget {
  const MoveMateScreen({super.key});
  @override
  Widget build(BuildContext context) => _PageFrame(
      title: 'MoveMate',
      eyebrow: 'PACKING MEMORY',
      subtitle: 'Scan a box as you pack it, then find anything later.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GlassPanel(
            padding: const EdgeInsets.all(22),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.all_inbox,
                      color: MemoraColors.gold, size: 32),
                  const SizedBox(height: 14),
                  const Text('No boxes yet',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 7),
                  const Text(
                      'Packing to move? Scan each box as you fill it and MEMORA '
                      'will remember what went inside, so you can ask "where are '
                      'my chargers?" after the move.',
                      style: TextStyle(
                          color: MemoraColors.muted,
                          fontSize: 12,
                          height: 1.5)),
                  const SizedBox(height: 18),
                  GlowButton(
                      label: 'Add a box',
                      icon: Icons.add,
                      onPressed: () => _showDemo(context)),
                ])),
      ]));
}

class _DocumentAskDialog extends StatefulWidget {
  final Map<String, dynamic> document;
  const _DocumentAskDialog({required this.document});

  @override
  State<_DocumentAskDialog> createState() => _DocumentAskDialogState();
}

class _DocumentAskDialogState extends State<_DocumentAskDialog> {
  final question = TextEditingController();
  Map<String, dynamic>? result;
  String? error;
  bool busy = false;

  Future<void> _search() async {
    final query = question.text.trim();
    if (query.isEmpty || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      result = await Api.askDocument(widget.document['id'].toString(), query);
    } catch (exception) {
      error = 'Could not search this document: $exception';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: MemoraColors.panel,
        title: Text('Search ${widget.document['name']}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Private local search: document text is not sent to the AI provider.',
                  style: TextStyle(
                      color: MemoraColors.muted, fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: question,
                  autofocus: true,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'What do you want to find?',
                    hintText: 'For example: What is the bill due date?',
                  ),
                  onSubmitted: (_) => _search(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: const TextStyle(
                          color: MemoraColors.danger, fontSize: 11)),
                ],
                if (result != null) ...[
                  const Divider(height: 24),
                  Text(result!['answer'].toString(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 8),
                  ...(result!['passages'] as List? ?? const []).map((item) {
                    final passage = Map<String, dynamic>.from(item as Map);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            passage['section'].toString(),
                            style: const TextStyle(
                                color: MemoraColors.gold, fontSize: 10),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            passage['text'].toString(),
                            style: const TextStyle(
                                color: MemoraColors.muted,
                                fontSize: 11,
                                height: 1.4),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: busy ? null : _search,
            child: Text(busy ? 'Searching…' : 'Search document'),
          ),
        ],
      );
}

class UpkeepScreen extends StatefulWidget {
  const UpkeepScreen({super.key});
  @override
  State<UpkeepScreen> createState() => _UpkeepScreenState();
}

class _UpkeepScreenState extends State<UpkeepScreen> {
  List items = const [];
  List<Map<String, dynamic>> documents = const [];
  bool loaded = false;
  bool uploadingDocument = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([Api.careItems(), Api.documents()]);
      if (mounted)
        setState(() {
          items = results[0];
          documents = results[1] as List<Map<String, dynamic>>;
          loaded = true;
        });
    } catch (error) {
      if (mounted) {
        setState(() => loaded = true);
        _message('Could not load upkeep records: $error');
      }
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final note = TextEditingController();
    final loc = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                backgroundColor: MemoraColors.panel,
                title: const Text('Add an item'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(
                          labelText: 'Name (e.g. Air conditioner)')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: note,
                      decoration: const InputDecoration(
                          labelText: 'Note (warranty, service date, serial…)')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: loc,
                      decoration: const InputDecoration(
                          labelText: 'Where it is (optional)')),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Save')),
                ]));
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await Api.addCareItem(
          name.text.trim(), note.text.trim(), loc.text.trim());
    } catch (_) {}
    if (mounted) _load();
  }

  Future<void> _addDocument() async {
    if (uploadingDocument) return;
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'docx'],
        withData: true,
      );
      if (!mounted || selection == null || selection.xFiles.isEmpty) return;
      final file = selection.xFiles.first;
      final description = TextEditingController();
      String? descriptionError;
      final requiredDescription = await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            backgroundColor: MemoraColors.panel,
            title: const Text('Describe this document'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name,
                    style: const TextStyle(
                        color: MemoraColors.muted, fontSize: 11)),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  autofocus: true,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    labelText: 'Description (required)',
                    hintText: 'What is this document and what should you find?',
                    errorText: descriptionError,
                  ),
                  onChanged: (_) {
                    if (descriptionError != null) {
                      setDialogState(() => descriptionError = null);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (description.text.trim().isEmpty) {
                    setDialogState(
                        () => descriptionError = 'A description is required.');
                    return;
                  }
                  Navigator.pop(dialogContext, description.text.trim());
                },
                child: const Text('Upload'),
              ),
            ],
          ),
        ),
      );
      description.dispose();
      if (requiredDescription == null) return;

      setState(() => uploadingDocument = true);
      await Api.uploadDocument(
        bytes: await file.readAsBytes(),
        filename: file.name,
        description: requiredDescription,
      );
      await _load();
      if (mounted) _message('Document uploaded to this workspace.');
    } catch (error) {
      if (mounted) _message('Could not upload document: $error');
    } finally {
      if (mounted) setState(() => uploadingDocument = false);
    }
  }

  Future<void> _askDocument(Map<String, dynamic> document) =>
      showDialog<void>(
        context: context,
        builder: (_) => _DocumentAskDialog(document: document),
      );

  Future<void> _deleteDocument(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MemoraColors.panel,
        title: const Text('Delete document?'),
        content: const Text(
            'This removes the document and its stored file from the workspace.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Api.deleteDocument(id);
      await _load();
    } catch (error) {
      if (mounted) _message('Could not delete document: $error');
    }
  }

  Future<void> _manageAiPrivacy() async {
    try {
      final consent = await Api.aiPrivacyConsent();
      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: MemoraColors.panel,
          title: const Text('AI privacy settings'),
          content: Text(consent['accepted'] == true
              ? 'You have accepted the image and AI processing notice. You can review it or withdraw your consent.'
              : 'You have not accepted the image and AI processing notice. AI image analysis and Ask MEMORA will remain unavailable until you consent.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'close'),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'policy'),
              child: const Text('Privacy policy'),
            ),
            if (consent['accepted'] == true)
              TextButton(
                onPressed: () => Navigator.pop(context, 'revoke'),
                child: const Text('Withdraw consent'),
              ),
          ],
        ),
      );
      if (action == 'policy' && mounted) {
        await showAiPrivacyPolicy(context);
      } else if (action == 'revoke') {
        await Api.revokeAiPrivacyConsent();
        if (mounted) _message('AI privacy consent withdrawn.');
      }
    } catch (error) {
      if (mounted) _message('Could not load AI privacy settings: $error');
    }
  }

  void _message(String value) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  Future<void> _delete(String id) async {
    try {
      await Api.deleteCareItem(id);
    } catch (_) {}
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
      title: 'Upkeep',
      eyebrow: 'CARE & RECORDS',
      subtitle:
          'Keep household records and private documents in one place.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add an item'),
            ),
            OutlinedButton.icon(
              onPressed: uploadingDocument ? null : _addDocument,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(uploadingDocument ? 'Uploading…' : 'Upload document'),
            ),
            TextButton.icon(
              onPressed: _manageAiPrivacy,
              icon: const Icon(Icons.privacy_tip_outlined),
              label: const Text('AI privacy'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'PDF and DOCX only. A description is required. Document text is searched locally and is not sent to the AI provider; convert legacy .doc files to .docx first.',
          style: TextStyle(color: MemoraColors.muted, fontSize: 10, height: 1.4),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: !loaded
              ? const Center(
                  child: CircularProgressIndicator(color: MemoraColors.gold))
              : ListView(
                  children: [
                    if (documents.isNotEmpty) ...[
                      const Text('Your documents',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      for (final document in documents) ...[
                        _documentTile(document),
                        const SizedBox(height: 8),
                      ],
                    ],
                    const Text('Care items',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      _empty()
                    else
                      for (final item in items) ...[
                        _tile(item),
                        const SizedBox(height: 9),
                      ],
                  ],
                ),
        ),
      ]));

  Widget _empty() => Center(
      child: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: GlassPanel(
              padding: const EdgeInsets.all(26),
              child: Column(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.shield_outlined, color: MemoraColors.gold, size: 34),
                SizedBox(height: 14),
                Text('Nothing saved yet',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                SizedBox(height: 7),
                Text(
                    'Add your appliances, warranties or anything you want to remember to care for. Only what you add shows here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: MemoraColors.muted, fontSize: 12, height: 1.5)),
              ]))));

  Widget _tile(dynamic it) {
    final id = (it['id'] ?? '').toString();
    final name = (it['name'] ?? '').toString();
    final note = (it['note'] ?? '').toString();
    final loc = (it['location'] ?? '').toString();
    return GlassPanel(
        child: Row(children: [
      const Icon(Icons.inventory_2_outlined,
          color: MemoraColors.gold, size: 22),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(note,
              style: const TextStyle(color: MemoraColors.gold, fontSize: 11)),
        ],
        if (loc.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(loc,
              style: const TextStyle(color: MemoraColors.muted, fontSize: 10)),
        ],
      ])),
      IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: MemoraColors.muted, size: 20),
          onPressed: () {
            _delete(id);
          }),
    ]));
  }

  Widget _documentTile(Map<String, dynamic> document) => GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined,
                    color: MemoraColors.cyan, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(document['name'].toString(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                Text(document['file_type'].toString().toUpperCase(),
                    style: const TextStyle(
                        color: MemoraColors.gold, fontSize: 9)),
              ],
            ),
            const SizedBox(height: 6),
            Text(document['description'].toString(),
                style: const TextStyle(
                    color: MemoraColors.muted, fontSize: 11, height: 1.4)),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _askDocument(document),
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text('Ask this document'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete document',
                  onPressed: () => _deleteDocument(document['id'].toString()),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: MemoraColors.muted, size: 19),
                ),
              ],
            ),
          ],
        ),
      );
}

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});
  @override
  Widget build(BuildContext context) => _PageFrame(
      title: 'Family space',
      eyebrow: 'SHARED HOUSEHOLD MEMORY',
      subtitle: 'One shared household account with individual member profiles.',
      child: Column(children: [
        const GlassPanel(
            child: Row(children: [
          Icon(Icons.home_rounded, color: MemoraColors.gold, size: 28),
          SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('The Malik household',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                Text('4 members · Shared home memory',
                    style: TextStyle(color: MemoraColors.muted, fontSize: 10))
              ])),
          Text('Shared',
              style: TextStyle(color: MemoraColors.success, fontSize: 10))
        ])),
        const SizedBox(height: 13),
        const _MemberTile('You', 'Admin', 'KM', MemoraColors.gold),
        const SizedBox(height: 8),
        const _MemberTile('Aarav', 'Member', 'A', MemoraColors.cyan),
        const SizedBox(height: 8),
        const _MemberTile('Meera', 'Member', 'M', MemoraColors.violet),
        const SizedBox(height: 8),
        const _MemberTile('Riya', 'Member', 'R', MemoraColors.success),
        const SizedBox(height: 15),
        GlowButton(
            label: 'Invite family member',
            icon: Icons.person_add_alt_1,
            onPressed: () => _showDemo(context)),
      ]));
}

class BusinessScreen extends StatelessWidget {
  const BusinessScreen({super.key});
  @override
  Widget build(BuildContext context) => _PageFrame(
      title: 'Business workspace',
      eyebrow: 'ASSET & SPACE MEMORY',
      subtitle: 'Track workspaces, equipment and shared inventory.',
      child: Column(children: [
        LayoutBuilder(
            builder: (context, c) =>
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _Metric(
                      c.maxWidth, 'Locations', '3', Icons.location_on_outlined),
                  _Metric(
                      c.maxWidth, 'Assets', '248', Icons.inventory_2_outlined),
                  _Metric(c.maxWidth, 'Team', '12', Icons.groups_outlined)
                ])),
        const SizedBox(height: 13),
        const _BoxTile('Bangalore Office', '148 assets · 6 rooms',
            Icons.business_outlined, MemoraColors.cyan),
        const SizedBox(height: 9),
        const _BoxTile('Studio A', '62 assets · 3 zones',
            Icons.camera_indoor_outlined, MemoraColors.violet),
        const SizedBox(height: 9),
        const _BoxTile('Storage unit', '38 assets · 2 zones',
            Icons.warehouse_outlined, MemoraColors.gold),
        const SizedBox(height: 15),
        GlowButton(
            label: 'Add location',
            icon: Icons.add_location_alt_outlined,
            onPressed: () => _showDemo(context)),
      ]));
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => _PageFrame(
      title: 'Settings',
      eyebrow: 'YOUR ACCOUNT',
      subtitle: 'Manage your profile, privacy and preferences.',
      child: Column(children: [
        _SettingTile(Icons.person_outline, 'Profile',
            'Name, workspace and account details',
            onTap: () => _profileSheet(context)),
        _SettingTile(Icons.shield_outlined, 'Privacy & permissions',
            'How MEMORA captures and shares',
            onTap: () => _infoSheet(context, 'Privacy & permissions', [
                  [
                    'Capture',
                    'Scans stay inside your workspace. Frames are stored only as evidence for your own questions.'
                  ],
                  [
                    'Sharing',
                    'Only people you invite to this workspace can see its memory.'
                  ],
                  [
                    'Your control',
                    'Delete any scan or object at any time to remove it from memory.'
                  ],
                ])),
        _SettingTile(Icons.notifications_none, 'Notifications',
            'Reminders and activity alerts',
            onTap: () => _infoSheet(context, 'Notifications', [
                  [
                    'Maintenance',
                    'Home Guardian reminds you before a warranty or service is due.'
                  ],
                  [
                    'Changes',
                    'Get notified when MEMORA detects something moved or went missing.'
                  ],
                ])),
        _SettingTile(Icons.devices_outlined, 'Devices & access',
            'Your devices and who can see this memory',
            onTap: () => _devicesSheet(context)),
        _SettingTile(
            Icons.help_outline, 'Help & support', 'Guides and contact support',
            onTap: () => _infoSheet(context, 'Help & support', [
                  [
                    'Getting started',
                    'Scan a room, then ask MEMORA where things are or what changed.'
                  ],
                  ['Contact', 'Reach the team at hello@memora.app'],
                ])),
      ]));
}

void _settingsModal(BuildContext context, String title, Widget body) {
  showModalBottomSheet(
    context: context,
    backgroundColor: MemoraColors.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
        child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: MemoraColors.line,
                              borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 16),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  body,
                ]))),
  );
}

void _infoSheet(BuildContext context, String title, List<List<String>> rows) {
  _settingsModal(
      context,
      title,
      Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows
              .map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r[0],
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: MemoraColors.gold)),
                        const SizedBox(height: 4),
                        Text(r[1],
                            style: const TextStyle(
                                color: MemoraColors.muted,
                                fontSize: 12,
                                height: 1.4)),
                      ])))
              .toList()));
}

void _profileSheet(BuildContext context) {
  final type = (Session.workspaceType ?? 'personal');
  _settingsModal(
      context,
      'Profile',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFF273D63),
              child: Icon(Icons.person_outline)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(Session.userName ?? 'You',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                Text('${type[0].toUpperCase()}${type.substring(1)} workspace',
                    style: const TextStyle(
                        color: MemoraColors.muted, fontSize: 12)),
              ])),
        ]),
        if (type != 'personal') ...[
          const SizedBox(height: 18),
          const Text('INVITE CODE',
              style: TextStyle(
                  color: MemoraColors.gold,
                  fontSize: 9,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          FutureBuilder(
            future: Session.workspaceId == null
                ? null
                : Api.invite(Session.workspaceId!),
            builder: (c, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Text('Loading…',
                    style: TextStyle(color: MemoraColors.muted, fontSize: 12));
              }
              final code = (snap.data as Map?)?['invite_code']?.toString();
              if (code == null)
                return const Text('Unavailable',
                    style: TextStyle(color: MemoraColors.muted, fontSize: 12));
              return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MemoraColors.line)),
                  child: Text(code,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 3)));
            },
          ),
          const SizedBox(height: 6),
          Text(
              type == 'family'
                  ? 'Share this code so family can join the same account.'
                  : 'Share this code to add teammates to this workspace.',
              style: const TextStyle(color: MemoraColors.muted, fontSize: 11)),
        ],
      ]));
}

void _devicesSheet(BuildContext context) {
  final type = (Session.workspaceType ?? 'personal');
  _settingsModal(
      context,
      'Devices & access',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GlassPanel(
            child: Row(children: const [
          Icon(Icons.phone_iphone, color: MemoraColors.success),
          SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('This device',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                Text('Active now · signed in',
                    style: TextStyle(color: MemoraColors.muted, fontSize: 10)),
              ])),
          Icon(Icons.check_circle, color: MemoraColors.success, size: 18),
        ])),
        if (type != 'personal') ...[
          const SizedBox(height: 16),
          const Text('PEOPLE WITH ACCESS',
              style: TextStyle(
                  color: MemoraColors.gold,
                  fontSize: 9,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          FutureBuilder<List>(
            future: Session.workspaceId == null
                ? Future.value(const [])
                : Api.members(Session.workspaceId!),
            builder: (c, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Text('Loading…',
                    style: TextStyle(color: MemoraColors.muted, fontSize: 12));
              }
              final list = snap.data ?? const [];
              if (list.isEmpty)
                return const Text(
                    'No one else yet. Share your invite code to add people.',
                    style: TextStyle(color: MemoraColors.muted, fontSize: 12));
              return Column(
                  children: list.map((m) {
                final mm = m as Map;
                return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.account_circle_outlined,
                          color: MemoraColors.cyan, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              mm['name']?.toString() ??
                                  mm['email']?.toString() ??
                                  'Member',
                              style: const TextStyle(fontSize: 12))),
                      Text(mm['role']?.toString() ?? '',
                          style: const TextStyle(
                              color: MemoraColors.muted, fontSize: 10)),
                    ]));
              }).toList());
            },
          ),
        ] else ...[
          const SizedBox(height: 10),
          const Text(
              'Your memory is private to this device and account. Upgrade to a Family or Business workspace to sync across devices and people.',
              style: TextStyle(
                  color: MemoraColors.muted, fontSize: 11, height: 1.4)),
        ],
      ]));
}

class _PageFrame extends StatelessWidget {
  final String title, eyebrow, subtitle;
  final Widget child;
  const _PageFrame(
      {required this.title,
      required this.eyebrow,
      required this.subtitle,
      required this.child});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(eyebrow,
            style: const TextStyle(
                color: MemoraColors.gold,
                fontSize: 9,
                letterSpacing: 2,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        Text(title,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(subtitle,
            style: const TextStyle(color: MemoraColors.muted, fontSize: 11)),
        const SizedBox(height: 18),
        Expanded(child: child),
      ]));
}

class _BoxTile extends StatelessWidget {
  final String title, detail;
  final IconData icon;
  final Color color;
  const _BoxTile(this.title, this.detail, this.icon, this.color);
  @override
  Widget build(BuildContext context) => GlassPanel(
      onTap: () => _infoSheet(context, title, [
            ['Contents', detail],
            ['Where', 'Saved in your workspace'],
            ['Tip', 'Open or scan this to update what is inside.']
          ]),
      child: Row(children: [
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: color.withOpacity(.14),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
          Text(detail,
              style: const TextStyle(color: MemoraColors.muted, fontSize: 9))
        ])),
        const Icon(Icons.chevron_right, color: MemoraColors.muted)
      ]));
}

class _MemberTile extends StatelessWidget {
  final String name, role, initial;
  final Color color;
  const _MemberTile(this.name, this.role, this.initial, this.color);
  @override
  Widget build(BuildContext context) => GlassPanel(
      onTap: () => _infoSheet(context, name, [
            ['Role', role],
            ['Access', 'Shares this workspace memory.']
          ]),
      child: Row(children: [
        CircleAvatar(
            backgroundColor: color.withOpacity(.2),
            child: Text(initial,
                style: TextStyle(color: color, fontWeight: FontWeight.w800))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
          Text(role,
              style: const TextStyle(color: MemoraColors.muted, fontSize: 9))
        ])),
        const Icon(Icons.verified_user_outlined,
            color: MemoraColors.success, size: 17)
      ]));
}

class _Metric extends StatelessWidget {
  final double width;
  final String label, value;
  final IconData icon;
  const _Metric(this.width, this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => SizedBox(
      width: width > 700
          ? (width - 20) / 3
          : width > 430
              ? (width - 10) / 2
              : width,
      child: GlassPanel(
          child: Row(children: [
        Icon(icon, color: MemoraColors.gold),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          Text(label,
              style: const TextStyle(color: MemoraColors.muted, fontSize: 9))
        ])
      ])));
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  const _SettingTile(this.icon, this.title, this.subtitle, {this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GlassPanel(
          onTap: onTap,
          child: Row(children: [
            Icon(icon, color: MemoraColors.gold),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 11)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: MemoraColors.muted, fontSize: 9))
                ])),
            const Icon(Icons.chevron_right, color: MemoraColors.muted)
          ])));
}

void _showDemo(BuildContext context) =>
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Demo interaction — connect this action to your backend.')));
