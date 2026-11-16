# n kurgu 0.8 — macOS düzenleme paketi

Apple Silicon / macOS 15+ için yerel SwiftUI + AppKit + AVFoundation uygulaması. Bu sürüm temel kurgu, proje kaydetme ve SDR MP4 çıktısını uçtan uca sunar. CapCut'ın bütün ileri özelliklerini içeren tamamlanmış ürün değildir.

## Başlatma

Hazır ZIP içindeki `n kurgu.app` dosyasını açın. Kaynak koddan paket oluşturmak için Xcode kurulu bir Mac'te:

```sh
./Scripts/build-app.sh
```

Bu komut `Dist/n kurgu.app` üretir.

Uygulama yerel kullanım için ad-hoc imzalıdır. Developer ID, notarization ve App Store dağıtımı henüz yoktur. Sandbox etkin değildir. Apple güvenlik ayarlarında değişiklik yapılması gerekmez; başka bir Mac'teki dağıtım uyarıları için imzalı/notarized bir sürüm gerekir.

## Kullanım

1. **Medya ekle (⌘I):** video/ses seçin veya dosyaları medya havuzuna sürükleyin.
2. **Timeline’a ekle:** havuzdan bir dosya seçin. Klip, seçili uyumlu ve kilitsiz izin sonuna; yoksa ilk uyumlu izin sonuna eklenir.
3. **Düzenleme:** timeline'da klip seçin. Cetvele tıklayarak/sürükleyerek playhead'i taşıyın. C ile kesme, V ile seçim aracına geçin. ⌘B seçili klibi playhead'de böler.
4. **Kısaltma:** Inspector'daki giriş/çıkış alanları timeline saniyesidir. Türkçe sayı biçiminde `1,5` kullanın. Mevcut kesitin içinden bir aralık belirleyin.
5. **Kaldırma:** Inspector'dan “Klibi kaldır” veya timeline odaktayken Delete. Kaynak dosya silinmez. ⌘Z / ⇧⌘Z geri al/yinele.
6. **Kaydetme:** ⌘S `.nkurgu` proje paketini kaydeder; ⌘O yeniden açar. Autosave yoktur.
7. **Dışa aktarma:** sağ üstten “Dışa aktar” veya ⌘E → konum seç → MP4. Çıktı proje boyutu/kare hızında SDR'dir. İlerleme, iptal ve Finder'da göster seçenekleri vardır.

J/K/L, Space ve ok tuşları timeline klavye odağındayken çalışır. J, kaynak destekliyorsa geriye oynatır; aksi hâlde bir kare geri gider. Yazı alanlarında tek harfli kurgu kısayolları çalışmaz.

Panel ayırıcıları sürüklenebilir. İz menüsünden video/ses izi eklenir. Çoklu sequence belgelerinde bu UI ilk sequence'i düzenler.

## Görsel tasarım

Açık/koyu nötr yüzeyler, canlı yeşil vurgu, kaynak görüntüden gerçek küçük resimler, aramalı medya kartları, klip film şeritleri ve ayrı export paneli kullanılır. Timeline film şeridi kaynak dosyanın ilk küçük resmini tekrarlar; zaman boyunca örneklenmiş bir thumbnail dizisi değildir. Ses için sahte waveform çizilmez.

Uygulama simgesi ve önceki açılış görseli Higgsfield üzerinden bu proje için üretildi. 0.6 açılış alanı ve uygulama içi ikonlar, kullanıcının çizgi stili referanslarına göre kodla çizilmiş özgün vektörlerdir. Kaynaklar ve üretim bilgileri `Brand/PROVENANCE.md` içindedir. Görseller pakete gömülüdür; uygulama çalışma sırasında Higgsfield'a bağlanmaz veya kullanıcının medyasını yüklemez.

## Örnekler

- `Demo/renk-testi.mov`: iki saniyelik kırmızı/mavi doğrulama medyası.
- `Demo/Ornek Kurgu.nkurgu`: UI'da kaydedilip tekrar açılmış örnek proje.
- `Demo/Ornek Kurgu.mp4`: son uygulama paketi üzerinden üretilmiş 1080p, 30 fps, 1.5 saniyelik çıktı.

