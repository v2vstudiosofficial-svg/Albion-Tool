V2V Studios için Roblox’ta çocukların da oynayabileceği bir RPG geliştireceğiz. Kıdemli Roblox/Luau geliştiricisi ve oyun tasarımcısı olarak bu planı uygula. Ben projeyi yöneteceğim; sen mevcut aşamayı çalışan, test edilebilir bir sonuca ulaştır. Türkçe iletişim kur, kod adlarını İngilizce yaz. Kısa ve somut ilerle.

1. OYUN FİKRİ

Çalışma adı: Işık Vadisi / Lantern Valley. İsim geçicidir; yayın öncesi uygunluğunu kontrol edeceğiz.

Renkli, sıcak, stilize bir fantastik dünyada oyuncu bir Işık Koruyucusu olur. Köyün sönen fenerlerini yeniden yakmak için ormana gider, büyülenmiş sevimli yaratıkları ışık asasıyla arındırır, görevleri tamamlar ve karakterini geliştirir. Arındırılan yaratıklar dost hâline gelip kaybolur; kan ve gerçekçi yaralanma bulunmaz.

Oyunun ayırt edici ödülü, görevlerle köyün görsel olarak canlanmasıdır. İlk sürümde bu, üç sabit dekorasyonun açılmasıdır; bina inşa sistemi değildir. Bu görseller oyuncunun kişisel ilerlemesine göre gösterilir, ortak haritanın çarpışmasını ve diğer oyuncuların erişimini değiştirmez.

Tasarım kitlesi yaklaşık 9–14 yaş ve rahat RPG seven diğer oyuncular. Bu, resmi yaş derecelendirmesi vaadi değildir. Mobil yatay ekran öncelikli, PC destekli; tek başına veya aynı sunucuda en fazla dört oyuncuyla oynanır. Oturum hedefi 10–15 dakika.

Ana döngü: kısa görev al → keşfet ve yaratıkları arındır → XP ve sikke kazan → asanı geliştir veya tılsım seç → köyde ilerlemeyi gör → sonraki göreve geç.

2. İLK SÜRÜMÜN KESİN KAPSAMI

- Tek Roblox place: küçük köy, bir orman rotası ve aynı haritadaki kısa harabe/boss alanı.
- Seviye 1–10; altı ana görev, üç normal düşman davranışı, iki okunabilir saldırısı olan bir boss.
- Tek silah: ışık asası. Normal saldırı ve seviye 3’te açılan bekleme süreli ışık dalgası. Mobilde hafif hedef yardımı; standart Roblox hareketi ve kamera.
- Asada üç yükseltme basamağı, üç tılsımdan birini takma; envanter yalnızca sahip olunan tılsımları ve asa seviyesini tutar.
- Tek kazanılabilir para birimi: sikke. Sikkeler asa yükseltmelerinde harcanır. XP seviye kazandırır; tılsımlar belirli görevlerden gelir. Ödüller ilk sürümde sabittir.
- Altı görevin akışı: ilk arındırma, işaretli kaynak toplama, keşif, ilk yükseltme, harabelere hazırlık, boss. Her görev yeni bir şey öğretir; uzun öldürme listeleri oluşturma.
- Sohbet veya parti kurma zorunluluğu olmadan yardımlaşma. Sunucunun doğruladığı aktif katılımcılar kendi ödülünü alır; son vuruş yarışı olmaz. Boss tek kişiyle de tamamlanabilir.
- Yenilince köyde yeniden doğma; eşya, sikke veya XP kaybı yok. İlk bölüm için yaklaşık 45–60 dakikalık içerik hedefle; süreyi testlerle ayarla.

MVP dışında: PvP, takas, lonca, pet yetiştirme, crafting, açık dünya, prosedürel harita, çoklu sınıf, ayrı zindan sunucuları, günlük giriş serileri ve battle pass. Bunlar için şimdiden altyapı yazma.

3. GÖRSEL VE OYUNCU DENEYİMİ

