import 'dart:async';

import 'package:serious_python/serious_python.dart';

class OmnitermInteraction {
  static Future<bool> fillOutCount() async {
    await runPythonScript('omniterm.py');

    return true;
  }
}

Future<String> runPythonScript(
  String scriptName, {
  Map<String, String>? args,
}) async {
  final String? result = await SeriousPython.run(
    'assets/python.zip',
    appFileName: scriptName,
    environmentVariables: args,
  );
  if (result == null) throw Exception('No response from serious_python plugin');
  return result;
}
