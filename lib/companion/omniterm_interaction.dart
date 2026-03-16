import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import 'window_model.dart';

Process? _activePythonProcess;
bool _pythonCancelRequested = false;

class OmnitermInteraction {
  static Map<String, int> lastExpectedByName = <String, int>{};

  static Future<void> cancelFillOutCount() async {
    _pythonCancelRequested = true;
    _activePythonProcess?.kill();
  }

  static Future<Map<String, int>> fillOutCount(String json) async {
    json = json.replaceAll('&', '');
    final String output = await runPythonScript(
      'assets/omniterm_autofill.exe',
      args: {'json': json},
    );

    // Refocus the app window after script execution
    await WindowModel.refocusWindow();

    if (output.isNotEmpty) {
      final dynamic decoded = jsonDecode(output);
      if (decoded is Map) {
        lastExpectedByName = decoded.map<String, int>((key, value) {
          final int parsed = value is num
              ? value.toInt()
              : int.tryParse(value?.toString() ?? '') ?? 0;
          return MapEntry(key.toString(), parsed);
        });
      }
    }

    return lastExpectedByName;
  }
}

Future<String> runPythonScript(
  String scriptPath, {
  Map<String, String?>? args,
}) async {
  if (!Platform.isWindows) {
    throw UnsupportedError(
      'Python script execution is only supported on Windows.',
    );
  }

  final cliArgs = <String>[
    for (final MapEntry<String, String?> entry
        in (args ?? <String, String?>{}).entries) ...[
      '--${entry.key}',
      if (entry.value != null) entry.value!,
    ],
  ];

  final String resolvedScriptPath = _resolveWindowsAssetPath(scriptPath);

  if (!File(resolvedScriptPath).existsSync()) {
    throw ArgumentError('The specified script does not exist: $scriptPath');
  }

  _pythonCancelRequested = false;
  final Process process = await Process.start(resolvedScriptPath, cliArgs);
  _activePythonProcess = process;

  try {
    final Future<String> stdoutData = process.stdout
        .transform(utf8.decoder)
        .join();
    final Future<String> stderrData = process.stderr
        .transform(utf8.decoder)
        .join();

    final int exitCode = await process.exitCode;
    final String stdoutText = (await stdoutData).trim();
    final String stderrText = (await stderrData).trim();

    if (_pythonCancelRequested) {
      _pythonCancelRequested = false;
      throw Exception('Operation canceled.');
    }

    if (exitCode != 0) {
      final rawError = stderrText.isNotEmpty ? stderrText : stdoutText;
      if (kDebugMode) print('Python script error output: $rawError');

      final runtimeErrorRegex = RegExp(
        r'^\s*(.+Error:\s*.+)$',
        multiLine: true,
      );
      final RegExpMatch? runtimeErrorMatch = runtimeErrorRegex.firstMatch(
        rawError,
      );

      final String conciseMessage =
          runtimeErrorMatch?.group(1)?.trim().isNotEmpty ?? false
          ? runtimeErrorMatch!.group(1)!.trim()
          : 'RuntimeError: Omniterm autofill failed.';

      throw Exception(conciseMessage);
    }

    return stdoutText;
  } finally {
    if (identical(_activePythonProcess, process)) {
      _activePythonProcess = null;
    }
    _pythonCancelRequested = false;
  }
}

String _resolveWindowsAssetPath(String scriptPath) {
  final inputFile = File(scriptPath);
  if (inputFile.existsSync()) {
    return inputFile.absolute.path;
  }

  final String normalizedPath = scriptPath.replaceAll('/', p.separator);
  final String executableDir = File(Platform.resolvedExecutable).parent.path;

  final candidates = <String>[
    p.join(Directory.current.path, normalizedPath),
    p.join(executableDir, normalizedPath),
    p.join(executableDir, 'data', 'flutter_assets', normalizedPath),
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  return scriptPath;
}
