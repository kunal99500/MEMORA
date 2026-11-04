import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/memora_models.dart';
import '../widgets/glass.dart';
import '../widgets/illustrations.dart';

TextStyle _disp(double size,
        {FontWeight weight = FontWeight.w600,
        Color? color,
        double spacing = -0.5,
        FontStyle style = FontStyle.normal,
        double height = 1.03}) =>
    TextStyle(
        fontFamily: 'Georgia',
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        fontStyle: style,
        height: height);

const _eyebrow = TextStyle(
    color: MemoraColors.gold,
    fontSize: 11,
    letterSpacing: 2.6,
    fontWeight: FontWeight.w700);

class LandingScreen extends StatefulWidget {
  final ValueChanged<AccountMode> onStart;
  final VoidCallback onSignIn;
  const LandingScreen(
      {super.key, required this.onStart, required this.onSignIn});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scroll = ScrollController();
  final _featuresKey = GlobalKey();
  final _pricingKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _to(GlobalKey k) {
    final ctx = k.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Column(children: [
            _nav(wide),
            Expanded(
                child: SingleChildScrollView(
              controller: _scroll,
              child: Column(children: [
                _hero(context, wide),
                _divider(),
                _problem(context),
                _divider(),
                _how(context),
                _divider(),
                _features(context),
                _divider(),
                _pricing(context),
                _divider(),
                _finalCta(context),
                _footer(),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _divider() => Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 1,
      color: MemoraColors.line);

  // ---------------- nav ----------------
  Widget _nav(bool wide) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 14, 8),
        child: Row(children: [
          const BrandMark(size: 32),
          const SizedBox(width: 10),
          const Text('MEMORA',
              style: TextStyle(
                  fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 18)),
          const Spacer(),
          if (wide) ...[
            _navLink('Features', () => _to(_featuresKey)),
            const SizedBox(width: 22),
            _navLink('Pricing', () => _to(_pricingKey)),
            const SizedBox(width: 22),
          ],
          TextButton(
              onPressed: widget.onSignIn,
              child: const Text('Sign in',
                  style: TextStyle(color: Colors.white, fontSize: 13))),
          const SizedBox(width: 6),
          GlowButton(label: 'Get started', onPressed: () => _to(_pricingKey)),
        ]),
      );

  Widget _navLink(String t, VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: Text(t,
          style: const TextStyle(color: MemoraColors.muted, fontSize: 13)));

  // ---------------- hero ----------------
  Widget _hero(BuildContext context, bool wide) {
    final text = Column(
      crossAxisAlignment:
          wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border:
                    Border.all(color: MemoraColors.gold.withValues(alpha: .3))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, size: 6, color: MemoraColors.cyan),
              SizedBox(width: 8),
              Text('AI FOR YOUR PHYSICAL WORLD',
                  style: TextStyle(
                      color: MemoraColors.gold,
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800))
            ])),
        const SizedBox(height: 22),
        Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Your home\nremembers\n'),
              TextSpan(
                  text: 'everything.',
                  style: _disp(wide ? 66 : 48,
                      color: MemoraColors.gold,
                      style: FontStyle.italic,
                      height: 1.0)),
            ], style: _disp(wide ? 66 : 48, height: 1.0)),
            textAlign: wide ? TextAlign.left : TextAlign.center),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
              'Record a room once. MEMORA remembers every object, notices what moves or goes missing, and answers "where is it?" with the exact photo and spot.',
              textAlign: wide ? TextAlign.left : TextAlign.center,
              style: const TextStyle(
                  color: MemoraColors.muted, fontSize: 14, height: 1.6)),
        ),
        const SizedBox(height: 26),
        Wrap(
            alignment: wide ? WrapAlignment.start : WrapAlignment.center,
            spacing: 11,
            runSpacing: 11,
            children: [
              GlowButton(
                  label: 'Start remembering',
                  onPressed: () => _to(_pricingKey)),
              OutlinedButton(
                  onPressed: () => _to(_featuresKey),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: MemoraColors.line),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14)),
                  child: const Text('See how it works')),
            ]),
        const SizedBox(height: 22),
        Wrap(
            alignment: wide ? WrapAlignment.start : WrapAlignment.center,
            spacing: 20,
            runSpacing: 8,
            children: const [
              _Trust('Private by design'),
              _Trust('No AR headset'),
              _Trust('Works on any phone'),
            ]),
      ],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, wide ? 34 : 22, 20, wide ? 40 : 30),
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(flex: 10, child: text),
              const SizedBox(width: 20),
              const Expanded(
                  flex: 11, child: FloatingHomeIllustration(height: 440)),
            ])
          : Column(children: [
              text,
              const SizedBox(height: 10),
              const FloatingHomeIllustration(height: 320),
            ]),
    );
  }

  // ---------------- section head ----------------
  Widget _head(BuildContext context, String eyebrow, String title, String sub,
          {Key? key}) =>
      Container(
        key: key,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Column(children: [
          Text(eyebrow, style: _eyebrow),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: _disp(MediaQuery.of(context).size.width > 700 ? 44 : 32)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: MemoraColors.muted, fontSize: 14, height: 1.55)),
          ),
        ]),
      );

  double _colW(double w, int cols) =>
      cols == 1 ? w : (w - 16 * (cols - 1)) / cols;

  // ---------------- problem ----------------
  Widget _problem(BuildContext context) {
    const items = [
      [
        'Misplaced things',
        'Passports, chargers, keys — gone exactly when you need them, with no record of where they were last.'
      ],
      [
        'No memory over time',
        'Was that vase already cracked? Did the tenant take the drill? Nobody kept a before.'
      ],
      [
        'Moving & chaos',
        'Everything ends up in unlabeled boxes. Finding the kettle on night one means opening all twelve.'
      ],
      [
        'Lapsed warranties',
        'The fridge warranty expired last month and the AC service is overdue — because nothing reminded you.'
      ],
    ];
    const icons = [
      Icons.search_off_rounded,
      Icons.history_toggle_off_rounded,
      Icons.inventory_2_outlined,
      Icons.verified_user_outlined
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 46),
      child: Column(children: [
        _head(context, 'THE PROBLEM', 'Where did I put it?',
            'Our homes hold thousands of things, but our memory of them fades the moment we close a drawer.'),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LayoutBuilder(builder: (c, cx) {
            final cols = cx.maxWidth > 900 ? 4 : (cx.maxWidth > 560 ? 2 : 1);
            final cw = _colW(cx.maxWidth, cols);
            return Wrap(spacing: 16, runSpacing: 16, children: [
              for (int i = 0; i < items.length; i++)
                SizedBox(
                    width: cw,
                    child: _Pain(icons[i], items[i][0], items[i][1])),
            ]);
          }),
        ),
      ]),
    );
  }

  // ---------------- how it works ----------------
  Widget _how(BuildContext context) {
    const steps = [
      [
        '01',
        'Scan a space',
        'Take a short walkthrough video. MEMORA sees every object and where it sits.'
      ],
      [
        '02',
        'It remembers',
        'Each object, its condition and its place are stored as a private, timestamped memory.'
      ],
      [
        '03',
        'Ask anything',
        'Get an answer grounded in the exact frame the object was last seen in.'
      ],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 46),
      child: Column(children: [
        _head(context, 'HOW MEMORA WORKS', 'Scan once. Remember forever.',
            'No tagging, no spreadsheets, no special hardware. Walk through a room with your phone.'),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LayoutBuilder(builder: (c, cx) {
            final cols = cx.maxWidth > 760 ? 3 : 1;
            final cw = _colW(cx.maxWidth, cols);
            return Wrap(spacing: 16, runSpacing: 16, children: [
              for (final s in steps)
                SizedBox(width: cw, child: _Step(s[0], s[1], s[2])),
            ]);
          }),
        ),
      ]),
    );
  }

  // ---------------- features ----------------
  Widget _features(BuildContext context) {
    final feats = <List<dynamic>>[
      [
        Icons.search_rounded,
        'Visual search',
        'Ask for any object and jump to where it was last seen.',
        MemoraColors.gold
      ],
      [
        Icons.history_rounded,
        'Time travel',
        'Scroll back to see how a room looked last week or last year.',
        MemoraColors.gold
      ],
      [
        Icons.compare_arrows_rounded,
        'Change tracking',
        'See what moved, appeared, or went missing between scans.',
        MemoraColors.cyan
      ],
      [
        Icons.auto_awesome,
        'Ask MEMORA',
        'A grounded assistant that answers using real visual evidence.',
        MemoraColors.gold
      ],
      [
        Icons.all_inbox_rounded,
        'MoveMate',
        'Pack by camera. MEMORA labels every box for you.',
        MemoraColors.cyan
      ],
      [
        Icons.home_repair_service_outlined,
        'Home Guardian',
        'Warranties and service dates tracked, with reminders.',
        MemoraColors.violet
      ],
      [
        Icons.center_focus_strong_outlined,
        'Live Search',
        'Point your camera and MEMORA guides you to an object.',
        MemoraColors.cyan
      ],
      [
        Icons.grid_view_rounded,
        'Floor plan',
        'A clean, auto-generated map of your home.',
        MemoraColors.violet
      ],
      [
        Icons.people_alt_outlined,
        'Shared access',
        'Family or team share one memory, with who-did-what history.',
        MemoraColors.gold
      ],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 46),
      child: Column(children: [
        _head(
            context,
            'EVERYTHING MEMORA DOES',
            'One memory, built around your world.',
            'From finding a single object to running a whole warehouse — every capability, in one calm app.',
            key: _featuresKey),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LayoutBuilder(builder: (c, cx) {
            final cols = cx.maxWidth > 900 ? 3 : (cx.maxWidth > 580 ? 2 : 1);
            final cw = _colW(cx.maxWidth, cols);
            return Wrap(spacing: 16, runSpacing: 16, children: [
              for (final f in feats)
                SizedBox(
                    width: cw,
                    child: _Feat(f[0] as IconData, f[1] as String,
                        f[2] as String, f[3] as Color)),
            ]);
          }),
        ),
      ]),
    );
  }

  // ---------------- pricing ----------------
  Widget _pricing(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 46),
      child: Column(children: [
        _head(context, 'PRICING COMING SOON', 'Plans are on the way.',
            'We’re finalizing MEMORA plans for homes, families, and businesses.',
            key: _pricingKey),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      color: MemoraColors.gold, size: 34),
                  const SizedBox(height: 14),
                  const Text(
                    'MEMORA pricing will be announced soon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create an account to start using MEMORA while we prepare the plans.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: MemoraColors.muted, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  GlowButton(
                    label: 'Get started',
                    onPressed: () => widget.onStart(AccountMode.personal),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ---------------- final cta ----------------
  Widget _finalCta(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 46, 20, 40),
        child: GlassPanel(
          padding: const EdgeInsets.all(30),
          child: Column(children: [
            Text('YOUR WORLD, REMEMBERED', style: _eyebrow),
            const SizedBox(height: 12),
            Text('Stop searching. Start remembering.',
                textAlign: TextAlign.center,
                style:
                    _disp(MediaQuery.of(context).size.width > 700 ? 42 : 30)),
            const SizedBox(height: 10),
            const Text(
                'Scan your first room in two minutes and ask MEMORA where anything is.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MemoraColors.muted, fontSize: 12)),
            const SizedBox(height: 20),
            GlowButton(
                label: 'Get started — free',
                onPressed: () => widget.onStart(AccountMode.personal)),
          ]),
        ),
      );

  Widget _footer() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Row(children: const [
          BrandMark(size: 24),
          SizedBox(width: 9),
          Text('MEMORA',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
          Spacer(),
          Text('© 2026 · Visual memory',
              style: TextStyle(color: MemoraColors.muted, fontSize: 10)),
        ]),
      );
}

// ================= small cards =================
class _Trust extends StatelessWidget {
  final String text;
  const _Trust(this.text);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_outline,
            size: 14, color: MemoraColors.gold),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(color: MemoraColors.muted, fontSize: 12)),
      ]);
}

