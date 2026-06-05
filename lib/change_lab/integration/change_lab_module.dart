import 'package:flutter/material.dart';

import '../ui/change_lab_shell_page.dart';

class ChangeLabModule {
  static const String routeName = '/change-lab';

  static Map<String, WidgetBuilder> get routes => {
        routeName: (_) => const ChangeLabShellPage(),
      };
}
