import 'dart:io';

import 'package:flutter/material.dart';

void showAppSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<File?> pathToFile(String? path) async {
  if (path == null || path.isEmpty) return null;
  final f = File(path);
  if (await f.exists()) return f;
  return null;
}
