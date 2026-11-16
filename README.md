# kurgucu 0.12.0

SwiftUI, AppKit ve AVFoundation ile Apple Silicon / macOS 15+ video düzenleme uygulaması. Yerel ad-hoc imzalı geliştirme sürümüdür; Developer ID/notarization dağıtımı yoktur.

## Başlatma

Hazır ZIP içindeki `kurgucu.app` dosyasını açın. Bu çalışma alanındaki paket `Dist/0.12.0-final/kurgucu.app` konumundadır. Kaynaktan derleme: `./Scripts/build-app.sh`; standart çıktı `Dist/kurgucu.app` olur. Test: `swift test`.

## 0.12.0 — OpenCut referansıyla temel kurgu araçları

Kırmızı tasarım ve native Swift motoru korundu. OpenCut Classic’in kaynak sesini ayırma, öğe bazlı özellikler ve geri alınabilir komut yaklaşımı incelendi. React/Rust kodu uygulamaya bağlanmadı; native karşılıklar yazıldı. İncelenen commitler ve özellik eşlemesi `Docs/OpenCut-Review.md` içindedir. MIT bildirimi uygulamanın Hakkında panelinde ve kaynak paketinde bulunur.

- **Döndürme / ayna:** video klibi → Özellikler → Kadraj. −180°…180°, ±90° düğmeleri, yatay/dikey ayna. Önce kaynak yönü, sonra dönüş/ayna, ardından sığdır/doldur uygulanır; önizleme ve export ortak hesaplama kullanır.
- **Klip sesi:** izden bağımsız %0–200 seviye ve susturma. Son kazanç, iz ve klip seviyelerinin çarpımıdır; aşırı kazançta kırpılmayı önlemek için mevcut limiter kullanılabilir.
- **Sesi ayır:** video klibi → Klip sesi → Sesi ayrı ize ayır veya Kurgu menüsü. Kaynakta ses olduğu kontrol edilir; ses aynı kaynak kesiti, timeline konumu, süre ve fade ile yeni ize alınır. Video artık kaynak sesini çalmaz. Sonraki düzenlemeler bağımsızdır; bağlantılı taşıma uygulanmaz. Ayırma ⌘Z ile geri alınabilir.
- **Kaynak kesitini kaydır (slip):** klibin konumu ve süresi sabitken kaynak başlangıcını değiştirir. Kaynak sınırını aşan işlem reddedilir.
- **İzde boşluk kapat:** seçili izin kliplerini sıfırdan başlayarak yan yana getirir; diğer izler, altyazılar ve çıkartmalar yerlerinde kalır.

Doğrulama: 37 test geçti; standart ve özel compositor üzerinde gerçek MP4 dönüş/ayna kareleri, ses ayırma RMS eşitliği ve klip kazancı ölçüldü. Çalışan uygulamada döndürme/ayna kontrolleri ve sessiz kaynak için ayırma uyarısı kontrol edildi. Paket yalnızca tanımlı uygulama kaynaklarını içerir.

Kilitli izler korunur; değişiklikler undo/redo ve proje kaydına dahildir. Yeni kayıt şema 7 yazar, 1–6 sürümleri yüklenir. Eski uygulamalara dönülecekse Farklı Kaydet kullanın. Bu sürüm bütün OpenCut özelliklerini içermez; kalan kapsam inceleme belgesinde açıkça ayrılmıştır.

## 0.11.1 — Kırmızı görsel kimlik

İş akışı ve kurgu motoru aynı kaldı. Yeşil vurgu yerine kırmızı; ana logo, uygulama simgesi, dört format kartı ve ok/yıldız çıkartmaları Higgsfield ile yenilendi. Timeline, butonlar, seçim sınırları ve simgeler kırmızı palete geçti. Açık/koyu tema için ayrı logo ve uyarlanabilir vurgu/metin renkleri kullanılır. Genel içerik olan renkli kalp korunur; daha önce projeye gömülen çıkartmaların rengi değiştirilmez.

