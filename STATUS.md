# Durum

## Aşama: M6a–M6d tamam (M6 bitti). Studio testi hâlâ bekliyor.

## Tamamlananlar
- M2–M5 (kısmen): seviye, dalga, tılsım, kayıt, 6 görev, boss, co-op, mobil arayüz, tip taraması.
- M6a: oyun İngilizce; çapraz takip kamerası, menzil halkası, sunucuda otomatik saldırı; 8 silah
  (farklı vuruş biçimleri); Sv100 sınırı; Sv25/50/75/100'de arkada süzülen 1–4 ek silah;
  Studio'da `LvDebugLevel` / `LvDebugAllWeapons`.
- M6b: 7 dünya noktasında kişisel sandık (4 tür: 2/5/10/20 dk); sandık yuvası 1→5 (Sv1/3/6/10/15);
  tek seferde tek kilit açma, sayaç sunucu saatiyle (çevrimdışı da işler); ödül: sikke, nadirliğe
  göre silah (Common→Legendary; asa dışı silahlar yalnızca sandıktan; kopya → sikke) ve silah yuvası
  seviyesi (0–30, seviye başına %8, yuvadaki her silaha). Chests penceresi, "!" rozeti, ödül paneli.
- M6c: yaratıklar sikke yerine Işık Kristali verir (kese kapasitesi 60+), Büyük Fener'de 1:1 sikke;
  Forge'da 5 çok seviyeli yükseltme (Güç 50, Kese 20, Can 50, İyileşme 20, Kritik 20; artan fiyat);
  kritik vuruş (x2); her seviye atlamada 3 karttan yetenek (10 yetenek, 45 rütbe; bitince sikke
  kartı), teklif kayıtta saklanır; ortak hesap `Shared/Stats` (sunucu+istemci aynı).
- M6d: doğu toprakları (kaya sırtı + 3 geçit): Misty Marsh Sv8–25, Frost Peaks Sv26–50, Shadow
  Citadel Sv51–100; 7 yeni yaratık, 37 yeni düşman (her doğuşta aralıktan seviye), 4 yeni sandık
  noktası; 3 seviyeli efsane boss + Legends koleksiyonu (ilk zafer: Mistik sandık); 2. bölüm görevleri.
- Denge: `lune run tests/balance` Sv1–100 modeli; silahlar nadirliğe göre kademeli; düşman canı
  üstel; seviye başına savaş sayısı formülle; kese seviyeyle büyür; başlangıç canı 150.

## Doğrulanan testler (bu bulut ortamında çalıştırıldı: `lune run tests/all`)
- logic 41, balance, api, scene 12, sim 33, client 27/28/28/1, place; hepsi geçti. Yeni: seviye
  aralıkları 1–100 boşluksuz, efsane kaydı tek sefer, Bog Mother simde yenilir, Legends ekranı.
- Denge modeli: yaratık 0,3–2,2 sn'de ölür, 3 yaratığa 9–47 sn dayanılır, seviye başı 1–12 dk,
  Sv100 ≈ 8 saat; efsane savaşları 50/59/79 sn. Hikâye botu: 3,9 bot-dk, Sv6'da biter.
- Roblox Studio'da HİÇ ÇALIŞTIRILMADI: kamera hissi, silah modellerinin eldeki duruşu,
  efektlerin görünümü, fizik, gerçek DataStore, ağ ve performans ölçülmedi.

## Bilinen riskler
- Silah modelleri, eldeki açılar ve sandık konumları tahmini; Studio'da ayar gerekebilir.
- Sandık/silah dengesi yalnızca hesapla kuruldu (gerçek oyuncu verisi yok).
- Denge bir model; gerçek oyuncu verisiyle (Studio/test sürümü) yeniden ayarlanmalı.
- Çok oyunculu ağ/efekt yükü ölçülmedi (uzak efektler çizilmiyor).
- Ses kimlikleri çoğunlukla boş; animasyonlar prosedürel.
## Bekleyen elle testler (kullanıcı isteğiyle ertelendi)
`docs/SETUP.md` → "Elle test listesi" maddelerinin tamamı (1–16, 6b/6c, 10b/10c) Studio'da oynanmadı.

## Sonraki adım (tek)
M7 geliştirme turu (kullanıcı isteği): sayı kısaltma, elit yaratıklar, Gölge Yarığı dalgaları.
