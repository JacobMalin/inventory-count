import 'dart:async';
import 'dart:io';

class OmnitermInteraction {
  static Future<bool> fillOutCount(String json) async {
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

  if (!File(scriptPath).existsSync()) {
    throw ArgumentError('The specified script does not exist: $scriptPath');
  }

  final ProcessResult result = await Process.run(scriptPath, cliArgs);

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