class _Pain extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const _Pain(this.icon, this.title, this.body);
  @override
  Widget build(BuildContext context) => GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: const Color(0xFFE58A83).withOpacity(.14),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFFE58A83), size: 20)),
        const SizedBox(height: 14),
        Text(title, style: _disp(21, weight: FontWeight.w700, spacing: 0)),
        const SizedBox(height: 7),
        Text(body,
            style: const TextStyle(
                color: MemoraColors.muted, fontSize: 13, height: 1.5)),
      ]));
}

class _Step extends StatelessWidget {
  final String no, title, body;
  const _Step(this.no, this.title, this.body);
  @override
  Widget build(BuildContext context) => GlassPanel(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(no, style: _disp(50, color: MemoraColors.gold, spacing: 0)),
        const SizedBox(height: 8),
        Text(title, style: _disp(22, weight: FontWeight.w700, spacing: 0)),
        const SizedBox(height: 7),
        Text(body,
            style: const TextStyle(
                color: MemoraColors.muted, fontSize: 13, height: 1.5)),
      ]));
}

class _Feat extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final Color tint;
  const _Feat(this.icon, this.title, this.body, this.tint);
  @override
  Widget build(BuildContext context) => GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: tint.withOpacity(.13),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: tint, size: 21)),
        const SizedBox(height: 14),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 7),
        Text(body,
            style: const TextStyle(
                color: MemoraColors.muted, fontSize: 13, height: 1.5)),
      ]));
}
