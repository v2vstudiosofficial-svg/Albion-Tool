# Durum
## Aşama: M59 (hasar yönü okları, ayar önbelleği; M58: ayarlar simgeleri ve müzik sesi, oyuncu madalyaları, kule kartı; M57: elit parıltısı, yetenek kartları; M56: sandık ışık sütunu; M55: mini harita ve yer adları; M54: günlük hediye açılışı; M53: silah güç farkı; M52: boss öfkesi, görev tiki, kapanış sesi; M51: Screen flashes ayarı; M50: yenilgi ekranı; M49: silah kartı simgeleri; M48: sade etiketler, parlayan ödül düğmeleri; M47: oyuna özel etkileşim istemi; M46: sıradaki açılış; M45: boss tanıtımı; M44: ekran kenarı hedef oku; M43: dokunmatik Menu; M42: küçük düzeltmeler; M41: ayak tozu; M40: önünü kapatan şeyler saydamlaşır; M39: bölge atmosferi; M38: gün-gece döngüsü; M37: yetenek bilgisi, kilitli silah önizlemesi; M36: menü simgeleri; M35: sandık açılış anı; M34: başlık şeridi ve ilerleme çubukları; M33: dövüş hissi; M32: yükleme ekranı; M31: arayüz cilası 1; M30: saldırı sesleri ve toz; M29: saldırı öncesi pozlar; M28: yaratık animasyonları ve bireysel tonlar; M27: yetenek çubuğu + Star Fall/Lantern Glow, yeni yaratık silüetleri; M26: grafik kalitesi düzeltmesi, düşman/harita görünümü; M25: yaratık kodeksi, günlük hediye, oyuncu etiketleri, mini harita, unvanlar; Kael epilogu, hikâye, sinematik, ayarlar, kule, pet, rebirth) tamam. Studio testleri ertelendi.

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
  Yalnızca kurulumdaki `content/sounds` dosyaları kullanıldı; sonra tüm sesler Creator Store kimlikleriyle değiştirildi (ProSoundEffects + Roblox; 16/16 Studio'da yüklendi); müzik bölgeye göre (`shared/MusicLogic`, 7 APM parçası; eski parça tamamen susunca yenisi başlar).
  M31: arayüz cilası: tam sinematik sahnelerde HUD/menü/mini harita/emote/oyuncu paneli ve görev işareti gizlenir; açık pencerenin
  arkasında karartma (tıklayınca kapanır) ve dünya bulanıklığı (Settings hariç, grafik ayarı görülsün diye); masaüstünde menü
  kısayolları (G Weapons, C Chests, L Legends, B Bag, J Log, H Shop, P Pass) ve düğme köşesinde tuş rozeti; oyuncu kartında can
  barı (Roblox'un küçük barı kapalı; renk yeşilden kırmızıya, vuruşta soluk iz), vuruşta ekran kenarı kırmızı parlar, %30 altında
  nabız gibi atar; bildirimler hap biçiminde, aynı metin "x2" diye birleşir, en çok 4 tane; dünya isim etiketleri sabit piksel boyutu.
  M32: oyuna özel yükleme ekranı (`src/first`, ReplicatedFirst): gece mavisi gökyüzü, yükselen altın kıvılcımlar, nefes alan
  hale içinde titreyen alevli fener, başlık, 4 sn'de bir değişen 8 ipucu, ilerleme çubuğu (dünya %60 + kayıt %40), uzun sürerse
  Skip; kayıt hazır olunca (en az 2,5 sn, en çok 25 sn) solarak kapanır; ilk hikâye sahnesi ekran kapanana kadar bekler.
  M33: dövüş okunurluğu (`shared/CombatFeel`, saf): yaratık adı seviye farkına göre renkli (çok kolay gri, denk krem, zor turuncu,
  ölümcül kırmızı; elit altın kalır, oyuncu seviyesi değişince güncellenir); düşman barında hasar izi; hasar sayıları büyük
  "pat" diye çıkıp yerine oturur, yana kayarak yükselir (kritikler eğik); arındırma serisi sayacı (3'ten itibaren altta "x12",
  10/25/50'de renk ısınır, 10/25/50/100/250/500'de bildirim; zincir 4 sn kopunca kaybolur, ödül vermez).
  M34: ekran ortası başlıklar kenarları solan koyu bir şeritte; sevinç anlarında (seviye, görev, boss arındırma) arkada dönen
  altın ışın yelpazesi, tehlike anlarında (boss geldi, rift dalgası, kule boss katı) mor şerit; sayaçlı görevlerde görev panelinde
  ilerleme çubuğu (bitince yeşil); boss barında yüzde ve hasar izi.
  M35: sandık açılışı tam ekran bir an (`client/ChestReveal`): ekran kararır, sandık düşüp üç kez sarsılır, kapak parlamayla
  fırlar, arkada sandık renginde dönen ışınlar; ödüller sırayla belirir (sikkeler sayarak artar, yeni silah nadirlik renginde),
  sonda Continue; yeni sandık gelirse baştan başlar. Sandık kartlarında küçük sandık çizimi, açılırken dolan çubuk, hazır olunca
  yeşil nabız çerçeve ve zıplayan kapak.
  M36: menü düğmelerinde emoji simgeler (üstte simge, altta ad; Strings `icon_*`): Weapons ⚔️, Chests 🧰, Legends 👑, Bag 🎒,
  Settings ⚙️, Log 📖, Shop 💰, Pass ⭐, Daily gift 🎁; Emotes/Players düğmelerinde soldan simge; her emote kendi simgesiyle.
  (🪙 Studio'da çizilmedi, 💰 kullanıldı.)
  M37: masaüstünde yetenek düğmesinin üzerine gelince bilgi kutusu (ad + tuş, ne yaptığı, dolum süresi ya da açıldığı seviye);
  yetenek yeniden hazır olunca düğmeden renkli halka yayılır; Weapons menüsünde bulunmamış silahlar "🔒 Ad" ve daha belirgin
  nadirlik şeridiyle görünür, tıklayınca nadirliğini, ne yaptığını ve sandıklarda aranacağını söyler.
  M38: gün-gece döngüsü (`shared/DayCycle` saf + `client/DayNight`): 20 dk'lık gün, saat sunucu zamanından (herkes aynı gökyüzü);
  uzun gündüz, sıcak turuncu gün batımı/doğumu, kısa ve aydınlık mavi gece; gece fener ışıkları (haritadaki "Glow" ışıkları)
  parlaklaşır, oyuncunun çevresinde ateş böcekleri çıkar (Effects: Low'da yok). Ayarlar > Graphics > "Day & night" kapalıysa
  hep öğleden sonra (15.5). Graphics artık saat/ışık rengine dokunmuyor.
  M39: bölgeye göre ortam partikülleri (`client/Ambience`, yerler MusicLogic.theme ile aynı): köyde polen, vadi ormanında süzülen
  yapraklar, bataklıkta yükselen yeşil sporlar, zirvelerde kar, kalede kor kıvılcımları, Gölge Kulesi'nde mor zerreler; boss
  arenalarında yok; Effects ayarıyla seyrelir, Low'da kapalı.
  M40: kamera ile oyuncu arasına giren harita parçaları (ağaç tepesi, çatı, kaya) yalnızca bu ekranda yarı saydamlaşır
  (`client/SeeThrough`, LocalTransparencyModifier, 0,1 sn'de bir ışın), artık engellemeyince yumuşakça geri gelir; yaratıklar
  ve oyuncular etkilenmez. Studio'da doğrulandı (ağacın arkasındaki karakter görünüyor).
  M41: koşarken ayaklarda zemine göre renkli küçük toz bulutları (çim yeşilimsi, kum bej, kar beyaz, çamur kahve), zıplayıp
  inince toz halkası; yalnızca kendi karakterin, Effects: Low'da yok. (Lune `FloorMaterial` okuyamadığı için otomatik test yok;
  Studio'da ölçüldü: koşarken aynı anda 6 bulut.)
  M42: sinematik sahnelerde NPC/pano/kule "!" işaretleri de gizlenir (`World.setMarkersHidden`); Bag'deki tılsım/pet satır
  düğmelerinde uzun yazı ("Earned from a quest") artık sığıyor; ekran kenarı kırmızı parlaması yalnızca canın en az %6'sını
  alan vuruşlarda ve vuruşla orantılı (sürekli küçük hasarda ekran kırmızıya boğulmuyordu, Studio'da görüldü).
  M43: dokunmatik ekranlarda sağ üstte tek "📋 Menu" düğmesi (telefonda 8 düğmelik ızgara ~67x32 piksele iniyordu); dokununca
  büyük kutucuklu (120x78, 32 punto simge) pencere açılır, kutucuk kendi penceresini açar; içerideki "!" rozetleri Menu düğmesinde
  toplanır. Masaüstü değişmedi. (Telefon görünümü Studio'da gözle denenmedi; dokunmatik testler geçiyor.)
  M44: görev hedefi ekran dışındayken ekran kenarında hedefe dönük altın bir ok ve mesafe (`MapLogic.edgeArrow` saf; kameranın
  arkasındaysa yansıtılır); hedef ekrana girince ok kaybolur, sahnelerde görünmez. Studio'da doğrulandı.
  M45: her boss bu oturumda ilk kez savaşa girince kamera 1,4 sn ona yakından döner, sonra oyuncuya geri gelir (Camera in story
  scenes kapalıysa ya da hikâye sahnesi sürerken olmaz); boss savaşı boyunca görev paneli gizlenir ve boss barı en üste çıkar
  (kamera kuzeye baktığı için paneller boss'un üstünü kapatıyordu). Studio'da doğrulandı. Ekran ortası başlık görünürken
  bildirimler gizlenir (şerit onların üstünden geçiyordu); başlık bitince geri gelir ve tam süre ekranda kalır.
  M46: oyuncu kartının altında sıradaki açılış ("Next at Lv 6: Star Fall"; yetenekler, sandık yuvaları, Gölge Kulesi, yüzen
  silah yuvaları; `Progression.unlocks/nextUnlock` saf, aynı seviyede yetenek önce), Sv100'de gizli.
  M47: etkileşim istemleri oyunun görünümünde (`client/Prompts`, istem stili yalnızca bu ekranda Custom): koyu hap, altın tuş
  rozeti (E; dokunmatikte 👆, gamepad'de düğme), eylem ve hedef adı; hapa dokunmak/tıklamak da kullanır; istem açıkken hedefin
  isim etiketi gizlenir (adı tekrarlamasın); hikâye sahnelerinde istem, ilk dakika ipucu ve kenar oku gizlenir. Studio'da doğrulandı.
  M48: sakin ve hasarsız yaratıkların etiketi yalnızca 40 birimden yakında görünür, hasar alan ya da kovalayanlar 90'dan
  (orman bir isim duvarına dönüyordu); bekleyen ödül düğmeleri nabız gibi parlar (`UiKit.setPulse`): Log "Claim!", pano
  "Claim", Pass "Claim all", sandık "Open!".
  M49: Weapons menüsünde her silah kartında kendi simgesi (WeaponData `iconKey`: 🔮 🏹 🗡️ ⚔️ 🔱 🎯 🌀 🔨; bulunmamışlarda soluk),
  ad ve yıldızlar altta, nadirlik şeridi yazının altında (önce yazının üstünden geçiyordu, Studio'da görüldü ve düzeltildi).
  Yeni Light Pass kademesinde Pass düğmesi (dokunmatikte Menu) zıplar ve 3 sn parlar.
  M50: yenilgi ekranı: ekran morumsu kararır, "The shadows got you!", köye dönüşe geri sayım (Balance.player.respawnTime) ve
  sırayla değişen bir ipucu (iyileşme, kırmızı isimler, sandık silahları); yeni karakter gelince kapanır. Studio'da doğrulandı.
  M51: erişilebilirlik: Settings > Gameplay > "Screen flashes" (açık varsayılan); kapalıyken vuruşta kırmızı kenar ve sandık
  açılışındaki beyaz flaş yok, düşük can sakin sabit bir kenarla gösterilir.
  M52: boss ikinci faza geçince yakındakilere "<Boss> is enraged!" tehlike başlığı ve boss barı kızıla döner (Studio'da
  doğrulandı); görev bitince görev panelinde yeşil ✓ ve 2 sn yeşil çerçeve; pencere kapanırken daha pes, yumuşak bir tık
  (`uiClose`, aynı ses perde 0,8).
  M53: Weapons menüsünde sahip olunan her silah kartının köşesinde, seçili yuvadaki silaha göre güç farkı (yeşil ▲, kırmızı ▼;
  yuva seviyesi ve yıldızlar hesaba katılır).
  M54: günlük hediye alınınca sandık açılış anı altın "Daily Gift" olarak oynar, sikkeler sayarak artar (miktar sikke
  değişiminden; ChestReveal artık kendi başlık/renk alabiliyor).
  M55: mini haritada üst kenarda N, açık Shadow Rift'ler için nabız gibi atan mor noktalar (`Effects.activeRifts`), haritanın
  altında bulunduğun yerin adı; yeni bir yere girince ortadaki şeritte yer adı (Lantern Village, Whisperwood, Misty Marsh,
  Frostpeak Heights, Shadow Citadel, Shadow Tower; boss arenaları boss'u duyurur). `Hud.banner` başka modüllere açıldı.
  M56: dünyadaki sandıkların üstünde kendi renginde, hafif nabız atan bir ışık sütunu (uzaktan, ağaçların arasından görünür);
  basılı tutulan istemlerde hapın altında dolan çubuk, hapa dokunmak istemi gereken süre kadar tutar (sandık istemi 0,3 sn
  istiyordu, dokunuş hemen bırakıyordu). Studio'da doğrulandı.
  M57: elit yaratıkların üzerinde altın parıltılar (Effects: Low'da yok); yetenek kartları açılınca tek tek dönerek dağıtılır,
  her kartta simge (SkillData `iconKey`: ⚡🗡️🎯🍀🛡️🧲👟🌊📚💖🔥💎💫, sikke kartı 💰); "Pick a skill" düğmesi sıradaki açılış
  satırının altına taşındı (çakışıyordu). Studio'da doğrulandı.
  M58: Settings'te her sekme ve satırda simge, ayrı Music ses ayarı (Audio: master × music), sunucu kaydedince
  satır parlar ve "✓ Saved" görünür; pencere 700 px. Players panelinde ilk üçe 🥇🥈🥉, seviye rozeti (renk seviyeyle
  büyür, rebirth'te altın halka), X ile kapatma. Kulede görev paneli yerine kule kartı: kat, en iyi kat, boss'a kalan
  kat (bir önceki katta kırmızı uyarı), kalan gölge sayacı (sunucu `TowerLeft`), yeni rekorda altın parlama.
  Eski kule yazısı Players düğmesinin üstüne biniyordu (kaldırıldı). Studio'da doğrulandı.
  M59: her vuruşta kahramanın çevresinde, vuruşun geldiği yöne bakan kırmızı ok (sunucu `hurt` Fx'i: temas, atılma,
  boss ezmesi, mermi; CharacterService.damage artık kaynağı alır). Performans: Settings.get her karede 22 öznitelik
  okuyup tablo kuruyordu; Pref_ değişene kadar önbellekte. Diğer kare döngüleri zaten seyreltilmiş/mesafeyle sınırlı.
  Studio'da doğrulandı.
- Denge: `lune run tests/balance` Sv1–100 modeli (silah, düşman canı, kese).

## Doğrulanan testler (bu bulut ortamında çalıştırıldı: `lune run tests/all`)
- logic 77, balance, api, scene 18, sim 62, client 72/73/73/1, place; hepsi geçti (sinematik akış,
  Skip mutasyonla doğrulandı; hikâye verisi, kutsama, ipuçları, işaretçiler, kazanılan kostümler).
- Denge modeli: yaratık 0,3–2,2 sn'de ölür, 3 yaratığa 9–47 sn dayanılır, seviye başı 1–12 dk,
  Sv100 ≈ 6,0 sa (hikâye ile); efsane savaşları 50/59/79 sn. Hikâye botu: 4,5 bot-dk. Kule duvar katı 25–47; yeniden doğuş tırmanışı 5,3–6,8 sa.
- Studio'da ilk çalıştırma yapıldı (kullanıcı, yerel). Bulunan: kol animasyonu C0 tween hatası (düzeltildi). Elle test listesi sürüyor.

## Bilinen riskler
- Silah/kostüm modelleri, açılar, sandık konumları tahmini; denge bir model. Ses kimlikleri boş; animasyonlar prosedürel.
- Mağaza ürün kimlikleri 0 (`StoreData`); sinematik kamera/PlayerModule kilidi Studio'da denenmedi.
## Bekleyen elle testler (ertelendi): `docs/SETUP.md` → "Elle test listesi" (1–16, 6b/6c, 10b–10v) oynanmadı.

## Sonraki adım: Studio testleri → Output hatalarını düzelt.
