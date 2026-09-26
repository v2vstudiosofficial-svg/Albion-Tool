# Durum

## Aşama: M1 — Oynanabilir beş dakika (kod hazır, Studio doğrulaması bekliyor)

## Tamamlananlar
- M0 düzeltmesi: Rojo eşlemesi servisleri script'e dönüştürüyordu; artık
  `ReplicatedStorage.Shared`, `ServerScriptService.Server`,
  `StarterPlayerScripts.Client` + `ReplicatedStorage.Remotes` (3 RemoteEvent).
- İdempotent sahne kurucu (`MapBuilder`): köy (4 ev, meydan, sönük fener,
  spawn), NPC Bilge Nur, orman patikası, 45 ağaç, açıklık, 3 düşman noktası.
- Tek görev (`first_purify`), tek düşman (Gölgecik: takip, temas hasarı,
  arınma efekti, 10 sn'de yeniden doğma), ışık asası normal saldırısı
  (istemci hedef yardımı; sunucu tür/bekleme/menzil/görüş hattı/canlılık
  doğrular), XP/sikke, HUD (istatistik, tek hedef paneli, ödül bildirimi, NPC
  konuşması). Metinler `Strings`, denge `Balance`, görev `QuestData` tablosunda.
- Katılım ödülü: son 30 sn içinde vuran ve oyunda olan herkes kendi ödülünü alır.
- Kalıcı kayıt YOK (bilerek; M2). Profil bellekte, plan şemasıyla.

## Doğrulanan testler (bu bulut ortamında çalıştırıldı)
- `lune run tests/logic`: 9/9 geçti (görev bir kez başlar/biter, düşman bir
  kez arınır, 2 oyuncu co-op ödülü, geçersiz ödül reddi, veri/metin tutarlılığı).
  Enjekte edilen ödül tekrarı hatasıyla 3 testin düştüğü de doğrulandı.
- `tests/place`: 17 dosya Luau derlemesi + Rojo çıktısı yapı kontrolü geçti.
- Roblox Studio'da ÇALIŞTIRILMADI: hareket, NPC, düşman AI, saldırı, HUD ve
  iki istemci testi kullanıcı tarafında `docs/SETUP.md` listesiyle yapılmalı.

## Bilinen riskler
- Roblox API tip denetimi yapılamadı (luau-lsp indirmesi ağda engelli).
- Küçük telefonlarda HUD/konuşma paneli yerleşimi M4'te ölçülecek.
- M0 Studio testi de henüz kullanıcı tarafından onaylanmadı.

## Sonraki adım (tek)
Kullanıcı `docs/SETUP.md` → "M1 elle test listesi"ni Studio'da uygulayıp
Output'taki hata satırlarını (varsa) iletsin; temizse M2'ye geçilir.
