# kurgucu — Logo ailesi

Referanslardaki kulaklıklı karakter, yuvarlatılmış çizgi ve yeşil vurgu; video ekranı ve ses dalgasıyla kurgucu'ya uyarlandı.

- `Logo-Light.png`: açık yüzeyler için 2048 × 2048 ana maskot, dış alanı şeffaf.
- `Logo-Dark.png`: koyu yüzeyler için 1254 × 1254 ana maskot, dış alanı şeffaf. Beyaz dış çizgi silüeti koyu zeminden ayırır.
- `Mark-Light.svg`, `Mark-Dark.svg`: küçük boyutlar için özgün, ölçeklenebilir kulaklık/oynatma simgesi. PNG karşılıkları 512 × 512.
- `AppIcon.icns`: macOS uygulama simgesi; büyük boyutlarda açık maskotu kullanır. Finder/Dock dosya simgesi sabittir. Uygulama içindeki logo tema seçimine göre değişir.
- `Logo-Onizleme.html`: iki temayı ve 20/32/48 piksel küçük simgeleri yan yana gösteren yerel sunum. Yazı HTML metnidir; ana logo PNG'lerinde yazı yoktur.
- `Higgsfield-Konsept.png`: ilk tasarım sunumu; son PNG dosyalarından ayrı konsept çalışmasıdır.

Ana maskotu 96 piksel ve üzerinde; sade simgeyi 20–48 pikselde kullanın. PNG'lerin şeffaf dış boşluğunu koruyun, en-boy oranını değiştirmeyin. Ana maskotlar rasterdır; vektör oldukları iddia edilmemelidir. Üretim tabanlı iki ana tema sürümünün geometrisi birebir aynı değildir; küçük SVG çiftinin geometrisi aynıdır.

Palet: yeşil `#05CF59`, koyu `#151719`, kırık beyaz `#F7F7F2`. Renk değerleri SVG'de kesindir; raster üretimde küçük ton değişimleri olabilir.

## Üretim kaydı
Açık ana logo ve ilk konsept Higgsfield / gpt_image_2_5 ile üretildi. Koyu logo, Higgsfield kredi sınırına ulaşıldıktan sonra yerleşik image_gen aracında açık logo referansıyla tamamlandı; CLI/API betiği kullanılmadı. Son promptlar `Uretim-Promptlari.json` içinde. Küçük simgeler mevcut SwiftUI/SVG ikon ailesine uygun özgün kod çizimleridir. Kullanıcının ekran görüntüleri Higgsfield'e yüklenmedi; metin tarifi ve bu proje için üretilen görseller kullanıldı.