Örnek proje bu çalışma alanındaki medya dosyasına referans verir; klasör farklı konuma taşınırsa test videosunu yeni projeye içe aktarın. Medyayı proje içine toplama ve dosya yeniden bağlama UI'ı henüz yoktur. Projeleri uygulamanın Aç komutuyla açın; Finder çift tıklama ilişkilendirmesi yoktur.

## Mimari

- **KurguCore:** rasyonel zaman, Project/Sequence/Track/Clip, doğrulama.
- **KurguEditing:** atomik komutlar, split/trim/remove, medya/iz ekleme, undo/redo.
- **KurguPersistence:** sürümlü JSON, atomik proje dosyası yazımı.
- **KurguMedia:** async metadata, dosya erişimi, CoreMedia zaman dönüşümü.
- **KurguPlayback:** timeline compilation, SDR katman kompozisyonu, AVPlayer preview.
- **KurguExport:** değişmez proje snapshot'ından MP4, ses miksajı, ilerleme/iptal, geçici dosyadan tamamlanmış çıktıya geçiş.
- **NKurguApp:** SwiftUI workspace, AppKit timeline ve AVPlayerView.

Export, AVAssetExportPresetHighestQuality kullanır. Bu Mac'teki testlerde video H.264 ve ses tek mikslenmiş iz olarak doğrulandı. Ayrı bitrate/codec seçimi veya zorunlu donanım encoder garantisi yoktur. Export başlarken alınan snapshot daha sonraki proje düzenlemelerinden etkilenmez. İptal/hata mevcut çıktı dosyasını korur; geçici dosya temizlenir. Kaynak dosya yoluna export engellenir.

Ad-hoc imza değiştiğinde eski bookmark çözülemezse yalnızca kayıtlı kaynak yoluna macOS zaten okuma izni veriyorsa fallback yapılır. OS erişim sınırları aşılmaz.

## Doğrulama

```sh
swift test
```

26 otomatik test başarılı. Rasyonel zaman, hatalı düzenleme rollback, undo/redo, persistence, kaynak/target zaman eşlemesi, yön düzeltme, katman ve siyah boşluk pikselleri, seek/playback, MP4 süresi/kodeği/sesi/kareleri, üzerine yazma, iptal temizliği ve bookmark fallback kapsanır.

Son uygulama paketiyle açılış görseli, örnek proje yükleme, medya thumbnail'ları ve MP4 export akışı ayrıca UI üzerinden kontrol edildi. Önceki UI turunda import, split, trim, undo ve save/open doğrulandı. 4K/HDR ve uzun proje performans benchmark'ı yapılmadı.

## Mevcut sınırlar

AI altyazı/segmentasyon, renk grading, Metal efekt compositor'u, metin/sticker, keyframe, speed ramp, HDR, codec/preset seçimi, proxy, tüm izlerde manyetik düzenleme, ripple trim, slip/slide ve waveform henüz uygulanmadı. Aynı izde overlap desteklenmez; birden çok izde kompozisyon yapılır. Görüntü ve ses için ilk kaynak stream kullanılır. Detaylı VoiceOver klip navigasyonu henüz yoktur.

## 0.5 — Timeline üzerinde doğrudan kurgu

- Klip gövdesini sürükleyerek aynı izde veya uyumlu başka bir izde taşıyın.
- Klip kenarındaki tutamacı içeri sürükleyerek kısaltın. Bu sürümde dışarı sürükleyerek kaynak aralığını genişletme yoktur.
- N veya hedef düğmesi otomatik hizalamayı açar/kapatır. Sürükleme sırasında Option geçici olarak devre dışı bırakır. 8 ekran pikseli içindeki klip sınırları, sıfır ve playhead hizalama hedefleridir; klibin her iki kenarı değerlendirilir.
- Yeşil çerçeve geçerli, kırmızı çerçeve reddedilecek yerleşimdir. Çakışan/uyumsuz/kilitli hedefe bırakmak projeyi değiştirmez.
- Escape sürüklemeyi iptal eder. Başlangıç noktasına dönüp bırakmak değişiklik üretmez. Her tamamlanmış sürükleme tek undo adımıdır.
- Shift+Delete veya Inspector “Boşluğu kapatarak kaldır”: klibi kaldırır, aynı izde sonrasındaki klipleri silinen klibin süresi kadar sola taşır. Önceden bulunan boşluklar ve diğer izler korunur. Bu özellik tüm izler için bir senkron kilidi veya tam manyetik timeline değildir.

