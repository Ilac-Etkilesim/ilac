import 'package:flutter/material.dart';
import '../services/dose_storage.dart';
import '../services/notification_service.dart';
import 'medication_app.dart';

class DemoDose {
  DemoDose(this.id, this.label, this.dose, this.time, this.period, {this.taken = false});
  final int id;
  final String label;
  final String dose;
  final String time;
  final String period;
  bool taken;
}

class PatientPage extends StatefulWidget {
  const PatientPage({super.key});

  @override
  State<PatientPage> createState() => _PatientPageState();
}

class _PatientPageState extends State<PatientPage> {
  final DoseStorage _doseStorage = const DoseStorage();
  bool _loading = true;

  final doses = [
    DemoDose(1, 'Örnek İlaç A', '1 tablet · demo', '08:00', 'Sabah'),
    DemoDose(2, 'Örnek İlaç B', '1 tablet · demo', '09:00', 'Sabah'),
    DemoDose(3, 'Örnek İlaç C', '1 tablet · demo', '13:00', 'Öğle'),
    DemoDose(4, 'Örnek İlaç A', '1 tablet · demo', '20:00', 'Akşam'),
  ];
  bool sending = false;

  @override
  void initState() {
    super.initState();
    _loadDoses();
  }

  Future<void> _loadDoses() async {
    final takenIds = await _doseStorage.loadTaken(DateTime.now());
    if (!mounted) return;
    setState(() {
      for (final dose in doses) {
        dose.taken = takenIds.contains(dose.id);
      }
      _loading = false;
    });
  }

  Future<void> _toggleDose(DemoDose dose) async {
    setState(() => dose.taken = !dose.taken);
    final takenIds = doses.where((d) => d.taken).map((d) => d.id).toSet();
    await _doseStorage.saveTaken(DateTime.now(), takenIds);
  }

  Future<void> _testNotification() async {
    setState(() => sending = true);
    try {
      final granted = await NotificationService.instance.showTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(granted
              ? 'Deneme bildirimi gönderildi.'
              : 'Bildirim izni verilmedi, bildirim gösterilemedi. Telefon ayarlarından izni açın.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildirim denemesi başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taken = doses.where((d) => d.taken).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 104),
      children: [
        Text('Bugünün ilaçları', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('Aşağıdaki kayıtlar örnektir, gerçek hasta verisi değildir.',
            style: TextStyle(color: Color(0xFF526783), fontSize: 15)),
        const SizedBox(height: 18),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text('Yükleniyor...', style: TextStyle(color: Color(0xFF526783))),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.today_outlined, color: kBlue, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Bugün $taken / ${doses.length} doz onaylandı',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
        ...['Sabah', 'Öğle', 'Akşam'].map((period) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 0, 10),
              child: Text(period, style: Theme.of(context).textTheme.titleLarge),
            ),
            ...doses.where((d) => d.period == period).map((dose) =>
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: dose.taken ? const Color(0xFFE2F5EB) : const Color(0xFFEAF2FD),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        width: 53, height: 53,
                        child: Icon(dose.taken ? Icons.check_circle : Icons.medication,
                            color: dose.taken ? const Color(0xFF14794D) : kBlue, size: 30),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(dose.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          Text('${dose.time} · ${dose.dose}', style: const TextStyle(fontSize: 14)),
                          Text(dose.taken ? 'Alındı olarak işaretlendi (demo)' : 'Onay bekliyor (demo)',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF526783))),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 50,
                        child: FilledButton.tonal(
                          onPressed: () => _toggleDose(dose),
                          child: Text(dose.taken ? 'Geri al' : 'İçtim'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        )),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: sending ? null : _testNotification,
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Telefonuma deneme bildirimi gönder'),
        ),
        const SizedBox(height: 12),
        const Text('Not: Doz onayları yalnızca bu cihazda tutulur, gerçek kayıt/senkronizasyon ve yakına bildirim yoktur.',
            style: TextStyle(color: Color(0xFF526783), fontSize: 13)),
      ],
    );
  }
}