Yuvarlak formlar, canlı ama göz yormayan renkler, büyük dokunmatik butonlar, kısa NPC konuşmaları. Görev paneli tek aktif hedefi gösterir. Türkçe arayüzle başla; metinleri ayrı tabloda tut ki İngilizce sonradan eklenebilsin. Ekranı mağaza ve ödül pencereleriyle doldurma.

İlk 90 saniyede oyuncu hareket etmeli, ilk yaratığı arındırmalı ve ödülünü görmeli. İlk beş dakikada görev → ödül → yükseltme döngüsü anlaşılmalı. İlerlemek için uzun metin okumak gerekmemeli.

Önce basit Roblox parçalarıyla oynanabilir sahne oluştur; sonra görsel kaliteyi artır. Sadece kod dosyaları üretip haritayı boş bırakma. Sahne kurulum aracı yeniden çalışınca nesneleri çoğaltmamalı veya elle yapılan ilgisiz düzenlemeleri silmemeli.

Korku, kan, ücretli rastgele ödül, satın almaya zorlayan ekran ve özel mesaj sistemi tasarlama. MVP’de özel sohbet sistemi kurma; varsa Roblox’un yerleşik iletişim ve yaş ayarlarına uy. Gerçek kişi bilgisi isteme. Oyun ekonomisine bağlı ücretli özellikleri MVP’den sonra ele al; ilk seçenek sabit fiyatlı kozmetikler olsun.

4. TEKNİK TEMEL

Varsayılan ortam Windows + Roblox Studio + VS Code/Claude Code + Rojo; dil Luau. Mevcut çalışan bir proje veya eşitleme düzeni varsa onu koru. Rojo kullanılıyorsa eşitlenen kodun kaynağı yerel dosyalardır. Studio MCP mevcutsa sahne inceleme ve test için kullan; aynı kodu iki farklı yerde düzenleyip çakışma yaratma. MCP kurulumu ilk prototipi engellemesin.

Dosya düzeni: src/server, src/client, src/shared. Sunucu kodu ServerScriptService’e; istemci kodu StarterPlayerScripts’e; paylaşılan tanımlar ReplicatedStorage’a eşlensin. Hizmetleri ihtiyaç çıktıkça ekle. Büyük framework, web arayüzü, dış backend veya oyun içinde LLM API’si kullanma.

Hasar, hedef geçerliliği, ödül, para, seviye, görev tamamlama ve ekipman sahipliğini sunucu belirler. İstemci yalnızca aksiyon ister ve arayüz/efekt gösterir. Remote çağrılarında tür, değer sınırı, mesafe, görüş hattı, canlılık, bekleme süresi ve çağrı sıklığını uygun olan yerde doğrula. Aynı olaydan iki kez ödül verilmesini önle.

Başlangıçtan itibaren tek oyuncu profili arayüzü kullan: schemaVersion, XP, coins, staffUpgrade, ownedCharms, equippedCharm, questProgress, restorationFlags. M1’de bellekte çalışabilir; kalıcı kayıt M2’de eklenir. Denge değerlerini, görevleri ve eşyaları veri tablolarında tut.

Kayıtta DataStoreService, UpdateAsync, oturum kilidi, sınırlı geri deneme ve düzenli/çıkış/kapanış kaydı kullan. UpdateAsync tek başına oturum kilidi değildir. Veri okunamazsa mevcut kaydın üstüne boş profil yazma; kayıtlı ilerlemeyi koruyan bir hata akışı göster. Test verisini canlı veriden ayır. Güvenilir bir kayıt kütüphanesi gerekiyorsa bakım durumunu ve lisansını doğrula; sırf bağımlılıksız olmak için kırılgan bir kayıt sistemi icat etme.

Asset ID ve Roblox API’si uydurma. Belirsiz API’leri ihtiyaç oluştuğunda resmi dokümantasyondan doğrula. Harici modellerin lisansını ve içindeki scriptleri kontrol et. Her karede tüm dünyayı tarama; düşman ve efekt sayısını sınırla, oyuncu ayrılınca bağlantıları temizle.

5. AŞAMALAR VE BİTİŞ ÖLÇÜTLERİ

