# Mimari kararlar — sürüm 0.1

## Bağımlılıklar

KurguCore yalnızca Foundation'a bağlıdır. KurguEditing ve KurguPersistence KurguCore'u kullanır. AVFoundation/SwiftUI/Metal tipleri domain modeline girmez. Package.swift şu anda tek yerel pakette üç bağımsız target tanımlar; ihtiyaç oluşunca ayrı paketlere taşınabilir.

## Zaman ve aralıklar

MediaTime normalize edilmiş rasyonel saniyedir. Aralıklar [başlangıç, bitiş) biçimindedir; bitişik klipler çakışmaz. Timeline başlangıcı ile sourceStart bağımsızdır. Bu sürümde kaynak ve timeline süreleri 1:1 eşlenir. Kaynak fps veya sequence kare süresi edit komutlarında zorunlu quantization uygulamaz: ses sample hassasiyeti korunur, video kare hizalaması gelecek edit politikası katmanının sorumluluğudur.

## İşlemler

EditorSession bir aday proje üzerinde işlem yapar, tamamını doğrular, sonra geçmişe ve mevcut duruma aktarır. Hatalı düzenleme state veya history değiştirmez. Split sol klibin kimliğini korur, sağa yeni kimlik verir. Trim boşlukları kapatmaz. Model farklı izlerde üst üste kliplere izin verir; aynı izde geçiş/overlap modeli henüz yoktur.

## Kalıcılık

Sürüm 1 JSON tek authoritative belgedir; ayrı manifest ile tutarsızlık ihtimali yaratılmaz. Yeni şema başlıktan kontrol edilir ve desteklenmiyorsa reddedilir. Decode edilen tüm zamanlar constructor validasyonundan, proje ise bütünsel validasyondan geçer. Asset URL'leri kaynak referansıdır; medya projeye kopyalanmaz. Bookmark alanı erişim adaptörü için ayrılmıştır.

## Eşzamanlılık

Core değer tipleri Sendable'dır. EditorSession UI entegre edildiğinde MainActor sahibi tarafından yönetilecektir. ProjectStore actor dosya işlemlerini sıralar. Henüz gerçek zamanlı callback veya render loop yoktur.

## Ölçülecek sonraki riskler

AVPlayer seek iptali, uzun GOP kaynaklarda scrubbing, VFR zaman eşleme, proxy/orijinal dönüşümü, preview/export eşitliği, ses saati ve video senkronu. Bu konularda ölçüm olmadan performans iddiasında bulunulmaz.

# İkinci adım — AVFoundation adaptörleri

KurguMedia → KurguCore; KurguPlayback → KurguMedia + KurguCore bağımlılıkları eklendi. Metadata AVAsset async load API'leriyle okunur. Bu aşamada compiler MainActor üzerinde kontrol akışını yürütür; medya yüklemeleri await ile beklenir. Büyük projelerde instruction üretiminin ayrı çalışma alanına taşınması ölçüme bağlıdır.

TimelineCompiler her klibe ayrı AVCompositionTrack ayırır. Kaynak zamanları değiştirilmeden hedef başlangıca yerleştirilir. Track sırası ön plandan arka plana doğrudur. Klip sınırlarından üretilen aralıklar için layer instruction hazırlanır; katmansız aralıklarda siyah background çizilir. Embedded audio'nun kaynak kesiti ile kesişimi aynı hedef ofsetine taşınır. Görüntü transform'u preferredTransform → normalize bounds → scale → center sırasındadır.

PreviewEngine, AVPlayer ve PreparedPreview yaşam sürelerini yönetir. Async load sırasında eski player item korunur; yalnızca en son istek sonucu commit edebilir. Seek istekleri iptal edilir ve istek kimliğiyle eski completion'ların kabul edilmesi önlenir. Playhead ayrı periodic observer ile güncellenir. Observer token ömrü ayrı sahip nesneyle eşlenir. Player item durumu/hatası AVPlayer'dan okunabilir; kapsamlı kullanıcıya dönük buffering/error UI sonraki adımdadır.

macOS 15 tabanı nedeniyle mutable video composition API'leri adaptörde tutulmuştur; yeni sistemlerdeki Configuration tabanlı API'lere geçiş domain modelini etkilemez. Bu sürüm SDR Rec.709 ve yerleşik compositor ile çalışır. Henüz render plan, custom compositor, export veya HDR tutarlılığı iddiası yoktur.

