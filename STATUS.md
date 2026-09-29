# Durum
## Aşama: M14 (hikâye, sinematik, animasyon, işaretçiler, kostümler) tamam. Studio testleri ertelendi.

## Tamamlananlar
- M2–M5: seviye, dalga, tılsım, kayıt, 6 görev, boss, co-op, mobil arayüz.
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
  M14: işaretçiler, ipuçları, 6 kostüm; M15: profesyonel ayarlar penceresi + grafik
  ön ayarları/özelleştirme
  (Auto–Ultra, gölge, parlama, sis, FOV, ses, arayüz boyutu); M16: Players paneli, ses rehberi; M17: kulede
  boss katları (her 10 katta Efsane Gölge).
- Denge: `lune run tests/balance` Sv1–100 modeli (silah kademeleri, üstel düşman canı, kese).

## Doğrulanan testler (bu bulut ortamında çalıştırıldı: `lune run tests/all`)
- logic 65, balance, api, scene 15, sim 52, client 45/46/46/1, place; hepsi geçti (sinematik akış,
  Skip mutasyonla doğrulandı; hikâye verisi, kutsama, ipuçları, işaretçiler, kazanılan kostümler).
- Denge modeli: yaratık 0,3–2,2 sn'de ölür, 3 yaratığa 9–47 sn dayanılır, seviye başı 1–12 dk,
  Sv100 ≈ 6,2 sa (hikâye ile); efsane savaşları 50/59/79 sn. Hikâye botu: 4,5 bot-dk. Kule duvar katı 25–47; yeniden doğuş tırmanışı 5,3–6,8 sa.
- Roblox Studio'da HİÇ ÇALIŞTIRILMADI: görünüm, fizik, gerçek DataStore, ağ, performans ölçülmedi.

## Bilinen riskler
- Silah/kostüm modelleri, açılar ve sandık konumları tahmini; denge bir model (gerçek veriyle ayarlanmalı).
- Ses kimlikleri boş (SETUP'ta rehber); animasyonlar prosedürel.
- Mağaza ürün kimlikleri 0 (`StoreData`); sinematik kamera/PlayerModule kilidi Studio'da denenmedi.
## Bekleyen elle testler (kullanıcı isteğiyle ertelendi)
`docs/SETUP.md` → "Elle test listesi" maddelerinin tamamı (1–16, 6b/6c, 10b–10o) oynanmadı.

## Sonraki adım: Studio testleri → Output hatalarını düzelt.
