# Kurulum ve Test (Windows)

## Bir kerelik kurulum
1. Roblox Studio'yu kur ve giriş yap.
2. Rojo 7.x kur (https://rojo.space/docs — Aftman/Rokit veya VS Code "Rojo" eklentisi).
3. Studio'da Rojo eklentisini kur (`rojo plugin install` ya da Creator Store'dan resmi "Rojo").
4. Repoyu klonla: `git clone https://github.com/v2vstudiosofficial-svg/LanternValley`

## Her çalışmada
```
rojo build default.project.json -o LanternValley.rbxlx   # ilk sefer
rojo serve
```
- Studio'da `LanternValley.rbxlx` dosyasını aç (Baseplate şablonu kullanma; zemin çakışır).
- Plugins → Rojo → **Connect**. Yerel `.luau` değişiklikleri anında Studio'ya gelir.
- Haritayı düzenleme modunda görmek için Command Bar'da bir kez:
  `require(game.ServerScriptService.Server.MapBuilder).build()`
  Tekrar çalıştırmak çoğaltmaz ve elle yapılan düzenlemeleri silmez. Eski bir sürümle
  "pişirilmiş" harita varsa önce `Workspace.LanternValleyMap` klasörünü silip yeniden çalıştır.
- Kalıcı kayıt: Studio'da Game Settings → Security → "Enable Studio Access to API Services"
  kapalıysa ProfileStore bellekte sahte kayıt kullanır (test için güvenli). Açıksa Studio,
  canlı oyundan ayrı `LanternValley_Studio_v1` deposuna yazar. Yerin yayınlanmış olması gerekir.
- Yayında maksimum oyuncu: Game Settings → Places → Max Players = 4.

## Elle test listesi (Studio)
1. **Play**: Output'ta `Server started` ve `Client started`, kırmızı hata yok; "Kaydın yükleniyor"
   kısa süre görünüp kaybolur.
2. Görev 1: Bilge Nur'da **!** işareti → E/dokun → elmas işaret açıklığa götürür → Gölgecik'i
   arındır (sol tık/F/IŞIK) → "Dost oldu" + "Görev tamamlandı" afişi.
3. Görev 2: 5 Fener Çiçeği (yalnızca bu oyuncuya görünür) → köyde çiçek tarhları/bayraklar.
4. Görev 3: 3 altın ışık sütunu → keşif bildirimi.
5. Görev 4: Usta Demir → Asa Tezgâhı → Güçlendir (yetersiz sikkede uyarı) → asa küresi renk
   değiştirir, köy fenerleri yanar, Kabuk Tılsımı gelir.
6. Seviye 3'te DALGA/Q açılır. Görev 5: harabe kapısında dalga → sarmaşıklar temizlenir.
7. Görev 6: arenada Gölge Bekçisi: kırmızı halkalardan çık, küre halkasındaki boşluktan geç;
   %50'de renk değişir ve hızlanır. Sonunda köyde şenlik (büyük fener, ateş böcekleri).
8. Çanta: tılsım tak/çıkar (Rüzgâr → hız, Kabuk → az hasar, Parıltı → dalga).
9. Yenil → köyde yeniden doğ; XP/sikke/eşya kaybı yok.
10. **Test → Clients and Servers → 2-4 Players**: aynı düşmana vuran herkes kendi ödülünü alır;
    boss canı oyuncu sayısıyla artar; bir oyuncunun çiçek/sarmaşık/köy dekoru diğerini etkilemez;
    sonradan katılan oyuncu kendi görevinden başlar.
11. Kayıt (API erişimi açık, yayınlanmış yerde): çık-gir → ilerleme korunur.
12. Ayarlar → Performans göstergesi: FPS/Ping. Ölçümü gerçek cihazda yap; cihaz modelini,
    grafik ayarını ve oyuncu sayısını not et (emülatör gerçek telefon ölçümü sayılmaz).

## Otomatik kontroller (Roblox gerektirmez; Lune 0.10 + Rojo 7.x)
`lune run tests/all` hepsini çalıştırır:
- `tests/logic`: oyun kuralları, tam görev zinciri, ödül tekrarı, veri/metin tutarlılığı.
- `tests/api`: sınıf/özellik/enum adları Roblox yansıma veritabanına karşı.
- `tests/scene`: MapBuilder ve düşman modelleri gerçek Lune Instance'larıyla; tekrar
  çalıştırmada çoğaltmama ve elle düzenlemeleri koruma.
- `tests/sim`: gerçek sunucu kodu + ProfileStore (mock) sahte oyuncular, sahte saat ve sahte
  remote'larla: 6 görev, co-op, boss, geçersiz istekler, çık-gir kaydı, hızlı yeniden bağlanma.
  Fizik, gerçek raycast ve istemci yok; Studio testinin yerini tutmaz.
- `tests/client desktop|touch|touch-cas|returning`: gerçek istemci kodu (HUD, kontroller, menüler, efektler,
  dünya, hedef işaretçisi) sahte LocalPlayer ve sunucu olaylarıyla; UI kurulumu, tepkiler ve
  sunucuya giden istekler. Hiçbir şey çizilmez; yerleşim ve his Studio/telefonda denenmeli.
- `tests/place`: tüm dosyalar derleniyor ve Rojo çıktısı doğru servislerde.
- Altyapı: `tests/harness.luau` (sahte saat/zamanlayıcı, sinyaller, remote'lar, yükleyici).

## Sesler
`src/shared/Sounds.luau` içindeki boş kimlikler sessizdir. Creator Store'dan lisansı uygun
sesler seçip `rbxassetid://<id>` biçiminde doldur.

## Üçüncü taraf
`src/server/Packages/ProfileStore.luau`: loleris (MAD STUDIO) ProfileStore, npm
`@rbxts/profile-store@1.0.3` paketindeki Luau kaynağı; lisans `docs/third_party/`.
İçerik incelendi: yalnızca DataStore/MessagingService/HttpService.GenerateGUID kullanıyor.
