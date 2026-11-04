import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/memora_models.dart';
import '../widgets/glass.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import 'landing_screen.dart';
import 'account_setup_screen.dart';
import 'dashboard_screen.dart';
import 'feature_screens.dart' hide TimelineScreen;
import 'timeline_screen.dart';
import 'camera_memory_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AccountMode? mode;
  int index = 0;
  bool entered = false;
  List<Widget?> _pageCache = List<Widget?>.filled(8, null);

  @override
  void initState() {
    super.initState();
    if (Session.isLoggedIn && Session.workspaceId != null) {
      mode = _modeFromType(Session.workspaceType);
      entered = true;
    }
  }

  AccountMode _modeFromType(String? t) => t == 'family'
      ? AccountMode.family
      : t == 'business'
          ? AccountMode.business
          : AccountMode.personal;

  void _snack(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _onMediaUploaded() async {
    if (!mounted) return;
    setState(() {
      _pageCache[0] = null;
    });
  }

  void _navigateTo(int destination) {
    final nextIndex = destination.clamp(0, 7).toInt();
    setState(() {
      if (nextIndex == 0) _pageCache[0] = null;
      index = nextIndex;
    });
  }

  void _showProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MemoraColors.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 14),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: MemoraColors.line,
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 14),
        ListTile(
          leading: const CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFF273D63),
              child: Icon(Icons.person_outline)),
          title: Text(Session.userName ?? 'You',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${mode?.label ?? 'Personal'} workspace',
              style: const TextStyle(color: MemoraColors.muted, fontSize: 12)),
        ),
        const Divider(color: MemoraColors.line, height: 1),
        ListTile(
          leading:
              const Icon(Icons.settings_outlined, color: MemoraColors.muted),
          title: const Text('Settings'),
          onTap: () {
            Navigator.pop(context);
            setState(() => index = 7);
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: MemoraColors.danger),
          title: const Text('Sign out',
              style: TextStyle(color: MemoraColors.danger)),
          onTap: () async {
            await Session.clear();
            if (!mounted) return;
            Navigator.pop(context);
            setState(() {
              entered = false;
              mode = null;
              index = 0;
              _pageCache = List<Widget?>.filled(8, null);
            });
          },
        ),
        const SizedBox(height: 10),
      ])),
    );
  }

  void start(AccountMode selected) {
    setState(() {
      mode = selected;
      index = 0;
      _pageCache = List<Widget?>.filled(8, null);
    });
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AccountSetupScreen(
            mode: selected,
            onComplete: () {
              Navigator.of(context).pop();
              setState(() {
                entered = true;
                _pageCache[0] = null;
              });
            })));
  }

  Future<void> _signIn() async {
    final creds = await showDialog<_SignInResult>(
        context: context, builder: (_) => const _SignInDialog());
    if (!mounted || creds == null) return;
    if (creds.forgotPassword) {
      final reset = await showDialog<bool>(
          context: context,
          builder: (_) => _PasswordRecoveryDialog(email: creds.email));
      if (reset == true && mounted) {
        _snack('Password reset. Sign in with your new password.');
      }
      return;
    }
    try {
      await Api.login(creds.email, creds.password,
          rememberMe: creds.rememberMe);
      await Api.me();
      final wss = await Api.workspaces();
      if (wss.isEmpty) {
        _snack('No workspace found for this account.');
        return;
      }
      final ws = wss.first;
      Session.workspaceId = ws['id'];
      Session.workspaceType = ws['tier'] ?? ws['type'];
      await Session.save();
      final sps = await Api.spaces(ws['id'] as String);
      if (sps.isNotEmpty) {
        Session.spaceId = sps.first['id'];
      } else {
        final sp = await Api.createSpace(ws['id'] as String, 'My Home');
        Session.spaceId = sp['space_id'];
      }
      await Session.save();
      setState(() {
        mode = _modeFromType(Session.workspaceType);
        entered = true;
        index = 0;
        _pageCache = List<Widget?>.filled(8, null);
      });
    } catch (e) {
      _snack(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!entered || mode == null) {
      return LandingScreen(onStart: start, onSignIn: _signIn);
    }
    final pageBuilders = <Widget Function()>[
      () => DashboardScreen(mode: mode!, onNavigate: _navigateTo),
      () => RoomsScreen(onMediaUploaded: _onMediaUploaded),
      () => TimelineScreen(onMediaUploaded: _onMediaUploaded),
      () => const AskMemoraScreen(),
      () => const MoveMateScreen(),
      () => const UpkeepScreen(),
      () => const CameraMemoryScreen(),
      () => mode == AccountMode.family
          ? const FamilyScreen()
          : mode == AccountMode.business
              ? const BusinessScreen()
              : const SettingsScreen(),
    ];
    _pageCache[index] ??= pageBuilders[index]();
    final pages = List<Widget>.generate(
      pageBuilders.length,
      (i) => _pageCache[i] ?? const SizedBox.shrink(),
    );
    final labels = [
      'Overview',
      'Spaces',
      'Timeline',
      'Ask AI',
      'MoveMate',
      'Upkeep',
      'Cameras',
      mode == AccountMode.family
          ? 'Family'
          : mode == AccountMode.business
              ? 'Business'
              : 'Settings'
    ];
    final icons = [
      Icons.dashboard_rounded,
      Icons.meeting_room_rounded,
      Icons.history_rounded,
      Icons.auto_awesome,
      Icons.all_inbox_rounded,
      Icons.shield_outlined,
      Icons.videocam_outlined,
      mode == AccountMode.family
          ? Icons.family_restroom
          : mode == AccountMode.business
              ? Icons.business_center
              : Icons.settings
    ];
    return Scaffold(
      body: AmbientBackground(
          child: SafeArea(
              child: Row(children: [
        if (MediaQuery.of(context).size.width > 850) _sideNav(labels, icons),
        Expanded(
            child: Column(children: [
          _topBar(),
          Expanded(child: IndexedStack(index: index, children: pages)),
          if (MediaQuery.of(context).size.width <= 850)
            _bottomNav(labels, icons),
        ])),
      ]))),
    );
  }

  Widget _sideNav(List<String> labels, List<IconData> icons) => Container(
        width: 225,
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
        decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: MemoraColors.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
              padding: EdgeInsets.fromLTRB(12, 5, 12, 25),
              child: Row(children: [
                _BrandMark(),
                SizedBox(width: 9),
                Text('MEMORA',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, letterSpacing: 1.2))
              ])),
          ...List.generate(
              labels.length, (i) => _navItem(labels[i], icons[i], i)),
          const Spacer(),
          const GlassPanel(
              padding: EdgeInsets.all(13),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome, color: MemoraColors.gold),
                    SizedBox(height: 8),
                    Text('Your world, remembered.',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 11)),
                    SizedBox(height: 4),
                    Text('Visual memory is ready.',
                        style:
                            TextStyle(color: MemoraColors.muted, fontSize: 9))
                  ])),
        ]),
      );

  Widget _navItem(String label, IconData icon, int i) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: InkWell(
            onTap: () => _navigateTo(i),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                  color: index == i
                      ? MemoraColors.gold.withOpacity(.13)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: index == i
                      ? Border.all(color: MemoraColors.gold.withOpacity(.25))
                      : null),
              child: Row(children: [
                Icon(icon,
                    size: 17,
                    color: index == i ? MemoraColors.gold : MemoraColors.muted),
                const SizedBox(width: 11),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            index == i ? FontWeight.w800 : FontWeight.w500,
                        color: index == i ? Colors.white : MemoraColors.muted)),
                if (index == i) ...[
                  const Spacer(),
                  Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                          color: MemoraColors.gold, shape: BoxShape.circle))
                ]
              ]),
            )),
      );

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(children: [
          if (MediaQuery.of(context).size.width <= 850) const _BrandMark(),
          if (MediaQuery.of(context).size.width <= 850)
            const SizedBox(width: 8),
          Text(mode?.label ?? 'Workspace',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const Spacer(),
          InkWell(
              onTap: _showProfile,
              borderRadius: BorderRadius.circular(20),
              child: const CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFF273D63),
                  child: Icon(Icons.person_outline, size: 18))),
        ]),
      );

  Widget _bottomNav(List<String> labels, List<IconData> icons) {
    const destinations = [0, 1, 3, 2];
    final moreSelected = index >= 4;
    return Container(
      height: 66,
      decoration: const BoxDecoration(
        color: Color(0xEE0A1B2F),
        border: Border(top: BorderSide(color: MemoraColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final i in destinations)
            _mobileNavItem(
                labels[i], icons[i], index == i, () => _navigateTo(i)),
          _mobileNavItem(
              'More', Icons.grid_view_rounded, moreSelected, _showMore),
        ],
      ),
    );
  }

  Widget _mobileNavItem(
          String label, IconData icon, bool selected, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? MemoraColors.gold : MemoraColors.muted),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.normal,
                      color:
                          selected ? MemoraColors.gold : MemoraColors.muted)),
            ],
          ),
        ),
      );

  void _showMore() {
    final labels = [
      'MoveMate',
      'Home care',
      'Camera memory',
      if (mode == AccountMode.family)
        'Family'
      else if (mode == AccountMode.business)
        'Business'
      else
        'Settings',
    ];
    const icons = [
      Icons.all_inbox_outlined,
      Icons.shield_outlined,
      Icons.videocam_outlined,
      Icons.settings_outlined,
    ];
    const pageIndexes = [4, 5, 6, 7];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MemoraColors.panel,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('More tools',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
            for (var i = 0; i < labels.length; i++)
              ListTile(
                leading: Icon(icons[i], color: MemoraColors.blue),
                title: Text(labels[i]),
                onTap: () {
                  Navigator.pop(context);
                  _navigateTo(pageIndexes[i]);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Container(
      width: 29,
      height: 29,
      decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: [
            MemoraColors.cyan,
            MemoraColors.violet,
            MemoraColors.gold,
            MemoraColors.cyan
          ])),
      child: Center(
          child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: MemoraColors.bg))));
}

