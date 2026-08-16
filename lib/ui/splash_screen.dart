import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Brief branded splash shown on startup. App data is already loaded by the
/// time [main] calls runApp, so this is purely a timed brand moment — held for
/// at least [minDuration] and faded into [child].
///
/// The 1100ms + 400ms fade were reviewed deliberately (issue #11) and kept as
/// a brand decision, not a placeholder. They land *on top of* the time the
/// window is already visible ([main] shows it before `runApp`), so startup is
/// ~1.5s total. That trade-off was considered and declined — don't "optimize"
/// these values without asking (see AI_MASTER §5 and `gherkin/window.feature`).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.child, this.minDuration = const Duration(milliseconds: 1100)});

  final Widget child;
  final Duration minDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Timer(widget.minDuration, () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _showSplash ? _buildSplash() : widget.child,
    );
  }

  Widget _buildSplash() {
    return Container(
      key: const ValueKey('splash'),
      color: kBackground,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // CAREFUL: the names denote the *image colour*, not the theme —
          // that is also how they are named in the source repo
          // kreativ-anders/static-assets:
          //   …-light-…  = light logo (white text) → for the DARK background
          //   …-dark-…   = dark logo (black text) → for the LIGHT background
          // Before this mapping the light logo was used in both themes and was
          // practically invisible on light at 1.3:1. Do not "straighten out".
          Image.asset(
            kIsDarkTheme
                ? 'assets/logo/kreativ-anders-light-512.png'
                : 'assets/logo/kreativ-anders-dark-512.png',
            width: 160,
            height: 160,
          ),
          const SizedBox(height: 24),
          Text(
            '🦎 FinanzGecko',
            style: TextStyle(
              color: kTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
