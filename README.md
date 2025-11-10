# Huawei Modem Monitor (hmonn)

Skrip ini berfungsi untuk memonitor koneksi internet pada modem Huawei dan melakukan tindakan secara otomatis jika koneksi terputus. Proyek ini juga terintegrasi dengan notifikasi Telegram dan antarmuka LuCI untuk OpenWrt.

## Fitur

*   **Monitoring Koneksi**: Secara otomatis memeriksa koneksi internet setiap menit.
*   **Ganti IP Manual**: Jika ingin mengganti IP secara manual tersedia tombol dengan satu klik.
*   **Ganti Otomatis**: Jika koneksi internet terputus, skrip akan mencoba menjalankan skrip Python (kemungkinan untuk mengganti ip pada modem atau menyambungkan ulang).
*   **Indikator LED**: Menggunakan LED untuk menunjukkan status (misalnya, LED mati saat koneksi terputus dan menyala kembali saat koneksi pulih).
*   **Notifikasi Telegram**: Mengirimkan pemberitahuan ke Telegram ketika koneksi internet hilang dan ketika berhasil dipulihkan.
*   **Antarmuka Web LuCI**: Dilengkapi dengan antarmuka pada LuCI untuk memudahkan konfigurasi parameter seperti IP router, username, password, token Telegram, dan lainnya.
*   **Instalasi Mudah**: Proses instalasi yang mudah dengan satu baris perintah.

## Instalasi

Untuk menginstal skrip ini di perangkat OpenWrt Anda, jalankan perintah berikut melalui SSH:

```bash
bash -c "$(wget -qO - 'https://raw.githubusercontent.com/alrescha79-cmd/hmonn/main/huaweisetup.sh')"
```

Skrip instalasi akan melakukan hal berikut:
1.  Membuat direktori yang diperlukan.
2.  Mengunduh semua skrip yang relevan (`huawei`, `hgledon`, `bledon`).
3.  Memasang file konfigurasi di `/etc/config/huawey`.
4.  Menginstal dependensi yang diperlukan seperti `python3`, `pip`, `curl`, dan paket `luci`.
5.  Mengatur cron job untuk menjalankan skrip monitor setiap menit.
6.  Menambahkan halaman konfigurasi di antarmuka LuCI.

## Konfigurasi

Setelah instalasi selesai, Anda dapat mengkonfigurasi skrip melalui antarmuka LuCI di router Anda.
1.  Buka browser dan masuk ke antarmuka web LuCI router Anda.
2.  Navigasi ke menu **Layanan** -> **Huawei Monitor**.
3.  Atur parameter berikut sesuai kebutuhan:
    *   **Router IP**: Alamat IP modem Huawei Anda (contoh: `192.168.8.1`).
    *   **Username**: Nama pengguna untuk login ke modem.
    *   **Password**: Kata sandi untuk login ke modem.
    *   **Telegram Token**: Token bot Telegram Anda untuk notifikasi.
    *   **Chat ID**: ID obrolan Telegram tujuan pengiriman notifikasi.

Jangan lupa untuk menyimpan konfigurasi Anda.

## Penggunaan

Setelah instalasi dan konfigurasi, skrip akan berjalan secara otomatis di latar belakang. Anda tidak perlu melakukan tindakan manual.

Anda juga bisa menjalankan perintah berikut dari terminal untuk mengelola layanan:
*   `huawei`: Menjalankan skrip monitor secara manual.
*   `huawei -d`: Mengaktifkan layanan monitoring (dijalankan via cron).
*   `huawei -s`: Menonaktifkan layanan monitoring.
*   `huawei -x`: Menghapus instalasi skrip dan layanan.

## Screenshot

Berikut adalah tampilan halaman konfigurasi di LuCI yang akan Anda dapatkan setelah instalasi.

<img width="1920" height="1050" alt="image" src="https://github.com/user-attachments/assets/ce65d1a8-d120-4ddc-9bb5-af76a7481621" />

Berikut adalah tampilan Notifikasi ke Bot Telegram.

<img width="441" height="341" alt="image" src="https://github.com/user-attachments/assets/5771425d-94f6-464d-a9c3-a5af2a3c2bfa" />



---

### **Huawei Monitor Settings**

- **Enable Service**: `[✓]`
- **Router IP**: `192.168.8.1`
- **Username**: `admin`
- **Password**: `********`
- **Telegram Token**: `[Token Bot Telegram Anda]`
- **Chat ID**: `[ID Obrolan Telegram Anda]`

[ **Simpan & Terapkan** ]

---