class _SignInDialog extends StatefulWidget {
  const _SignInDialog();
  @override
  State<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<_SignInDialog> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool rememberMe = true;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: GlassPanel(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [
                    BrandMark(size: 34),
                    SizedBox(width: 11),
                    Text('MEMORA',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2)),
                  ]),
                  const SizedBox(height: 22),
                  const Text('Welcome back',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Sign in to your visual memory.',
                      style:
                          TextStyle(color: MemoraColors.muted, fontSize: 12)),
                  const SizedBox(height: 22),
                  TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.mail_outline))),
                  const SizedBox(height: 13),
                  TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline))),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: rememberMe,
                    onChanged: (value) =>
                        setState(() => rememberMe = value ?? false),
                    title: const Text('Remember me',
                        style: TextStyle(fontSize: 13)),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(
                          context, _SignInResult.recovery(email.text.trim())),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side:
                                    const BorderSide(color: MemoraColors.line),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15)),
                            child: const Text('Cancel'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: GlowButton(
                            label: 'Sign in',
                            icon: Icons.login_rounded,
                            onPressed: () => Navigator.pop(
                                context,
                                _SignInResult(
                                  email: email.text.trim(),
                                  password: password.text,
                                  rememberMe: rememberMe,
                                )))),
                  ]),
                ],
              ),
            ),
          ),
        ),
      );
}

