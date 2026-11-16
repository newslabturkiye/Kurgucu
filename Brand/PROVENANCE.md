# Görsel kaynaklar

Bu proje için Higgsfield bağlantısı kullanılarak üretildi; model: gpt_image_2_5.

- Açılış resmi: `Sources/NKurguApp/Resources/Welcome.png`
  - İş kimliği: 199ad0ac-2696-49f6-a777-52d1a8eedccf
  - 16:9, antrasit zemin üzerinde mint cam film şeridi; yazılar yerel SwiftUI katmanındadır.
- Uygulama simgesi: `Brand/Archive-0.9/AppIcon.png`
  - İş kimliği: 0bc8088d-e4d5-4da0-8624-62171fdd2b27
  - 1:1, mint kurdele biçiminde n monogramı.
  - `AppIcon.icns`, üretilen görselin macOS ikon boyutlarına dönüştürülmesiyle hazırlanmıştır.

Kullanıcının dosyaları veya uygulama ekran görüntüleri görsel üretim servisine yüklenmedi. Yalnızca metin tasarım tarifleri gönderildi.


## 0.6 uygulama içi görsel dil
Kullanıcının iki referans görselindeki yuvarlak monoline çizgi ve yeşil vurgu yönü temel alındı. Yeni ikonlar SwiftUI Canvas ve SVG geometrisiyle özgün olarak çizildi; referans görsellerin pikselleri kopyalanmadı. Yeni açılış alanı bu vektörleri kullanır. Bu sürümün uygulama içi ikonları Higgsfield çıktısı değildir. Önceki Higgsfield uygulama simgesi korunmuştur.


## 0.9.1 logo ailesi
Yeni açık maskot Higgsfield gpt_image_2_5: 53fb35f8-d8bc-4c92-afb5-1deb31e8b32a. Konsept: 923a03f0-910f-44fb-8dd7-3cf0bb949af7. Son koyu maskot yerleşik image_gen aracında üretildi. Kredi sınırı nedeniyle tamamlanamayan Higgsfield düzeltmesinden sonra yerleşik araca geçildi. Küçük simgeler özgün SVG/SwiftUI Canvas çizimleridir. `Brand/AppIcon.png` artık yeni açık maskottur. Son promptlar ve kullanım bilgisi `LogoKit` klasöründedir.


## 0.9.3 — Higgsfield stüdyo illüstrasyonları
Model: gpt_image_2_5. Kullanıcının ekran görüntüsü yüklenmedi; çizgi dili metinle tarif edildi. Ana logo aynı kaldı. Yeni PNG kaynakları uygulama paketine dahil edilmiştir; uygulama çalışırken internet gerekmez.

- Scene-Landscape.png: b8f21158-25b4-43f9-afab-0759133c9968
- Scene-Portrait.png: ff2839ff-34f2-4f39-bb8e-55fe2e83ea02
- Scene-Square.png: 71a83a38-e2c6-4984-9a31-db16c38359c0
- Scene-Social.png: 886e5746-3b03-49b4-a935-56394a11b190

Görseller `Sources/NKurguApp/Resources` içindedir. Bu sahneler formatları anlatan illüstrasyonlardır; kamera kaydı veya çoklu konuşmacı yakalama gibi ek işlev vaat etmezler.

## 0.11.0 — Genel kullanıma uygun çıkartmalar
Higgsfield, gpt_image_2_5, 1:1, gerçek alfa kanallı 1024×1024 PNG. Uygulamanın logosu değişmedi. Kullanıcının son yönlendirmesi doğrultusunda renkli sosyal medya görsel dili de kullanıldı. Yalnızca metin tarifleri gönderildi.

- Sticker-Arrow.png: 01d381f7-5771-43f8-82b3-0fb1ca1422ad — kıvrımlı yeşil ok.
- Sticker-Spark.png: 89b2c3db-a399-427c-adb2-dbf9339ae4b2 — yeşil/beyaz yıldızlar.
- Sticker-Heart.png: 27ebf603-6b09-48e6-9f06-cb362d2a0278 — pembe mercan kalp ve mor/sarı vurgular.

Kaynaklar Sources/NKurguApp/Resources içindedir; çevrimdışı kullanılabilir. Bunlar statik çıkartmalardır; animasyonlu GIF/WebP oynatma bu sürümde yoktur.


## 0.11.1 — Kırmızı görsel kimlik
Higgsfield / gpt_image_2_5, önceki üretimlerin job kimlikleri referans alındı. Kullanıcının yerel dosyaları yüklenmedi. Son logolar 1024×1024 gerçek alfa kanallıdır. İlk koyu taslak bir karşılaştırma panosu ürettiği için pakete alınmadı; son tek-logo sürümleri kullanıldı. Uygulama simgesi açık logodan macOS boyutlarına ölçeklendi.

- Logo-Light.png: 74c9c0c4-e04e-49fb-8009-fa83e03bce7f
- Logo-Dark.png: c5eac50b-684c-48f1-a707-80708974855a
- Scene-Landscape.png: dc085e05-d3a6-403d-a9ba-104766ac0897
- Scene-Portrait.png: 6d3b9394-5763-4975-a10a-b1ce70286ff7
- Scene-Square.png: 7d01d03e-8ae5-4406-b0d7-70f236731d60
- Scene-Social.png: f00f0820-06c0-4bc8-b4ae-b1fadb10eff3
- Sticker-Arrow.png: f7129cff-0a18-47df-8543-1d5fdc5dfae1
- Sticker-Spark.png: ecdc2d94-45d0-4f9e-85a0-3cfcff60f61f
