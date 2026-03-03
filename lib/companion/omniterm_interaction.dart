import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

class OmnitermInteraction {
  static Future<bool> fillOutCount(String json) async {
    json = json.replaceAll('&', '');
    await runPythonScript('assets/omniterm_autofill.exe', args: {'json': json});

    return true;
  }
}

Future<String> runPythonScript(
  String scriptPath, {
  Map<String, String>? args,
}) async {
  if (!Platform.isWindows) {
    throw UnsupportedError(
      'Python script execution is only supported on Windows.',
    );
  }

  final cliArgs = <String>[
    for (final MapEntry<String, String> entry
        in (args ?? <String, String>{}).entries) ...<String>[
      '--${entry.key}',
      entry.value,
    ],
  ];

  final String resolvedScriptPath = _resolveWindowsAssetPath(scriptPath);

  if (!File(resolvedScriptPath).existsSync()) {
    throw ArgumentError('The specified script does not exist: $scriptPath');
  }

  final ProcessResult result = await Process.run(resolvedScriptPath, cliArgs);

  final String stdoutText = (result.stdout ?? '').toString().trim();
  final String stderrText = (result.stderr ?? '').toString().trim();

  if (result.exitCode != 0) {
    final rawError = stderrText.isNotEmpty ? stderrText : stdoutText;

    final runtimeErrorRegex = RegExp(r'^\s*(.+Error:\s*.+)$', multiLine: true);
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
