import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../widgets/glass.dart';
import '../services/api_service.dart';

class CameraMemoryScreen extends StatefulWidget {
  final Future<bool> Function()? ensureAiConsent;
  const CameraMemoryScreen({super.key, this.ensureAiConsent});
  @override
  State<CameraMemoryScreen> createState() => _CameraMemoryScreenState();
}

class _CameraMemoryScreenState extends State<CameraMemoryScreen> {
  List cameras = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final rows = await Api.cameras();
      if (mounted) setState(() { cameras = rows; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final ref = TextEditingController();
    String protocol = 'rtsp';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: MemoraColors.panel,
        title: const Text('Connect a camera'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Camera name', hintText: 'Garage camera')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: protocol,
            decoration: const InputDecoration(labelText: 'Connection type'),
            items: const [
              DropdownMenuItem(value: 'rtsp', child: Text('RTSP / RTSPS')),
              DropdownMenuItem(value: 'onvif', child: Text('ONVIF')),
              DropdownMenuItem(value: 'vendor_api', child: Text('Manufacturer API')),
            ],
            onChanged: (v) => setLocal(() => protocol = v ?? 'rtsp'),
          ),
          const SizedBox(height: 12),
          TextField(controller: ref, decoration: const InputDecoration(
            labelText: 'Secret reference (optional)',
            hintText: 'vault://home/garage-camera',
            helperText: 'Do not paste a camera password or raw stream URL here.',
          )),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save camera')),
        ],
      ),
    ));
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await Api.addCamera(name: name.text.trim(), protocol: protocol, connectionRef: ref.text.trim());
      await _load();
    } catch (e) { if (mounted) _message(e.toString()); }
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('LIVE MEMORY', style: TextStyle(color: MemoraColors.gold, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text('Connected cameras', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          SizedBox(height: 5),
          Text('Bring compatible home and office cameras into your visual memory.',
            style: TextStyle(color: MemoraColors.muted, fontSize: 12)),
        ])),
        GlowButton(label: 'Add camera', icon: Icons.add_rounded, onPressed: _add),
      ]),
      const SizedBox(height: 20),
      GlassPanel(padding: const EdgeInsets.all(16), child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(
          color: MemoraColors.gold.withOpacity(.12), borderRadius: BorderRadius.circular(13)),
          child: const Icon(Icons.shield_moon_outlined, color: MemoraColors.gold)),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Privacy-first connection', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Camera passwords are not stored by this registry. Use a secret-manager reference for stream credentials.',
            style: TextStyle(color: MemoraColors.muted, fontSize: 11, height: 1.4)),
        ])),
      ])),
      const SizedBox(height: 16),
      Expanded(child: loading ? const Center(child: CircularProgressIndicator(color: MemoraColors.gold))
        : error != null ? Center(child: Text(error!, style: const TextStyle(color: MemoraColors.muted)))
        : cameras.isEmpty ? Center(child: GlassPanel(padding: const EdgeInsets.all(28), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam_outlined, size: 42, color: MemoraColors.gold),
            const SizedBox(height: 12),
            const Text('No cameras connected', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Add a compatible camera to register it with this workspace.',
              textAlign: TextAlign.center, style: TextStyle(color: MemoraColors.muted, fontSize: 12)),
            const SizedBox(height: 16),
            GlowButton(label: 'Connect first camera', icon: Icons.add, onPressed: _add),
          ],
        )))
        : ListView.separated(itemCount: cameras.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final c = cameras[i] as Map;
            final enabled = c['enabled'] == true;
            return GlassPanel(padding: const EdgeInsets.all(15), child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(
                color: MemoraColors.cyan.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.videocam_outlined, color: MemoraColors.cyan)),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c['name'] ?? 'Camera'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${(c['protocol'] ?? 'rtsp').toString().toUpperCase()} · ${c['status'] ?? 'configured'}',
                  style: const TextStyle(color: MemoraColors.muted, fontSize: 10)),
              ])),
              IconButton(tooltip: 'Start stream ingestion',
                onPressed: enabled ? () async {
                  if (widget.ensureAiConsent != null &&
                      !await widget.ensureAiConsent!.call()) return;
                  try { await Api.startCamera('${c['id']}'); _message('Camera worker starting'); await _load(); }
                  catch (e) { _message(e.toString()); }
                } : null,
                icon: const Icon(Icons.play_circle_fill_outlined, color: MemoraColors.cyan)),
              IconButton(tooltip: 'Stop stream ingestion',
                onPressed: () async {
                  try { await Api.stopCamera('${c['id']}'); _message('Camera worker stopping'); await _load(); }
                  catch (e) { _message(e.toString()); }
                },
                icon: const Icon(Icons.stop_circle_outlined, color: MemoraColors.gold)),
              IconButton(tooltip: enabled ? 'Pause camera' : 'Enable camera',
                onPressed: () async { await Api.setCameraPaused('${c['id']}', enabled); await _load(); },
                icon: Icon(enabled ? Icons.pause_circle_outline : Icons.play_circle_outline, color: MemoraColors.gold)),
              IconButton(tooltip: 'Remove camera', onPressed: () async {
                await Api.deleteCamera('${c['id']}'); await _load();
              }, icon: const Icon(Icons.delete_outline, color: MemoraColors.danger)),
            ]));
          })),
    ]),
  );
}
