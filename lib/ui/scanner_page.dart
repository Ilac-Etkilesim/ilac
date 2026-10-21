import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (handled) return;
    for (final barcode in capture.barcodes) {
      if (barcode.format != BarcodeFormat.dataMatrix) continue;
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;
      handled = true;
      Navigator.of(context).pop(value);
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DataMatrix okut')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Text('Kamera açılamadı: $error\nKamera iznini kontrol edin.',
                    textAlign: TextAlign.center),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black87,
              padding: const EdgeInsets.all(24),
              child: const SafeArea(
                child: Text(
                  'İlaç kutusundaki karekod alanını kameraya tutun.\n'
                  'Yalnızca GS1 DataMatrix/GTIN okuma denemesidir; ilaç güvenlik kontrolü yapılmaz.',
                  style: TextStyle(fontSize: 17, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
