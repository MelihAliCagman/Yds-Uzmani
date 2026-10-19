# YDS Uzmanı

**YDS / YÖKDİL** sınavlarına hazırlanmak için geliştirilmiş, açık kaynak, Flutter tabanlı bir çalışma uygulaması. Sorular, kelime listesi ve kodun tamamı serbestçe kullanılabilir.

Amaç basit: **kelimeyi bir kez gör, yanlış yaptığın şeyi tam unutmak üzereyken tekrar karşına çıkar.** Bunun için bilimsel olarak en iyi sonuç veren aralıklı tekrar algoritmalarından biri olan **FSRS** kullanılıyor.

<p align="center">
  <img src="docs/screenshots/ana-sayfa.png" width="23%" alt="Ana sayfa" />
  <img src="docs/screenshots/mufredat.png" width="23%" alt="Müfredat" />
  <img src="docs/screenshots/kelime-calismasi.png" width="23%" alt="Test öncesi kelime çalışması" />
  <img src="docs/screenshots/soru-aciklama.png" width="23%" alt="Soru ve açıklama" />
</p>
<p align="center">
  <img src="docs/screenshots/yanlis-defteri.png" width="23%" alt="Yanlış defteri" />
  <img src="docs/screenshots/setlerim.png" width="23%" alt="Setlerim ve kelime defteri" />
</p>

## Özellikler

- **Test öncesi kelime çalışması:** Her 10 soruluk testten önce, o testteki kelimeler (anlam + örnek cümle) ve soru metnindeki diğer zor kelimeler listelenir. Bilmediklerini deftere eklersin, sonra testi çözersin.
- **Kelime defteri + FSRS tekrar:** Kelimeler aralıklı tekrarla çalışılır. Yanlış yaptığın kelime aynı gün tekrar sorulur, ertesi güne planlanır; tekrar yanlış yaparsan yeniden kısa aralığa düşer. Her butonun altında bir sonraki tekrar zamanı görünür.
- **Yanlış defteri:** Yanlış yapılan soruların doğru cevabı, kelimenin anlamı ve örnek cümlesi. "Test çöz" yanlışlarını ve aynı konulardan benzer soruları karıştırır. "Benzer üret" Gemini ile yanlış yaptığın kelimelere benzer yeni sorular yazar.
- **Sınav tarihine göre planlama:** Sınav tarihini girersin, tekrar aralıkları sınavı aşmayacak şekilde kısalır.
- **YDS ve YÖKDİL müfredatı:** Kelime, gramer, cloze, okuma, çeviri, diyalog ve YÖKDİL alan kategorileri (fen, sağlık, sosyal), konu bazlı ilerleme.
- **Yarım kalan test kaldığı yerden devam eder.** İlerleme, XP, seri ve defter cihazda saklanır.
- **Gemini ile soru üretimi:** Konu, seviye ve adet seç, uygulama içinden soru üret (kendi API anahtarınla, ücretsiz katmanla çalışır).
- **Hazır soru bankası:** [assets/seed/questions.json](assets/seed/questions.json) içinde yüzlerce hazır soru, her birinde test edilen kelime, Türkçe anlamı, örnek cümle ve soru metnindeki zor kelimeler var.

## Hızlı başlangıç

Gereksinimler: [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable) ve bir Android cihaz/emülatör.

```bash
git clone https://github.com/MelihAliCagman/Yds-Uzmani.git
cd Yds-Uzmani
flutter pub get
flutter run
```

Hazır soru bankası ile uygulama **API anahtarı olmadan** çalışır. Sadece uygulama içinden soru üretmek ve "Benzer üret" için anahtar gerekir.

### Gemini API anahtarı (isteğe bağlı)