M0 — Kurulum: mevcut ortamı kontrol et; gereken eşitlemeyi, asgari klasörleri ve çalıştırma yönergesini hazırla. Bitiş: Studio’da istemci ve sunucu başlangıç kodu hatasız çalışıyor, yerel bir kod değişikliği oyuna ulaşıyor.

M1 — Oynanabilir beş dakika: küçük köy/orman sahnesi, NPC, tek görev, tek düşman, normal saldırı, XP/sikke ve basit HUD. Bitiş: oyuncu görevi alıp düşmanı arındırabiliyor ve ödülü yalnızca bir kez kazanıyor. İki istemcide temel davranışı kontrol et. Kalıcı kayıt henüz yoksa açıkça belirt.

M2 — RPG ve kayıt: seviye, ışık dalgası, asa yükseltmeleri, tılsımlar ve güvenli kalıcı profil. Bitiş: çıkıp girince ilerleme korunuyor; hızlı yeniden bağlantı, başarısız veri yükleme, yetersiz para ve yinelenen ödül istekleri veriyi bozmuyor.

M3 — İçerik ve birlikte oynama: altı görev, üç düşman türü, boss ve köyün üç görsel aşaması. Bitiş: görev zinciri tek kişiyle tamamlanıyor; dört istemciyle oynama, sonradan katılma/ayrılma ve kişisel ödüller çalışıyor.

M4 — Sunum ve performans: animasyon, ses, saldırı geri bildirimi, mobil arayüz ve denge. Bitiş: farklı ekranlarda butonlar çakışmıyor; belirlenen test cihazlarında mobil 30 FPS, PC 60 FPS hedefi ölçülüyor. Ölçüm cihazını ve koşullarını yaz; emülatörü gerçek telefon performans testi sayma.

M5 — Yayına hazırlık: önemli hataları kapat, özel test sürümünü ve mağaza metinlerini hazırla; güncel yayınlama ve çocuklara erişim koşullarını resmi kaynaklardan kontrol et. Maturity & Compliance yanıtları gerçek içeriğe dayanmalı; yaş etiketini önceden garanti etme. Bitiş: test sonuçları ve kalan engeller belli. Herkese açık yayınlama ve ücretli ürün etkinleştirme için ayrıca talimatımı bekle.

