import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final EdgeInsets edgeInsets;

  const MyButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.edgeInsets = const EdgeInsets.only(left: 8, right: 8, bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: edgeInsets,
        child: ElevatedButton(onPressed: onPressed, child: child),
      ),
    );
  }
}
