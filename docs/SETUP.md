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
10h. M11: **Pet**: Bag → Pets sekmesi; Sv10 olunca Glowmoth açılır ve otomatik peşinden gelir; "Equip"/"Send home".
   Kilitli pet'te ilerleme "(120 / 500)". **Ranger Wren**: doğu topraklarının girişinde (sırt açıklığının hemen doğusu)
   yeşil cübbeli NPC. Warden bittikten sonra zincirin sıradaki görevi onundur (Sv8): Elder "Wren'e git" der, görev
   ipucu, "!" ve ok Wren'i gösterir. `LvDebugLevel` ile Sv8/12/26/50 dene; "Rift Watch" bir Gölge Yarığı bitirince,
   "Crowned Shadows" 3 elit yenince, "Tower Climber" kule 12. kata çıkınca tamamlanır. **Yeniden doğuş**: Sv100 için
   `LvDebugLevel` = 100; Büyük Fener direğine yaklaş → "Rebirth" → panel (neyin sıfırlandığı/kaldığı yazar) → onay.
   Sv1'e dönersin, 300 sikke; HUD'da seviye rozetinin altında "Rebirth 1", "Dawn Aura" kostümü, 5 sandık yuvası açık kalır.
10i. M12: **Sinematik**: yeni oyuncu ilk girişte "prologue" sahnesini görür (siyah bantlar, kamera Büyük Fener'de, yazı harf harf
   çıkar, dokun/Space/E ile devam, sağ altta **Skip**). Elder'a/Wren'e konuşunca görev sahnesi oynar; görev sürerken tekrar
   konuşunca sahne tekrar oynar. Görev bitince kısa alt yazı; Warden ve Shadow King bitince 2,5 sn sonra tam sahne. Sahnede
   hareket kilitlenir (Skip ile çıkılır). Sahneyi hemen görmek için (Studio): Workspace'e `LvDebugScene` (string) = `warden_end`.
   Bittiğinde kamera yumuşakça geri döner. Konuşan NPC baş sallar. **Animasyon**: sandıklar süzülür, vuruşta yaratık ezilir,
   seviye atlayınca yer halkası, düğmeler üstüne gelince büyür, HUD'da seviye/sikke artınca "pop". **Kutsama**: her ana görev
   sonunda "Story blessing! +N% XP"; Smith hikâyeye göre farklı selam verir.
10j. M13: **Story sekmesi**: Bag → Story: Prologue ve biten görevler "Replay" ile yeniden izlenir (sahne + bitişi), sıradaki
   görev "Now", sonrakiler "???". Aynı NPC'ye 2 dakika içinde tekrar konuşunca sahne tekrar oynamaz, kısa cevap verir.
   Rebirth sonrası seviye atlamak Pas XP'si vermez (ilk tırmanışta verir).
10k. M14: **İşaretçiler**: köydeki İlan Panosu'nun üstünde biten ilan varken "!" çıkar; Sv10'dan sonra Kule kapısının üstünde
   ilk tırmanışa kadar "!" durur. Seviye atlayınca tek seferlik ipuçları: Sv2 pano, Sv8 doğu topraklar, Sv10 kule, Sv15 pet
   (rebirth sonrası çıkmaz). **Yeni kostümler**: sikkeyle Moon Hat (12K), Comet Cape (40K), Starlit Aura (250K); kule 20. katta
   Tower Crown, 40. katta Skybound Cape; Shadow King bitince Kael's Crown (Shop → Costumes'ta nasıl kazanıldığı yazar).
10l. M15: **Rahatlık ayarları**: Settings → "Screen shake" (ekran sarsıntısı ve kamera yumruğu) ve "Camera in story scenes" (kapalıysa
   sahneler yalnızca alt yazı olur, bant/kamera/hareket kilidi yok). İkisi de profile kaydedilir. Sahne sonrası hemen yeni alt yazı
   gelince siyah bantlar kalmaz.
