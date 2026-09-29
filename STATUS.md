# Durum

## Aşama: M11 (hata taraması, pet, Wren hikâyesi, yeniden doğuş) tamam. Studio testleri ertelendi.

## Tamamlananlar
- M2–M5 (kısmen): seviye, dalga, tılsım, kayıt, 6 görev, boss, co-op, mobil arayüz, tip taraması.
- M6a: oyun İngilizce; takip kamerası, sunucuda otomatik saldırı; 8 silah; Sv100 sınırı;
  Sv25/50/75/100'de arkada süzülen 1–4 ek silah; Studio'da `LvDebugLevel` / `LvDebugAllWeapons`.
- M6b: kişisel süreli sandıklar (4 tür, 2–20 dk, yuva 1→5); ödül: sikke, silah, yuva seviyesi (%5/sv).
- M6c: Işık Kristali + kese + Büyük Fener; Forge'da 5 yükseltme; kritik vuruş; seviyede 3 karttan
  yetenek (10 yetenek); ortak hesap `Shared/Stats`.
- M6d: doğu toprakları (Sv8–100), 7 yeni yaratık, 3 efsane boss + Legends, 2. bölüm görevleri.
- M7: sayı kısaltma; elit yaratıklar; Gölge Yarığı dalga olayları; özel düşman saldırıları.
- M8: hata düzeltmeleri, hesap önbelleği, Macera Günlüğü (9 başarım), takım bonusu (+%10/oyuncu).
- M9: Robux mağazası (3 sikke paketi, 30 dk 2x XP, başlangıç paketi, Premium Pas, 2 kostüm; ücretli
  rastgele ödül yok, ürün kimliği yoksa "Soon"); 50 kademeli Işık Pası; 12 görünüş kostümü.
- M10: silah yıldızları (kopya silah → yıldız, en çok 5, +%6/yıldız); İlan Panosu (3 ilan, süresiz);
  Gölge Kulesi (dış arenada sonsuz kat, co-op, sandık/5 kat, duvar katı balance testinde); 6 emote.
- M11: hata taraması (ilan/kule ödülü sınırı); 6 pet (oynayarak, kozmetik); Ranger Wren + 4 görev
  (sayaç görevleri); Yeniden doğuş (Sv100, +%10 XP en çok 5, koleksiyon kalır).
- Denge: `lune run tests/balance` Sv1–100 modeli (silah kademeleri, üstel düşman canı, kese).

## Doğrulanan testler (bu bulut ortamında çalıştırıldı: `lune run tests/all`)
- logic 60, balance, api, scene 15, sim 49, client 38/39/39/1, place; hepsi geçti. M11: pet, Wren
  görevleri (sayaç), yeniden doğuş (mutasyonla doğrulandı: yakınlık ve seviye kontrolü).
- Denge modeli: yaratık 0,3–2,2 sn'de ölür, 3 yaratığa 9–47 sn dayanılır, seviye başı 1–12 dk,
  Sv100 ≈ 8 saat; efsane savaşları 50/59/79 sn. Hikâye botu: 4,5 bot-dk, Sv7'de biter. Kule duvar katı 25–47; yeniden doğuş tırmanışı 5,3–6,8 sa.
- Roblox Studio'da HİÇ ÇALIŞTIRILMADI: görünüm, fizik, gerçek DataStore, ağ, performans ölçülmedi.

## Bilinen riskler
- Silah/kostüm modelleri, açılar ve sandık konumları tahmini; denge bir model (gerçek veriyle ayarlanmalı).
- Çok oyunculu ağ/efekt yükü ölçülmedi (uzak efektler çizilmiyor).
- Ses kimlikleri çoğunlukla boş; animasyonlar prosedürel.
- Mağaza ürün kimlikleri 0: Developer Products oluşturulup `StoreData`'ya yazılmadan satış kapalı.

## Bekleyen elle testler (kullanıcı isteğiyle ertelendi)
`docs/SETUP.md` → "Elle test listesi" maddelerinin tamamı (1–16, 6b/6c, 10b–10h) oynanmadı.

## Sonraki adım (tek)
Kullanıcının yeni isteği; ertelenen Studio testleri (yukarıda) yapılınca Output hatalarını düzeltmek.
