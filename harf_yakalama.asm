; ============================================================
; HARF YAKALAMA OYUNU - 8086 Assembly (FASM / EMU8086)
; Ogrenci No: 170424051 | Ad: Hüseyin Ekiz
; Aciklama: Ekrandan dusen harfleri sepetle yakala,
;           gizli kelimeyi tamamla. A/D ile hareket et.
; ============================================================

ORG 100h

jmp start

; ==========================================
; DATA (VERI) BOLUMU
; ==========================================

; Her kelime tam 5 karakter. Dizi 20 byte.
word_pool   db 'ELMAS', 'SILGI', 'KITAP', 'KALEM'

basket_x    db 40        ; Sepetin baslangic yatay konumu (ekran ortasi)
target_word db 0,0,0,0,0 ; Rastgele secilen hedef kelime buraya kopyalanir
word_index  dw 0         ; Kelimede kac harf yakalandi (0-5)
target_char db 'Z'       ; Simdi yakalanmasi gereken harf
score       dw 0         ; Oyuncu skoru (dogru: +5, yanlis: -5)
game_state  db 0         ; 0=devam, 1=kazandi, 2=kaybetti

; --- 1. Harf (Letter 1) ---
l1_x        db 0         ; Yatay konum
l1_y        db 0         ; Dikey konum (satirlar, yukari=0)
l1_c        db 0         ; Gosterilen karakter
l1_a        db 0         ; Aktif mi? (1=evet, 0=hayir)

; --- 2. Harf (Letter 2) ---
l2_x        db 0
l2_y        db 0
l2_c        db 0
l2_a        db 0         ; Ikinci harf 1. harf belirli bir yere gelince dogup ayni karakter olmaz

; Gecikme degerleri - UpdateSpeed ile dinamik ayarlanir
delay_outer dw 50        ; Her 10 puanda azalir, minimum 10
delay_inner dw 1

seed        dw 0         ; Sahte rastgele sayi uretimi icin tohum (RNG)

; Kullanici arayuzu metin sabitleri
msg_title   db 'HARF YAKALAMA OYUNU', 13, 10
            db '-------------------', 13, 10
            db 'Gizli kelimenin harflerini yakala!', 13, 10
            db 'Her 10 puanda oyun hizlanir.', 13, 10
            db '0 Puanin altina dusersen oyun biter!', 13, 10
            db 'Hareket: A (Sol), D (Sag) - Cikis: ESC', 13, 10, 13, 10
            db 'Baslamak icin herhangi bir tusa basin...$'
msg_target  db 'HEDEF: $'
msg_word    db 'KELIME: $'
msg_score   db 'SKOR: $'
msg_win     db 'TEBRIKLER! KELIMEYI BULDUNUZ!$'
msg_lose    db 'KAYBETTINIZ! SKOR 0 ALTINA DUSTU.$'

; ==========================================
; KOD (CODE) BOLUMU
; ==========================================
start:
    call InitVideo      ; Metin moduna gec (80x25)
    call ShowIntro      ; Tanitim ekranini goster, tusa basin bekle
    call InitRNG        ; BIOS saat tikini tohum olarak al

    ; --- RASTGELE KELIME SECIMI ---
    ; word_pool'dan 0-3 arasinda rastgele bir indeks sec, 5 ile carp -> baslangic adresi
    call GetRandom8
    mov ah, 0
    mov bl, 4           ; 4 kelime var
    div bl              ; AH = bolumdeki kalan (0..3)
    mov al, 5
    mul ah              ; AX = indeks * 5 (her kelime 5 byte)
    lea si, word_pool
    add si, ax          ; SI -> secilen kelimenin ilk harfi
    lea di, target_word
    mov cx, 5
    rep movsb           ; 5 bayt kopyala: word_pool -> target_word

    ; Yakalanacak ilk harfi ayarla
    mov al, [target_word]
    mov [target_char], al
    mov ax, 0
    mov [word_index], ax

    call ClearScreen
    call DrawBorders    ; Sol (x=20) ve sag (x=60) sinir cizgileri

