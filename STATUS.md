# Durum

## Aşama: M8 (hata taraması, performans, bağlılık) tamam. Studio testleri ertelendi.

## Tamamlananlar
- M2–M5 (kısmen): seviye, dalga, tılsım, kayıt, 6 görev, boss, co-op, mobil arayüz, tip taraması.
- M6a: oyun İngilizce; çapraz takip kamerası, menzil halkası, sunucuda otomatik saldırı; 8 silah
  (farklı vuruş biçimleri); Sv100 sınırı; Sv25/50/75/100'de arkada süzülen 1–4 ek silah;
  Studio'da `LvDebugLevel` / `LvDebugAllWeapons`.
- M6b: kişisel süreli sandıklar (4 tür, 2–20 dk, yuva 1→5, tek kilit, çevrimdışı işler); ödül:
  sikke, nadirliğe göre silah (asa dışı silahlar yalnızca sandıktan) ve silah yuvası seviyesi (%5/sv).
- M6c: Işık Kristali + kese + Büyük Fener; Forge'da 5 çok seviyeli yükseltme; kritik vuruş; her
  seviyede 3 karttan yetenek (10 yetenek); ortak hesap `Shared/Stats` (sunucu+istemci aynı).
- M6d: doğu toprakları (Marsh Sv8–25, Peaks 26–50, Citadel 51–100), 7 yeni yaratık, 3 efsane boss
  + Legends koleksiyonu (ilk zafer: Mistik sandık), 2. bölüm görevleri.
- M7: sayı kısaltma (K/M/B); elit yaratıklar (%6, taçlı, 4x can, 3x ödül, sandık şansı);
  Gölge Yarığı dalga olayları (3 dalga, 90 sn, Silver Chest); Bubbler/Hexcap çoklu atış, Shade ışınlanma.
- M8: düzeltilen hatalar: bildirim yağmuru, boss sikkelerinin dolu kesede kaybolması, geç oyunda
  işe yaramaz dalga, hatırlatma tekrarı, mermi sınırı; performans: istemci/sunucu hesap önbelleği;
  Macera Günlüğü (9 başarım, kademeli ödül) ve takım bonusu (+%10/oyuncu, en çok %30).
- Denge: `lune run tests/balance` Sv1–100 modeli (silah kademeleri, üstel düşman canı, kese).

## Doğrulanan testler (bu bulut ortamında çalıştırıldı: `lune run tests/all`)
- logic 46, balance, api, scene 12, sim 40, client 30/31/31/1, place; hepsi geçti. M8: günlük
  sayaç/ödül, takım bonusu (mutasyonla doğrulandı), toplu bildirim, dalga hasarı, boss sikkesi.
- Denge modeli: yaratık 0,3–2,2 sn'de ölür, 3 yaratığa 9–47 sn dayanılır, seviye başı 1–12 dk,
  Sv100 ≈ 8 saat; efsane savaşları 50/59/79 sn. Hikâye botu: 3,9 bot-dk, Sv6'da biter.
- Roblox Studio'da HİÇ ÇALIŞTIRILMADI: görünüm, fizik, gerçek DataStore, ağ, performans ölçülmedi.

## Bilinen riskler
- Silah modelleri, eldeki açılar ve sandık konumları tahmini; Studio'da ayar gerekebilir.
- Denge (sandık/silah dahil) bir model; gerçek oyuncu verisiyle yeniden ayarlanmalı.
- Çok oyunculu ağ/efekt yükü ölçülmedi (uzak efektler çizilmiyor).
- Ses kimlikleri çoğunlukla boş; animasyonlar prosedürel.

## Bekleyen elle testler (kullanıcı isteğiyle ertelendi)
`docs/SETUP.md` → "Elle test listesi" maddelerinin tamamı (1–16, 6b/6c, 10b–10e) oynanmadı.

## Sonraki adım (tek)
Kullanıcının yeni isteği; ertelenen Studio testleri (yukarıda) yapılınca Output hatalarını düzeltmek.