33 test geçti. Açık/koyu tema logoları, kırmızı seçim/buton renkleri ve format kartları çalışan uygulamada kontrol edildi. Yeni sürüm şema 6 kullanır; 0.11.0 projeleri aynı biçimde açılır. Önceki yeşil varlıklar Brand/Archive-0.11-green içinde arşivdir; uygulamaya dahil edilmez. Aşağıdaki sürüm notları geçmiş sürümlerin durumunu anlatır.

## 0.11.0 — Fotoğraf, çıkartma ve görüntü araçları

Dokuz araç bölümü artık kullanılabilir. Medya, video/sesin yanında fotoğraf alır. Fotoğraflar en uzun kenarı 1920 piksel, 30 fps, 5 saniyelik yönetilen MOV kliplerine dönüştürülür; timeline'a eklenip kısaltılabilir. Dosyalar `~/Library/Application Support/kurgucu/Stills` altında tutulur. Başka bilgisayara taşırken kaynak videolar gibi bu dosyaları da taşıyın. Saydam fotoğraf zemini siyahtır; şeffaf katman için Çıkartmalar bölümünü kullanın.

**Çıkartmalar:** Higgsfield ile üretilen ok, yıldızlar ve renkli kalp; ayrıca kendi görselinizi içe aktarma. Başlangıç, süre, konum, boyut, dönüş ve opaklık düzenlenir; Uygula ile kaydedilir. En fazla 1024 piksel normalize edilen PNG proje içine gömülür. Katmanlar panelde yönetilir; timeline üzerinde ayrı çıkartma şeridi henüz yoktur. Video süresini uzatmazlar.

**Filtreler:** orijinal, siyah-beyaz, sıcak, soğuk, canlı ve soluk görünümler ile yoğunluk. **Efektler:** bulanıklık ve vinyet. **Ayar:** pozlama, kontrast, doygunluk, sıcaklık ve tuval ayarları. Video klibini seçin, değerleri düzenleyip Uygula'ya basın. Sıfırla, klibin tüm görüntü ayarlarını temizler. Değişiklikler geri alınabilir ve projede saklanır.

**Geçişler:** klip başında açılma ve sonunda kararma. Altta görüntü varsa onu, yoksa siyah zemini gösterir. Bu sürüm komşu klipler arasında otomatik çapraz çözünme veya kaydırma geçişi içermez; ses fade ayarları ayrıdır. Efekt ve renk değerleri klip boyunca sabittir; keyframe içermez. Ortak Core Image compositor, filtreli önizleme ve export için kullanılır.

Metin düzenleyicide üç font ailesi (sistem/serif/eş aralıklı), kalınlık, sol/orta/sağ hizalama, yazı/zemin/kontur renkleri ve alfa, kontur genişliği ve gölge bulunur. Ekle/Güncelle ile uygulanır; değişiklikler geri alınabilir. Stili sıfırla varsayılan görünümü geri getirir. Stil, ortak yazı katmanı üzerinden hem önizlemeye hem export'a uygulanır. SRT stil taşımaz; stiller proje dosyasında korunur.

Eski projeler açılabilir; yeni kaydetme şema 6 yazar. Şema 6 dosyası önceki sürümlerde açılmaz. Eski sürümle de çalışılacaksa Farklı Kaydet kullanın.

Doğrulama: 33 test geçti; fotoğraf dönüştürme, filtre/fade, saydam çıkartma zamanlaması, standart ve özel compositor üzerinde katmanlar/boşluklar ile gerçek MP4 kareleri doğrulandı; yeni stilin saklanması, şema 4 yükleme, geçersiz stilin atomik reddi, undo/redo ve gerçek MP4 karelerinde renkli yazının doğru zamanda görünmesi test edildi. Çalışan 0.11.0 uygulamasında fotoğraf içe aktarma, timeline’a ekleme, siyah-beyaz filtre uygulama ve renkli kalp çıkartmasının birlikte görünmesi kontrol edildi. Ana maskot logo araç çubuğunda doğrulandı.