; ==========================================
; ANA OYUN DONGUSU
; ==========================================
main_loop:
    ; Oyun durumunu kontrol et
    mov al, [game_state]
    cmp al, 1
    je game_won         ; Tum harfler yakalandi
    cmp al, 2
    je game_lost        ; Skor 0 altina dustu

    call ClearPlayArea  ; Oyun alanini temizle (1-59 arasi satirlar)
    call DrawUI         ; Ust bilgi bandi: hedef harf, kelime, skor
    call DrawBasket     ; Sepeti ciz: \  _ /
    call DrawLetters    ; Aktif harfleri ekrana yaz

    call CheckInput     ; Klavye girisi (A/D/ESC)
    call UpdateLetters  ; Harfleri asagi hareket ettir, yakalama kontrol et
    call UpdateSpeed    ; Skora gore delay'i guncelle

    call DoDelay        ; Gecikme: oyun hizini belirler
    jmp main_loop

; --- Kazanma ekrani ---
game_won:
    call ClearScreen
    mov dl, 12
    mov dh, 12
    call SetCursor
    mov dx, offset msg_win
    mov ah, 09h
    int 21h
    jmp wait_esc

; --- Kaybetme ekrani ---
game_lost:
    call ClearScreen
    mov dl, 12
    mov dh, 12
    call SetCursor
    mov dx, offset msg_lose
    mov ah, 09h
    int 21h

; ESC'ye basilana kadar bekle, sonra programdan cik
wait_esc:
    mov ah, 00h
    int 16h             ; Tusun kodunu al (bekleme modunda)
    cmp al, 27          ; ESC = ASCII 27
    jne wait_esc
    int 20h             ; COM programini sonlandir

; ==========================================
; PROSEDURLER (ALT PROGRAMLAR)
; ==========================================

; BIOS ile metin modunu 03h (80x25, 16 renk) olarak ayarla
InitVideo:
    mov ah, 00h
    mov al, 03h
    int 10h
    ret

; Tum ekrani gri (07h) arka planla temizle
ClearScreen:
    mov ax, 0600h       ; AH=06 (scroll), AL=0 (tum alan)
    mov bh, 07h         ; Renk: gri uzerine siyah
    mov cx, 0000h       ; Sol ust kose: (0,0)
    mov dx, 184Fh       ; Sag alt kose: (24,79) -> 80x25
    int 10h
    ret

; Sadece oyun alanini temizle (sinir cizgileri ve UI korunur)
ClearPlayArea:
    mov ax, 0600h
    mov bh, 07h
    mov ch, 1           ; Satir 1'den
    mov cl, 21          ; Sutun 21'den (sol sinirin icerisi)
    mov dh, 24          ; Satir 24'e kadar
    mov dl, 59          ; Sutun 59'a kadar (sag sinirin icerisi)
    int 10h
    ret

; Tanitim metnini goster ve herhangi bir tusa basilmasini bekle
ShowIntro:
    call ClearScreen
    mov dl, 0
    mov dh, 0
    call SetCursor
    mov dx, offset msg_title
    mov ah, 09h
    int 21h
    mov ah, 00h
    int 16h             ; Herhangi bir tus: oyun baslangici
    ret

; Oyun alaninin sol (x=20) ve sag (x=60) sinirlarini '|' ile ciz
DrawBorders:
    mov cx, 23          ; 23 satir boyunca
    mov dh, 1           ; Satir 1'den baslat
db_loop:
    push cx
    mov dl, 20
    call SetCursor
    mov al, '|'
    call PrintChar
    mov dl, 60
    call SetCursor
    mov al, '|'
    call PrintChar
    pop cx
    inc dh
    loop db_loop
    ret

; Ust bilgi bandini guncelle:
; Satir 0: HEDEF harfi | Satir 1: KELIME durumu | Sag: SKOR
DrawUI:
    ; Hedef harfi goster
    mov dl, 2
    mov dh, 0
    call SetCursor
    mov dx, offset msg_target
    mov ah, 09h
    int 21h
    mov al, [target_char]
    call PrintChar

    ; Kelimeyi goster: yakalananlar gercek harf, kalanlar '?'
    mov dl, 2
    mov dh, 1
    call SetCursor
    mov dx, offset msg_word
    mov ah, 09h
    int 21h

    mov cx, 5
    mov bx, 0
print_word_loop:
    push cx
    mov cx, [word_index]
    cmp bx, cx
    jl pw_actual        ; bx < word_index: yakalanmis, gercek harfi yaz
    mov dl, '?'         ; Henuz yakalanmamis harf
    jmp pw_print
