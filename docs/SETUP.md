# Kurulum ve Test (Windows)

## Bir kerelik kurulum
1. Roblox Studio'yu kur ve giriş yap.
2. Rojo 7.x kur (https://rojo.space/docs — Aftman/Rokit veya VS Code "Rojo" eklentisi).
3. Studio'da Rojo eklentisini kur (`rojo plugin install` ya da Creator Store'dan resmi "Rojo").
4. Repoyu klonla: `git clone https://github.com/v2vstudiosofficial-svg/LanternValley`

## Her çalışmada
```
rojo build default.project.json -o LanternValley.rbxlx   # ilk sefer
rojo serve
```
- Studio'da `LanternValley.rbxlx` dosyasını aç (Baseplate şablonu kullanma; zemin çakışır).
- Plugins → Rojo → **Connect**. Yerel `.luau` değişiklikleri anında Studio'ya gelir.
- Haritayı düzenleme modunda görmek için Studio Command Bar'da bir kez:
  `require(game.ServerScriptService.Server.MapBuilder).build()`
  (Tekrar çalıştırmak çoğaltmaz, elle eklenen/değiştirilen parçaları silmez.)

## M1 elle test listesi
1. **Play**: Output'ta `[LanternValley] Server started` ve `Client started`, kırmızı hata yok.
2. Bilge Nur'a yaklaş → **E** (mobilde dokun) → görev paneli "Gölgeciği arındır: 0/1".
3. Patikayı takip et, Gölgecik'e sol tık / **F** / mobilde "Işık" butonu → 2 vuruşta arınır.
4. Ekranda "+10 XP +5 Sikke" ve "Görev tamamlandı! +50 XP +20 Sikke"; HUD: XP 60, Sikke 25.
5. 10 sn sonra yeni Gölgecik doğar; onu arındırmak yalnızca +10/+5 verir, görev ödülü tekrar gelmez.
6. Bilge Nur ile tekrar konuş → "Yakında yeni görevler". Görev yeniden başlamaz.
7. Gölgecik'e temas edip yenil → köyde yeniden doğ, XP/Sikke korunur.
8. **Test → Clients and Servers → 2 Players**: iki oyuncu aynı Gölgecik'e vurunca ikisi de
   kendi ödülünü alır; sadece izleyen oyuncu almaz.

Not: M1'de kalıcı kayıt yok; oyundan çıkınca ilerleme sıfırlanır (M2'de eklenecek).

## Otomatik kontroller (Roblox gerektirmez; Lune 0.10 + Rojo 7.x)
```
lune run tests/logic
rojo build default.project.json -o build/test.rbxlx && lune run tests/place build/test.rbxlx
```
