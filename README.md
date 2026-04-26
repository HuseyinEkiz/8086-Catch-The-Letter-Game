# 🎮 Harf Yakalama Oyunu — 8086 Assembly

Ekranın üstünden düşen harfleri sepetle yakala, gizli kelimeyi tamamla!  
8086 Assembly (COM formatı) ile geliştirilmiş, BIOS ve DOS kesmelerini kullanan gerçek zamanlı konsol oyunu.

---

## 📽️ Oynanış

```
HEDEF: E                    SKOR: 15
KELIME: E ? ? ? ?

     |                   |
     |        K          |
     |    E              |
     |                   |
     |       \_ /        |
```

Ekrandan düşen harfleri `\_ /` şeklindeki sepetle yakala.  
**Hedef harf**i yakalarsan +5 puan kazanırsın, yanlış harfi yakalar ya da hedef harfi ıskalarsan −5 puan kaybedersin.  
5 harfi sırayla tamamlarsan **kazanırsın**; skor 0'ın altına düşerse **kaybedersin**.

---

## 🕹️ Kontroller

| Tuş | Eylem |
|-----|-------|
| `A` / `←` | Sepeti sola hareket ettir |
| `D` / `→` | Sepeti sağa hareket ettir |
| `ESC` | Oyundan çık |

---

## ✨ Özellikler

- **Dinamik hız:** Her 10 puanda oyun hızlanır (`delay_outer` = max(10, 50 − skor÷10×10))
- **2 eş zamanlı harf:** Ekranda aynı anda en fazla 2 harf düşer
- **Ağırlıklı harf üretimi:** Hedef harf ~%29 olasılıkla seçilir; oyun oynanabilir kalır
- **Rastgele kelime seçimi:** ELMAS, SİLGİ, KİTAP, KALEM arasından rastgele seçilir
- **Lineer Kongrüansiyel RNG:** `seed = (seed × 25173 + 13849) mod 65536`
- **BIOS tabanlı:** Harici kütüphane gerektirmez

---

## 🗂️ Dosya Yapısı

```
harf-yakalama-oyunu/
├── harf_yakalama.asm   # Açıklamalı kaynak kod (8086 Assembly)
├── rapor.docx          # Proje raporu
├── sunum.pptx          # Proje sunumu
└── README.md           # Bu dosya
```

---

## 🚀 Nasıl Çalıştırılır?

### emu8086 ile (Önerilen)
1. [emu8086](https://emu8086-microprocessor-emulator.en.softonic.com/) programını indir ve kur.
2. `harf_yakalama.asm` dosyasını emu8086 ile aç.
3. **Compile** → **Run** ile çalıştır.

### DOSBox ile
```bash
# DOSBox içinde
NASM -f bin harf_yakalama.asm -o oyun.com
oyun.com
```

### NASM + DOSBox (Linux/macOS)
```bash
nasm -f bin harf_yakalama.asm -o oyun.com
dosbox oyun.com
```

---

## 🔧 Teknik Detaylar

### Kullanılan BIOS / DOS Kesmeleri

| Kesme | İşlev |
|-------|-------|
| `INT 10h / AH=00h` | Video modunu ayarla (03h: 80×25 metin) |
| `INT 10h / AH=02h` | İmleci konumlandır |
| `INT 10h / AH=06h` | Ekran alanını temizle |
| `INT 10h / AH=09h` | Renkli karakter yaz |
| `INT 16h / AH=01h` | Tuş var mı kontrol et (beklemez) |
| `INT 16h / AH=00h` | Klavyeden karakter oku |
| `INT 1Ah / AH=00h` | Sistem saatini oku (RNG tohumu) |
| `INT 21h / AH=09h` | DOS: '$' sonlandırıcılı string yaz |
| `INT 20h` | COM programını sonlandır |

### Oyun Alanı Koordinatları
- **Yatay sınırlar:** x = 21 (sol) — x = 59 (sağ)
- **Sepet satırı:** y = 23
- **Sepet genişliği:** 3 karakter (`\` `_` `/`)
- **Yakalama aralığı:** `basket_x − 1 ≤ letter_x ≤ basket_x + 1`

### Puan Sistemi

| Durum | Puan |
|-------|------|
| Doğru harf yakalandı | +5 |
| Yanlış harf yakalandı | −5 |
| Hedef harf ıskalandı | −5 |
| Hedef dışı harf ıskalandı | ±0 |

---

## 👤 Geliştirici

**Hüseyin Ekiz** — 170424051  
Bilgisayar Mimarisi & Assembly Programlama Dersi, Nisan 2025

---

## 📄 Lisans

Bu proje eğitim amaçlı geliştirilmiştir.
