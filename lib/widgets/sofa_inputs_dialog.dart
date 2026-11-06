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

import '../providers/apps_service.dart';
import '../providers/sofa_state.dart';

/// Lists the TV's HDMI (and other passthrough) inputs and switches to one.
class SofaInputsDialog extends StatelessWidget {
  const SofaInputsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final AppsService apps = context.read<AppsService>();

    return Dialog(
      backgroundColor: SofaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: FutureBuilder<List<Map<dynamic, dynamic>>>(
            future: apps.getTvInputs(),
            builder: (context, snapshot) {
              final List<Widget> children = [
                const Text(
                  'Inputs',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: SofaColors.paper),
                ),
                const SizedBox(height: 14),
              ];

              if (!snapshot.hasData) {
                children.add(const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ));
              } else if (snapshot.data!.isEmpty) {
                children.add(const Text(
                  'No inputs found. Double-press Home to use Amazon\'s Inputs screen instead.',
                  style: TextStyle(fontSize: 15, height: 1.45, color: SofaColors.mist),
                ));
              } else {
                bool first = true;
                for (final input in snapshot.data!) {
                  final String id = input['id'] as String;
                  final String name = (input['name'] as String?) ?? id;
                  children.add(Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _InputButton(
                      name: name,
                      autofocus: first,
                      onPressed: () async {
                        Navigator.of(context).pop();
                        final bool ok = await apps.launchTvInput(id);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(content: Text('Couldn\'t switch to $name. Double-press Home and use Amazon\'s Inputs instead.')),
                          );
                        }
                      },
                    ),
                  ));
                  first = false;
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InputButton extends StatelessWidget {
  final String name;
  final bool autofocus;
  final VoidCallback onPressed;

  const _InputButton({required this.name, required this.autofocus, required this.onPressed});

  @override
  Widget build(BuildContext context) => TextButton(
        autofocus: autofocus,
        onPressed: onPressed,
        style: ButtonStyle(
          alignment: Alignment.centerLeft,
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused) ? SofaColors.room : SofaColors.paper),
          backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused) ? SofaColors.paper : SofaColors.raised),
        ),
        child: Row(
          children: [
            Icon(Icons.input_rounded, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
          ],
        ),
      );
}