1. [Google AI Studio](https://aistudio.google.com/apikey) üzerinden ücretsiz bir anahtar al.
2. `env.example.json` dosyasını `env.json` adıyla kopyala ve anahtarını yaz:
   ```json
   { "GEMINI_API_KEY": "AIza..." }
   ```
3. Anahtarı derleme anında vererek çalıştır:
   ```bash
   flutter run --dart-define-from-file=env.json
   ```

> **Güvenlik:** `env.json` `.gitignore` içindedir ve repoya girmez. Anahtarını asla commit'leme, paylaşma ya da koda gömme. Release APK'yı başkalarına dağıtacaksan anahtarı bir backend/proxy arkasına taşı: derlenmiş uygulamadan anahtar çıkarılabilir.

APK almak için: `flutter build apk --release --dart-define-from-file=env.json`

## Soru ve kelime üretme araçları

Soru bankasını büyütmek için iki script var (kendi anahtarınla çalışır, ücretsiz katmanın dakikalık/günlük limitine uyar, kota dolunca durur):

```bash
# Tüm konulara sırayla soru üretir, her istekten sonra assets/seed/questions.json'a kaydeder
dart run tool/generate_questions.dart 100      # konu başına en fazla 100 soru

# Kelime listesi (glossary) eksik sorulara zor kelimeleri ekler
dart run tool/enrich_glossary.dart
```

Üretilen her soru doğrulanır: tam 5 farklı şık, geçerli doğru cevap, dolu açıklama, tekrar eden soru yok. Yine de **sorular yapay zekâ ile üretilmiştir ve hata içerebilir**; şüphelendiğin sorularda resmi kaynaklara ve ÖSYM kılavuzuna bak. Hatalı bir soru bulursan issue açman çok yardımcı olur.

## Tekrar algoritması (FSRS)

Uygulama [FSRS-4.5](https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm) (Free Spaced Repetition Scheduler) kullanır. Klasik SM-2'ye göre aynı hatırlama oranı için daha az tekrar gerektirir. Her kelime için **stabilite** (unutma hızı) ve **zorluk** ayrı hesaplanır, hedef hatırlama oranı %90'dır.

- Yeni kelime: Tekrar/Zor → 10 dk sonra; İyi/Kolay → günler sonra.
- Yanlış → kelime tekrar öğrenme adımına düşer, 10 dk sonra aynı oturumda gelir.
- Doğru → aralık, zorluğa ve tam zamanında hatırlayıp hatırlamadığına göre büyür.
- Sınav tarihi seçiliyse aralıklar sınava kalan sürenin yarısını geçmez.

Uygulama: [lib/core/srs/fsrs.dart](lib/core/srs/fsrs.dart), testler: [test/widget_test.dart](test/widget_test.dart).

## Proje yapısı

```
lib/
├── app/             # tema, router, alt gezinme
├── core/
│   ├── ai/          # Gemini istemcisi (JSON çıktı + doğrulama)
│   ├── srs/         # FSRS ve SM-2
│   ├── data/        # müfredat iskeleti, başlangıç verisi
│   ├── vocab.dart   # kelime defteri, sınav tarihi
│   └── providers.dart
└── features/        # home, curriculum, quiz, vocab, wrong, flashcards, generator, ...
assets/seed/         # hazır soru bankası (questions.json)
tool/                # soru üretme scriptleri
docs/                # ekran görüntüleri ve ilk tasarım notları (TASARIM.md)
```

Teknoloji: Flutter, Riverpod, go_router, dio, shared_preferences. Veriler şimdilik cihazda `shared_preferences` ile saklanır. Planlanan sıradaki işler için bkz. [docs/TASARIM.md](docs/TASARIM.md).

## Yol haritası

- [ ] Deneme sınavı modu (80 soru, süreli, konu bazlı analiz)
- [ ] Günlük çalışma planı (sınav tarihine göre)
- [ ] Kelime telaffuzu (TTS) ve günlük hatırlatma bildirimi
- [ ] Her soru için yedek (benzer) soru bankası
- [ ] Drift/SQLite'a geçiş, web sürümü ve bulut senkronizasyonu

Katkılar memnuniyetle karşılanır: hatalı soru bildirimi, yeni soru/kelime, çeviri düzeltmesi, kod. Bir issue ya da pull request açman yeterli.

## Uyarılar

- Bu proje resmi bir ÖSYM ürünü değildir. Sınav formatı ve içeriği için daima güncel ÖSYM kılavuzuna bak.
- Sorular özgün olarak üretilmiştir, kitaplardan veya çıkmış sorulardan kopyalanmamıştır. Katkı yaparken de telifli kaynaklardan birebir metin ekleme.
- Gemini API kullanım koşullarına ve kota limitlerine uy.

## Lisans

[MIT](LICENSE). Kod ve soru bankası dahil serbestçe kullanabilir, değiştirebilir ve paylaşabilirsin.
