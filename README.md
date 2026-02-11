# 🖥️ Remote PC Control System (Python & Firebase)

Bu proje, Python ve Firebase Realtime Database kullanarak bilgisayarınızı uzaktan kontrol etmenizi, ekran görüntüsü almanızı ve kapatmanızı sağlayan bir otomasyon sistemidir.

Özellikler

Uzaktan Kapatma: Mobil uygulamadan veya veritabanından gelen komutla bilgisayarı kapatır.
Anlık Ekran Görüntüsü: Uzaktan tetikleme ile o anki ekran görüntüsünü alıp Firebase Storage'a yükler ve link üretir.
Aktif Uygulamalar: Çalışan uygulamaların listesini çeker.
Otomatik Başlatma:`kurulum.py` sayesinde sistem başlangıcına yerleşir.

Kurulum

1. Projeyi bilgisayarınıza indirin.
2. Gerekli kütüphaneleri yükleyin:
   ```bash
   pip install -r requirements.txt