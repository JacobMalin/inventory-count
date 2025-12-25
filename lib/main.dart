import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

void main() {
  var debug = false;

  if (debug) {
    runApp(
      DevicePreview(
        builder: (context) {
          return const MainApp();
        },
      ),
    );
  } else {
    runApp(const MainApp());
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      home: Scaffold(body: Center(child: Text('Hello World!!'))),
    );
  }
}