pw_actual:
    mov dl, [target_word + bx]
pw_print:
    mov ah, 02h
    int 21h
    mov dl, ' '         ; Harfler arasi bosluk
    mov ah, 02h
    int 21h
    inc bx
    pop cx
    loop print_word_loop

    ; Skoru sag uste yaz
    mov dl, 65
    mov dh, 0
    call SetCursor
    mov dx, offset msg_score
    mov ah, 09h
    int 21h
    call PrintScore
    ret

; Sepeti ciz: \_ / sekli basket_x konumunda satir 23'e
DrawBasket:
    mov dl, [basket_x]
    dec dl              ; Sol kol: x-1
    mov dh, 23
    call SetCursor
    mov al, '\'
    call PrintChar
    mov dl, [basket_x]  ; Taban: x
    mov dh, 23
    call SetCursor
    mov al, '_'
    call PrintChar
    mov dl, [basket_x]
    inc dl              ; Sag kol: x+1
    mov dh, 23
    call SetCursor
    mov al, '/'
    call PrintChar
    ret

; Aktif harfleri ekrana yaz (l1 ve l2 icin ayri kontrol)
DrawLetters:
    mov al, [l1_a]
    cmp al, 1
    jne dl_check2       ; l1 aktif degilse atla
    mov dl, [l1_x]
    mov dh, [l1_y]
    call SetCursor
    mov al, [l1_c]
    call PrintChar
dl_check2:
    mov al, [l2_a]
    cmp al, 1
    jne dl_end          ; l2 aktif degilse atla
    mov dl, [l2_x]
    mov dh, [l2_y]
    call SetCursor
    mov al, [l2_c]
    call PrintChar
dl_end:
    ret

; Klavye girisini isle (A=sol, D=sag, ESC=cikis)
; INT 16h/01h: tus var mi? ZF=0 ise var, oku
CheckInput:
ci_loop:
    mov ah, 01h
    int 16h             ; Tus var mi kontrol et (beklemez)
    jz ci_end           ; Tus yoksa cik
    mov ah, 00h
    int 16h             ; Tus kodunu oku
    cmp al, 27
    je ci_esc           ; ESC
    cmp al, 'a'
    je ci_left
    cmp al, 'A'
    je ci_left
    cmp ah, 4Bh         ; Sol ok tus scan kodu
    je ci_left
    cmp al, 'd'
    je ci_right
    cmp al, 'D'
    je ci_right
    cmp ah, 4Dh         ; Sag ok tus scan kodu
    je ci_right
    jmp ci_loop

ci_left:
    mov al, [basket_x]
    cmp al, 22          ; Sol sinir kontrolu (oyun alani x=21)
    jle ci_loop
    dec al
    mov [basket_x], al
    jmp ci_loop

ci_right:
    mov al, [basket_x]
    cmp al, 58          ; Sag sinir kontrolu (oyun alani x=59)
    jge ci_loop
    inc al
    mov [basket_x], al
    jmp ci_loop

ci_esc:
    int 20h             ; Programdan cik
ci_end:
    ret

; Harfleri guncelle: asagi hareket ettir, yakalama ve kayip kontrolu yap
UpdateLetters:
    ; --- HARF 1 ---
    mov al, [l1_a]
    cmp al, 1
    je up_move_l1
    call SpawnL1        ; l1 aktif degil, yeni uret
    jmp up_check_l2

up_move_l1:
    mov al, [l1_y]
    inc al              ; Bir satir asagi in
    mov [l1_y], al
    cmp al, 23          ; Sepet satirina ulasti mi?
    jne up_check_l1_miss

    ; Sepet hizasinda: x araligi kontrol et (basket_x-1 .. basket_x+1)
    mov al, [l1_x]
    mov bl, [basket_x]
    dec bl
    cmp al, bl
    jl l1_missed_at_23  ; Sepetin solunda kaldi
    mov bl, [basket_x]
    inc bl
    cmp al, bl
    jg l1_missed_at_23  ; Sepetin saginda kaldi

    ; Yakalandi! Dogru harf mi?
    mov al, [l1_c]
    mov bl, [target_char]
    cmp al, bl
    jne up_l1_wrong     ; Yanlis harf: -5 puan

    ; Dogru harf: +5 puan, sonraki harfe gec
    mov ax, [score]
    add ax, 5
    mov [score], ax
    mov bx, [word_index]
    inc bx
    mov [word_index], bx
    cmp bx, 5           ; Kelime tamamlandi mi?
    jge l1_trigger_win
    mov al, [target_word + bx]
    mov [target_char], al
    jmp up_l1_done

