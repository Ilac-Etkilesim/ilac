import 'package:flutter/material.dart';
import 'medication_app.dart';

class CaregiverPage extends StatelessWidget {
  const CaregiverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('Aile ve yakınlık takibi', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('TEMSİLİ EKRAN — henüz gerçek hasta hesabı bağlı değil.',
            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF8D5B16))),
        const SizedBox(height: 16),
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Örnek Profil 1',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kNavy)),
            const SizedBox(height: 16),
            Row(children: [
              SizedBox(
                height: 95, width: 95,
                child: Stack(alignment: Alignment.center, children: [
                  const SizedBox.expand(child: CircularProgressIndicator(
                    value: 0.75, strokeWidth: 12, color: kBlue,
                    backgroundColor: Color(0xFFE5ECF6),
                  )),
                  const Text('%75', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(width: 20),
              const Expanded(child: Text(
                'Örnek günlük doz onay oranı\n3 / 4 doz işaretlendi\nGerçek bir sağlık göstergesi değildir.',
                style: TextStyle(fontSize: 15, height: 1.5),
              )),
            ]),
          ]),
        )),
        const SizedBox(height: 12),
        Text('Örnek olay geçmişi', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        _event(Icons.check_circle_outline, const Color(0xFF14794D),
            '09:00', 'Doz onaylandı (demo)'),
        _event(Icons.schedule, const Color(0xFFD58A24),
            '13:00', 'Doz onayı bekleniyor (demo)'),
        _event(Icons.info_outline, kBlue,
            '15:00', 'Karekod tarama örneği (gerçek işlem değil)'),
        const SizedBox(height: 12),
        const Card(child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'Gerçek yakın bağlantısı, onay/izin sistemi, erişim kontrolleri '
            've FCM kritik bildirimleri sonraki sprintlerde geliştirilecektir.',
            style: TextStyle(fontSize: 15),
          ),
        )),
      ],
    );
  }

  Widget _event(IconData icon, Color color, String time, String message) => Card(
    child: ListTile(
      minTileHeight: 70,
      leading: Icon(icon, color: color, size: 30),
      title: Text(message, style: const TextStyle(fontSize: 16)),
      subtitle: Text(time),
    ),
  );
}
