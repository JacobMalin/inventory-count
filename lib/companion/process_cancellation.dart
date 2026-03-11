import 'dart:io';

class CompanionProcessCancellation {
  static Process? _activePrintProcess;
  static bool _printCancelRequested = false;

  static void registerPrintProcess(Process process) {
    _activePrintProcess = process;
    _printCancelRequested = false;
  }

  static void clearPrintProcess(Process process) {
    if (identical(_activePrintProcess, process)) {
      _activePrintProcess = null;
    }
  }

  static Future<void> cancelPrintProcess() async {
    _printCancelRequested = true;
    _activePrintProcess?.kill();
  }

  static bool consumePrintCancelRequested() {
    final bool wasRequested = _printCancelRequested;
    _printCancelRequested = false;
    return wasRequested;
  }
}
