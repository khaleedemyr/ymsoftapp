# Panduan Upload YMSoft App ke Google Play Store

Nama aplikasi di Play Store: **YMSoft ERP**

---

## Persiapan

### 1. Akun Google Play Console

- Buka [Google Play Console](https://play.google.com/console) dan login dengan akun Google.
- Bayar biaya pendaftaran **sekali** ($25) jika belum punya akun developer.
- Setelah aktif, Anda bisa memublikasikan banyak aplikasi.

### 2. Buat Aplikasi Baru (jika belum)

- Di Play Console: **All apps** → **Create app**.
- Isi **App name**: `YMSoft ERP`.
- Pilih **Default language** (misalnya Indonesian atau English).
- Pilih **App or game**: App.
- Pilih **Free** atau **Paid**.
- Centang persetujuan dan klik **Create app**.

---

## Langkah 1: Siapkan Application ID (Package name)

Application ID dipakai sebagai identitas unik di Play Store dan **tidak bisa diubah** setelah publish.

Saat ini di project sudah memakai **`com.ymsoft.erp`** (`applicationId` dan `namespace` di `android/app/build.gradle.kts`).  
**Penting:** Application ID di Play Console harus **sama persis** dengan ini saat membuat aplikasi baru. Application ID **tidak bisa diubah** setelah app dipublikasikan.

Jika Anda masih punya app lama dengan package lain, itu dianggap app terpisah; untuk update harus pakai app yang package-nya sama dengan AAB yang di-upload.

---

## Langkah 2: Buat Keystore (untuk tanda tangan release)

Play Store **wajib** pakai release signing. Jangan pakai debug key.

### 2.1 Generate keystore (sekali saja, simpan aman)

**Windows — kalau muncul error "keytool is not recognized":**  
`keytool` ada di dalam **JDK** dan sering tidak ada di PATH. Pakai salah satu cara berikut.

**Cara 1: Pakai JAVA_HOME (jika sudah ada JDK)**  
Di PowerShell:

```powershell
cd d:\Gawean\web\ymsoftapp\android
& "$env:JAVA_HOME\bin\keytool.exe" -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Cara 2: Pakai JDK dari Android Studio**  
Ganti `XX` dengan versi yang ada di komputer Anda (misalnya `17` atau `21`):

```powershell
cd d:\Gawean\web\ymsoftapp\android
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Jika path Android Studio berbeda (misalnya di `D:\`), sesuaikan. Atau buka folder `C:\Program Files\Android\Android Studio\` dan cek apakah ada folder `jbr\bin\keytool.exe`.

**Cara 3: Install JDK lalu pakai PATH**  
1. Install [Eclipse Temurin JDK 17](https://adoptium.net/) atau Oracle JDK.  
2. Saat instalasi, centang opsi **Add to PATH** (jika ada).  
3. Buka PowerShell/CMD **baru**, lalu jalankan:

```bash
cd d:\Gawean\web\ymsoftapp\android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

---

Jalankan **salah satu** perintah di atas (Cara 1, 2, atau 3). Setelah perintah jalan, isikan:

- **Password keystore**: buat password kuat, simpan di tempat aman.
- **Nama, Organisasi, Kota, dll.**: isi sesuai bisnis/developer (bisa nama PT atau nama Anda).

File `upload-keystore.jks` akan terbentuk di folder `android/`.  
**Simpan file ini dan password-nya dengan aman.** Jika hilang, Anda tidak bisa update app yang sama dengan signature baru.

### 2.2 Buat file `key.properties` (jangan di-commit ke Git)

Di folder `android/` buat file `key.properties` dengan isi:

```properties
storePassword=<password-keystore-anda>
keyPassword=<password-key-anda>
keyAlias=upload
storeFile=upload-keystore.jks
```

Ganti `<password-keystore-anda>` dan `<password-key-anda>` dengan password yang Anda pakai saat membuat keystore. Biasanya sama untuk keduanya.

**Tambahkan ke .gitignore:**

Di project ini `android/.gitignore` sudah berisi `key.properties` dan `*.jks`, jadi keystore dan password tidak ikut ter-commit.

---

## Langkah 3: Konfigurasi signing di Gradle

Di project ini **signing release sudah dikonfigurasi** di `android/app/build.gradle.kts`. Jika file `android/key.properties` ada, build release akan memakai keystore Anda; jika belum ada, build release memakai debug key (hanya untuk development).

Anda **tidak perlu mengedit Gradle** lagi—cukup buat keystore dan `key.properties` seperti Langkah 2.

---

## Langkah 4: Build App Bundle (AAB)

Play Store meminta format **Android App Bundle (.aab)**, bukan APK.

Di terminal (dari folder project `ymsoftapp`):

```bash
cd d:\Gawean\web\ymsoftapp

flutter clean
flutter pub get
flutter build appbundle --release
```

Output:

- `build/app/outputs/bundle/release/app-release.aab`

File inilah yang nanti di-upload ke Play Console.

---

## Langkah 5: Isi data di Play Console

Di [Play Console](https://play.google.com/console) → pilih app **YMSoft ERP**.

### 5.1 Dashboard / Setup checklist

Selesaikan semua item yang diminta (biasanya):

- **App access**: apakah ada fitur login/akses khusus (mis. hanya karyawan). Jika ya, isi cara akses (link, akun tester, dll.).
- **Ads**: jika app tidak menampilkan iklan, pilih “No, my app does not contain ads”.
- **Content rating**: isi kuesioner (biasanya untuk bisnis/ERP pilih kategori yang sesuai, lalu dapat rating mis. Everyone/PEGI 3).
- **Target audience**: pilih rentang usia.
- **News app**: pilih “No” jika bukan aplikasi berita.
- **COVID-19**: pilih “No” jika tidak terkait tracing/kesehatan COVID.
- **Data safety**: jelaskan data yang dikumpulkan (login, device, dll.) sesuai kenyataan.

### 5.2 Store listing

- **Short description** (max 80 karakter): ringkasan singkat app.
- **Full description**: penjelasan fitur YMSoft ERP (approval, reservasi, dll.).
- **App icon**: 512 x 512 px, PNG 32-bit.
- **Feature graphic**: 1024 x 500 px (banner di halaman store).
- **Screenshots**: minimal 2 (phone); bisa tambah tablet jika perlu. Ukuran umum 16:9 atau 9:16.

Nama yang tampil di Play Store bisa diatur di sini (bisa tetap **YMSoft ERP**).

### 5.3 Upload AAB

- Masuk ke **Release** → **Production** (atau **Testing** dulu jika ingin uji dulu).
- **Create new release**.
- Upload file `app-release.aab` (drag & drop atau pilih file).
- Isi **Release notes** (perubahan untuk pengguna).
- Klik **Save** lalu **Review release** → **Start rollout to Production** (atau ke track testing dulu).

---

## Langkah 6: Review dan publish

- Setelah rollout, Google akan **review** (biasanya beberapa jam sampai beberapa hari).
- Jika ada penolakan, baca email dan notifikasi di Play Console, perbaiki lalu kirim ulang.
- Setelah disetujui, app **YMSoft ERP** akan tampil di Play Store.

---

## Ringkasan checklist

| No | Item |
|----|------|
| 1 | Akun Play Console aktif ($25 sekali bayar) |
| 2 | Aplikasi “YMSoft ERP” dibuat di Play Console |
| 3 | (Opsional) Application ID diganti dari com.example.ymsoftapp ke com.ymsoft.erp |
| 4 | Keystore dibuat dan disimpan aman |
| 5 | `key.properties` dibuat, `key.properties` dan `*.jks` di-.gitignore |
| 6 | `android/app/build.gradle.kts` dikonfigurasi signing release |
| 7 | `flutter build appbundle --release` sukses |
| 8 | App access, Ads, Content rating, Target audience, Data safety diisi |
| 9 | Store listing (deskripsi, icon, graphic, screenshot) diisi |
| 10 | AAB di-upload dan release dijalankan |

---

## Nama di Play Store

- **Label di HP** sudah “YMSoft ERP” lewat `android:label` di `AndroidManifest.xml`.
- **Nama di halaman Play Store** mengikuti **App name** yang Anda isi di Play Console (Store listing). Isi saja **YMSoft ERP** di sana agar konsisten.

---

## Troubleshooting singkat

- **Build gagal setelah tambah signing**: cek path `storeFile` di `key.properties` (relatif ke folder `android/`) dan pastikan `key.properties` ada di `android/key.properties`.
- **Upload ditolak “Version code sudah dipakai”**: naikkan `version` di `pubspec.yaml` (mis. `1.0.0+1` → `1.0.0+2`); angka setelah `+` adalah `versionCode`.
- **Permission ditolak**: pastikan semua permission di `AndroidManifest.xml` punya alasan jelas; jelaskan di form “Data safety” dan “App access” jika perlu.

Setelah langkah ini selesai, app Anda akan live di Play Store dengan nama **YMSoft ERP**.
