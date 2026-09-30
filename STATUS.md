# Durum
## Aşama: M30 (saldırı sesleri ve toz; M29: saldırı öncesi pozlar; M28: yaratık animasyonları ve bireysel tonlar; M27: yetenek çubuğu + Star Fall/Lantern Glow, yeni yaratık silüetleri; M26: grafik kalitesi düzeltmesi, düşman/harita görünümü; M25: yaratık kodeksi, günlük hediye, oyuncu etiketleri, mini harita, unvanlar; Kael epilogu, hikâye, sinematik, ayarlar, kule, pet, rebirth) tamam. Studio testleri ertelendi.

## Tamamlananlar
- M2–M5: seviye, dalga, tılsım, kayıt, 6 görev, boss, co-op, mobil.
- M6a: oyun İngilizce; takip kamerası, otomatik saldırı; 8 silah; Sv100; yüzen ek silahlar;
  Studio'da `LvDebugLevel` / `LvDebugAllWeapons`.
- M6b: süreli sandıklar (4 tür, 2–20 dk, yuva 1→5): sikke, silah, yuva seviyesi.
- M6c: kristal/kese, Forge, kritik vuruş, yetenek kartları.
- M6d: doğu toprakları, 3 efsane boss + Legends.
- M7–M8: sayı kısaltma, elitler, yarıklar, Macera Günlüğü, takım bonusu.
- M9: Robux mağazası (paketler, 2x XP, Premium Pas; ücretli rastgele ödül yok, kimlik yoksa "Soon");
  50 kademeli Işık Pası; görünüş kostümleri.
- M10: silah yıldızları (kopya silah → yıldız, en çok 5, +%6/yıldız); İlan Panosu (3 ilan, süresiz);
  Gölge Kulesi (dış arenada sonsuz kat, co-op, sandık/5 kat, duvar katı balance testinde); 6 emote.
- M11: hata taraması (ilan/kule ödülü sınırı); 6 pet (oynayarak, kozmetik); Ranger Wren + 4 görev
  (sayaç görevleri); Yeniden doğuş (Sv100, +%10 XP en çok 5, koleksiyon kalır).
