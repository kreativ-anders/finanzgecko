import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Timed brand moment: 1100ms hold + 400ms fade, deliberately kept (issue #11) — see dev/ai/ui-conventions.md.
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
// WARNING: the file names denote the image color, not the theme — swapping them makes the logo invisible (1.3:1).
          Image.asset(
            kIsDarkTheme ? 'assets/logo/kreativ-anders-light-512.png' : 'assets/logo/kreativ-anders-dark-512.png',
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