## 0.9.3 görsel yenileme

Ana logo paket içindeki PNG dosyasından doğrudan yüklenir; eski sürümdeki boş logo alanı giderildi. Açık/koyu logo görselleri değiştirilmedi. Dört format kartına Higgsfield illüstrasyonları eklendi. Resimler özgün renkleriyle çizilir; koyu temada görünürlük korunur. Kartı seçip proje adı girin ve **Kurguya başla** düğmesine basın. Boş önizleme alanı da yeni stüdyo illüstrasyonunu kullanır.

Kontrol: paket derlendi; çalışan uygulamada açık/koyu logo ve dört kart görseli doğrulandı; özel proje adıyla 9:16/1080×1920 proje oluşturuldu.

## Ad değişikliği

Uygulamanın yeni adı **kurgucu**. Logo ve açık/koyu görselleri aynen korunmuştur. Eski projeler, otomatik kurtarma kayıtları ve ayarlar için paket kimliği, `.nkurgu` proje uzantısı ve mevcut veri dizinleri korunmuştur.

## Logo ailesi

Başlangıç ekranı açık/koyu temaya göre değişen yeni kulaklıklı kurgu maskotunu; araç çubuğu da aynı ana maskot logosunu kullanır. Finder/Dock simgesi sabit açık maskottur. Önceki uygulama simgesi `Brand/Archive-0.9` altında korunmuştur. Marka kaynakları ve üretim kaydı `Brand/LogoKit` içindedir.

## Yeni görsel düzen

Referanslardaki açık/koyu nötr yüzeyler, yeşil vurgu, çizgi ikonlar ve serif başlıklar kullanıldı. Başlangıç ekranında dört tuval şablonu, proje açma ve kurtarma kayıtları bulunur. Üstte ev simgesi başlangıca döner; çalışma alanı menüsü medya havuzunu ve özellikleri gizler. Bölücülerle paneller büyütülür. Gerçek dosya ve gerçek görev durumları gösterilir. Referanstaki podcast kayıt, AI temizleme veya otomatik transkripsiyon vaatleri bu sürümün işlevi olarak eklenmedi.

## Kurgu akışı

1. Bir şablon seçin, proje adını girip Kurguya başla düğmesine basın veya Proje aç (⌘O) kullanın. Medya ekle (⌘I) ile video/ses/fotoğraf alın.
2. Havuzdan bir medya kartını timeline'ın uygun video/ses izine bırakın. Bırakılan konum kareye yuvarlanır; çakışma, yanlış iz türü ve kilit reddedilir. Havuzdaki Timeline’a ekle düğmesi izin sonuna ekler.
3. Klip gövdesini taşıyın; kenarları içeri sürükleyerek kısaltın. C kesme, V seçim, ⌘B bölme, ⌘D izin sonunda çoğaltma.
4. Shift+tıkla çoklu seçim yapın. Seçili kliplerden birini sürüklemek grubun zamanını aynı miktarda değiştirir; her klip kendi izinde kalır. Çoklu silme normal silmedir, ripple uygulanmaz. Bir klip hata verirse bütün grup değişikliği reddedilir.
5. N snapping; sürüklerken Option geçici kapatır. Escape sürüklemeyi iptal eder. Tek klipte Shift+Delete aynı izde aradaki klip süresini kapatır.
6. ⌘Z / Shift+⌘Z geri al/yinele. ⌘S proje kaydı; Shift+⌘S farklı kaydetme. Kaynak medya proje içine kopyalanmaz.

Timeline’da klip başına gerçek kaynaktan zaman içinde örneklenmiş 12 küçük resim ve gerçek PCM sesinden çıkarılmış 1500 kutulu tepe dalga biçimi bulunur. Çok yakın zoom'da bunlar seyrek örneklemedir; her kare için ayrı thumbnail değildir.

