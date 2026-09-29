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
- Tüm kontroller: `lune run tests/all` (logic, api, scene, sim, place). Sunucu
  kodu değişince `tests/sim.luau` senaryosunu da güncelle. Kurulum/elle test:
  `docs/SETUP.md`.
- Saf modüller `if script then require(...) else require("./X")` ile hem Roblox'ta
  hem Lune'da çalışır. Metinler `Strings` (oyun içi her şey İngilizce; kullanıcıya
  raporlar Türkçe), silahlar `WeaponData`, denge `Balance`, dünya noktaları
  `WorldData`, görevler `QuestData` tablolarında.
- Kod: Luau (`.luau` uzantısı). Sunucu her zaman otorite: hasar, ödül,
  para, seviye, görev tamamlama, ekipman sahipliği sunucuda doğrulanır.
- Gereksiz refactor, alternatif mimari, gelecek özellik iskeleti üretme.
- Çalıştırmadığın testi geçmiş gibi gösterme; bu ortamda Roblox Studio
  yok — yalnızca yukarıdaki kontroller çalıştırılabilir.
- Yanıt biçimi: Yapılanlar / Test sonucu / Benden gereken / Sonraki adım.
