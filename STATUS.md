# Durum

## Aşama: M6a–M6c tamam; sıradaki M6d. Studio testi hâlâ bekliyor.

## Tamamlananlar
- M2–M5 (kısmen): seviye, Işık Dalgası, tılsımlar, ProfileStore kayıt; 6 görev, 3 düşman, boss,
  köy canlanması, co-op; efektler, mobil arayüz; luau-lsp tip taraması temiz.
- M6a: tüm oyun İngilizce (NPC: Elder Nora, Smith Bram); yukarıdan çapraz takip kamerası +
  zoom; menzil halkası; sunucuda otomatik saldırı (en yakın hedef, görüş hattı, bekleme);
  8 silah (Light Staff, Sunleaf Bow, Starlight Daggers, Brave Sword, Comet Spear, Thunder
  Crossbow, Whirlwind Axe, Moonstone Hammer) her biri farklı vuruş biçimiyle, Weapons menüsünden
  seçilir; seviye sınırı 100; Sv25/50/75/100'de arkada süzülen 1–4 ek silah; seviyeli sürüler
  (Sv1–6) + boss Sv8; Studio'da `LvDebugLevel` / `LvDebugAllWeapons` ile deneme.
- M6b: 7 dünya noktasında kişisel sandık (4 tür: 2/5/10/20 dk); sandık yuvası 1→5 (Sv1/3/6/10/15);
  tek seferde tek kilit açma, sayaç sunucu saatiyle (çevrimdışı da işler); ödül: sikke, nadirliğe
  göre silah (Common→Legendary; asa dışı silahlar yalnızca sandıktan; kopya → sikke) ve silah yuvası
  seviyesi (0–30, seviye başına %8, yuvadaki her silaha). Chests penceresi, "!" rozeti, ödül paneli.
- M6c: yaratıklar sikke yerine Işık Kristali verir (kese kapasitesi 60+), Büyük Fener'de 1:1 sikke;
  Forge'da 5 çok seviyeli yükseltme (Güç 50, Kese 20, Can 50, İyileşme 20, Kritik 20; artan fiyat);
  kritik vuruş (x2); her seviye atlamada 3 karttan yetenek (10 yetenek, 45 rütbe; bitince sikke
  kartı), teklif kayıtta saklanır; ortak hesap `Shared/Stats` (sunucu+istemci aynı).

## Doğrulanan testler (bu bulut ortamında çalıştırıldı: `lune run tests/all`)
- logic 39, api, scene 12, sim 32, client 26/27/27/1, place; hepsi geçti. Yeni: kese sınırı ve
  tek uyarı, fener dönüşümü, Forge fiyat/seviye, sadece sunulan kartın seçilebilmesi, kritik vuruş,
  iyileşme; istemcide kese göstergesi, Forge satırları, kart ekranı.
- Denge botu: hikâye 3,8 bot-dk, Sv8'de biter; güç 10 hikâye sonrası hedef.
- Roblox Studio'da HİÇ ÇALIŞTIRILMADI: kamera hissi, silah modellerinin eldeki duruşu,
  efektlerin görünümü, fizik, gerçek DataStore, ağ ve performans ölçülmedi.

## Bilinen riskler
- Silah modelleri, eldeki açılar ve sandık konumları tahmini; Studio'da ayar gerekebilir.
- Sandık/silah dengesi yalnızca hesapla kuruldu (gerçek oyuncu verisi yok).
- Mevcut bölgeler Sv1–8 içerik sunuyor; Sv25+ için M6d'deki yeni bölgeler gerekli.
- Çok oyuncu + 4 yüzen silahta ağ olayı sayısı ve efekt yükü ölçülmedi (uzak efektler çizilmiyor).
- Ses kimlikleri çoğunlukla boş; animasyonlar prosedürel.

## Sonraki adım (tek)
Kullanıcı Studio'da `docs/SETUP.md` elle test listesini oynayıp Output hatalarını iletsin;
ardından M6d (Efsane Gölgeler boss koleksiyonu, Sv25+ için yeni zorlu bölgeler).
