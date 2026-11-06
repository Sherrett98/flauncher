/*
 * Sofa additions to FLauncher
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app.dart';

/// Colours for the Sofa look.
class SofaColors {
  static const Color room = Color(0xFF24201C);
  static const Color surface = Color(0xFF2F2A25);
  static const Color raised = Color(0xFF3A342E);
  static const Color paper = Color(0xFFF4EFE6);
  static const Color mist = Color(0xFFC9C0B3);
  static const Color defaultGlow = Color(0xFF7A6652);
}

/// Tracks what the home screen should show around the focused tile:
/// its name (the big title), its colour (the glow), and the last app
/// opened, so Play/Pause on the home screen can reopen it.
class SofaState extends ChangeNotifier {
  static const _lastAppKey = 'sofa_last_app';

  final SharedPreferences _prefs;
  final Map<String, Color> _colorCache = {};

  /// Focus target for Back: the first tile of the first section.
  final FocusNode homeNode = FocusNode(debugLabel: 'sofa-home');

  App? _focused;
  Color _glow = SofaColors.defaultGlow;
  int _focusSeq = 0;

  SofaState(this._prefs);

  App? get focused => _focused;
  Color get glow => _glow;
  String? get lastLaunchedPackage => _prefs.getString(_lastAppKey);

  Future<void> setFocused(App app, Uint8List? imageBytes) async {
    final int seq = ++_focusSeq;
    _focused = app;
    notifyListeners();

    Color? color = _colorCache[app.packageName];
    if (color == null && imageBytes != null && imageBytes.isNotEmpty) {
      color = await _dominantColor(imageBytes);
      if (color != null) {
        _colorCache[app.packageName] = color;
      }
    }

    // Focus may have moved on while the colour was being worked out.
    if (seq != _focusSeq) {
      return;
    }
    _glow = color ?? SofaColors.defaultGlow;
    notifyListeners();
  }

  Future<void> recordLaunch(String packageName) => _prefs.setString(_lastAppKey, packageName);

  /// Average the banner's colours, favouring saturated pixels so a logo's
  /// colour wins over a white or black background, then tame it for a glow.
  static Future<Color?> _dominantColor(Uint8List bytes) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: 24, targetHeight: 14);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      if (data == null) {
        return null;
      }

      double r = 0, g = 0, b = 0, total = 0;
      for (int i = 0; i + 3 < data.lengthInBytes; i += 4) {
        final int a = data.getUint8(i + 3);
        if (a < 128) {
          continue;
        }
        final int pr = data.getUint8(i), pg = data.getUint8(i + 1), pb = data.getUint8(i + 2);
        final HSLColor hsl = HSLColor.fromColor(Color.fromARGB(255, pr, pg, pb));
        // Weight: saturated, mid-light pixels count most; near-white/black barely count.
        final double lightnessWeight = 1.0 - (hsl.lightness - 0.5).abs() * 1.6;
        final double weight = 0.05 + hsl.saturation * lightnessWeight.clamp(0.0, 1.0);
        r += pr * weight;
        g += pg * weight;
        b += pb * weight;
        total += weight;
      }
      if (total == 0) {
        return null;
      }

      final Color avg = Color.fromARGB(255, (r / total).round(), (g / total).round(), (b / total).round());
      final HSLColor hsl = HSLColor.fromColor(avg);
      return hsl
          .withLightness(hsl.lightness.clamp(0.38, 0.58))
          .withSaturation(hsl.saturation < 0.12 ? hsl.saturation : hsl.saturation.clamp(0.35, 0.75))
          .toColor();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    homeNode.dispose();
    super.dispose();
  }
}
