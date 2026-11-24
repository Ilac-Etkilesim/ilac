
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/gs1_parser.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _scannerController =
      MobileScannerController();

  bool handled = false;
  bool _manualEntryOpen = false;
  String? _scanWarning;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!mounted || handled || _manualEntryOpen) return;

    bool unsupportedBarcode = false;

    for (final barcode in capture.barcodes) {
      // DataMatrix dışındaki kodları belirle.
      if (barcode.format != BarcodeFormat.dataMatrix) {
        unsupportedBarcode = true;
        continue;
      }

      final value = barcode.rawValue;

      if (value == null || value.isEmpty) continue;

      handled = true;
      Navigator.of(context).pop(value);
      return;
    }

    // Yanlış barkod okutulduğunda kullanıcıya bilgi ver.
    if (unsupportedBarcode && _scanWarning == null) {
      setState(() {
        _scanWarning =
            'Bu kod desteklenmiyor. İlaç kutusundaki DataMatrix kodunu okutun.';
      });
    }
  }

  /// Kamera okuyamadığında yedek yol: 14 haneli GTIN elle girilir.
  Future<void> _enterManually() async {
    if (handled || _manualEntryOpen) return;

    _manualEntryOpen = true;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualGtinDialog(),
    );

    _manualEntryOpen = false;

    if (!mounted || result == null || handled) return;

    handled = true;
    Navigator.of(context).pop(result);
  }

  // Kamera flaşını açma ve kapatma.
  Future<void> _toggleFlash() async {
    try {
      await _scannerController.toggleTorch();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flaş kullanılamıyor.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DataMatrix okut'),
        actions: [
          IconButton(
            onPressed: _toggleFlash,
            icon: const Icon(Icons.flashlight_on),
            tooltip: 'Flaşı aç/kapat',
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Text(
                  'Kamera açılamadı: $error\n'
                  'Kamera iznini kontrol edin.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // Desteklenmeyen barkod uyarısı.
          if (_scanWarning != null)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _scanWarning!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() => _scanWarning = null);
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                      tooltip: 'Uyarıyı kapat',
                    ),
                  ],
                ),
              ),
            ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black87,
              padding: const EdgeInsets.all(24),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'İlaç kutusundaki karekod alanını kameraya tutun.\n'
                      'Yalnızca GS1 DataMatrix/GTIN okuma denemesidir; '
                      'ilaç güvenlik kontrolü yapılmaz.',
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: FilledButton.icon(
                        onPressed: _enterManually,
                        icon: const Icon(Icons.keyboard, size: 26),
                        label: const Text(
                          'Kodu elle gir',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualGtinDialog extends StatefulWidget {
  const _ManualGtinDialog();

  @override
  State<_ManualGtinDialog> createState() => _ManualGtinDialogState();
}

class _ManualGtinDialogState extends State<_ManualGtinDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final normalized = normalizeManualGtin(_controller.text);

    if (normalized == null) {
      setState(() => _error = '14 haneli geçerli bir kod girin.');
      return;
    }

    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Kodu elle gir',
        style: TextStyle(fontSize: 22),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kutunun üzerindeki 14 haneli numarayı yazın.',
            style: TextStyle(fontSize: 17),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            maxLength: 14,
            style: const TextStyle(
              fontSize: 22,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              hintText: '99990000000008',
              border: const OutlineInputBorder(),
              errorText: _error,
              errorStyle: const TextStyle(
                fontSize: 16,
                color: Color(0xFFB3261E),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          const Text(
            'Elle girilen kod ilaç güvenliğini doğrulamaz; '
            'yalnızca katalog eşleştirme denemesidir.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF526783),
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          height: 52,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Vazgeç',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _submit,
            child: const Text(
              'Onayla',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }
}
