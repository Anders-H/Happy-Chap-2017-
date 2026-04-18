FUNGERAR MEN MAX 255 tecken.

; ------------------------------------------------------------------------------
; Happy Chap, music written on the C64 in 2017 by Anders Hesselbom.
; This code (2026) plays the song and displays a scrolltext.
; Compile using CBM Prg Studio.
; ------------------------------------------------------------------------------

; Start address for the BASIC stub (SYS 2064)
* = $0801

        BYTE $0B,$08,$0A,$00
        BYTE $9E,$32,$30,$36
        BYTE $34,$00,$00,$00

; Constants
SCRBASE  = $0400                ; Skärm-RAM
COLBASE  = $D800                ; Färg-RAM
VICBGC   = $D021                ; Bakgrundsfärg
VICCOL   = $D020                ; Kantfärg
VICRAST  = $D012                ; Rasterlinje
VICCTRL1 = $D011                ; VIC kontrollregister 1
VICCTRL2 = $D016                ; VIC kontrollregister 2 (x-scroll)
IRQVEC   = $0314                ; Avbrottsvektor (kernal)
CIA1ICR  = $DC0D                ; CIA1 avbrottsmask
VICIRQ   = $D019                ; VIC avbrottsregister
VICIRQM  = $D01A                ; VIC avbrottsmask
SID_INIT = $8000                ; SID init-adress
SID_PLAY = $8003                ; SID play-adress
SCROLL_ROW = 12                 ; Textrad för scrolltext (0-24)
SCROLL_SCR = SCRBASE + (SCROLL_ROW * 40)
SCROLL_COL = COLBASE + (SCROLL_ROW * 40)
; Rasterlinje för IRQ2:
; Varje textrad är 8 pixlar hög.
; Rad 12 börjar på rasterlinje 12*8 + 50 = 146
; Vi lägger IRQ2 på linje 146 + 8 = 154, dvs precis efter rad 12
IRQ1_LINE = 100                 ; Linje för IRQ1 (före scroll-raden)
IRQ2_LINE = 154                 ; Linje för IRQ2 (efter scroll-raden)
SCROLL_COLOR = 7                ; Scrolltextens färg (7 = gul)
BG_COLOR     = 0                ; Bakgrundsfärg (0 = svart)
BORDER_COLOR = 0                ; Kantfärg (0 = svart)

; ------------------------------------------------------------------------------
; Program start
        * = $0810
; ------------------------------------------------------------------------------

START
        SEI
        LDA #BG_COLOR
        STA VICBGC
        LDA #BORDER_COLOR
        STA VICCOL
        JSR CLRSCR
        ; Färgsätt scroll-raden
        LDX #0
COLINIT LDA #SCROLL_COLOR
        STA SCROLL_COL,X
        INX
        CPX #40
        BNE COLINIT
        ; Initiera SID
        LDA #0
        JSR SID_INIT
        ; Nollställ variabler
        LDA #0
        STA TEXT_IDX
        STA TEXT_IDX+1
        STA DO_SHIFT            ; Flagga för skift = av
        ; Set hardware scroll to 7
        LDA #7
        STA FINE_X
        LDA VICCTRL2
        AND #%11111000
        AND #%11110111          ; 38-kolumners läge
        ORA #7
        STA VICCTRL2
        ; Fyll scroll-raden med mellanslag
        LDX #0
FILSCR  LDA #32
        STA SCROLL_SCR,X
        INX
        CPX #40
        BNE FILSCR
        ; Sätt upp rasteravbrott
        LDA #%01111111
        STA CIA1ICR
        LDA CIA1ICR
        LDA #%00000001
        STA VICIRQM
        ; Starta med IRQ1
        LDA #IRQ1_LINE
        STA VICRAST
        LDA VICCTRL1
        AND #%01111111
        STA VICCTRL1
        LDA #<IRQ1
        STA IRQVEC
        LDA #>IRQ1
        STA IRQVEC+1
        CLI
MAIN    JMP MAIN

