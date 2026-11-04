import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/memora_models.dart';
import '../widgets/glass.dart';
import '../widgets/illustrations.dart';
import '../services/api_service.dart';
import '../services/session.dart';

class DashboardScreen extends StatefulWidget {
  final AccountMode mode;
  final ValueChanged<int> onNavigate;
  const DashboardScreen(
      {super.key, required this.mode, required this.onNavigate});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? stats;
  List rooms = const [];
  bool loaded = false;

  AccountMode get mode => widget.mode;
  ValueChanged<int> get onNavigate => widget.onNavigate;

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
      final results = await Future.wait([
        Api.stats(wid),
        Api.roomsSummary(wid),
      ]);
      final s = results[0] as Map<String, dynamic>;
      final r = results[1] as List;
      if (mounted) {
        setState(() {
          stats = s;
          rooms = r;
          loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loaded = true);
    }
  }

  String _n(String key) {
    final v = stats?[key];
    return v == null ? '—' : '$v';
  }

  int _i(String key) => (stats?[key] as int?) ?? 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 850;
    final title = mode == AccountMode.family
        ? 'Your family memory'
        : mode == AccountMode.business
            ? 'Workspace overview'
            : 'Your memory at a glance';
    final fourthLabel = mode == AccountMode.personal ? 'Scans' : 'Members';
    final fourthKey = mode == AccountMode.personal ? 'scans' : 'members';

