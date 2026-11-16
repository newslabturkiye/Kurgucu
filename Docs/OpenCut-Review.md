# OpenCut incelemesi — 5 Ekim 2026

## Kaynak ve kapsam

- https://github.com/OpenCut-app/OpenCut — commit `e668010778568641babef2cc40be4703ae6916d6`.
- Ana README, Rust çekirdekli yeniden yazımı anlatıyor ve kullanılabilir sürüm için Classic'e yönlendiriyor. Editor API, eklentiler, MCP ve headless hedeflerini bugün tamamlanmış özellikler olarak kabul etmedik.
- https://github.com/OpenCut-app/opencut-classic — commit `cf5e79e919144200294fb9fed22a222592a0aeea`.
- Her iki deponun LICENSE dosyası MIT. Classic bildirimi uygulamaya `Resources/OpenCut-LICENSE.txt` olarak eklendi. Üçüncü taraf alt bağımlılıklar veya marka varlıkları taşınmadı.

Kurgucu SwiftUI/AppKit/AVFoundation uygulamasıdır. OpenCut web kodunu içine gömmek, iki oynatma/render motoru ve ayrı veri modelleri getirecekti. Burada incelenen davranışların native karşılıkları uygulandı; OpenCut marka, servis, font veya görselleri kullanılmadı. Kurgucu'nun kırmızı kimliği ve geliştirici credit'i korundu.

## İncelenen Classic kaynakları

- `apps/web/src/commands/timeline/element/toggle-source-audio-separation.ts`: kaynak sesi devre dışı bırakma, ayrı ses öğesi oluşturma ve undo.
- `apps/web/src/timeline/audio-separation/index.ts`: kaynak kesiti, süre ve ses özelliklerinin ayrı ses öğesine aktarılması.
- `apps/web/src/commands/timeline/tracks-snapshot.ts`: önceki/sonraki durumun geri alınabilir işlem olarak ele alınması.
- `apps/web/src/preview/controllers/transform-handle-controller.ts`: döndürme ve dönüşüm etkileşimleri.
- `apps/web/src/speed/components/speed-tab.tsx` ve `retime/split.ts`: hızın kaynak zamanı ve kesmeyle ilişkisi. Bu sürümde hız değişimi eklenmedi; mevcut unit-speed varsayımı tek slider eklemekten daha geniş bir dönüşüm gerektiriyor.

## 0.12.0'da tamamlananlar

| İhtiyaç | Native uygulama | Doğrulama |
|---|---|---|
| Video döndürme / ayna | ClipFraming alanları, dönüştürülmüş sınırlar üzerinden fit/fill | İki compositor yolu için gerçek MP4 ve piksel karşılaştırması |
| Klip sesi | Klip kazancı × iz kazancı; klip mute | Gerçek PCM RMS ve export ölçümü |
| Kaynak sesini ayırma | Yeni ses izi, aynı medya/kesit, video sesini devre dışı bırakma | Çift ses oluşmaması, RMS eşitliği, undo/redo, kilit |
| Slip | Kaynak başlangıcını değiştir; timeline süre/konumunu koru | Sınırlar, atomiklik ve süre korunması |
| Boşluk kapatma | Seçili izde sıralı, sıfırdan başlayan yerleşim | Kaynak aralıkları, kilit ve undo atomikliği |
| Kalıcılık | Şema 7, yeni alanlar opsiyonel | Eski alanların varsayılanları ve JSON round-trip |

Slip ve toplu boşluk kapatma, inceleme sırasında belirlenen Kurgucu eksikleri için yazılan ek komutlardır; Classic'ten doğrudan aktarılmış kod olarak sunulmaz.

## Açık kalan işler

1. Hız: timeline süresi / kaynak süresi ayrımı; pitch koruma; split, trim, waveform ve proxy zaman dönüşümü. Ardından speed ramp/reverse/freeze.
2. Yazı ve çıkartmaların timeline üzerinde ayrı şeritleri; keyframe interpolasyonu ve animasyon düzenleyicisi.
3. Gerçek komşu-klip geçişleri, maske, blend ve HSL/curves/LUT. Mevcut açılma/kararma bunların yerine geçmez.
4. Eksik medyayı yeniden bağlama ve taşınabilir proje paketi; uzun proje, bellek ve farklı Mac'lerde performans ölçümü.
5. Otomatik altyazı, arka plan kaldırma ve takip için ayrı model/izin/gizlilik ve kalite çalışması.
6. Ticari dağıtım: Developer ID/notarization, güncelleme altyapısı, ödeme/lisans. OpenCut'ın MIT lisansı, Kurgucu'nun diğer varlıklarının ticari haklarını veya satışa hazır olduğunu tek başına doğrulamaz.

Bu belge tam OpenCut eşdeğerliği ya da ticari sürüm onayı değildir. Uygulanmamış araçlar çalışıyormuş gibi eklenmedi.
