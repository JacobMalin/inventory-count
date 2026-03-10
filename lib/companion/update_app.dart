import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

import '../core/types/json.dart';

class UpdateApp extends StatefulWidget {
  const UpdateApp({super.key});

  @override
  State<UpdateApp> createState() => _UpdateAppState();
}

class _UpdateAppState extends State<UpdateApp> {
  bool _doUpdateApp = false;
  bool _dismissed = false;
  bool _isDownloading = false;
  String? _latestVersion;
  String? _currentVersion;
  String? _companionZipDownloadUrl;

  static const requiredAssetName = 'CompanionApp.zip';

  @override
  void initState() {
    super.initState();
    unawaited(_checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final String currentVersion = _normalizeVersion(info.version);

      const endpoint =
          'https://api.github.com/repos/JacobMalin/inventory-count/releases/latest';

      final http.Response response = await http.get(
        Uri.parse(endpoint),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Json;

      final String latestVersion = _normalizeVersion(
        (data['tag_name'] as String?) ?? '',
      );

      final List<dynamic> assets =
          (data['assets'] as List<dynamic>?) ?? const <dynamic>[];
      String? companionZipDownloadUrl;
      for (final dynamic asset in assets) {
        if (asset is! Json) {
          continue;
        }
        final name = asset['name'] as String?;
        if (name != requiredAssetName) {
          continue;
        }
        final downloadUrl = asset['browser_download_url'] as String?;
        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          companionZipDownloadUrl = downloadUrl;
          break;
        }
      }

      if (!mounted || latestVersion.isEmpty) return;

      setState(() {
        _currentVersion = currentVersion;
        _latestVersion = latestVersion;
        _companionZipDownloadUrl = companionZipDownloadUrl;
        _doUpdateApp =
            companionZipDownloadUrl != null &&
            _isVersionNewer(latestVersion, currentVersion);
      });
    } on Exception {
      // Silent fail: no update prompt if request cannot be completed.
    }
  }