10m. M15: **Ayarlar penceresi** (sağ üst Settings): solda 4 sayfa (Graphics, Audio, Gameplay, Interface). Graphics'te üstte
   Auto/Low/Medium/High/Ultra; Auto telefonda Medium, bilgisayarda High seçer ve altta yazar. Tek bir seçeneği (Shadows,
   Glow, Haze and colors, Effects, Render detail) değiştirince "Custom" olur. Field of view kaydırıcısı: sürükle ya da -/+.
   Low: gölge, sis ve parlama kapanır (Lighting'de gözle kontrol et); Ultra: güneş ışınları eklenir. Audio: ana ses ve efekt
   ses düzeyi (ses kimlikleri boş olduğu için duymazsın). Gameplay: sarsıntı, sahne kamerası, hasar sayıları, menzil halkası.
   Interface: arayüz boyutu (Small/Normal/Large; telefonda dene), yaratık adı ve can çubuğu, performans göstergesi.
   "Reset this page" sayfayı sıfırlar. Çık-gir yapınca ayarlar korunmalı. Studio'da gerçek fark: Rendering QualityLevel
   ve Lighting efektleri (Bloom, Atmosphere, ColorCorrection, SunRays) yalnızca Studio/oyun içinde görülür.
10n. M16: **Players paneli**: solda ortada "Emotes"un altındaki **Players** düğmesi ya da **Tab** tuşu: sunucudaki herkes, en yüksek
   seviye üstte; "Lv N   Rebirth N   Tower N" (sıfırlar gösterilmez). Seviye değişince ve biri çıkınca kendini yeniler.
   2 oyunculu testte (Test → Clients and Servers) diğerinin seviyesini `LvDebugLevel` ile değiştirip sırayı gör.
10o. M17: **Kulede boss katları**: her 10. katta ortada bir Efsane Gölge (seviyeye göre Bog Mother → Frost Titan →
   Shadow King) ve birkaç yardımcı; afişte "X awaits!". Boss can payı normalin %40'ı. Kule boss'ları hikâye görevine ve "ilk zafer" ödülüne (Mistik sandık, Legends kaydı, pet) SAYILMAZ; bunlar kendi arenalarında kalır. Hemen denemek için Studio'da
   Sv12 ile girip 9. kata kadar çıkmak gerekir (uzun); mantık testlerde ve modelde doğrulandı (boss savaşları 25–180 sn).
10p. M18: **3 yeni yetenek kartı** (artık 13 yetenek): Healing Light (her arındırmada canın %2'si/rank iyileşir), Brave Heart
   (can yarıdan azken +%10/rank hasar), Treasure Hunter (sandık sikkesi +%15/rank). Seviye atlayınca kartlarda çıkar;
   `LvDebugLevel` ile çok seviye atlayıp denenebilir.
10q. M20: **Kael the Keeper** (epilog): Shadow King arındırılana kadar köyde görünmez; sonra Elder/Wren onu işaret eder.
   `keepers_promise` (Sv92, 200 arındırma) → köyde "reunion" süsü (Büyük Fener çevresinde 3 Bekçi); `begin_again` (Sv100,
   1 rebirth). Test: `LvDebugLevel` ile Sv100'e çık, Kael'le konuş, arındır, Great Lantern'de rebirth yap.
10r. M21: **Unvanlar** (Bag → Titles): 11 unvan oynayarak kazanılır (Light Keeper hemen; Glow Walker Sv25 ... Lantern Master Sv100).
   Yeni unvan bildirimi gelir, seçmek oyuncuya kalır; seçilen unvan Tab (Players) panelinde adın altında görünür. Seçmeden "Hide" ile gizlenir.
10s. M22: **Mini harita** (sağ üst, düğmelerin altında): sen ortada ▲, kuzey yukarı; yaratık bölgeleri seviye rengiyle, köy (sarı) ve
   Shadow Tower (mor) noktaları, diğer oyuncular (beyaz), rehber hedefi (altın nokta, uzaksa kenara yapışır). Dokununca tüm vadi görünür,
   tekrar dokununca yakın görünüm. Settings → Interface → Mini map ile kapanır; sahne oynarken ve yüklenirken gizlenir.
   Telefonda sağ üst düğmelerle ve joystick/atlama tuşlarıyla çakışıp çakışmadığına bak.
10t. M23: **Oyuncu etiketleri**: diğer oyuncuların başında unvan (altın), ad ve "Lv N  Rebirth M" görünür; Roblox'un kendi ad etiketi
   gizlenir. Kendi karakterinde etiket yok. Settings → Interface → Player tags ile kapanınca varsayılan etiket geri gelir. İki kişiyle dene.
10u. M24 (+inceleme düzeltmeleri: Kael Büyük Fener'den uzakta (-14,18); yeniden doğmuş oyuncu Kael görevlerinde seviye kapısına takılmaz; hediye düğmesi mini haritayla aynı bölgede): **Günlük hediye**: oyuna girince mini haritanın solunda altın "Daily gift" düğmesi + "ready" bildirimi çıkar; basınca
   ≈8 dakikalık sikke gelir (seviyeye göre), aynı UTC gününde bir daha çıkmaz. Seri/ceza yok. Ertesi gün (veya gece yarısını aşan oturumda
   ≤1 dk içinde) yeniden görünür. Kayıt/rejoin sonrası aynı gün tekrar verilmediğini de kontrol et.
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
sesler seçip `rbxassetid://<id>` biçiminde doldur (kimlik uydurma; yanlış kimlik sessiz kalır).
Hangi anahtar ne zaman çalar ve neye benzemeli (Creator Store'da arama önerisi):
- `ui`: her düğme/pencere (27 yer): kısa, yumuşak "tık" — "ui click soft".
- `hit`: vuruş: kısa tok bir çarpma — "hit soft impact". `attack`: silah savurma (var: swordslash).
- `purify`/`pickup`: arındırma ve kristal toplama: parlak çıngırak — "magic chime short".
- `levelUp`/`questComplete`: 1–2 sn zafer melodisi — "level up fanfare".
- `wave`: Light Wave: geniş "vuu" — "magic whoosh". `slamWarn`/`slam`: boss uyarısı ve yere vuruş —
  "warning low tone", "heavy slam".
- `music`: döngülü, sakin, masalsı köy müziği — "fantasy village ambient loop".
Ses düzeyini oyun içinde Settings > Audio'dan ayarlayabilirsin.

## Üçüncü taraf
`src/server/Packages/ProfileStore.luau`: loleris (MAD STUDIO) ProfileStore, npm
`@rbxts/profile-store@1.0.3` paketindeki Luau kaynağı; lisans `docs/third_party/`.
İçerik incelendi: yalnızca DataStore/MessagingService/HttpService.GenerateGUID kullanıyor.
