# Durum

## Aşama: M0 — Kurulum (tamamlandı, Studio doğrulaması bekliyor)

## Tamamlananlar
- Rojo proje iskeleti: `default.project.json` (ServerScriptService ←
  src/server, ReplicatedStorage ← src/shared, StarterPlayerScripts ←
  src/client).
- Başlangıç scriptleri: `src/server/init.server.luau`,
  `src/client/init.client.luau` (her biri sadece bir `print` yapar),
  `src/shared/init.luau` (boş placeholder modül).
- `docs/MASTER_PLAN.md` (plan tek seferlik kaydedildi), `CLAUDE.md`,
  `.gitignore`.

## Doğrulanan testler
- `rojo build default.project.json -o test-build.rbxlx` bu ortamda
  (cargo ile kurulan Rojo 7.7.0) başarıyla çalıştı; çıktı dosyasında
  scriptlerin doğru servislere yerleştiği ve print satırlarının içerikte
  yer aldığı grep ile doğrulandı.
- Roblox Studio'da ÇALIŞTIRILMADI — bu bulut ortamında Studio veya GUI
  erişimi yok. "İstemci/sunucu hatasız çalışıyor" ölçütü kullanıcı
  tarafından yerel makinede doğrulanmalı.

## Kalan sorun / engel
- Kullanıcının Windows makinesinde Rojo CLI + Roblox Studio + Rojo Studio
  eklentisinin kurulu olup olmadığı bilinmiyor.

## Sonraki adım (tek)
Kullanıcı: Roblox Studio'da boş bir place açıp Rojo eklentisini
"Connect" ile bu repodaki `rojo serve`ye bağlasın, `src/server` ve
`src/client` scriptlerinin Output'ta print ettiğini doğrulasın, sonucu
bildirsin. Onaylanınca M1'e geçilecek.
