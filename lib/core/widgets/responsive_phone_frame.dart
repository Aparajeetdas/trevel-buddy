import 'package:flutter/material.dart';

/// Pass-through wrapper replacing the legacy phone frame constraint.
/// Responsive layout is handled directly in screen layouts via LayoutBuilder breakpoints.
class ResponsivePhoneFrame extends StatelessWidget {
  final Widget child;

  const ResponsivePhoneFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