## Tuval ve doğrudan kadraj

Önizleme oran menüsü: 9:16, 16:9, 1:1, 4:5, 4:3, 3:4, 21:9. Ayar panelinde Sığdır/Doldur, yönü çevir, çift sayılı 64–4096 px özel ölçü ve yatay/dikey 4K bulunur.

Video klibi seçiliyken önizlemeyi sürükleyerek kadraj konumunu, sağ alt köşeyi sürükleyerek yakınlaştırmayı değiştirin. Kalıcı değişiklik bırakıldığında uygulanır; sürükleme sırasında geçici görsel dönüşüm gösterilir. Kaynak sınırına ulaşan konum sınırlanır. Taşma/boşluk olmayan eksen sabittir. Özellikler paneli %100–400 zoom ve tam konum ayarı sunar. Genel %10 güvenli alan kılavuzu çıktıya çizilmez.

## Ses

İz adını seçin: yeniden adlandırma, kilit, susturma, %0–200 ses. Video izi kaynak videonun gömülü sesini etkiler. Klip panelinde saniye cinsinden fade giriş/çıkış ayarlanır; toplamları klip süresini aşamaz. Bölmede sol parçanın giriş fade'i, sağ parçanın çıkış fade'i korunur; kısaltmada fade süreleri yeni uzunluğa sınırlandırılır.

Master limiter, miksin PCM örneklerini ±0.98'e sınırlayan hard-ceiling işlemidir. Look-ahead/true-peak limiter değildir; sert sınırlama yoğun sinyalde distorsiyon yapabilir. Oynatma seviye göstergesi hazırlanmış miksin 50 ms kutulu gerçek örnek tepesini gösterir; ses aygıtının çıkışını ölçmez. Ses ve limiter önizleme/çıktıda aynıdır. Tuval, kadraj veya metin değişirken ses yeniden değişmediyse son miks önbellekten kullanılır. AAC kodlama true-peak taşmalarını ayrıca garanti etmez.

Miks göstergesi için ses, önizleme hazırlanırken analiz edilir; limiter açıkken işlenmiş geçici CAF dosyası kullanılır. Uzun kurgularda ilk hazırlık zaman/disk alanı gerektirir. Geçici dosya hazırlanmış kompozisyon bırakıldığında temizlenir; çökme sonrası işletim sistemi geçici dizininde kalabilir.

## Yazı ve altyazı

Üstte Metin düğmesi: başlık, alt bant ve altyazı şablonları. Metin, başlangıç, süre, yazı boyutu ve dikey konum düzenlenir. Varsayılan beyaz yazı/yarı saydam siyah zemin görünümü özelleştirilebilir; seçilen stil önizlemeye ve videoya işlenir. Yazı aralıklarını mevcut video süresi içinde tutun; yalnızca yazı içeren proje henüz render edilmez.

UTF-8 SRT içe/dışa aktarma vardır. SRT dosyası metin ve zaman taşır; stil bilgilerini taşımaz. Otomatik konuşma tanıma henüz yoktur. Metin içeriğini değiştirerek ses kesme bu sürümde uygulanmamıştır.

## Proxy ve önizleme

Çalışma alanı menüsünden 720p proxy oluşturun. Dosyalar `~/Library/Caches/n kurgu/Proxies` altında kaynak kimliği, boyutu ve değişiklik tarihine göre önbelleğe alınır; yeniden aynı komut verildiğinde kullanılır. Proxy aç/kapat ve tam/yarım/çeyrek önizleme çözünürlüğü seçilebilir. Export her zaman proje içindeki özgün kaynakları kullanır. Kaynak dosyaları taşınırsa yeniden bağlama UI'ı henüz yoktur.

## Otomatik kayıt ve kurtarma