Yeni testler: izler arası taşımanın sourceStart/kimlik koruması, undo/redo, çakışma/iz türü/kilit/negatif zaman reddi, tek izde ripple silme ve snapping mesafe/eşitlik kuralları. Uygulama penceresinde taşıma, kenardan trim, uyumsuz ize bırakma reddi, undo ve ripple silme doğrulandı.

## 0.6 — Çizgi ikonları ve iki tema

Yuvarlak uçlu konturlar, düz yeşil vurgular ve sade yüzeylerden oluşan görsel dil. Medya, kulaklık, dosya ekleme, kesme, özellikler ve dışa aktarma ikonları SwiftUI Canvas ile çözünürlükten bağımsız çizilir. Küçük araç ikonlarında ayrıntı azaltılır. Mikrofon motifi de aileye dahildir; ses kaydı işlevi eklenmiş değildir.

Sağ üstteki yarım daire menüsünden Sistem / Açık / Koyu seçilir; tercih saklanır. AppKit timeline aynı temayı izler. Inspector kaydırılabilir, devre dışı düğmeler soluk görünür. `Brand/IconGuide.svg` iki temada ikon paftasıdır.

0.6 doğrulama: 19 test geçti; açık/koyu tema geçişi, örnek proje yükleme, önizleme ve timeline kontrastı gerçek uygulama penceresinde kontrol edildi.

## 0.7 — İz kontrolleri ve ses miksajı

- İz adına tıklayın: sağ panelde adlandırma, kilitleme, susturma ve %0–200 ses seviyesi bulunur. Video izinde bu ayar videonun gömülü sesini etkiler; görüntüyü gizlemez.
- Ses sürgüsünü bırakınca değişiklik tek undo adımı olarak uygulanır; önizleme kompozisyonu yeniden hazırlanır. Bu sürüm gerçek zamanlı kayıt mikseri değildir. %100 üzeri kazanç veya birden çok sesin toplamı clipping oluşturabilir; limiter henüz yoktur.
- Ses seviyesi ve susturma aynı AVAudioMix üzerinden önizlemeye ve MP4 çıktısına uygulanır. Susturmak ayarlı ses seviyesini korur.
- Timeline iz başlığında kilit ve hoparlör düğmeleri ile ses yüzdesi gösterilir. Aynı kontroller sağ panelde erişilebilir düğmelerdir.
- Kilitleme klip düzenlemesini, iz adını ve ses ayarını korur. Kilidi açma ve undo kullanılabilir. Kilit oynatma veya çıktıyı engellemez.
- ⌘D veya “İzin sonunda çoğalt”: kaynak aralığı ve süre korunarak aynı izin sonuna yeni kimlikli bir klip eklenir. Diğer klipler kaymaz.
- “Sığdır” görünür alan ve kurgu süresine göre zoom'u ayarlar (1–180 piksel/saniye aralığı). Çok uzun projelerde minimum zoom sınırı geçerlidir.
- İz, ses ve klip kontrolleri gruplanmış kaydırılabilir özellikler panelinde sunulur.

Proje şeması 2 oldu. Şema 1 dosyaları açılırken bellekte dönüştürülür ve varsayılan %100/açık ses kullanılır. Kaydetme yeni şemayı yazar. 0.6 ve önceki sürümler şema 2 dosyalarını açamaz; eski sürümle çalışmaya devam edecekseniz Farklı Kaydet kullanın.

