"""
Flutter native proje dosyalarını uygulama koduna dokunmadan üretir.
Çalıştırmadan önce Flutter 3.38.1+ ve Android SDK kurulu olmalıdır.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import sys
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
if shutil.which("flutter") is None:
    sys.exit("Flutter komutu bulunamadı. Önce Flutter SDK kurun, sonra flutter doctor çalıştırın.")
if (root / "android").exists():
    sys.exit("android/ zaten var; mevcut native dosyaların üzerine yazılmadı.")

with tempfile.TemporaryDirectory(prefix="flutter_native_") as directory:
    tmp = Path(directory) / "ilac_yakinlik_takip"
    command = [
        "flutter", "create", "--project-name", "ilac_yakinlik_takip",
        "--org", "com.example", "--platforms", "android,ios",
        "--no-pub", str(tmp),
    ]
    print("Çalıştırılıyor:", " ".join(command))
    subprocess.run(command, check=True)
    for folder in ("android", "ios"):
        shutil.copytree(tmp / folder, root / folder)

# AndroidManifest.xml: izinler, XML bildiriminin DEĞİL <manifest> açılışının içine eklenir.
# Önceki betikte ilk '>' kullanımı XML bildirimi arkasına geçersiz bir etiket ekleyebilirdi.
manifest = root / "android/app/src/main/AndroidManifest.xml"
data = manifest.read_text(encoding="utf-8")
manifest_open = re.search(r"<manifest\b[^>]*>", data, flags=re.DOTALL)
if manifest_open is None:
    sys.exit("AndroidManifest.xml içinde <manifest> etiketi bulunamadı.")
new_permissions = ""
for permission in ("android.permission.CAMERA", "android.permission.POST_NOTIFICATIONS"):
    if permission not in data:
        new_permissions += f'\n    <uses-permission android:name="{permission}" />'
if new_permissions:
    data = data[:manifest_open.end()] + new_permissions + data[manifest_open.end():]
manifest.write_text(data, encoding="utf-8")

info = root / "ios/Runner/Info.plist"
plist = info.read_text(encoding="utf-8")
if "NSCameraUsageDescription" not in plist:
    plist = plist.replace(
        "</dict>",
        "  <key>NSCameraUsageDescription</key>\n"
        "  <string>İlaç kutusundaki DataMatrix kodunu okuyabilmek için kamera izni gerekir.</string>\n"
        "</dict>", 1)
    info.write_text(plist, encoding="utf-8")
print("Native Android/iOS klasörleri ve kamera izni oluşturuldu.")
print("Sıradaki komutlar: flutter pub get; flutter analyze; flutter test; flutter run")
