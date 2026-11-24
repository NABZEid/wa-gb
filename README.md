# WhatsApp iOS (Flutter)

Login pakai userkey dari bot Telegram, chat antar pengguna lewat server:
https://srvwagb.duckdns.org:3001

## Build APK otomatis (GitHub Actions)
1. Upload semua isi folder ini ke repo GitHub (branch main).
2. Buka tab Actions > Build APK > Run workflow (atau otomatis tiap push).
3. Setelah hijau, buka run-nya, unduh artifact `wa-ios-apk`, ekstrak, install app-release.apk.

## Build APK manual
1. Pasang Flutter SDK, lalu di folder ini jalankan:
   flutter create --platforms=android --project-name wa_ios .
   (file lib/ dan pubspec.yaml milikmu tidak ditimpa)
2. Buka android/app/src/main/AndroidManifest.xml, tambahkan di atas <application ...>:
   <uses-permission android:name="android.permission.INTERNET"/>
3. flutter pub get
4. flutter build apk --release
   Hasil: build/app/outputs/flutter-apk/app-release.apk

## Menyesuaikan server
Semua endpoint ada di lib/api.dart (bagian atas file). Ubah path dan
nama field di sana sesuai API servermu.
