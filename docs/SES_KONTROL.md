# Ses kontrol listesi

M61–M72 arasında eklenen sesleri Studio'da hızlıca dinlemek için. Her sesin seviyesi
`src/shared/Sounds.luau` içindeki `volume` sayısıdır (0–1); beğenmediğini söylemen yeterli.

Hazırlık: Studio'da **Play**, giriş sahnesinde **Skip**. Komutlar Studio'nun alttaki komut
çubuğuna yazılır; "Sunucu" yazanlar üstteki **Sunucu** sekmesindeyken, "İstemci" yazanlar
**İstemci** sekmesindeyken çalıştırılır. Ses ayarları açık olmalı (Settings > Audio).

Kısaltma (her komutun başına eklenebilir):

```lua
local p = game.Players:GetPlayers()[1]
```

## 1. Bataklık yağmuru ve gök gürültüsü
- Ses: yağmur `rain` (0.35), gök gürültüsü `thunder` (0.55).
- Yağmur her 9 dakikanın ilk 3 dakikası. Ne zaman olduğunu görmek için (Sunucu):
  `local t = workspace:GetServerTimeNow() % 540 print(t < 180 and "yağıyor" or ("yağmura " .. math.floor(540 - t) .. " sn"))`
- Bataklığa git (Sunucu): `p.Character:PivotTo(CFrame.new(130, 4, 0))`
- Dinle: suyun üstüne düşen yağmur; yağmur tam yoğunken 17 sn'de bir şimşek ve ~1,5 sn sonra gürleme.
- Bak: bataklıktan çıkınca yağmur 1,5 sn'de sönmeli.

## 2. Zirvelerde kar fırtınası
- Ses: rüzgâr `wind` (0.4).
- Fırtına, yağmurdan 4,5 dakika sonra başlar (Sunucu):
  `local t = (workspace:GetServerTimeNow() + 270) % 540 print(t < 180 and "fırtına" or ("fırtınaya " .. math.floor(540 - t) .. " sn"))`
- Zirvelere git (Sunucu): `workspace:SetAttribute("LvDebugAllWeapons", true) workspace:SetAttribute("LvDebugLevel", 80) task.wait(1) p.Character:PivotTo(CFrame.new(160, 4, -76))`
- Dinle: ıslıklı rüzgâr; kar yoğunlaşıp yana savrulmalı.

## 3. Köyde kuşlar ve cırcır böcekleri
- Ses: `birds` (0.22) gündüz, `crickets` (0.18) gece.
- Köyde dur. Gündüzse kuşlar duyulur; geceyi beklemek yerine Settings > Graphics > Day & night'ı
  kapatıp açarak farkı duyabilirsin (kapalıyken hep öğleden sonradır = kuşlar).
- Bak: müziğin altında kalmalı, onu bastırmamalı.

## 4. Gölette kurbağalar
- Ses: `frogs` (0.3).
- Glow Pond'a git (Sunucu): `p.Character:PivotTo(CFrame.new(64, 4, -120))`
- Dinle: yaklaştıkça vıraklama yükselir, 60 stud ötede duyulmaz. Suda halkalar da görünür.

## 5. Düşük canda kalp atışı
- Ses: `heartbeat` (0.35). **En önemli kontrol:** APM'nin korku albümünden geliyor; arkasında
  ürkütücü uğultu varsa değiştireceğim.
- Ormanda (köyde can hızla dolar) canı düşür (Sunucu):
  `p.Character:PivotTo(CFrame.new(0, 4, -100)) task.wait(1) p.Character.Humanoid.Health = p.Character.Humanoid.MaxHealth * 0.2`
- Dinle: kırmızı kenarlarla birlikte kalp atışı; iyileşince söner.

## 6. Hikâye konuşma sesleri
- Ses: `voice` (0.22), her konuşanın kendi tonu (StoryData `voice`).
- Bir sahne oynat (Sunucu): `workspace:SetAttribute("LvDebugScene", "first_purify")`
- Dinle: Elder Nora konuşurken minik "pop"lar; anlatıcı sessiz. Tatlı mı, rahatsız edici mi?

## 7. Ses ayarında örnek ses
- Settings > Audio > Sound effects'te `-` veya `+`: kaydedilince yeni seviyede bir örnek çalar.

## 8. Silah değişimi ve boss yenilgisi
- Silah: Weapons menüsünden başka bir silah kuşan; elde parlama ve çan sesi (`purify`, tonu yüksek).
- Boss anı (Sunucu):
  `game.ReplicatedStorage.Remotes.Fx:FireClient(p, "purify", p.Character.HumanoidRootPart.Position + Vector3.new(0, 0, -12), "Warden", Vector3.new(0, 0, 1))`
  Dünya bir an griye döner, renk geri gelir ve şerit çıkar.