Düzenlemeden 800 ms sonra ayrı atomik kurtarma JSON'u yazılır. Her proje için son 20 kopya tutulur; asıl `.nkurgu` dosyası kullanıcı kaydetmeden üzerine yazılmaz. Kayıtlar `~/Library/Application Support/n kurgu/Recovery` altındadır. Başlangıç ekranı veya çalışma alanı menüsünden eski kopyayı ayrı proje olarak açın. Uygulamadan çıkarken bekleyen kurtarma kaydı tamamlanır. Son 800 ms içinde güç kesilirse en yeni düzenleme kurtarma kaydına girmemiş olabilir.

Şema 7. Şema 1–6 projeleri açılırken bellekte güncellenir. Kaydetme şema 7 yazar; önceki uygulamalar yeni dosyaları açamaz.

## Dışa aktarma

⌘E: H.264/MP4, HEVC/MP4 veya ProRes 422/MOV; proje boyutu, yarım veya iki kat boyut; proje fps veya 24/25/30/50/60 fps. SDR Rec.709. ProRes kalite seçimi encoder presetine bağlıdır. Diğer kodeklerde küçük/standart kalite yaklaşık 3/8 Mbps toplam dosya bütçesi uygular; tam bitrate garantisi değildir. Tahmini dosya boyutu yaklaşık değerdir. Metinler, kadraj, fade ve miks birlikte çıktıya girer. İlerleme, iptal ve Finder'da göster bulunur. Geçici dosya başarıyla bitmeden mevcut çıktı değiştirilmez; kaynak yolunun üzerine çıktı engellenir.

## Doğrulama ve sınırlar

33 test: düzenleme/undo atomikliği, çoklu taşıma, fade süreleri, 20 sürümlü kurtarma, SRT zaman round-trip, gerçek waveform/proxy, limiter tavanı ve sessiz başlangıç, yazının doğru zaman aralığında export karelerinde bulunması, HEVC/ProRes boyutları ve önceki render/ses testleri. Uzun proje/4K performans benchmark'ı yapılmadı.

Bu sürüm temel stüdyo iş akışını kapsar. AI altyazı/segmentasyon, otomatik reframe, HSL/curves/LUT renk grading, keyframe/speed ramp, HDR, kayıt ve profesyonel efekt zinciri henüz yoktur.

Önceki mimari ve sürüm notları `Docs/History-through-0.8.md` içindedir.

UI doğrulaması: yeni başlangıç ekranı, eski proje açma, otomatik kayıttan kurtarma, metin ekleme ve önizlemede görünmesi, gelişmiş export paneli gerçek uygulamada kontrol edildi. Otomasyon ortamında medya kartı sürükleme hareketi tamamlanamadı; yerel NSDraggingSource/Destination yolu derlendi fakat uçtan uca sürükle-bırak etkileşimi manuel doğrulama gerektiriyor.


## Geliştirici

Sarphan Uzunoğlu  
Dijital Medya Araştırmaları Derneği  
newslabturkey

Geliştirici kredisi başlangıç ekranında ve kurgucu → kurgucu Hakkında penceresinde gösterilir.


## 0.9.5 — Üst çubuk logosu

Eski sade kulaklık işareti kaldırıldı. Üst çubuk ve başlangıç ekranı artık aynı ana logoyu, açık/koyu temaya uygun sürümüyle gösterir. Logo görsel dosyaları ve geliştirici kredisi korunmuştur.

## Lisans

kurgucu, [NewsLab Türkiye](https://newslabturkey.org) tarafından geliştirilir ve GNU General Public License v3.0 ile yayımlanır. Ayrıntılar için `LICENSE` dosyasına bakın.

Kurgu araçlarının bir kısmı [OpenCut](https://github.com/OpenCut-app/OpenCut) incelenerek native Swift ile yeniden yazıldı. OpenCut'ın MIT lisans bildirimi `Sources/NKurguApp/Resources/OpenCut-LICENSE.txt` içinde ve uygulamanın Hakkında panelinde yer alır. Görsel kaynakların üretim bilgisi `Brand/PROVENANCE.md` dosyasındadır.