; ------------------------------------------------------------------------------
; IRQ1: Play music and update scroll value
; ------------------------------------------------------------------------------

IRQ1
        LDA #$01
        STA VICIRQ              ; Kvittera avbrott
        JSR SID_PLAY            ; Spela SID
        ; Minska FINE_X och uppdatera $D016
        DEC FINE_X
        LDA VICCTRL2
        AND #%11111000
        ORA FINE_X
        STA VICCTRL2
        ; Om FINE_X nått 0: sätt flagga för skift och återställ till 7
        LDA FINE_X
        BNE IRQ1_DONE
        LDA #7
        STA FINE_X
        LDA #1
        STA DO_SHIFT            ; Sätt skift-flagga
IRQ1_DONE
        ; Växla till IRQ2
        LDA #IRQ2_LINE
        STA VICRAST
        LDA #<IRQ2
        STA IRQVEC
        LDA #>IRQ2
        STA IRQVEC+1
        JMP $EA31

; ------------------------------------------------------------------------------
; IRQ 2: Shift screen memory
; ------------------------------------------------------------------------------

IRQ2
        LDA #$01
        STA VICIRQ              ; Kvittera avbrott
        ; Ska vi shifta denna frame?
        LDA DO_SHIFT
        BEQ IRQ2_DONE
        LDA #0
        STA DO_SHIFT            ; Nollställ flaggan
        ; Shifta skärm-raden ett tecken åt vänster
        LDX #0
SHIFTLP LDA SCROLL_SCR+1,X
        STA SCROLL_SCR,X
        INX
        CPX #39
        BNE SHIFTLP
        ; Hämta nästa tecken ur scrolltexten
        LDY TEXT_IDX
        LDA SCROLLTEXT,Y
        BEQ WRAP_TEXT
        ; Konvertera ASCII → PETSCII skärmkod
        CMP #65                 ; >= 'A'?
        BCC PUT_CHAR
        CMP #91                 ; <= 'Z'?
        BCS PUT_CHAR
        SEC
        SBC #64                 ; A=1, B=2 ... Z=26
PUT_CHAR
        STA SCROLL_SCR+39       ; Sätt tecknet längst till höger
        INC TEXT_IDX
        BNE IRQ2_DONE
        INC TEXT_IDX+1
        JMP IRQ2_DONE
WRAP_TEXT
        LDA #0
        STA TEXT_IDX
        STA TEXT_IDX+1
        LDA #32
        STA SCROLL_SCR+39
IRQ2_DONE
        ; Växla tillbaka till IRQ1
        LDA #IRQ1_LINE
        STA VICRAST
        LDA #<IRQ1
        STA IRQVEC
        LDA #>IRQ1
        STA IRQVEC+1
        JMP $EA31

; ------------------------------------------------------------------------------
; Clear screen
; ------------------------------------------------------------------------------

CLRSCR  LDA #32
        LDX #0
CLRLP   STA SCRBASE,X
        STA SCRBASE+$100,X
        STA SCRBASE+$200,X
        STA SCRBASE+$300,X
        INX
        BNE CLRLP
        RTS

; ------------------------------------------------------------------------------
; Variables
; ------------------------------------------------------------------------------

FINE_X      BYTE 7              ; Aktuellt hårdvaru-scroll-värde (0-7)
DO_SHIFT    BYTE 0              ; Flagga: 1 = dags att shifta skärmminnet
TEXT_IDX    WORD 0              ; Pekare in i SCROLLTEXT

; ------------------------------------------------------------------------------
; Scrolltext data.
; ------------------------------------------------------------------------------

SCROLLTEXT
        BYTE "in 2017, roger and i decided to do a c64 demo, just for fun. "
        BYTE "klas had brought his machine to work, and we squeezed in some "
        BYTE "programming whenever we had a moment between customer "
        BYTE "assignments. we never released anything, but this is the sid "
        BYTE "tune i wrote.  "
        BYTE 0

; ------------------------------------------------------------------------------
; Load the SID music
; ------------------------------------------------------------------------------

        * = $8000
        INCBIN "the_roger_boogie.sid", 126
