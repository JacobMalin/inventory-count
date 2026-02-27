import 'dart:async';
import 'dart:io';

class OmnitermInteraction {
  static Future<bool> fillOutCount() async {
    await runPythonScript('assets/omniterm_autofill.exe');

    return true;
  }
}

Future<String> runPythonScript(
  String scriptPath, {
  Map<String, String>? args,
}) async {
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
    throw ProcessException(
      scriptPath,
      cliArgs,
      stderrText.isEmpty ? stdoutText : stderrText,
      result.exitCode,
    );
  }

  return stdoutText;
}
