# Durum

## Aşama: M6a + M6b (sandıklar) tamam; sıradaki M6c. Studio testi hâlâ bekliyor.

## Tamamlananlar
- M2–M4: seviye, Işık Dalgası, güç kademeleri, 3 tılsım, ProfileStore kayıt; 6 görev, 3 düşman
  davranışı, boss, köy canlanması, co-op ödül; efektler, mobil arayüz, HUD.
- M5 (kısmen): luau-lsp tip taraması temiz (yalnızca araç kaynaklı uyarılar).
- M6a: tüm oyun İngilizce (NPC: Elder Nora, Smith Bram); yukarıdan çapraz takip kamerası +
  zoom; menzil halkası; sunucuda otomatik saldırı (en yakın hedef, görüş hattı, bekleme);
  8 silah (Light Staff, Sunleaf Bow, Starlight Daggers, Brave Sword, Comet Spear, Thunder
  Crossbow, Whirlwind Axe, Moonstone Hammer) her biri farklı vuruş biçimiyle, Weapons menüsünden
  seçilir, eldeki model değişir; seviye sınırı 100 (formül), her yaratık
  seviyesine göre XP/sikke; Sv25/50/75/100'de arkada süzülen 1–4 ek silah (otomatik seçim veya
  elle); 19 düşmanlık seviyeli sürüler (Sv1–6) + boss Sv8, etiket "Lv.N Ad"; yalnızca
  Studio'da `LvDebugLevel` / `LvDebugAllWeapons` ile deneme.
- M6b: 7 dünya noktasında kişisel sandık (4 tür: 2/5/10/20 dk); sandık yuvası 1→5 (Sv1/3/6/10/15);
  tek seferde tek kilit açma, sayaç sunucu saatiyle (çevrimdışı da işler); ödül: sikke, nadirliğe
  göre silah (Common→Legendary; asa dışı silahlar yalnızca sandıktan; kopya → sikke) ve silah yuvası
  seviyesi (0–30, seviye başına %8, yuvadaki her silaha). Chests penceresi, "!" rozeti, ödül paneli.

## Doğrulanan testler (bu bulut ortamında çalıştırıldı: `lune run tests/all`)
- logic 35, api, scene 12, sim 27, client 24/25/25/1, place; hepsi geçti. Sandık testleri: dolu
  yuva, tek kilit, erken açma reddi, ödül tek sefer, nadirlik ağırlıkları, sandıkların haritada
  bir parçanın içine düşmemesi (bir ağaçla çakışma bu testle bulunup düzeltildi).
- Denge botu: hikâye 3,3 bot-dk, Sv7'de biter.
- Roblox Studio'da HİÇ ÇALIŞTIRILMADI: kamera hissi, silah modellerinin eldeki duruşu,
  efektlerin görünümü, fizik, gerçek DataStore, ağ ve performans ölçülmedi.

## Bilinen riskler
- Silah modelleri, eldeki açılar ve sandık konumları tahmini; Studio'da ayar gerekebilir.
- Sandık/silah dengesi yalnızca hesapla kuruldu (gerçek oyuncu verisi yok).
- Mevcut bölgeler Sv1–8 içerik sunuyor; Sv25+ için M6c'deki yeni bölgeler gerekli
  (şu an Sv25'e ~34 bin XP kalıyor, yavaş).
- Çok oyuncu + 4 yüzen silahta ağ olayı sayısı ve efekt yükü ölçülmedi (uzak efektler çizilmiyor).
- Ses kimlikleri çoğunlukla boş; animasyonlar prosedürel.

## Sonraki adım (tek)
Kullanıcı Studio'da `docs/SETUP.md` elle test listesini oynayıp Output hatalarını iletsin;
ardından M6c (kristal/kese, çok seviyeli yükseltme paneli, seviye atlayınca 3 kart).
