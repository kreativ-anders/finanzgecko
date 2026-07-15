import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Brief branded splash shown on startup, crediting kreativ.anders. App data
/// is already loaded by the time [main] calls runApp, so this is purely a
/// timed brand moment (not gating on any real loading work) — held for at
/// least [minDuration] and faded into [child].
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
          Image.asset('assets/logo/kreativ-anders-light-512.png', width: 160, height: 160),
          const SizedBox(height: 24),
          const Text(
            '🦎 FinanzGecko',
            style: TextStyle(
              color: Colors.white,
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