# Üçüncü adım — Workspace uygulaması

NKurguApp executable target, WorkspaceModel üzerinden EditorSession ve PreviewEngine'i birleştirir. SwiftUI HSplitView/VSplitView panel yerleşimini, AppKit TimelineCanvas klip çizimi ve odaklı klavye olaylarını, AVPlayerView görüntüyü sunar. Timeline içerik genişliği zoom ve süreye, görünür yüzey boyutuna göre hesaplanır. Görünmeyen klipler çizilmez; thumbnail cache sonraki adımdadır.

Model her başarılı kurgu işleminden sonra mevcut konumu koruyarak preview'ı yeniden kurar. Eski compile task iptal edilir. Bu prototip artımlı compilation uygulamaz. Medya/iz ekleme komutları undo geçmişine girer. Yerel düzenleme belgesi, kaydedilen snapshot ile karşılaştırılarak dirty durumu bulunur. Save sırasında alınan snapshot kaydedilir; daha yeni düzenlemeler dirty kalır.

Tek pencere ve ilk sequence üzerinde çalışılır. Proje açma/kaydetme NSOpenPanel/NSSavePanel üzerinden yapılır. `.nkurgu` paket UTI'sı Info.plist'te tanımlıdır. App paketi Scripts/build-app.sh ile release binary'den üretilir, ad-hoc imzalanır. App sandbox ve dağıtım profilleri henüz eklenmedi.

UI smoke testi: renk-testi.mov import → timeline'a ekle → 1 saniyeye seek → split → undo → 1.5 saniyeye trim → save → uygulamayı yeniden aç → proje aç → play. Proje seçicinin genel klasörleri kabul etmesi testte fark edilip engellendi; persistence katmanı da uzantıyı doğrular.

# Dördüncü adım — Tasarım ve MP4 export

KurguExport, playback ile aynı TimelineCompiler çıktısını kullanır. AVAssetExportSession'a videoComposition ve açık AVMutableAudioMix atanır; farklı source audio track'leri tek çıkış miksine dönüştürülür. Önce hedef klasörde benzersiz staging dosyası üretilir. Yalnızca tamamlandıktan ve iptal kontrolünden sonra move/replace yapılır. Source URL'ye yazma reddedilir. İlerleme task'ı işlem bitince iptal edilir, kaynak erişim lease'leri export boyunca tutulur.

UI'da Higgsfield üretimi welcome resmi ve uygulama simgesi yerel bundle'a eklenmiştir. SwiftPM resource bundle app/Contents/Resources içine paketlenir. Thumbnail'lar gerçek kaynak videodan AVAssetImageGenerator ile okunur, UI oturumu boyunca bellekte tutulur; büyük kütüphaneler için bounded cache sonraki performans işidir.

Yeni dosyalar: DesignSystem.swift, ExportSheet.swift, KurguExport/ExportEngine.swift. Klip kaldırma undo edilebilir domain komutu olarak eklendi. Export UI sonucu Finder'da gösterir ve işlem sürerken sheet kapatmayı engeller.

# Beşinci adım — Doğrudan timeline düzenleme

Move ve rippleRemove domain komutları mevcut doğrulama/commit sınırından geçer. Move, clip kimliği ve kaynak aralığını korur; hedef aynı sequence ve aynı türde kilitsiz iz olmalıdır. RippleRemove yalnızca kendi izindeki silinen zaman aralığını kapatır. Snapping, rasyonel zamanları karşılaştırır; ekran toleransı UI'da zamana dönüştürülür. Eşit uzaklıkta önce daha erken hedef, sonra sol kenar seçilir.

TimelineCanvas gesture state, kaynak proje snapshot'ı ve aday komutu tutar. Sürüklemede aday oturum kopyasında doğrulanır, asıl model değişmez; release tek commit üretir. Proje arada değişirse commit atılır. Escape state'i temizler; başlangıca geri dönen gesture adayını siler. Bu sürümde her mouse event'te tam doğrulama yapılır; büyük timeline performansı için artımlı validation optimizasyonu ileride ölçülmelidir.
