import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:honeywell_scanner/honeywell_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) => runApp(const MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp>
    with WidgetsBindingObserver
    implements ScannerCallback {
  HoneywellScanner honeywellScanner = HoneywellScanner();
  ScannedData? scannedData;
  String? errorMessage;
  bool scannerEnabled = false;
  bool scan1DFormats = true;
  bool scan2DFormats = true;
  bool isDeviceSupported = false;

  List<String> scannedCodes = [];

  static const BTN_START_SCANNER = 0,
      BTN_STOP_SCANNER = 1,
      BTN_START_SCANNING = 2,
      BTN_STOP_SCANNING = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    honeywellScanner.scannerCallback = this;
    init();
  }

  Future<void> init() async {
    updateScanProperties();
    isDeviceSupported = await honeywellScanner.isSupported();
    if (mounted) setState(() {});
  }

  void updateScanProperties() {
    List<CodeFormat> codeFormats = [];
    if (scan1DFormats) codeFormats.addAll(CodeFormatUtils.ALL_1D_FORMATS);
    if (scan2DFormats) codeFormats.addAll(CodeFormatUtils.ALL_2D_FORMATS);

    Map<String, dynamic> properties = {
      ...CodeFormatUtils.getAsPropertiesComplement(codeFormats),
      'DEC_CODABAR_START_STOP_TRANSMIT': true,
      'DEC_EAN13_CHECK_DIGIT_TRANSMIT': true,
    };
    honeywellScanner.setProperties(properties);
  }

  @override
  void onDecoded(ScannedData? scannedData) {
    if (scannedData?.code != null) {
      setState(() {
        this.scannedData = scannedData;
        scannedCodes.add(scannedData!.code!);
        //print("Added code: ${scannedData.code}");
        //print("Total codes: ${scannedCodes.length}");
      });
    }
  }

  @override
  void onError(Exception error) {
    setState(() {
      errorMessage = error.toString();
    });
  }

  Future<void> sendScannedCodes() async {
    final url = Uri.parse('https://www.dioda.ro/module/presta2saga/api');
    try {
      final response = await http.post(
        url,
        body: json.encode({'codes': scannedCodes}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        print('Codes sent successfully');
        setState(() {
          scannedCodes.clear();
        });
      } else {
        print('Failed to send codes. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending codes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Honeywell scanner example'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            Text(
              'Scanned Codes (${scannedCodes.length}):',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (var code in scannedCodes.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(code, style: const TextStyle(fontSize: 16)),
              ),
            const Divider(thickness: 2),
            const SizedBox(height: 16),
            Text(
              'Device supported: $isDeviceSupported',
              style: TextStyle(
                color: isDeviceSupported ? Colors.green : Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scanner: ${scannerEnabled ? "Started" : "Stopped"}',
              style: TextStyle(
                color: scannerEnabled ? Colors.blue : Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            if (scannedData != null && errorMessage == null)
              Text('Last scanned: ${scannedData?.code}'),
            if (errorMessage != null)
              Text(
                'Error: $errorMessage',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => onClick(BTN_START_SCANNER),
                  child: const Text("Start Scanner"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await onClick(BTN_STOP_SCANNER);
                    await sendScannedCodes();
                  },
                  child: const Text("Stop Scanner"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => onClick(BTN_START_SCANNING),
                  child: const Text("Start Scanning"),
                ),
                ElevatedButton(
                  onPressed: () => onClick(BTN_STOP_SCANNING),
                  child: const Text("Stop Scanning"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        honeywellScanner.resumeScanner();
        break;
      case AppLifecycleState.inactive:
        honeywellScanner.pauseScanner();
        break;
      case AppLifecycleState.paused:
        honeywellScanner.pauseScanner();
        break;
      case AppLifecycleState.detached:
        honeywellScanner.pauseScanner();
        break;
      default:
        break;
    }
  }

  Future<void> onClick(int id) async {
    try {
      errorMessage = null;
      switch (id) {
        case BTN_START_SCANNER:
          if (await honeywellScanner.startScanner()) {
            setState(() {
              scannerEnabled = true;
            });
          }
          break;
        case BTN_STOP_SCANNER:
          if (await honeywellScanner.stopScanner()) {
            setState(() {
              scannerEnabled = false;
            });
          }
          break;
        case BTN_START_SCANNING:
          await honeywellScanner.startScanning();
          break;
        case BTN_STOP_SCANNING:
          await honeywellScanner.stopScanning();
          break;
      }
    } catch (e) {
      print(e);
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    honeywellScanner.stopScanner();
    super.dispose();
  }
}
