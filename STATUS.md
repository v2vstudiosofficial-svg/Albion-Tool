# Durum

## Aşama: M5 yayına hazırlık (M2–M4 kodu yazıldı; Studio testi bekliyor)

## Tamamlananlar
- M2: Seviye 1–10, Işık Dalgası (Sv3), 3 kademeli asa yükseltmesi, 3 tılsım + çanta;
  ProfileStore ile kalıcı profil (oturum kilidi, periyodik/çıkış/kapanış kaydı, Studio
  ayrı depo, yükleme hatasında ilerlemeyi koruyan "Tekrar Dene" ekranı, veri temizleme).
- M3: 6 görevlik zincir (arındırma, çiçek toplama, keşif, yükseltme, sarmaşık, boss),
  3 düşman davranışı (kovalayan, uzaktan atan, uyarılı hücum), iki saldırılı boss
  (uyarı halkaları + boşluklu küre halkası, %50'de 2. evre, oyuncu sayısına göre can),
  köyün 3 kişisel canlanma aşaması, katılımcı başına ödül, kişisel sarmaşık engeli.
- M4: istemci efektleri (ışık oku, isabet sayıları, dostlaşma, dalga halkası, mermiler,
  seviye/görev afişleri, kamera sarsıntısı), NPC ünlemleri, hedef işaretçisi, bekleme
  göstergeli yetenek tuşları, ekran boyutuna göre ölçeklenen HUD, FPS/ping göstergesi,
  bölge bazlı düşman uykusu, istemcide çizilen mermiler, sıcak ışıklandırma.
- M5 (başladı): İngilizce dil desteği (oyuncunun Roblox diline göre; Türkçe dışı → İngilizce),
  NPC isimleri/istemleri ve atılma mesajı da yerelleşir. luau-lsp tip taraması: gerçek hata yok.

## Doğrulanan testler (bu bulut ortamında çalıştırıldı: `lune run tests/all`)
- logic 24, api ~1170 referans, scene 10, sim 24, client 20 (masaüstü, Türkçe) + 21
  (dokunmatik, İngilizce) + 21 (CAS yedeği) + 1 (geri dönen oyuncu), place 42 dosya; hepsi geçti.
- Kod inceleme: 39 bulgu düzeltildi, kritik olanlar testlerle (mutasyonla) sabitlendi.
- sim: gerçek sunucu kodu + ProfileStore mock ile 6 görev, co-op ödülü, boss saldırıları,
  geçersiz istekler, çık-gir ve hızlı yeniden bağlanmada veri korunumu. Enjekte edilen
  çift ödül ve menzil hatalarını yakaladığı doğrulandı.
- client: gerçek istemci modülleri sahte oyuncu/olaylarla (çizim yok). Roblox Studio'da HİÇ
  ÇALIŞTIRILMADI: görsel yerleşim, fizik, gerçek DataStore, ağ ve performans ölçülmedi.

## Bilinen riskler
- Tip denetimi (luau-lsp) yok; simülasyonların taklit ettiği motor davranışları
  (fizik, raycast, tween, giriş) Studio'da farklı sonuç verebilir.
- Ses kimlikleri çoğunlukla boş; müzik yok. Animasyonlar prosedürel (asset yok).
- Denge (`lune run tests/playtime` botu): zincir 3,3 bot-dk, Sv6'da biter, boss'ta
  1 yenilgi; Sv10 (≈1640 XP) ve asa kademe 3 hikâye sonrası hedef. Çocuk için tahmin
  ~15 dk hikâye + ~20–30 dk hedefler; gerçek oyun testleriyle doğrulanmalı.
- Yayın hazırlığı taslağı `docs/RELEASE.md`; herkese açık yayın talimat bekler.

## Sonraki adım (tek)
Kullanıcı `docs/SETUP.md` "Elle test listesi"ni Studio'da oynayıp Output hatalarını iletsin.
