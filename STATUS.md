# Durum

## Aşama: M6a tamam (otomatik savaş); sıradaki M6b. Studio testi hâlâ bekliyor.

## Tamamlananlar
- M2–M4: seviye, Işık Dalgası, güç kademeleri, 3 tılsım, ProfileStore kayıt; 6 görev, 3 düşman
  davranışı, boss, köy canlanması, co-op ödül; efektler, mobil arayüz, HUD.
- M5 (kısmen): luau-lsp tip taraması temiz (yalnızca araç kaynaklı uyarılar).
- M6a: tüm oyun İngilizce (NPC: Elder Nora, Smith Bram); yukarıdan çapraz takip kamerası +
  zoom; menzil halkası; sunucuda otomatik saldırı (en yakın hedef, görüş hattı, bekleme);
  8 silah (Light Staff, Sunleaf Bow, Starlight Daggers, Brave Sword, Comet Spear, Thunder
  Crossbow, Whirlwind Axe, Moonstone Hammer) her biri farklı vuruş biçimiyle, seviyeyle açılır,
  Weapons menüsünden seçilir, eldeki model değişir; seviye sınırı 100 (formül), her yaratık
  seviyesine göre XP/sikke; Sv25/50/75/100'de arkada süzülen 1–4 ek silah (otomatik seçim veya
  elle); 19 düşmanlık seviyeli sürüler (Sv1–6) + boss Sv8, etiket "Lv.N Ad"; yalnızca
  Studio'da `LvDebugLevel` ile seviye deneme.

## Doğrulanan testler (bu bulut ortamında çalıştırıldı: `lune run tests/all`)
- logic 30, api, scene 11 (8 silah modeli dâhil), sim 26, client 22/23/23/1, place 47 dosya;
  hepsi geçti. sim: otomatik saldırı, menzil dışı saldırı yok, silah değiştirme, yüzen silahın
  arkadan saldırması, geçersiz EquipWeapon istekleri, co-op'ta ödülün en fazla bir kez ödenmesi.
- Denge botu (`lune run tests/playtime`): hikâye 3,7 bot-dk, Sv8'de biter, boss'ta 1 yenilgi.
- Roblox Studio'da HİÇ ÇALIŞTIRILMADI: kamera hissi, silah modellerinin eldeki duruşu,
  efektlerin görünümü, fizik, gerçek DataStore, ağ ve performans ölçülmedi.

## Bilinen riskler
- Silah modelleri ve eldeki açıları tahmini; Studio'da ayar gerekebilir.
- Mevcut bölgeler Sv1–8 içerik sunuyor; Sv25+ için M6c'deki yeni bölgeler gerekli
  (şu an Sv25'e ~34 bin XP kalıyor, yavaş).
- Çok oyuncu + 4 yüzen silahta ağ olayı sayısı ve efekt yükü ölçülmedi (uzak efektler çizilmiyor).
- Ses kimlikleri çoğunlukla boş; animasyonlar prosedürel.

## Sonraki adım (tek)
Kullanıcı Studio'da `docs/SETUP.md` elle test listesini oynayıp Output hatalarını iletsin;
ardından M6b (kristal/kese, çok seviyeli yükseltme paneli, seviye atlayınca 3 kart).
