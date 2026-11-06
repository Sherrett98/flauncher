/*
 * FLauncher
 * Copyright (C) 2021  Oscar Rojas
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'apps_service.dart';
import 'sofa_state.dart';

class LauncherState extends ChangeNotifier
{
  bool _isDefaultLauncher;
  bool _launcherVisible;

  bool  get isDefaultLauncher => _isDefaultLauncher;
  bool  get launcherVisible => _launcherVisible;

  LauncherState() : _isDefaultLauncher = false, _launcherVisible = true;

  void toggleLauncherVisibility() {
    _launcherVisible = !_launcherVisible;
    notifyListeners();
  }

  Future<void> refresh(AppsService appsService) async {
    _isDefaultLauncher = await appsService.isDefaultLauncher();
    notifyListeners();
  }

  /// Back on the home screen: leave the clock view if it's showing,
  /// otherwise jump to the first tile. It never leaves the launcher,
  /// because with Launcher Manager Mini that would drop you on Amazon's home.
  void handleBackNavigation(BuildContext context) {
    LauncherState launcherState = context.read<LauncherState>();

    if (!launcherState.launcherVisible) {
      launcherState.toggleLauncherVisibility();
      return;
    }

    final FocusNode home = context.read<SofaState>().homeNode;
    if (home.context != null) {
      home.requestFocus();
    }
  }
}