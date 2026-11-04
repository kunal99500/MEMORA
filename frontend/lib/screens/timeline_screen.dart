import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../core/app_theme.dart';
import '../services/api_service.dart';
import '../services/session.dart';

class TimelineScreen extends StatefulWidget {
  final Future<void> Function()? onMediaUploaded;
  final Future<bool> Function()? ensureAiConsent;
  const TimelineScreen(
      {super.key, this.onMediaUploaded, this.ensureAiConsent});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Map<String, dynamic>> timelines = const [];
  List spaces = const [];
  List entries = const [];
  String? selectedTimelineId;
  String? error;
  bool loading = true;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? preferTimelineId}) async {
    final workspaceId = Session.workspaceId;
    if (workspaceId == null) {
      setState(() {
        loading = false;
        error = 'Sign in to manage timelines.';
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        Api.timelines(workspaceId),
        Api.spaces(workspaceId),
      ]);
      final availableTimelines = results[0] as List<Map<String, dynamic>>;
      final availableSpaces = results[1];
      final preferred = preferTimelineId ?? selectedTimelineId;
      final selected = availableTimelines
              .any((timeline) => timeline['id'].toString() == preferred)
          ? preferred
          : availableTimelines.isEmpty
              ? null
              : availableTimelines.first['id'].toString();
      final timelineEntries = selected == null
          ? <dynamic>[]
          : await Api.timeline(timelineId: selected);
      if (!mounted) return;
      setState(() {
        timelines = availableTimelines;
        spaces = availableSpaces;
        selectedTimelineId = selected;
        entries = timelineEntries;
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load timelines: $exception';
      });
    }
  }

  Future<void> _selectTimeline(String? id) async {
    if (id == null) return;
    setState(() {
      selectedTimelineId = id;
      loading = true;
      error = null;
    });
    try {
      final timelineEntries = await Api.timeline(timelineId: id);
      if (!mounted) return;
      setState(() {
        entries = timelineEntries;
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not open this timeline: $exception';
      });
    }
  }

  Future<void> _startTimeline() async {
    final selection = await showDialog<_TimelineStartSelection>(
      context: context,
      builder: (_) => _TimelineStartDialog(spaces: spaces),
    );
    if (selection == null) return;
    final workspaceId = Session.workspaceId;
    if (workspaceId == null) return;
    try {
      var locationId = selection.locationId;
      if (selection.createSpace) {
        final space = await Api.createSpace(
          workspaceId,
          selection.spaceName,
          type: selection.spaceType,
        );
        locationId = space['space_id'].toString();
      }
      final timeline = await Api.createTimeline(
        workspaceId,
        locationId!,
        selection.timelineName,
      );
      await _load(preferTimelineId: timeline['id'].toString());
    } catch (exception) {
      if (mounted) _showMessage('Could not start timeline: $exception');
    }
  }

  Future<void> _addMedia({
    required bool video,
    required ImageSource source,
  }) async {
    final timelineId = selectedTimelineId;
    final timeline = timelines
        .where((item) => item['id'].toString() == timelineId)
        .firstOrNull;
    if (timeline == null || uploading) return;
    if (widget.ensureAiConsent != null &&
        !await widget.ensureAiConsent!.call()) return;
    try {
      final picker = ImagePicker();
      final file = video
          ? await picker.pickVideo(source: source)
          : await picker.pickImage(source: source, imageQuality: 95);
      if (file == null) return;
      setState(() => uploading = true);
      final bytes = await file.readAsBytes();
      if (bytes.length > 50 * 1024 * 1024) {
        throw const FormatException(
            'This file is larger than the 50 MB upload limit.');
      }
      var gallerySaved = true;
      final supportsGallerySave = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      if (source == ImageSource.camera && supportsGallerySave) {
        try {
          if (video) {
            await Gal.putVideo(file.path);
          } else {
            await Gal.putImage(file.path);
          }
        } on GalException catch (exception) {
          gallerySaved = false;
          if (mounted) {
            _showMessage(
                'Media will be added to the timeline, but could not be saved to your gallery: ${exception.type.message}');
          }
        }
      }
      await Api.uploadTimelineMedia(
        timelineId: timelineId!,
        locationId: timeline['location_id'].toString(),
        name: file.name,
        filename: video ? file.name : _jpegFilename(file.name),
        bytes: video ? bytes : _serverImageCopy(bytes),
      );
      if (!mounted) return;
      _showMessage(gallerySaved
          ? 'Added to ${timeline['name']} timeline.'
          : 'Added to ${timeline['name']} timeline; gallery save failed.');
      await _load(preferTimelineId: timelineId);
      await widget.onMediaUploaded?.call();
    } catch (exception) {
      if (mounted) _showMessage('Could not upload media: $exception');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  String _jpegFilename(String originalName) {
    final withoutExtension = originalName.contains('.')
        ? originalName.substring(0, originalName.lastIndexOf('.'))
        : originalName;
    return '$withoutExtension.jpg';
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

  Future<void> _deleteEntry(dynamic entry) async {
    final captureId = (entry['capture_id'] ?? '').toString();
    if (captureId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MemoraColors.panel,
        title: const Text('Delete this timeline item?'),
        content: const Text('Its uploaded photo or video will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Api.deleteTimelineEntry(captureId);
      await _load(preferTimelineId: selectedTimelineId);
    } catch (exception) {
      if (mounted) _showMessage('Could not delete timeline item: $exception');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _when(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour < 12 ? 'AM' : 'PM';
    return '${date.month}/${date.day}/${date.year} · $hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final selected = timelines
        .where((item) => item['id'].toString() == selectedTimelineId)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YOUR WORLD OVER TIME',
              style: TextStyle(
                  color: MemoraColors.gold,
                  fontSize: 9,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text('Timeline',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text(
              'Start when you are ready. Add photos or videos directly to a room, garden, or any space.',
              style: TextStyle(color: MemoraColors.muted, fontSize: 11)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (timelines.isNotEmpty)
                DropdownButton<String>(
                  value: selectedTimelineId,
                  dropdownColor: MemoraColors.panel,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final timeline in timelines)
                      DropdownMenuItem(
                        value: timeline['id'].toString(),
                        child:
                            Text('${timeline['name']} · ${timeline['space']}'),
                      ),
                  ],
                  onChanged: _selectTimeline,
                ),
              OutlinedButton.icon(
                onPressed: _startTimeline,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Start timeline'),
              ),
              if (selected != null) ...[
                IconButton(
                  tooltip: 'Refresh timeline',
                  onPressed: loading || uploading
                      ? null
                      : () => _load(preferTimelineId: selectedTimelineId),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () =>
                          _addMedia(video: false, source: ImageSource.gallery),
                  icon:
                      const Icon(Icons.add_photo_alternate_outlined, size: 17),
                  label: const Text('Upload image'),
                ),
                OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () =>
                          _addMedia(video: true, source: ImageSource.gallery),
                  icon: const Icon(Icons.video_library_outlined, size: 17),
                  label: const Text('Upload video'),
                ),
                OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () =>
                          _addMedia(video: false, source: ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 17),
                  label: const Text('Capture image'),
                ),
                OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () =>
                          _addMedia(video: true, source: ImageSource.camera),
                  icon: const Icon(Icons.videocam_outlined, size: 17),
                  label: const Text('Record video'),
                ),
              ],
              if (uploading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: MemoraColors.cyan),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
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
              child: error != null
                  ? Center(
                      child: Text(error!,
                          style: const TextStyle(color: MemoraColors.danger)))
                  : loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: MemoraColors.cyan))
                      : timelines.isEmpty
                          ? _empty(
                              'Start a space timeline',
                              'Choose an existing space or create one, then upload photos and videos here.',
                              Icons.history_rounded)
                          : entries.isEmpty
                              ? _empty(
                                  'Your timeline is ready',
                                  'Add a photo or video to begin tracking ${selected?['space'] ?? 'this space'} over time.',
                                  Icons.collections_bookmark_outlined)
                              : ListView.builder(
                                  itemCount: entries.length,
                                  itemBuilder: (context, index) => _entry(
                                      entries[index],
                                      index == entries.length - 1),
                                ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String title, String subtitle, IconData icon) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: const Color(0xFF1D4568),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MemoraColors.line),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: MemoraColors.cyan, size: 34),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 7),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: MemoraColors.muted, fontSize: 12, height: 1.5)),
          ]),
        ),
      );

  Widget _entry(dynamic entry, bool last) {
    final status = (entry['status'] ?? '').toString();
    final mediaType = (entry['media_type'] ?? 'photo').toString();
    final image = entry['image'];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 18),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: MemoraColors.cyan),
            ),
            if (!last)
              Expanded(
                  child: Container(
                      width: 2,
                      color: MemoraColors.line,
                      margin: const EdgeInsets.symmetric(vertical: 4))),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: last ? 0 : 12),
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
                  Row(children: [
                    Expanded(
                      child: Text(
                        (entry['label'] ?? mediaType).toString(),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete timeline item',
                      onPressed: () => _deleteEntry(entry),
                      icon: const Icon(Icons.delete_outline),
                      color: MemoraColors.muted,
                    ),
                  ]),
                  Text(_when(entry['created_at']),
                      style: const TextStyle(
                          color: MemoraColors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                  if (image != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          Api.frameUrl(image.toString()),
                          headers: Api.imageHeaders,
                          width: 240,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _mediaPlaceholder(
                              mediaType, 'Preview unavailable'),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _mediaPlaceholder(
                        mediaType,
                        status == 'failed'
                            ? 'Processing failed'
                            : status == 'queued' || status == 'processing'
                                ? 'Processing upload…'
                                : 'Media saved',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaPlaceholder(String mediaType, String message) => Container(
        width: 240,
        height: 110,
        decoration: BoxDecoration(
          color: MemoraColors.panel2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            mediaType == 'video'
                ? Icons.videocam_outlined
                : Icons.image_outlined,
            color: MemoraColors.cyan,
            size: 30,
          ),
          const SizedBox(height: 6),
          Text(message,
              style: const TextStyle(color: MemoraColors.muted, fontSize: 10)),
        ]),
      );
}

class _TimelineStartSelection {
  final String? locationId;
  final String timelineName;
  final bool createSpace;
  final String spaceName;
  final String spaceType;

  const _TimelineStartSelection({
    required this.locationId,
    required this.timelineName,
    required this.createSpace,
    required this.spaceName,
    required this.spaceType,
  });
}

class _TimelineStartDialog extends StatefulWidget {
  final List spaces;
  const _TimelineStartDialog({required this.spaces});

  @override
  State<_TimelineStartDialog> createState() => _TimelineStartDialogState();
}

class _TimelineStartDialogState extends State<_TimelineStartDialog> {
  late final TextEditingController _spaceName;
  late final TextEditingController _timelineName;
  String? _locationId;
  String _spaceType = 'room';
  bool _createSpace = false;

  @override
  void initState() {
    super.initState();
    _spaceName = TextEditingController(
      text: widget.spaces.isEmpty ? '' : widget.spaces.first['name'].toString(),
    );
    _timelineName = TextEditingController();
    _locationId =
        widget.spaces.isEmpty ? null : widget.spaces.first['id'].toString();
    _createSpace = widget.spaces.isEmpty;
  }

  @override
  void dispose() {
    _spaceName.dispose();
    _timelineName.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _createSpace
        ? _spaceName.text.trim()
        : widget.spaces
            .where((space) => space['id'].toString() == _locationId)
            .map((space) => space['name'].toString())
            .firstOrNull;
    if (name == null ||
        name.isEmpty ||
        (!_createSpace && _locationId == null)) {
      return;
    }
    Navigator.pop(
      context,
      _TimelineStartSelection(
        locationId: _createSpace ? null : _locationId,
        timelineName: _timelineName.text.trim().isEmpty
            ? '$name timeline'
            : _timelineName.text.trim(),
        createSpace: _createSpace,
        spaceName: name,
        spaceType: _spaceType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: MemoraColors.panel,
        title: const Text('Start a timeline'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_createSpace)
                DropdownButtonFormField<String>(
                  initialValue: _locationId,
                  decoration: const InputDecoration(labelText: 'Space'),
                  items: [
                    for (final space in widget.spaces)
                      DropdownMenuItem(
                        value: space['id'].toString(),
                        child: Text(space['name'].toString()),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _locationId = value;
                      final selected = widget.spaces
                          .where((space) => space['id'].toString() == value)
                          .firstOrNull;
                      if (selected != null) {
                        _spaceName.text = selected['name'].toString();
                      }
                    });
                  },
                )
              else ...[
                TextField(
                  controller: _spaceName,
                  decoration: const InputDecoration(
                      labelText: 'New space name',
                      hintText: 'e.g. Garden, Workshop'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _spaceType,
                  decoration: const InputDecoration(labelText: 'Space type'),
                  items: const [
                    DropdownMenuItem(value: 'room', child: Text('Room')),
                    DropdownMenuItem(value: 'garden', child: Text('Garden')),
                    DropdownMenuItem(value: 'garage', child: Text('Garage')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _spaceType = value);
                  },
                ),
              ],
              if (widget.spaces.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _createSpace = !_createSpace;
                      if (!_createSpace) {
                        _locationId = widget.spaces.first['id'].toString();
                        _spaceName.text =
                            widget.spaces.first['name'].toString();
                      }
                    }),
                    child: Text(_createSpace
                        ? 'Choose existing space'
                        : 'Create a space'),
                  ),
                ),
              TextField(
                controller: _timelineName,
                decoration: const InputDecoration(
                    labelText: 'Timeline name (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start'),
          ),
        ],
      );
}
