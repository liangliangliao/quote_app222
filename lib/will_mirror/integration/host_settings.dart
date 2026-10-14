import 'package:flutter/material.dart';
import '../../pages/settings_page.dart';

Future<void> openHostAiSettings(BuildContext context) =>
    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