M6 — Otomatik savaş dönüşümü (kullanıcı isteği, XP Hero tarzı). Oyun içi tüm metinler İngilizce; kullanıcıya raporlar Türkçe.
- M6a: çapraz yukarıdan takip kamerası; menzil halkası ve sunucu tarafında otomatik saldırı; 8 silah türü (asa, yay, arbalet, fırlatma hançerleri, kılıç, balta, mızrak, savaş çekici), Weapons menüsünden seçilir; seviye sınırı 100, her yaratık XP verir; her 25 seviyede karakterin arkasında havada süzülen ek bir silah yuvası (en fazla 4); seviyeli, yeniden doğan yaratık sürüleri, üstlerinde seviye ve can çubuğu.
- M6b: süreli sandıklar (kullanıcı isteği): dünyadaki noktalardan kişisel sandık toplanır; sandık yuvası başta 1, seviyeyle en fazla 5; aynı anda tek sandık açılır; 4 tür (Tahta 2 dk, Gümüş 5 dk, Altın 10 dk, Mistik 20 dk); sandıktan sikke, nadirliğe göre silah (Common, Rare, Epic, Legendary; asa dışındaki silahlar yalnızca sandıktan) ve silah yuvası seviyesi (yuvaya takılan her silahı güçlendirir) çıkar. Ücretli açma yok.
- M6c: Işık Kristali ganimeti ve sınırlı fener kesesi, Büyük Fener'de sikkeye çevirme; çok seviyeli yükseltme paneli (Güç, Kese, Can, Can yenileme, Kritik); seviye atlayınca 3 karttan yetenek seçimi (sunucu doğrular).
- M6d: "Efsane Gölgeler" boss koleksiyonu, yeni zorlu bölgeler (seviye 100'e kadar içerik); mevcut 6 görev giriş bölümü olarak kalır.
Bitiş (her parça): `lune run tests/all` geçer, sim senaryoları yeni sunucu davranışını kapsar, Studio'da elle test listesi güncellenir.

M7 — Eğlence turu (kullanıcı isteği): büyük sayıların kısaltılması (K/M); nadir elit yaratıklar (güçlü, altın taçlı, sandık şansı); bölgelerde zaman zaman açılan 3 dalgalık Gölge Yarığı olayları (katılanlara ödül sandığı); doğu yaratıklarına özel saldırılar (çoklu atış, ışınlanma). Bitiş: `lune run tests/all` geçer, sim yeni sunucu davranışlarını kapsar.

M8 — Kalite ve bağlılık (kullanıcı isteği): kod/mantık hatalarının taranıp düzeltilmesi, sunucu ve istemci performansı, Macera Günlüğü (kademeli başarımlar, alınabilir ödüller) ve takım bonusu (yakındaki oyuncularla daha çok XP/kristal). Baskı kuran mekanikler (günlük seri, ücretli hızlandırma) yok.

6. TOKEN VE ÇALIŞMA KURALLARI

- Bu planı MASTER_PLAN.md’ye bir kez kaydet; her mesajda yeniden yazma ve yeniden tasarlama.
- CLAUDE.md en fazla 60 satır: temel kurallar ve gerekli dosyalara yönlendirmeler. Master planın tamamını otomatik yüklenen dosyaya kopyalama.
- STATUS.md en fazla 40 satır: mevcut aşama, tamamlananlar, doğrulanan testler, kalan sorun ve tek sonraki adım. Her aşama sonunda güncelle.
- Her tur yalnızca mevcut aşamayı veya onun sınırlı alt görevini tamamla. Gelecek aşamaların kodunu önceden üretme. Aynı görev içinde rutin teknik kararlar için tekrar tekrar onay isteme.
- Önce hedefli aramayla ilgili dosyaları bul; tüm depoyu, geçmişi veya büyük logları tekrar okuma. Yalnızca gerekli hata satırlarını getir.
- Dosya erişimin varsa doğrudan düzenle; değiştirdiğin dosyaların tamamını sohbete tekrar basma. Normal sohbet kullanıyorsak sadece gereken dosyanın eksiksiz kodunu, yolunu ve Studio nesne türünü ver.
- Gereksiz refactor, alternatif mimari listeleri, gelecek özellik iskeletleri ve otomatik paralel ajan ekipleri oluşturma. Uzun düşünme modunu her küçük işte isteme.
- Riskli davranışları doğrula: kayıt, ödül tekrarı, istemci doğrulaması, çok oyunculu durumlar. Basit renk/metin değişikliği için geniş test paketi yazma. Çalıştırmadığın testi geçmiş gibi gösterme.
- Aynı hatada iki başarısız düzeltmeden sonra rastgele yeniden yazma; eksik logu veya yeniden üretim adımını belirle. Gerekiyorsa yalnızca bu sorun için daha güçlü model öner.
- Yanıt biçimi: Yapılanlar / Test sonucu / Benden gereken / Sonraki adım. Kod hariç normalde 150 kelimeyi geçme; gerekli ilk kurulum yönergesini sırf bu sınıra uymak için eksik bırakma.
- Yeni oturumda önce CLAUDE.md, STATUS.md ve yalnızca mevcut aşamanın planını oku; tüm projeyi yeniden analiz etme.

7. ŞİMDİ BAŞLA

Bu tur yalnızca M0’ı uygula. Erişebildiğin ortamı ve mevcut projeyi kontrol et, sonra en küçük çalışan kurulumu oluştur. Bilgisayarıma veya Studio’ya erişimin yoksa bunu açıkça söyle; kurulum durumunu öğrenmek için yalnızca ilerlemeyi engelleyen soruları tek mesajda sor ve uygulanabilir adımları ver. Erişmediğin yerde dosya oluşturmuş veya test yapmış gibi konuşma.

Master planı tekrar anlatma. Bu turda bütün oyunun kodunu üretme. M0 sonucunu ve M1’e geçmek için gereken tek sonraki adımı sun.
