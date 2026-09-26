# Lantern Valley — Çalışma Kuralları

- Master plan: `docs/MASTER_PLAN.md`. Güncel durum: `STATUS.md`.
- Her oturumda önce bu dosyayı, `STATUS.md`'yi ve yalnızca mevcut aşamanın
  plan bölümünü oku. Tüm projeyi yeniden analiz etme.
- Bu turda yalnızca mevcut aşamayı (STATUS.md'de yazan) uygula. Gelecek
  aşamaların kodunu önceden üretme.
- Dosya düzeni: `src/server` → ServerScriptService.Server (Script),
  `src/client` → StarterPlayerScripts.Client (LocalScript), `src/shared` →
  ReplicatedStorage.Shared; RemoteEvent'ler `default.project.json` içinde.
- Saf mantığı (Roblox API'siz) ayrı modülde tut ve `tests/logic.luau`'ya test ekle.
- Kontroller: `lune run tests/logic` ve `rojo build default.project.json -o
  build/test.rbxlx && lune run tests/place build/test.rbxlx`. Kurulum/elle
  test: `docs/SETUP.md`.
- Kod: Luau (`.luau` uzantısı). Sunucu her zaman otorite: hasar, ödül,
  para, seviye, görev tamamlama, ekipman sahipliği sunucuda doğrulanır.
- Gereksiz refactor, alternatif mimari, gelecek özellik iskeleti üretme.
- Çalıştırmadığın testi geçmiş gibi gösterme; bu ortamda Roblox Studio
  yok — yalnızca yukarıdaki kontroller çalıştırılabilir.
- Yanıt biçimi: Yapılanlar / Test sonucu / Benden gereken / Sonraki adım.
