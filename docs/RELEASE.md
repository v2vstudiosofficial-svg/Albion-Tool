# Yayına Hazırlık Notları (M5 taslağı)

Herkese açık yayın ve ücretli ürün etkinleştirme **kullanıcı talimatı olmadan yapılmaz**.
Buradaki metinler taslaktır; yayın öncesi güncel Roblox kuralları resmi kaynaklardan kontrol edilmeli.

## İsim
Çalışma adı "Işık Vadisi / Lantern Valley". Yayından önce Roblox'ta ve mağazalarda aynı/benzer
isimli deneyim ve marka olup olmadığı kontrol edilmeli; gerekirse değiştirilmeli.

## Mağaza metni (taslak)
**TR:** Işık Vadisi'nin fenerleri söndü! Işık Koruyucusu ol, ışık asanla büyülenmiş sevimli
yaratıkları arındır ve onları yeniden dost yap. Fener çiçekleri topla, ormanın gizemli yerlerini
keşfet, asanı güçlendir ve harabelerdeki Gölge Bekçisi'ni yen. Görevleri bitirdikçe köyün
yeniden canlandığını gör. Tek başına ya da en fazla 4 arkadaşınla oyna!

**EN:** The lanterns of Lantern Valley have gone dark! Become a Light Keeper, use your light staff
to free enchanted, cute creatures and turn them back into friends. Gather lantern flowers, explore
mysterious places, upgrade your staff and face the Shadow Warden in the ruins. Watch the village
come back to life as you finish quests. Play solo or with up to 4 friends!

## İçerik gerçekleri (Maturity & Compliance yanıtları bunlara dayanmalı)
- Şiddet: stilize fantastik çatışma; oyuncu ışık oku/dalgasıyla yaratıklara vurur, yaratıklar
  oyuncuya temas/küre ile hasar verir. Kan, yara, parçalanma, ölüm animasyonu yok; yaratıklar
  "dost olup" kaybolur; oyuncu yenilince parçalanmadan köyde yeniden doğar, hiçbir şey kaybetmez.
- Korku: yok (renkli, gündüz, sevimli tasarımlar).
- Sohbet: özel sohbet sistemi yok; yalnızca Roblox'un yerleşik iletişimi ve yaş ayarları.
- Kişisel bilgi: istenmiyor.
- Satın alma: yok (Robux ürünü, ücretli rastgele ödül, reklam yok).
- Kullanıcı içeriği: yok.
Yaş etiketi önceden garanti edilmez; anket yanıtları yayın anındaki gerçek içerikle doldurulur.

## Özel test sürümü planı
1. Studio → File → Publish to Roblox (özel/erişim kısıtlı). Game Settings → Security →
   "Enable Studio Access to API Services" yalnızca test için.
2. Max Players = 4. Test kişileri deneyime davetle eklenir.
3. Cihaz matrisi (ölçüm koşullarıyla birlikte not edilecek): en az bir düşük/orta Android telefon,
   bir iPhone, bir PC. Ayarlar → Performans göstergesi ile FPS/ping; hedef mobil 30, PC 60 FPS.
   Emülatör ölçümleri gerçek telefon sonucu sayılmaz.
4. Senaryolar: `docs/SETUP.md` elle test listesi; ayrıca 4 kişilik boss, sonradan katılma,
   oyundan çıkıp girme ve iki cihazdan aynı hesapla hızlı giriş.
5. Bulunan hatalar önem sırasıyla kapatılır; kalan engeller STATUS.md'ye yazılır.

## Yayın öncesi kontrol listesi (talimat bekler)
- [ ] İsim ve simge uygunluğu
- [ ] Sesler: Creator Store'dan lisansı uygun kimlikler (`src/shared/Sounds.luau`)
- [ ] Maturity & Compliance anketi gerçek içerikle
- [ ] Oyun açıklaması, küçük resim ve ekran görüntüleri
- [ ] Canlı DataStore adı (`LanternValley_Live_v1`) ve kayıt testi
- [ ] Herkese açık yayın onayı (kullanıcıdan)
