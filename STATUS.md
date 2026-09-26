# Durum

## Aşama: M2–M4 kodu yazıldı (kullanıcı isteğiyle hızlı geliştirme; Studio testi bekliyor)

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

## Doğrulanan testler (bu bulut ortamında çalıştırıldı)
- `tests/logic`: 22/22 (tam görev zinciri, ödül tekrarı, co-op, veri temizleme,
  yükseltme/tılsım kuralları, veri ve metin anahtarı tutarlılığı).
- `tests/api`: ~1090 Roblox sınıf/özellik/enum referansı yansıma DB'sine karşı temiz;
  denetleyicinin enjekte edilen hatalı adları yakaladığı doğrulandı.
- `tests/place`: 34 dosya derleniyor, Rojo çıktısı doğru servislerde.
- Roblox Studio'da HİÇ ÇALIŞTIRILMADI: oynanış, AI, UI yerleşimi, kayıt, çok oyunculu
  davranış ve performans ölçülmedi.

## Bilinen riskler
- Tip denetimi (luau-lsp) yok; çalışma zamanı hataları Studio'da çıkabilir.
- Ses kimlikleri çoğunlukla boş; müzik yok. Animasyonlar prosedürel (asset yok).
- Denge değerleri tahmini; 45–60 dk hedefi oynanarak ayarlanmalı.

## Sonraki adım (tek)
Kullanıcı `docs/SETUP.md` "Elle test listesi"ni Studio'da oynayıp Output hatalarını iletsin.