Doğrulama: 22 test geçti. Gerçek PCM örneklerinde %25 kazanç oranı ve sessizlik; AAC/MP4 dışa aktarımında aynı sonuç ölçüldü. Klip çoğaltma, kilit, hatalı kazanç reddi, undo/redo, eski proje migrasyonu ve dosyanın açılışta değiştirilmemesi doğrulandı. Mac kilitli olduğundan 0.7'nin interaktif UI kontrolü bu turda yapılamadı.

Bu çalışma alanında yeni hazır paket `Dist/0.7/n kurgu.app` konumundadır. Önceki açık uygulama değiştirilmeden korunmuştur. İndirilebilir 0.7 ZIP'inin içinde uygulama doğrudan bulunur.

## 0.8 — Tuval oranları ve klip kadrajı

Önizlemenin sağ üstündeki oran menüsünden tek tıkla 9:16 (1080×1920), 16:9 (1920×1080), 1:1, 4:5, 4:3, 3:4 veya 21:9 seçin. Yanındaki ayar düğmesi veya ⇧⌘R, görsel tuval kartlarını açar. Oran seçimi anında uygulanır; Bitti yalnızca paneli kapatır. Her değişiklik ⌘Z ile geri alınabilir. Klip süreleri, kaynak aralıkları ve kare hızı değişmez.

- **Sığdır:** görüntünün tamamı görünür; gerekiyorsa siyah boşluk bırakılır.
- **Doldur:** görüntü bozulmadan büyütülür ve taşan kenarlar kırpılır.
- **Yönü çevir:** tuvalin genişliği/yüksekliği yer değiştirir. Kaynak videoyu döndürmez.
- **Özel boyut:** her eksende 64–4096 arasında çift sayılı piksel ölçüleri. Uygula ile kaydedilir.
- **4K:** yatay 3840×2160 veya dikey 2160×3840 tuval seçimi. Performans donanıma/kaynağa bağlıdır; 4K benchmark yapılmadı.
- **Klip kadrajı:** video klibi seçin. Özellikler panelinde Tuval ayarı / Sığdır / Doldur, %100–400 yakınlaştırma ve yatay/dikey kadraj bulunur. Sürgüyü bırakınca uygulanır. Konum -100'de ilk kenarı, +100'de son kenarı hizalar; boşluk/taşma olmayan eksende etkisi yoktur.
- **Güvenli alan:** önizlemedeki vizör simgesi %10 iç boşluk kılavuzu gösterir. Genel hizalama yardımıdır; platform arayüzlerinin güncel kaplama alanını garanti etmez ve çıktıya çizilmez.

Önizleme gerçek tuval oranında çerçevelenir. MP4, aynı kompozisyon ve kadraj dönüşümleriyle üretilir. Kadraj ayarları split/trim/duplicate sırasında korunur. Kilitli izde klip kadrajı değiştirilemez; proje genelindeki tuval seçimi kilitli izler dahil bütün projeye uygulanır. Otomatik konu takibi, AI reframe ve bulanık arka plan bu sürümde yoktur.

Şema 3: şema 1 ve 2 projeleri dosyaları değiştirilmeden bellekte güncellenir. Kaydetme şema 3 yazar; önceki uygulamalar bunu açamaz. Geriye dönük kopya için Farklı Kaydet kullanın.

26 test: dönüşüm geometrisi, rotasyon, piksel düzeyinde sığdır/doldur ve üç yatay kadraj konumu, 1080×1920 ve 1920×1080 MP4 boyutları, undo/redo, kadrajın split/duplicate ve persistence sırasında korunması, geçersiz boyut/kadraj reddi.

Bu çalışma alanındaki 0.8 paketi `Dist/0.8-final/n kurgu.app` konumundadır.

0.8 UI kontrolü: oran kartları, 9:16 geçişi, Sığdır/Doldur seçimi, geri alma ve eski örnek proje açılışı uygulama penceresinde doğrulandı. Kapsamlı interaktif klip kadrajı sürükleme testi yapılmadı; dönüşüm ve export doğrulaması otomatik piksel testleriyle tamamlandı.