l1_trigger_win:
    mov al, 1
    mov [game_state], al
    jmp up_l1_done

up_l1_wrong:
    mov ax, [score]
    cmp ax, 5
    jl l1_trigger_lose  ; 5'ten az skor varsa 0 altina duser
    sub ax, 5
    mov [score], ax
    jmp up_l1_done

l1_trigger_lose:
    mov al, 2
    mov [game_state], al
    jmp up_l1_done

; Satir 23'te sepet ıskalandı: hedef harf kacırıldıysa -5 puan
l1_missed_at_23:
    mov al, [l1_c]
    mov bl, [target_char]
    cmp al, bl
    jne up_check_l1_miss  ; Hedef harf degilse ceza yok
    mov ax, [score]
    cmp ax, 5
    jl l1_trigger_lose
    sub ax, 5
    mov [score], ax
    jmp up_check_l1_miss

up_l1_done:
    mov al, 0
    mov [l1_a], al      ; l1'i deaktive et, yeniden uretilsin
    jmp up_check_l2

up_check_l1_miss:
    mov al, [l1_y]
    cmp al, 25          ; Ekran disina cikti mi?
    jl up_check_l2
    mov al, 0
    mov [l1_a], al      ; Ekrandan cikti, deaktive et

    ; --- HARF 2 ---
up_check_l2:
    mov al, [l2_a]
    cmp al, 1
    je up_move_l2
    mov al, [l1_y]
    cmp al, 6           ; l1 en az 6 satir inmeden l2 uretme (kalabalik onleme)
    jl up_end
    call SpawnL2
    jmp up_end

up_move_l2:
    mov al, [l2_y]
    inc al
    mov [l2_y], al
    cmp al, 23
    jne up_check_l2_miss

    mov al, [l2_x]
    mov bl, [basket_x]
    dec bl
    cmp al, bl
    jl l2_missed_at_23
    mov bl, [basket_x]
    inc bl
    cmp al, bl
    jg l2_missed_at_23

    mov al, [l2_c]
    mov bl, [target_char]
    cmp al, bl
    jne up_l2_wrong

    mov ax, [score]
    add ax, 5
    mov [score], ax
    mov bx, [word_index]
    inc bx
    mov [word_index], bx
    cmp bx, 5
    jge l2_trigger_win
    mov al, [target_word + bx]
    mov [target_char], al
    jmp up_l2_done

l2_trigger_win:
    mov al, 1
    mov [game_state], al
    jmp up_l2_done

up_l2_wrong:
    mov ax, [score]
    cmp ax, 5
    jl l2_trigger_lose
    sub ax, 5
    mov [score], ax
    jmp up_l2_done

l2_trigger_lose:
    mov al, 2
    mov [game_state], al
    jmp up_l2_done

l2_missed_at_23:
    mov al, [l2_c]
    mov bl, [target_char]
    cmp al, bl
    jne up_check_l2_miss
    mov ax, [score]
    cmp ax, 5
    jl l2_trigger_lose
    sub ax, 5
    mov [score], ax
    jmp up_check_l2_miss

up_l2_done:
    mov al, 0
    mov [l2_a], al
    jmp up_end

up_check_l2_miss:
    mov al, [l2_y]
    cmp al, 25
    jl up_end
    mov al, 0
    mov [l2_a], al

up_end:
    ret

; l1 icin rastgele x konumu ve karakter ata, y=1'den baslat
SpawnL1:
    call GetRandomX
    mov [l1_x], al
    call GetRandomChar
    mov [l1_c], al
    mov al, 1
    mov [l1_y], al      ; Ust sinirdan baslat
    mov [l1_a], al      ; Aktif et
    ret

; l2 icin spawn: l1 ile ayni karakter olmamasi icin dongu
SpawnL2:
    call GetRandomX
    mov [l2_x], al
