import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../native.dart';
import '../store.dart';
import '../i18n.dart';

/// Lo scanner c'è solo su Android (mobile_scanner non supporta Windows; sul web si incolla).
bool get qrScannerSupported => NativeBridge.supported;

/// Link nel QR del codice: la fotocamera del telefono apre direttamente Easy Lesson.
String accountLink(String code) => 'easylesson://login?c=${Uri.encodeQueryComponent(code)}';

/// Link nel QR del codice di recupero.
String recoveryLink(String code) => 'easylesson://recover?r=${Uri.encodeQueryComponent(code)}';

/// Che cosa c'è in un testo letto da un QR o incollato: ('login'|'recover', codice) o
/// ('raw', testo) se non è un link di Easy Lesson.
(String, String) parseCodeText(String text) {
  final t = text.trim();
  if (t.startsWith('easylesson://')) {
    final u = Uri.tryParse(t);
    if (u != null && u.host == 'login' && (u.queryParameters['c'] ?? '').isNotEmpty) {
      return ('login', u.queryParameters['c']!);
    }
    if (u != null && u.host == 'recover' && (u.queryParameters['r'] ?? '').isNotEmpty) {
      return ('recover', u.queryParameters['r']!);
    }
    // 3.0: invito in una classe e codice amico.
    if (u != null && (u.host == 'class' || u.host == 'friend') && (u.queryParameters['c'] ?? '').isNotEmpty) {
      return (u.host, u.queryParameters['c']!);
    }
  }
  return ('raw', t);
}

/// Apre la fotocamera e restituisce il primo QR letto (null = annullato).
Future<String?> scanQr(BuildContext context, {String? title}) =>
    Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => _ScannerPage(title: title ?? tr('Inquadra il QR', 'Scan the QR'))));

class _ScannerPage extends StatefulWidget {
  const _ScannerPage({required this.title});
  final String title;

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.trim().isNotEmpty) {
        _done = true;
        StoreScope.read(context).bump('qrScans');
        Navigator.of(context).pop(v.trim());
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              tooltip: tr('Torcia', 'Flashlight'),
              onPressed: () => _controller.toggleTorch(),
              icon: const Icon(Icons.flashlight_on_rounded),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(controller: _controller, onDetect: _onDetect),
            Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: Text(
                tr('Inquadra il QR del foglio di recupero o di un altro telefono', 'Scan the QR of the recovery sheet or of another phone'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
      );
}
