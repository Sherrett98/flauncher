/*
 * Sofa additions to FLauncher
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/sofa_state.dart';

/// The focused app's name, set huge across the top of the home screen.
class SofaHero extends StatelessWidget {
  const SofaHero({super.key});

  @override
  Widget build(BuildContext context) => Selector<SofaState, String?>(
        selector: (_, state) => state.focused?.name,
        builder: (context, name, _) => Padding(
          padding: const EdgeInsets.fromLTRB(32, 4, 32, 12),
          child: SizedBox(
            height: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    name ?? '',
                    key: ValueKey(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Bricolage',
                      fontSize: 80,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2.4,
                      color: SofaColors.paper,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name == null ? '' : 'Press OK to open. Menu for options.',
                  style: const TextStyle(fontFamily: 'Bricolage', fontSize: 15, color: SofaColors.mist),
                ),
              ],
            ),
          ),
        ),
      );
}

/// A soft pool of the focused app's colour, rising from the bottom left.
class SofaGlow extends StatelessWidget {
  const SofaGlow({super.key});

  @override
  Widget build(BuildContext context) => Selector<SofaState, Color>(
        selector: (_, state) => state.glow,
        builder: (context, glow, _) => IgnorePointer(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.55, 1.35),
                radius: 1.45,
                colors: [glow.withOpacity(0.62), glow.withOpacity(0.22), glow.withOpacity(0.0)],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
      );
}