spawnL2_recheck:
    call GetRandomChar
    mov [l2_c], al
    mov al, [l1_a]
    cmp al, 1
    jne spawnL2_ok      ; l1 aktif degilse karakter catismasi olamaz
    mov al, [l2_c]
    cmp al, [l1_c]
    je spawnL2_recheck  ; l1 ile ayni harf: yeniden dene
spawnL2_ok:
    mov al, 1
    mov [l2_y], al
    mov [l2_a], al
    ret

; Skora gore hiz guncelle: delay_outer = max(10, 50 - (skor/10)*10)
; Ornek: 0 puan->50, 10 puan->40, 40 puan->10 (minimum)
UpdateSpeed:
    mov ax, [score]
    mov bl, 10
    div bl              ; AL = skor/10, AH = kalan
    mov bl, 10
    mul bl              ; AX = (skor/10)*10
    mov bx, 50
    sub bx, ax          ; 50 - AX
    cmp bx, 10
    jge set_spd
    mov bx, 10          ; Alt sinir: 10
set_spd:
    mov [delay_outer], bx
    ret

; Skoru ekrana yaz: bolusme ile basamaklari ayir (onlu)
PrintScore:
    mov ax, [score]
    mov cx, 0
    mov bx, 10
ps_loop1:               ; Basamaklari tersten stack'e it
    mov dx, 0
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne ps_loop1
ps_loop2:               ; Stack'ten pop ederek dogru sirada yaz
    pop dx
    add dl, '0'
    mov ah, 02h
    int 21h
    loop ps_loop2
    ret

; Imleci (DL=sutun, DH=satir) konumlandir - BIOS INT 10h/02h
SetCursor:
    mov ah, 02h
    mov bh, 00h         ; Sayfa 0
    int 10h
    ret

; Tek karakter yaz (AL=karakter) - BIOS INT 10h/09h
; BL=renk (07h=beyaz uzerine siyah), CX=tekrar sayisi
PrintChar:
    mov ah, 09h
    mov bh, 00h
    mov bl, 07h
    mov cx, 1
    int 10h
    ret

; Ic ice dongu ile gecikme uygula (delay_outer * delay_inner NOP)
DoDelay:
    mov cx, [delay_outer]
dd_outer:
    push cx
    mov cx, [delay_inner]
dd_inner:
    nop                 ; Bos islem: sadece zaman harca
    loop dd_inner
    pop cx
    loop dd_outer
    ret

; BIOS saat tiki (INT 1Ah/00h) ile RNG tohumunu baslat
InitRNG:
    mov ah, 00h
    int 1Ah             ; DX:CX = sistem saati tikleri
    mov [seed], dx      ; Dusuk 16 bit tohum olarak kullan
    ret

; Lineer Kongruansiyel Uretec: seed = seed*25173 + 13849 (mod 65536)
; Sonuc AL'de degil, seed'de guncellenir -> cagiran AH'yi okur
GetRandom8:
    mov ax, [seed]
    mov cx, 25173
    mul cx
    add ax, 13849
    mov [seed], ax      ; Yeni tohum kaydet (tasmalar dikkate alinmaz)
    ret                 ; Cagiran prosedur seed'i okuyarak AL/AH elde eder

; 22-58 arasi rastgele sutun uret (oyun alani sinirlarinda)
GetRandomX:
    call GetRandom8
    mov ah, 0
    mov cl, 37          ; 37 farkli konum: 58-22+1
    div cl              ; AH = kalan (0..36)
    add ah, 22          ; 22 + 0..36 = 22..58
    mov al, ah
    ret

; %75 olasilikla rastgele A-Z harfi, %25 olasilikla hedef harf uret
; Bu sayede hedef harf ekranda daha sik gorulur
GetRandomChar:
    call GetRandom8
    cmp al, 75          ; AL <= 75: %29 olasilik -> hedef harf zorla
    jl grc_force_target
    mov ah, 0
    mov cl, 26          ; A-Z: 26 harf
    div cl              ; AH = 0..25
    add ah, 'A'         ; 'A' + 0..25 = 'A'..'Z'
    mov al, ah
    ret

grc_force_target:
    mov al, [target_char] ; Hedef harfi dogrudan ata
    ret
