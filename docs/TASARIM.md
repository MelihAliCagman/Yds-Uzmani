# YDS / YÖKDİL Hazırlık Uygulaması

YDS ve YÖKDİL sınavlarına hazırlanmak için geliştirilen, Flutter tabanlı mobil uygulama. İlk hedef: **Android (kişisel kullanım)**. Sonraki hedef: **Web** (aynı Flutter kod tabanından).

Uygulama; seviyeli kelime çalışması, hafıza kartları (spaced repetition), gramer konu takibi ve çoktan seçmeli soru çözümünü tek yerde toplar. Sorular Gemini API ile üretilir ve cihazda önbelleğe alınır.

---

## İçindekiler

1. [Özellikler](#özellikler)
2. [Sınav Bilgisi ve Müfredat](#sınav-bilgisi-ve-müfredat)
3. [Teknoloji Seçimleri](#teknoloji-seçimleri)
4. [Kurulum (VS Code)](#kurulum-vs-code)
5. [Çalıştırma](#çalıştırma)
6. [Klasör Yapısı](#klasör-yapısı)
7. [Mimari](#mimari)
8. [Veri Modelleri](#veri-modelleri)
9. [Gemini ile Soru Üretimi](#gemini-ile-soru-üretimi)
10. [Hafıza Kartı Algoritması](#hafıza-kartı-algoritması)
11. [Seviye ve İlerleme Sistemi](#seviye-ve-ilerleme-sistemi)
12. [Yol Haritası](#yol-haritası)
13. [Web'e Geçiş Notları](#webe-geçiş-notları)
14. [Güvenlik ve Telif Notları](#güvenlik-ve-telif-notları)

---

## Özellikler

### Çekirdek (MVP)
- **Çoktan seçmeli soru çözme**: tek tek, konu bazlı, karışık
- **Hafıza kartları (flashcards)**: aralıklı tekrar (spaced repetition) ile
- **Kelime çalışması**: akademik kelime listeleri, seviyelere ayrılmış
- **Gramer konu takibi**: tense, conditionals, passive, relative clauses vb.
- **Gemini ile soru/kart üretimi**: konu + seviye + sınav türü seçip üret
- **Yerel veri**: internet olmadan önceden üretilmiş sorular çözülebilir

### Sonraki aşamalar
- Deneme sınavı modu (süre tutmalı, 80 soruluk)
- Yanlış defteri (yanlış yapılan sorular otomatik tekrar kuyruğuna girer)
- Günlük hedef, seri (streak), XP
- İstatistik ekranı (konu bazlı başarı, zayıf alanlar)
- Paragraf okuma ve çeviri (EN↔TR) sorusu çalışması
- Sesli telaffuz (TTS) ve örnek cümleler
- Bildirimle günlük hatırlatma
- Web sürümü ve bulut senkronizasyonu

---

## Sınav Bilgisi ve Müfredat

> Güncel format, süre ve soru dağılımı için mutlaka ÖSYM'nin yayımladığı en son kılavuzu kontrol et. Aşağıdaki liste uygulamanın içerik planı içindir.

### YDS (Yabancı Dil Sınavı)
Soru tipleri:
- Kelime (vocabulary)
- Gramer
- Cloze test (boşluk doldurma paragrafı)
- Cümle tamamlama
- İngilizceden Türkçeye çeviri
- Türkçeden İngilizceye çeviri
- Paragraf soruları (okuduğunu anlama)
- Diyalog tamamlama
- Anlamca yakın cümle
- Paragraf tamamlama
- Anlam bütünlüğünü bozan cümle

### YÖKDİL
YDS'ye benzer yapıda, ancak içerik **alan odaklıdır**:
- Fen Bilimleri
- Sağlık Bilimleri
- Sosyal Bilimler

Uygulama, her soru ve kelimeye bir `exam` (YDS / YÖKDİL) ve `field` (genel / fen / sağlık / sosyal) etiketi koyar.

### İçerik Kategorileri

| Kategori | Alt başlıklar (örnek) |
|---|---|
| Kelime | Akademik kelimeler, phrasal verbs, prepositions, collocations, bağlaçlar, eş/zıt anlamlılar |
| Gramer | Tenses, Modals, Passive, Conditionals, Noun clauses, Relative clauses, Adverb clauses, Reduced clauses, Inversion, Gerunds/Infinitives, Articles, Quantifiers |
| Okuma | Ana fikir, çıkarım, referans, ton/amaç, paragraf tamamlama |
| Çeviri | EN→TR, TR→EN |
| Alan kelimeleri | Fen / Sağlık / Sosyal (YÖKDİL için) |

Kitap kullanımı: kitaplardaki **konu başlıkları ve sıralaması** müfredat iskeleti olarak kullanılabilir. Kitaptan soru veya paragraf birebir kopyalanmaz (bkz. [Telif Notları](#güvenlik-ve-telif-notları)).

---

## Teknoloji Seçimleri

| Alan | Seçim | Neden |
|---|---|---|
| Framework | **Flutter (Dart)** | Tek kod tabanı: Android şimdi, web sonra |
| State management | **Riverpod** | Test edilebilir, ölçeklenebilir |
| Navigasyon | **go_router** | Web için URL desteği de verir |
| Yerel veritabanı | **Drift (SQLite)** | İlişkisel veri, sorgu gücü, web desteği var |
| AI | **Gemini API** | Daha önce kullanıldı, soru üretimi için uygun |
| HTTP | **dio** (veya resmi Gemini paketi) | Retry, interceptor kolaylığı |
| Ayarlar | **shared_preferences** | Basit tercihler |
| Model sınıfları | **freezed + json_serializable** | Gemini JSON çıktısını güvenli parse etmek için |
| Grafik | **fl_chart** | İstatistik ekranı |
| Bildirim | **flutter_local_notifications** | Günlük hatırlatma |

> Not: Gemini için resmi Dart paketlerinin durumu zamanla değişebiliyor. Kurulumdan önce pub.dev ve Google'ın güncel dokümantasyonundan hangi paketin önerildiğini kontrol et. REST ile `dio` kullanmak her durumda çalışan sade bir yoldur.

---

## Kurulum (VS Code)

### 1. Gereksinimler
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable kanal)
- [Android Studio](https://developer.android.com/studio) (yalnızca Android SDK ve emülatör için)
- [VS Code](https://code.visualstudio.com/)
- Git
- Gemini API anahtarı ([Google AI Studio](https://aistudio.google.com/))

### 2. VS Code eklentileri
- **Flutter** (Dart eklentisini otomatik getirir)
- **Dart**
- **Error Lens** (hataları satır içinde gösterir)
- **Pubspec Assist** (paket eklemek için)
- **Flutter Riverpod Snippets** (opsiyonel)

### 3. Kurulumu doğrula
```bash
flutter doctor
```
Android toolchain ve VS Code satırlarının yeşil olması gerekir. Eksik lisanslar için:
```bash
flutter doctor --android-licenses
```

### 4. Projeyi oluştur
```bash
flutter create --org com.senin_adin --platforms=android,web yds_yokdil_app
cd yds_yokdil_app
code .
```
`--platforms=android,web` ile web desteği baştan hazır gelir, ama şimdilik sadece Android'e odaklanırsın.

### 5. Bağımlılıkları ekle
```bash
flutter pub add flutter_riverpod go_router drift sqlite3_flutter_libs path_provider path dio shared_preferences fl_chart flutter_local_notifications freezed_annotation json_annotation
flutter pub add --dev build_runner drift_dev freezed json_serializable flutter_lints
```

### 6. API anahtarı
Anahtarı koda **gömme**. Kök dizine `env.json` oluştur:

```json
{
  "GEMINI_API_KEY": "BURAYA_ANAHTARIN"
}
```

`.gitignore` dosyasına ekle:
```
env.json
```

Kodda okuma:
```dart
const geminiKey = String.fromEnvironment('GEMINI_API_KEY');
```

---

## Çalıştırma

### Emülatör veya telefon
Gerçek telefonda: Ayarlar → Geliştirici seçenekleri → USB hata ayıklamayı aç, kabloyla bağla.

```bash
flutter devices
flutter run --dart-define-from-file=env.json
```

### VS Code'da tek tuşla çalıştırma
`.vscode/launch.json` oluştur:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "YDS App (debug)",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define-from-file=env.json"]
    },
    {
      "name": "YDS App (release)",
      "request": "launch",
      "type": "dart",
      "flutterMode": "release",
      "args": ["--dart-define-from-file=env.json"]
    }
  ]
}
```
Sonra `F5` ile başlat.

### Kod üretimi (freezed / drift)
```bash
dart run build_runner build --delete-conflicting-outputs
# geliştirirken sürekli izlemek için:
dart run build_runner watch --delete-conflicting-outputs
```

### APK alma (kendi telefonuna kurmak için)
```bash
flutter build apk --release --dart-define-from-file=env.json
```
Çıktı: `build/app/outputs/flutter-apk/app-release.apk`

---

## Klasör Yapısı

Feature-first yapı önerilir:

```
lib/
├── main.dart
├── app/
│   ├── router.dart
│   └── theme.dart
├── core/
│   ├── db/                  # Drift veritabanı, tablolar, DAO'lar
│   ├── ai/                  # Gemini istemcisi, prompt şablonları, parser
│   ├── srs/                 # Aralıklı tekrar algoritması
│   └── utils/
├── features/
│   ├── home/                # Ana sayfa, günlük hedef, seri
│   ├── curriculum/          # Müfredat: YDS / YÖKDİL > kategori > konu
│   ├── quiz/                # Çoktan seçmeli soru çözme
│   ├── flashcards/          # Hafıza kartları ve tekrar oturumu
│   ├── vocabulary/          # Kelime listeleri ve seviyeler
│   ├── grammar/             # Gramer konuları
│   ├── mock_exam/           # Deneme sınavı modu
│   ├── generator/           # Gemini ile içerik üretim ekranı
│   ├── stats/               # İstatistikler
│   └── profile/             # Ayarlar, hedefler
assets/
├── curriculum/              # Müfredat JSON'ları (konu ağacı)
└── seed/                    # Başlangıç kelime ve soru verisi
test/
```

Alt gezinme önerisi: **Ana Sayfa · Müfredat · Çalış · Setlerim · Profil**

---

## Mimari

```
UI (Widgets)
   ↓ okur/dinler
Riverpod Providers (state)
   ↓ çağırır
Repository katmanı
   ├── Local: Drift (SQLite)  ← tek doğruluk kaynağı
   └── Remote: Gemini client  ← içerik üretir, sonuç yerel DB'ye yazılır
```

Temel kural: **UI hiçbir zaman doğrudan Gemini'ye gitmez.** Üretilen içerik doğrulanır, DB'ye kaydedilir, uygulama DB'den okur. Böylece offline çalışır, maliyet düşer ve aynı soru tekrar tekrar üretilmez.

---

## Veri Modelleri

### Müfredat
```
Exam (yds | yokdil)
 └─ Category (vocabulary | grammar | reading | translation ...)
     └─ Topic (ör. "Conditionals", "Phrasal Verbs")
```

### Tablolar (özet)

**topics**
| alan | açıklama |
|---|---|
| id | |
| exam | yds / yokdil / both |
| field | general / science / health / social |
| category | vocabulary / grammar / reading ... |
| name | konu adı |
| level | 1-5 |

**questions**
| alan | açıklama |
|---|---|
| id | |
| topic_id | |
| type | vocab / grammar / cloze / translation_en_tr / translation_tr_en / paragraph / dialogue / ... |
| stem | soru metni |
| options | 5 şık (JSON) |
| correct_index | 0-4 |
| explanation | açıklama (Türkçe) |
| level | 1-5 |
| source | `ai` / `manual` / `seed` |
| created_at | |

**cards** (hafıza kartı)
| alan | açıklama |
|---|---|
| id | |
| front | İngilizce kelime/ifade |
| back | Türkçe karşılığı |
| example | örnek cümle |
| topic_id | |
| level | |
| ease, interval, due_at, repetitions | SRS alanları |

**attempts** (cevap geçmişi)
| alan | açıklama |
|---|---|
| question_id | |
| selected_index | |
| is_correct | |
| time_ms | |
| answered_at | |

---

## Gemini ile Soru Üretimi

### Akış
1. Kullanıcı: sınav (YDS/YÖKDİL) + alan + konu + seviye + adet seçer
2. Uygulama prompt şablonunu doldurur
3. Gemini'den **yalnızca JSON** istenir (response schema / JSON mode kullan)
4. Cevap parse edilir ve doğrulanır
5. Geçerli sorular DB'ye `source = ai` ile kaydedilir
6. Quiz ekranı DB'den okur

### Doğrulama kuralları
- Tam olarak 5 şık (A-E) var mı?
- `correct_index` 0-4 arasında mı?
- Şıklar birbirinden farklı mı?
- Aynı stem DB'de zaten var mı? (tekrar önleme)
- Açıklama boş mu?

Bir soru doğrulamadan geçemezse atılır, kullanıcıya hata gösterilmez; eksik kalan adet için ikinci istek yapılır.

### Örnek prompt şablonu

```text
Sen ÖSYM YDS/YÖKDİL tarzında soru hazırlayan deneyimli bir İngilizce öğretmenisin.

Görev: {adet} adet çoktan seçmeli soru üret.
Sınav: {YDS | YÖKDİL}
Alan: {general | science | health | social}
Soru tipi: {vocabulary | grammar | cloze | translation_en_tr | ...}
Konu: {konu}
Zorluk: {1-5}  (3 = gerçek sınav ortalaması)

Kurallar:
- Her soruda tam 5 şık (A, B, C, D, E) olsun, yalnızca biri doğru olsun.
- Çeldiriciler makul ve sınav tarzında olsun.
- Soru metni akademik/resmi İngilizce olsun.
- Açıklamayı Türkçe yaz; neden doğru, neden diğerleri yanlış kısaca belirt.
- Daha önce sorulmuş bir soruyu kopyalama; özgün üret.
- Çıktı YALNIZCA aşağıdaki JSON şemasında olsun.

Şema:
{
  "questions": [
    {
      "stem": "string",
      "options": ["A...", "B...", "C...", "D...", "E..."],
      "correct_index": 0,
      "explanation": "string",
      "topic": "string",
      "level": 3
    }
  ]
}
```

### Maliyet ve kalite ipuçları
- Toplu üret (ör. 10 soru/istek), sonuçları önbelleğe al.
- Üretilen sorulara "Bu soru hatalı" butonu ekle; işaretlenenleri gizle.
- Gerçek sınav kalitesi için ilk aşamada örnek (few-shot) sorular ver; kendi çözdüğün gerçek çıkmış soruların **tarzını** örnek göster.
- AI açıklamaları ara sıra hatalı olabilir. Şüpheli durumlarda kaynak kitapla karşılaştır.

---

## Hafıza Kartı Algoritması

Başlangıçta **SM-2** (Anki'nin eski algoritması) yeterli ve uygulaması basit:

```
Kalite q: 0-5 (Bilmiyorum ... Çok kolay)  →  UI'da 4 buton: Tekrar / Zor / İyi / Kolay

q < 3 ise: repetitions = 0, interval = 1 gün
değilse:
  repetitions == 0 → interval = 1
  repetitions == 1 → interval = 6
  değilse          → interval = round(interval * ease)
  ease = max(1.3, ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))
  repetitions += 1
due_at = bugün + interval
```

İleride daha iyi sonuç için **FSRS** algoritmasına geçilebilir. `core/srs/` altında arayüz soyut tutulursa geçiş kolay olur.

Günlük kuyruk: `due_at <= bugün` olan kartlar + günlük limit kadar yeni kart.

---

## Seviye ve İlerleme Sistemi

Dil uygulamalarındaki yapıya benzer:

- **Seviyeler (1-5)**: Her konu için seviye açılır. Bir seviyeyi geçmek için ör. son 20 sorunun %75'ini doğru yapmak gerekir.
- **XP**: Doğru cevap, tamamlanan oturum, günlük hedef XP kazandırır.
- **Seri (streak)**: Ardışık çalışılan gün sayısı.
- **Günlük hedef**: Ör. 20 kart + 15 soru.
- **Zayıf alan**: Başarı oranı düşük konular ana sayfada önerilir.
- **Yanlış defteri**: Yanlış yapılan her soru, birkaç gün sonra tekrar karşına çıkar.

---

## Yol Haritası

**Faz 0: Altyapı** (1 hafta sonu)
- [ ] Proje iskeleti, tema, router, alt gezinme
- [ ] Drift DB kurulumu ve tablolar
- [ ] Müfredat JSON'unu DB'ye yükleme

**Faz 1: Soru çözme**
- [ ] Quiz ekranı (5 şık, anında geri bildirim, açıklama)
- [ ] Attempts kaydı
- [ ] Gemini istemcisi + prompt + doğrulama
- [ ] "Soru üret" ekranı

**Faz 2: Hafıza kartları**
- [ ] Kart tablosu, SM-2
- [ ] Kart çalışma ekranı (çevirme animasyonu)
- [ ] Gemini ile kelime kartı üretimi (kelime, anlam, örnek cümle)

**Faz 3: Ilerleme**
- [ ] Seviye sistemi, XP, seri
- [ ] İstatistik ekranı
- [ ] Yanlış defteri

**Faz 4: Deneme modu**
- [ ] 80 soruluk, süreli deneme
- [ ] Sonuç analizi (konu bazlı)

**Faz 5: Web**
- [ ] Web için Drift yapılandırması
- [ ] Bulut senkronizasyonu (Firebase veya Supabase)
- [ ] Responsive düzen

---

## Web'e Geçiş Notları

Flutter seçimi bunun için mantıklı. Önceden dikkat edilecekler:

- Gemini anahtarı web'de tarayıcıya sızar. Web yayınında **mutlaka bir backend/proxy** (Cloud Functions, Supabase Edge Function vb.) arkasına al.
- `dart:io` yerine web uyumlu paketler kullan (ör. `path_provider` web'de çalışmaz, Drift'in web desteğini ayrıca yapılandır).
- Cihazlar arası ilerleme için bir hesap sistemi ve bulut DB gerekir. Şimdilik yerel DB yeterli.
- Layout'u baştan `LayoutBuilder` ile esnek yaz; mobil dar, web geniş ekran.

---

## Güvenlik ve Telif Notları

- `env.json` ve API anahtarları repoya girmez.
- Release APK'yı sadece kendin kullandığın sürece `--dart-define` ile gömülü anahtar kabul edilebilir. Başkasına dağıtacaksan anahtarı backend'e taşı.
- Kitaplardan veya çıkmış sorulardan **birebir metin kopyalama**. Müfredat yapısı ve konu başlıkları için kullanabilirsin; sorular ve açıklamalar özgün (AI veya kendi yazdığın) olmalı. Uygulamayı yayınlamayı düşünüyorsan bu daha da önemli.
- Gemini'nin kullanım koşullarına ve kota limitlerine uy.

---

## Lisans

Kişisel proje. Yayınlama kararı verilirse lisans burada belirtilecek.