    return RefreshIndicator(
      color: MemoraColors.gold,
      backgroundColor: MemoraColors.panel,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      'Hello${Session.userName != null ? ', ${Session.userName}' : ''}',
                      style: const TextStyle(
                          color: MemoraColors.muted, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                ])),
            GlowButton(
                label: 'Scan a space',
                icon: Icons.document_scanner_outlined,
                onPressed: () => onNavigate(1)),
          ]),
          const SizedBox(height: 18),
          LayoutBuilder(
              builder: (context, c) =>
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    _stat(c.maxWidth, 'Spaces', _n('rooms'),
                        Icons.home_work_outlined, MemoraColors.cyan),
                    _stat(c.maxWidth, 'Photos', _n('scans'),
                        Icons.photo_library_outlined, MemoraColors.gold),
                    if (mode != AccountMode.personal)
                      _stat(c.maxWidth, fourthLabel, _n(fourthKey),
                          Icons.people_outline, MemoraColors.success),
                  ])),
          const SizedBox(height: 22),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 7, child: _homeCard(context)),
              const SizedBox(width: 14),
              Expanded(flex: 5, child: _askCard(context)),
            ])
          else
            Column(children: [
              _homeCard(context),
              const SizedBox(height: 14),
              _askCard(context)
            ]),
          const SizedBox(height: 22),
          Row(children: [
            const Expanded(
                child: Text('Your spaces',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            if (rooms.isNotEmpty)
              TextButton(
                  onPressed: () => onNavigate(1),
                  child: const Text('View all')),
          ]),
          const SizedBox(height: 4),
          _spacesSection(),
          const SizedBox(height: 22),
          const Text('Recent activity',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _activitySection(),
        ]),
      ),
    );
  }

  Widget _spacesSection() {
    if (!loaded) return _skeletonRow();
    if (rooms.isEmpty) {
      return _emptyCard(Icons.add_home_outlined, 'No spaces yet',
          'Scan your first room and MEMORA will start remembering what is in it.',
          action: 'Scan a space', onTap: () => onNavigate(1));
    }
    return LayoutBuilder(
        builder: (context, c) => Wrap(spacing: 12, runSpacing: 12, children: [
              for (int i = 0; i < rooms.length; i++)
                _roomCard(
                    c.maxWidth,
                    (rooms[i]['name'] ?? 'Space').toString(),
                    '${rooms[i]['image_count'] ?? 0} photos',
                    _roomIcons[i % _roomIcons.length],
                    _roomColors[i % _roomColors.length]),
            ]));
  }

  Widget _activitySection() {
    if (!loaded) return _skeletonRow(height: 60);
    final withScans = rooms.where((r) => r['last_scan'] != null).toList();
    if (withScans.isEmpty) {
      return _emptyCard(Icons.history_toggle_off_outlined, 'Nothing yet',
          'Your recent scans will show up here.');
    }
    return GlassPanel(
        child: Column(children: [
      for (int i = 0; i < withScans.length && i < 4; i++) ...[
        if (i > 0) const Divider(color: MemoraColors.line),
        _Activity(
            icon: Icons.document_scanner_outlined,
            title: '${withScans[i]['name']} scanned',
            subtitle: '${withScans[i]['last_scan']}',
            color: MemoraColors.cyan),
      ]
    ]));
  }

  Widget _emptyCard(IconData icon, String title, String body,
          {String? action, VoidCallback? onTap}) =>
      GlassPanel(
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            Icon(icon, color: MemoraColors.gold, size: 30),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: MemoraColors.muted, fontSize: 11, height: 1.5)),
            if (action != null) ...[
              const SizedBox(height: 16),
              GlowButton(
                  label: action,
                  icon: Icons.document_scanner_outlined,
                  onPressed: onTap ?? () {}),
            ]
          ]));

  Widget _skeletonRow({double height = 72}) => Row(children: [
        Expanded(child: _skel(height)),
        const SizedBox(width: 12),
        Expanded(child: _skel(height)),
      ]);
  Widget _skel(double h) => Container(
      height: h,
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(.035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MemoraColors.line)));

  static const _roomIcons = [
    Icons.weekend_outlined,
    Icons.bed_outlined,
    Icons.kitchen_outlined,
    Icons.desk_outlined,
    Icons.chair_outlined,
    Icons.meeting_room_outlined,
  ];
  static const _roomColors = [
    MemoraColors.cyan,
    MemoraColors.violet,
    MemoraColors.gold,
    MemoraColors.success,
    MemoraColors.blue,
  ];

  Widget _stat(double width, String label, String value, IconData icon,
          Color color) =>
      SizedBox(
          width: width > 850
              ? (width - 36) / 4
              : width > 500
                  ? (width - 12) / 2
                  : width,
          child: GlassPanel(
              padding: const EdgeInsets.all(15),
              child: Row(children: [
                Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                        color: color.withOpacity(.12),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: color, size: 19)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(value,
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w900)),
                      Text(label,
                          style: const TextStyle(
                              fontSize: 9, color: MemoraColors.muted),
                          overflow: TextOverflow.ellipsis)
                    ]))
              ])));

  Widget _homeCard(BuildContext context) {
    final summary = !loaded
        ? 'Loading…'
        : (_i('rooms') == 0
            ? 'No photos yet'
            : '${_i('rooms')} spaces · ${_i('scans')} photos');
    return GlassPanel(
        tint: MemoraColors.blue,
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.home_work_outlined, color: MemoraColors.gold),
            SizedBox(width: 8),
            Text('Home overview', style: TextStyle(fontWeight: FontWeight.w800))
          ]),
          const SizedBox(height: 5),
          const Text('Your latest space memory',
              style: TextStyle(color: MemoraColors.muted, fontSize: 10)),
          const FloatingHomeIllustration(height: 210),
          Row(children: [
            const Icon(Icons.circle, size: 7, color: MemoraColors.success),
            const SizedBox(width: 6),
            Text(
                loaded && _i('rooms') > 0
                    ? 'Updated recently'
                    : 'Ready to scan',
                style: const TextStyle(fontSize: 9, color: MemoraColors.muted)),
            const Spacer(),
            Text(summary,
                style: const TextStyle(fontSize: 9, color: MemoraColors.gold))
          ])
        ]));
  }

  Widget _askCard(BuildContext context) => GlassPanel(
      padding: const EdgeInsets.all(17),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.auto_awesome, color: MemoraColors.gold),
          SizedBox(width: 8),
          Text('Ask MEMORA', style: TextStyle(fontWeight: FontWeight.w800))
        ]),
        const SizedBox(height: 12),
        const Text('What would you like to remember?',
            style: TextStyle(color: MemoraColors.muted, fontSize: 11)),
        const SizedBox(height: 12),
        ...[
          'Where is my passport?',
          'What changed this week?',
          'Where did I keep the camera?'
        ].map((q) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: InkWell(
                onTap: () => onNavigate(3),
                child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.045),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: MemoraColors.line)),
                    child: Row(children: [
                      Expanded(
                          child: Text(q, style: const TextStyle(fontSize: 10))),
                      const Icon(Icons.arrow_outward,
                          size: 13, color: MemoraColors.gold)
                    ]))))),
        const SizedBox(height: 5),
        GlowButton(
            label: 'Ask a question',
            icon: Icons.auto_awesome,
            onPressed: () => onNavigate(3))
      ]));

  Widget _roomCard(double width, String name, String count, IconData icon,
          Color color) =>
      SizedBox(
          width: width > 850
              ? (width - 36) / 4
              : width > 500
                  ? (width - 12) / 2
                  : width,
          child: GlassPanel(
              onTap: () => onNavigate(1),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: color.withOpacity(.13),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: color)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800)),
                      Text(count,
                          style: const TextStyle(
                              fontSize: 9, color: MemoraColors.muted))
                    ]))
              ])));
}

class _Activity extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _Activity(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          Text(subtitle,
              style: const TextStyle(fontSize: 9, color: MemoraColors.muted))
        ])),
        const Icon(Icons.chevron_right, color: MemoraColors.muted, size: 18)
      ]));
}