  Future<void> _downloadUpdateZip() async {
    final String? url = _companionZipDownloadUrl;
    if (url == null || url.isEmpty || _isDownloading) {
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final Uri uri = Uri.parse(url);
      final http.Response response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Download failed with status ${response.statusCode}.');
      }

      final Directory directory = File(Platform.resolvedExecutable).parent;
      if (!directory.existsSync()) {
        throw Exception(
          'Download directory did not resolve: ${directory.path}',
        );
      }

      final extractionDirectory = Directory(
        p.join(directory.path, p.basenameWithoutExtension(requiredAssetName)),
      );
      if (!extractionDirectory.existsSync()) {
        extractionDirectory.createSync(recursive: true);
      }

      await _extractZip(
        zipBytes: response.bodyBytes,
        outputDirectory: extractionDirectory,
      );

      await _runUpdaterScript(
        targetDirectory: directory,
        extractionDirectory: extractionDirectory,
      );

      exit(0);
    } on Exception catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update download failed: $error')));
      if (kDebugMode) print('Update download failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _runUpdaterScript({
    required Directory targetDirectory,
    required Directory extractionDirectory,
  }) async {
    if (!Platform.isWindows) {
      throw Exception('Automatic updater script is only supported on Windows.');
    }

    final String script = await rootBundle.loadString(
      'assets/ApplyCompanionUpdate.cmd',
    );
    final scriptFile = File(
      p.join(
        Directory.systemTemp.path,
        'apply_companion_update_${DateTime.now().millisecondsSinceEpoch}.cmd',
      ),
    );
    await scriptFile.writeAsString(script, flush: true);

    final String exeName = p.basename(Platform.resolvedExecutable);
    _startHiddenWithCreateProcess(
      scriptPath: scriptFile.path,
      targetDirectoryPath: targetDirectory.path,
      extractionDirectoryPath: extractionDirectory.path,
      exeName: exeName,
    );
  }

  void _startHiddenWithCreateProcess({
    required String scriptPath,
    required String targetDirectoryPath,
    required String extractionDirectoryPath,
    required String exeName,
  }) {
    final String cmdExe =
        Platform.environment['ComSpec'] ?? r'C:\Windows\System32\cmd.exe';
    final commandLine =
        '/d /s /c '
        '"${_quoteCmdArg(scriptPath)} '
        '${_quoteCmdArg(targetDirectoryPath)} '
        '${_quoteCmdArg(extractionDirectoryPath)} '
        '${_quoteCmdArg(exeName)}"';

    final ffi.Pointer<Utf16> appNamePtr = cmdExe.toNativeUtf16();
    final ffi.Pointer<Utf16> cmdLinePtr = commandLine.toNativeUtf16();
    final ffi.Pointer<STARTUPINFO> startupInfo = calloc<STARTUPINFO>();
    final ffi.Pointer<PROCESS_INFORMATION> processInfo =
        calloc<PROCESS_INFORMATION>();

    try {
      startupInfo.ref.cb = ffi.sizeOf<STARTUPINFO>();

      final int result = CreateProcess(
        appNamePtr,
        cmdLinePtr,
        ffi.nullptr,
        ffi.nullptr,
        FALSE,
        CREATE_NO_WINDOW,
        ffi.nullptr,
        ffi.nullptr,
        startupInfo,
        processInfo,
      );

      if (result == FALSE) {
        throw Exception(
          'Win32 CreateProcess failed with error ${GetLastError()}.',
        );
      }

      CloseHandle(processInfo.ref.hThread);
      CloseHandle(processInfo.ref.hProcess);
    } finally {
      calloc
        ..free(appNamePtr)
        ..free(cmdLinePtr)
        ..free(startupInfo)
        ..free(processInfo);
    }
  }

  String _quoteCmdArg(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  Future<void> _extractZip({
    required List<int> zipBytes,
    required Directory outputDirectory,
  }) async {
    final Archive archive = ZipDecoder().decodeBytes(zipBytes);

    final String outputRoot = p.normalize(outputDirectory.path).toLowerCase();

    for (final file in archive) {
      final String outputPath = p.normalize(
        p.join(outputDirectory.path, file.name),
      );
      if (!outputPath.toLowerCase().startsWith(outputRoot)) {
        throw Exception('Unsafe zip entry path: ${file.name}');
      }

      if (file.isFile) {
        final outFile = File(outputPath);
        final Directory parent = outFile.parent;
        if (!parent.existsSync()) {
          parent.createSync(recursive: true);
        }
        await outFile.writeAsBytes(file.content as List<int>, flush: true);
      } else {
        final dir = Directory(outputPath);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
      }
    }
  }

  String _normalizeVersion(String value) {
    final String lower = value.trim().toLowerCase();
    if (lower.startsWith('v')) {
      return value.trim().substring(1);
    }
    return value.trim();
  }

  bool _isVersionNewer(String latest, String current) {
    final List<int> latestParts = _versionParts(latest);
    final List<int> currentParts = _versionParts(current);
    final int length = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (var index = 0; index < length; index++) {
      final int latestPart = index < latestParts.length
          ? latestParts[index]
          : 0;
      final int currentPart = index < currentParts.length
          ? currentParts[index]
          : 0;

      if (latestPart != currentPart) {
        return latestPart > currentPart;
      }
    }

    return false;
  }

  List<int> _versionParts(String version) {
    return version
        .split(RegExp('[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed ||
        !_doUpdateApp ||
        _latestVersion == null ||
        _currentVersion == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isDownloading
                      ? 'Downloading version v$_latestVersion...'
                      : 'Update available: v$_latestVersion '
                            '(current v$_currentVersion)',
                  style: Theme.of(context).textTheme.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _isDownloading ? null : _downloadUpdateZip,
                    child: const Text('Update'),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _dismissed = true;
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