- M12: 27 sahnelik hikâye + sinematik mod (Skip, daktilo, kamera); hikâye XP'si (seviye kapılı görevler
  2–3 seviye, +%1 XP/görev); animasyonlar; M13: Story sekmesi, Pas/rebirth düzeltmesi;
  M14: işaretçiler, ipuçları, 6 kostüm; M15: profesyonel ayarlar penceresi + grafik ön ayarları
  (Auto–Ultra, gölge, parlama, sis, FOV, ses, arayüz boyutu); M16: Players paneli, ses rehberi; M17: kule boss katları;
  M18: 3 yeni yetenek; M19: fuzz testleri; M20: Kael epilogu (2 görev, köyde buluşma);
  M21: 11 unvan (Bag → Titles); M22: mini harita; M23: oyuncu etiketleri; M24: günlük hediye
  (UTC günde 1, ≈8 dk gelir); M25: Yaratık Kodeksi (Adventure Log → Creatures, tür sayacı + sikke taşları).
  M26: grafik kalitesi hatası düzeltildi (yerleşik Bloom/Atmosphere/ColorCorrection/SunRays açık kalıyordu, ayar yalnızca `Lv*` kopyalarını
  kapatıyordu; artık yerleşik olanlar devralınıyor); düşmanlar: göz parıltısı, Gloomling ayakları, her doğu yaratığı ve 3 boss için
  kendi ayrıntıları (çamur, tüy, hayalet dumanı, kristal, boynuz, mantar, buz sivrisi, neon taç); harita: çim yamaları, yabani çiçekler,
  orman patikasında parlayan fenerler ve kenar taşları (yalnızca görsel, parça bütçesi 843/900).
  M27: yetenek çubuğu (masaüstünde sağ altta ikon, tuş rozeti, isim, sayısal geri sayım, kilit; sinematikte gizlenir; dokunmatikte
  zıplama düğmesinin çevresinde 3 düğme); yeni yetenekler: Star Fall (R, Sv6: en yakın yaratığa ana silah x3, 12 sn, hedef yoksa
  harcanmaz) ve Lantern Glow (F, Sv10: canın %40'ı, 30 sn; can doluyken basılmaz), sunucuda doğrulanır (`RequestAbility`);
  doğu yaratıkları kendi silüetleriyle (yayvan çamur, kar bulutu, hayalet, jöle, cadı şapkalı mantar, buz kristali, lav küpü),
  Gloomling'e ağız+anten, Rockling'e yosun+kaş.
  M28: her yaratık türü kendi hareketiyle (zıplama, paytak, süzülme, jöle sallanması, sekme, ağır adım, boss süzülmesi; birey
  başına tempo farkı, eğilme); sürü içinde renk tonu farkı (boss hariç); süsler istemcide canlanıyor (kulak, rün/taç/buz dönmesi,
  baloncuk yükselmesi, alev/çatlak/kristal titremesi) - yalnızca kameraya 120 birim yakın olanlar, Effects: Low'da kapalı.
  M29: saldırı pozları (`shared/CreatureMotion`, saf): şarj edenler çömelip geriye yaslanır ve titrer, atılırken öne eğilir;
  atıcılar şişip geriye eğilir, atışta öne fırlar; Shade ışınlanmadan önce çöküp hızlanarak döner; temasla vuranlar yakındayken
  öne eğilip hızlı zıplar; geri itilenler sersemleyip sallanır; bosslar yer çarpmasından önce yükselip çakılır, küre saldırısında döner.
  M30: saldırı sesleri ve toz (istemci, yalnızca 90 birim yakındakiler): şarj edenler eşeler/atılır/iner, atıcılar "pop",
  Shade mor duman, bosslar uğultu + yer çarpmasında gümbürtü ve toz halkası; sesler 3B (`Audio.playAt`), `pitch` alanı.
  Yalnızca kurulumdaki `content/sounds` dosyaları kullanıldı; eksik `swordslash.wav`/`electronicpingshort.wav` yerine saldırı `action_swim` (perde 2,2), arındırma `impact_water` (1,8), toplama `volume_slider` (1,4).
- Denge: `lune run tests/balance` Sv1–100 modeli (silah, düşman canı, kese).

## Doğrulanan testler (bu bulut ortamında çalıştırıldı: `lune run tests/all`)
- logic 72, balance, api, scene 18, sim 62, client 56/57/57/1, place; hepsi geçti (sinematik akış,
  Skip mutasyonla doğrulandı; hikâye verisi, kutsama, ipuçları, işaretçiler, kazanılan kostümler).
- Denge modeli: yaratık 0,3–2,2 sn'de ölür, 3 yaratığa 9–47 sn dayanılır, seviye başı 1–12 dk,
  Sv100 ≈ 6,0 sa (hikâye ile); efsane savaşları 50/59/79 sn. Hikâye botu: 4,5 bot-dk. Kule duvar katı 25–47; yeniden doğuş tırmanışı 5,3–6,8 sa.
- Studio'da ilk çalıştırma yapıldı (kullanıcı, yerel). Bulunan: kol animasyonu C0 tween hatası (düzeltildi). Elle test listesi sürüyor.

## Bilinen riskler
- Silah/kostüm modelleri, açılar, sandık konumları tahmini; denge bir model. Ses kimlikleri boş; animasyonlar prosedürel.
- Mağaza ürün kimlikleri 0 (`StoreData`); sinematik kamera/PlayerModule kilidi Studio'da denenmedi.
## Bekleyen elle testler (ertelendi): `docs/SETUP.md` → "Elle test listesi" (1–16, 6b/6c, 10b–10v) oynanmadı.

## Sonraki adım: Studio testleri → Output hatalarını düzelt.