class _SignInResult {
  final String email;
  final String password;
  final bool rememberMe;
  final bool forgotPassword;

  const _SignInResult({
    required this.email,
    required this.password,
    required this.rememberMe,
  }) : forgotPassword = false;

  const _SignInResult.recovery(this.email)
      : password = '',
        rememberMe = false,
        forgotPassword = true;
}

class _PasswordRecoveryDialog extends StatefulWidget {
  final String email;
  const _PasswordRecoveryDialog({required this.email});

  @override
  State<_PasswordRecoveryDialog> createState() =>
      _PasswordRecoveryDialogState();
}

class _PasswordRecoveryDialogState extends State<_PasswordRecoveryDialog> {
  late final email = TextEditingController(text: widget.email);
  final code = TextEditingController();
  final password = TextEditingController();
  bool codeSent = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Api.requestPasswordReset(email.text.trim());
      if (!mounted) return;
      setState(() => codeSent = true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resetPassword() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Api.confirmPasswordReset(
          email.text.trim(), code.text.trim(), password.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassPanel(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(codeSent ? 'Choose a new password' : 'Recover password',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  codeSent
                      ? 'Enter the 8-digit code sent to your email.'
                      : 'We will email you a one-time reset code.',
                  style: const TextStyle(color: MemoraColors.muted),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: email,
                  enabled: !codeSent,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline)),
                ),
                if (codeSent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: code,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    decoration: const InputDecoration(
                        labelText: 'Reset code',
                        prefixIcon: Icon(Icons.pin_outlined)),
                  ),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'New password (at least 10 characters)',
                        prefixIcon: Icon(Icons.lock_outline)),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!,
                      style: const TextStyle(color: MemoraColors.danger)),
                ],
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlowButton(
                      label: busy
                          ? 'Please wait'
                          : codeSent
                              ? 'Reset password'
                              : 'Send code',
                      icon: codeSent
                          ? Icons.lock_reset_rounded
                          : Icons.mail_outline,
                      onPressed: () {
                        if (busy) return;
                        if (codeSent) {
                          _resetPassword();
                        } else {
                          _requestCode();
                        }
                      },
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
}
