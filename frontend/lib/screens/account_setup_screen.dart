import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/memora_models.dart';
import '../widgets/glass.dart';
import '../services/api_service.dart';
import '../services/session.dart';

class AccountSetupScreen extends StatefulWidget {
  final AccountMode mode;
  final VoidCallback onComplete;
  const AccountSetupScreen(
      {super.key, required this.mode, required this.onComplete});
  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final household = TextEditingController();
  final password = TextEditingController();
  int step = 0;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    household.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (step == 0) {
      setState(() => step = 1);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final nm = name.text.trim().isEmpty ? 'User' : name.text.trim();
      await Api.signup(email.text.trim(), nm, password.text);
      final wsName = household.text.trim().isNotEmpty
          ? household.text.trim()
          : (widget.mode == AccountMode.personal
              ? 'My Memory'
              : "$nm's ${widget.mode.label}");
      final ws = await Api.createWorkspace(wsName, widget.mode.name);
      Session.workspaceId = ws['id'];
      Session.workspaceType = ws['type'];
      await Session.save();
      final sp = await Api.createSpace(ws['id'] as String, 'My Home');
      Session.spaceId = sp['space_id'];
      await Session.save();
      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
          child: SafeArea(
              child: Center(
                  child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GlassPanel(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const BrandMark(size: 30),
                    const SizedBox(width: 11),
                    Text('MEMORA ${widget.mode.label.toUpperCase()}',
                        style: const TextStyle(
                            letterSpacing: 1.5, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    _StepDots(step: step),
                  ]),
                  const SizedBox(height: 22),
                  Text(
                      step == 0
                          ? 'Let’s set up your space'
                          : 'Create your account',
                      style: const TextStyle(
                          fontSize: 25, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  Text(widget.mode.subtitle,
                      style: const TextStyle(
                          color: MemoraColors.muted, fontSize: 12)),
                  const SizedBox(height: 24),
                  if (step == 0) ...[
                    TextField(
                        controller: name,
                        decoration: InputDecoration(
                            labelText: widget.mode == AccountMode.business
                                ? 'Workspace name'
                                : 'Your name',
                            prefixIcon: const Icon(Icons.person_outline))),
                    if (widget.mode != AccountMode.personal) ...[
                      const SizedBox(height: 13),
                      TextField(
                          controller: household,
                          decoration: InputDecoration(
                              labelText: widget.mode == AccountMode.family
                                  ? 'Family / household name'
                                  : 'Business name',
                              prefixIcon:
                                  const Icon(Icons.home_work_outlined))),
                    ],
                    const SizedBox(height: 16),
                    if (widget.mode == AccountMode.family)
                      const Text(
                          'Family members can join this household with an invite code after setup.',
                          style: TextStyle(
                              color: MemoraColors.muted,
                              fontSize: 11,
                              height: 1.5)),
                    if (widget.mode == AccountMode.business)
                      const Text(
                          'Invite teammates and organize assets by office, studio or storage location.',
                          style: TextStyle(
                              color: MemoraColors.muted,
                              fontSize: 11,
                              height: 1.5)),
                  ] else ...[
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
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!,
                          style: const TextStyle(
                              color: MemoraColors.danger, fontSize: 11)),
                    ],
                  ],
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: busy
                                ? null
                                : (step == 0
                                    ? () => Navigator.pop(context)
                                    : () => setState(() => step = 0)),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side:
                                    const BorderSide(color: MemoraColors.line),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15)),
                            child: Text(step == 0 ? 'Back' : 'Previous'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: GlowButton(
                            label: busy
                                ? 'Please wait…'
                                : (step == 0 ? 'Continue' : 'Create account'),
                            onPressed: busy ? () {} : _submit)),
                  ]),
                ],
              )),
        ),
      )))),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int step;
  const _StepDots({required this.step});
  Widget _bar(bool on) => Container(
      width: 20,
      height: 4,
      decoration: BoxDecoration(
          color: on ? MemoraColors.gold : MemoraColors.line,
          borderRadius: BorderRadius.circular(3)));
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        _bar(true),
        const SizedBox(width: 5),
        _bar(step >= 1),
      ]);
}
