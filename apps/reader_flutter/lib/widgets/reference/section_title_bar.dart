import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../primitives/shared_widgets.dart';

class SectionTitleBar extends StatelessWidget {
  const SectionTitleBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppSectionAccent(label: title);
  }
}
