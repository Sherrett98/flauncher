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

  /// The banner's brand colour: group the clearly coloured pixels by hue,
  /// take the biggest group and average it. White, black and grey
  /// backgrounds are ignored, so Netflix comes out red rather than pink.
  static Future<Color?> _dominantColor(Uint8List bytes) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: 48, targetHeight: 27);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      if (data == null) {
        return null;
      }

      const int buckets = 24; // 15 degrees of hue each
      final List<double> weight = List.filled(buckets, 0);
      final List<double> sr = List.filled(buckets, 0), sg = List.filled(buckets, 0), sb = List.filled(buckets, 0);

      for (int i = 0; i + 3 < data.lengthInBytes; i += 4) {
        if (data.getUint8(i + 3) < 128) {
          continue;
        }
        final int r = data.getUint8(i), g = data.getUint8(i + 1), b = data.getUint8(i + 2);
        final HSLColor hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
        if (hsl.saturation < 0.3 || hsl.lightness < 0.12 || hsl.lightness > 0.88) {
          continue; // background-ish: white, black, grey
        }
        final int bucket = (hsl.hue / (360 / buckets)).floor() % buckets;
        final double w = hsl.saturation;
        weight[bucket] += w;
        sr[bucket] += r * w;
        sg[bucket] += g * w;
        sb[bucket] += b * w;
      }

      int best = 0;
      for (int k = 1; k < buckets; k++) {
        if (weight[k] > weight[best]) {
          best = k;
        }
      }
      if (weight[best] < 2.0) {
        return null; // no real colour in the banner: use the neutral glow
      }

      final Color brand = Color.fromARGB(255, (sr[best] / weight[best]).round(),
          (sg[best] / weight[best]).round(), (sb[best] / weight[best]).round());
      final HSLColor hsl = HSLColor.fromColor(brand);
      return hsl
          .withLightness(hsl.lightness.clamp(0.36, 0.55))
          .withSaturation(hsl.saturation.clamp(0.45, 0.85))
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
