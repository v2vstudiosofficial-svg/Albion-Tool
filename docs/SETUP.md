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
Oyun içi tüm metinler İngilizce.
1. **Play**: Output'ta `Server started` ve `Client started`, kırmızı hata yok; "Loading your save..."
   kısa süre görünüp kaybolur. Kamera yukarıdan çapraz bakar ve karakteri takip eder; fare tekerleği
   veya iki parmakla yakınlaşma çalışır. Karakterin altında beyaz menzil halkası görünür.
2. Görev 1: Elder Nora'da **!** → E/dokun → elmas işaret açıklığa götürür → Gloomling'lere yaklaş:
   saldırı tuşu yok, asa en yakın yaratığa **kendiliğinden** ateş eder → "Friend made!" + "Quest complete!".
3. Yaratıkların üstünde "Lv.N Ad" ve can çubuğu; ormanın derinlerinde seviye 3–6 sürüler.
4. Görev 2: 5 Lantern Flower (yalnızca bu oyuncuya görünür) → köyde çiçek tarhları/bayraklar.
5. Görev 3: 3 altın ışık sütunu → keşif bildirimi.
6. Görev 4: Smith Bram → Forge: 5 satır (Weapon Power, Crystal Pouch, Big Heart, Healing, Lucky Strike),
   her birinde "Lv x/max" ve fiyat; Weapon Power al (yetersiz sikkede uyarı) → köy fenerleri yanar,
   Shell Charm gelir. Big Heart can çubuğunu uzatır, Healing köy dışında yavaş iyileştirir.
6b. Kristaller: yaratıklar sikke değil **kristal** verir, küçük kristaller oyuncuya uçar; sol üstte
   "12/60" kese göstergesi. Kese dolunca sayı kırmızı olur, bir kez uyarı gelir ve elmas işaret köy
   meydanındaki Büyük Fener'i gösterir; fenerin yanına gelince kristaller sikkeye döner (1 kristal = 1 sikke).
6c. Seviye atlayınca ortada 3 yetenek kartı açılır (adı, açıklaması, "Rank 2/5"); birine dokun → seçilir.
   "Later" kapatır; sol üstte "Pick a skill (n)" butonu kalır. Kartların etkisi (ör. Swift Strikes ile
   daha sık saldırı, Long Reach ile daha geniş menzil halkası) hissedilmeli. Kritik vuruşlar kırmızı "123!".
7. Seviye 3'te WAVE/Q açılır. Görev 5: harabe kapısında dalga → sarmaşıklar temizlenir.
8. Görev 6: arenada Shadow Warden: kırmızı halkalardan çık, küre halkasındaki boşluktan geç.
9. **Sandıklar**: ormanda parlayan sandıklar (Wooden/Silver/Golden/Mystic) → "Take" → sağ üstte
   **Chests** penceresinde görünür; Sv1'de tek yuva (dolunca uyarı), Sv3/6/10/15'te yeni yuva. "Unlock" ile
   sayaç başlar (tahta 2 dk … mistik 20 dk), bu sırada diğerleri "Wait"; bitince "Open!" → ödül paneli
   (sikke, belki silah, yuva seviyesi). Alınan nokta bir süre boş kalır, sonra sandık geri gelir.
   Sayaçlar oyundan çıkınca da işler. Hazır sandık varken Chests butonunda "!" rozeti çıkar.
10. **Weapons** menüsü: bulunmamış silahlar "Find in chests" yazar ve seçilmez; alt çizginin rengi nadirliği
   gösterir; sandıktan silah çıkınca seçilebilir, eldeki model ve menzil halkası değişir. Yuva
   butonlarında yuva seviyesi ("Main Lv 3") görünür; o yuvaya takılan her silah güçlenir.
   Yüksek seviyeleri denemek için (yalnızca Studio): Play sırasında Server görünümüne geç, Explorer'da
   Workspace'i seç, Properties → Attributes → "+" ile `LvDebugLevel` (number) ekle ve 25/60/100 yaz;
   tüm oyuncular o seviyeye geçer. Aynı yolla `LvDebugAllWeapons` (boolean) işaretlenirse 8 silahın hepsi
   verilir (ikisi de yalnızca Studio'da çalışır, Studio kayıt deposuna yazılır, canlı veriye dokunmaz).
10b. **Doğu toprakları**: köyün doğusundaki, orman açıklığının doğusundaki ve harabelerin doğusundaki kaya
   sırtı geçitlerinden Misty Marsh (Sv8–25), Frost Peaks (Sv26–50), Shadow Citadel (Sv51–100) bölgelerine geç;
   zemin/dekor her bölgede farklı; yaratık adları ve "Lv.N" seviyeleri bölgeye uygun. Hikâye bitince Elder
   Nora 2. bölümü verir (Sv22/46/92'de); elmas işaret oyuncunun seviyesine uygun bölgeyi gösterir.
10c. Efsane boss'lar (Bog Mother, Frost Titan, Shadow King): yaklaşınca "X woke up!" afişi ve seviyeli boss
   çubuğu; ilk zaferde Mistik sandık (yuva doluysa sikke). Sağ üstte **Legends**: yenilenler renkli ve adıyla,
   diğerleri "???" siluet. Yüksek seviyeyi hızlı denemek için `LvDebugLevel` + `LvDebugAllWeapons`.
10d. M7: büyük sayılar kısalır (hasar "12.3K", sikke "4.5M"). Nadiren altın taçlı **Elite** yaratık doğar
   (etiket "Elite Lv.N", 4 kat can, 3 kat ödül, sandık düşürebilir). **Gölge Yarığı**: bir bölgede dolaşırken
   ara sıra mor dönen portal açılır, "Wave 1 of 3" afişi; 90 sn'de 3 dalgayı temizleyince Silver Chest,
   süre biterse kalanlar kaybolur. Hemen denemek için (Studio): Workspace'e `LvDebugRift` (string) = `glade`.
   Doğuda Bubbler/Hexcap yelpaze şeklinde çoklu mermi atar, Shade kısa uyarıdan sonra ışınlanarak yaklaşır.
10e. M8: sürüler eriyince tek toplu bildirim ("5 friends made! +230 XP"); sağ üstte **Log** (Macera Günlüğü):
   9 başarım, ilerleme çubuğu, hazır olana "Claim!" ve butonda "!" rozeti; ödül sikke + bazen sandık.
   İki oyuncu yakın durunca sol üstte "Team bonus +10%" ve arındırmalarda daha çok XP/kristal.
10f. M9: sağ üstte **Shop** ve **Pass**. Shop → Packs: ürün kimliği girilmemiş paketler "Soon" yazar ve
   tıklanmaz; Costumes: sikke ile al → "Wear"/"Remove", karakterde şapka/pelerin/aura görünür. Pass: 50 kademe,
   yaratık/görev/sandık/yarık ile XP; "Claim all", ücretsiz ve premium satırlar, alınacak varsa butonda "!".
   Satın almayı Robux harcamadan denemek için (Studio): Workspace'e `LvDebugGrant` (string) = `coins_small`,
   `xp_boost` (sol üstte "2x XP 29:59"), `starter` veya `pass_premium`. Gerçek satın alma: Creator Dashboard →
   Monetization → Developer Products'ta ürünleri oluştur, kimlikleri `src/shared/StoreData.luau` → `productId`'ye yaz,
   yayınla; Studio'daki satın alma penceresi test modudur (Robux düşmez).
10g. M10: **Silah yıldızları**: sandıktan zaten sahip olduğun silah çıkınca ödül panelinde "X again - now 2/5 stars!";
   Weapons menüsünde silah kutusunda "2/5 stars", altta hasar (Power) artar. 5 yıldızda kopya sikkeye döner.
   **İlan Panosu**: köyde ahşap pano (Elder'ın soluna doğru) → "Read": 3 ilan, ilerleme çubuğu; bitince "Claim" ve
   toast "A bounty is ready..."; uzaklaşınca panel kapanır. **Gölge Kulesi**: köyün doğu-güneyinde mor kapı (Climb),
   Sv10 gerekir (`LvDebugLevel` ile dene) → çok uzaktaki taş arenaya ışınlanır; 3 sn sonra "Floor 1" afişi ve
   yaratıklar; kat bitince sikke toast'ı ve 4 sn sonra sonraki kat; 5. katta sandık. Arenada altın "Leave" pedi köye
   döndürür; yenilirsen köyde doğarsın. Sol ortada "Tower Floor N Best M". İki oyuncuyla aynı koşuya katılınır.
   **Emote**: ekranın solunda ortada "Emotes" → 6 emote; konuşma balonu 3 sn, Dance/Cheer zıplar, Sit oturur.
11. Sv25/50/75/100'de karakterin arkasında havada süzülen 1–4 silah belirir ve kendiliğinden saldırır;
    Weapons → Slot N ile değiştirilebilir, "Auto pick" otomatik seçime döner.
12. Bag: tılsım tak/çıkar (Wind → hız, Shell → az hasar, Sparkle → dalga).
13. Yenil → köyde yeniden doğ; XP/sikke/eşya kaybı yok.
14. **Test → Clients and Servers → 2-4 Players**: aynı düşmana vuran herkes kendi ödülünü alır;
    diğer oyuncuların yüzen silahları ve saldırı efektleri görünür; sonradan katılan kendi görevinden başlar.
15. Kayıt (API erişimi açık, yayınlanmış yerde): çık-gir → ilerleme, silahlar, sandıklar ve sayaçlar korunur.
16. Settings → Performance display: FPS/Ping. Özellikle 4 yüzen silahlı oyuncularla gerçek cihazda ölç;
    cihaz modelini, grafik ayarını ve oyuncu sayısını not et (emülatör gerçek telefon ölçümü sayılmaz).

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
- Denge aracı (pakete dahil değil): `lune run tests/playtime` — bot tüm zinciri gerçek
  sunucu koduyla yürüyerek oynar; görev başına süre, seviye, sikke, yenilgi yazar.
- Altyapı: `tests/harness.luau` (sahte saat/zamanlayıcı, sinyaller, remote'lar, yükleyici).

## Sesler
`src/shared/Sounds.luau` içindeki boş kimlikler sessizdir. Creator Store'dan lisansı uygun
sesler seçip `rbxassetid://<id>` biçiminde doldur.

## Üçüncü taraf
`src/server/Packages/ProfileStore.luau`: loleris (MAD STUDIO) ProfileStore, npm
`@rbxts/profile-store@1.0.3` paketindeki Luau kaynağı; lisans `docs/third_party/`.
İçerik incelendi: yalnızca DataStore/MessagingService/HttpService.GenerateGUID kullanıyor.
