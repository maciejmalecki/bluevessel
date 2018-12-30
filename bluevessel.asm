/*
 * BlueVessel one file demo.
 *
 * Author:    Maciej Malecki (npe)
 *
 * License:   MIT
 * (c):       2018
 * GIT repo:  https://github.com/maciejmalecki/bluevessel
 */
 
#define VISUAL_DEBUG
#define IRQH_BG_RASTER_BAR
#define IRQH_HSCROLL
#define IRQH_JSR
#define IRQH_HSCROLL_MAP
#define IRQH_BORDER_BG_0_COL

#import "chipset/lib/mos6510.asm"
#import "chipset/lib/vic2.asm"
#import "chipset/lib/cia.asm"
#import "text/lib/text.asm"
#import "text/lib/scroll1x1.asm"
#import "common/lib/mem-global.asm"
#import "common/lib/invoke-global.asm"
#import "copper64/lib/copper64.asm"

// zero page addresses
.label DISPLAY_LIST_PTR_LO = $02
.label DISPLAY_LIST_PTR_HI = $03
.label LIST_PTR = $04
.label ANIMATION_IDX = $05
.label BAR_DEFS_IDX = $06
.label SCROLL_TEMP = $07 // and $08
.label SCROLL_OFFSET = $09
.label CYCLE_CNTR = $0A

// constants

.label COLOR_1 = LIGHT_GREY
.label COLOR_2 = LIGHT_BLUE
.label COLOR_3 = BLUE
.label COLOR_4 = WHITE

.label SCREEN_PTR = 1024

.label LOGO_POSITION = 2
.label LOGO_LINE = LOGO_POSITION * 8 + $33 - 4
.label TECH_TECH_WIDTH = 9*8
.label COLOR_SWITCH_1 = LOGO_LINE + TECH_TECH_WIDTH + 15
.label COLOR_SWITCH_2 = COLOR_SWITCH_1 + 6
.label COLOR_SWITCH_3 = COLOR_SWITCH_2 + 16

.label CREDITS_POSITION = 17
.label CREDITS_COLOR_BARS_LINE = CREDITS_POSITION * 8 + $33 - 4

.label SCROLL_POSITION = 22
.label SCROLL_POSITION_OFFSET = SCROLL_POSITION * 40
.label SCROLL_COLOR_BARS_LINE = SCROLL_POSITION * 8 + $33 - 2
.label SCROLL_HSCROLL_LINE_START = SCROLL_COLOR_BARS_LINE - 5 
.label SCROLL_HSCROLL_LINE_END = SCROLL_HSCROLL_LINE_START + 10 + 8 

.label COPYRIGHT_COLOR = LIGHT_BLUE
.label COPYRIGHT_POSITION = 24

// Jeroen Tel granted me a permission to use his tune in this intro. I'm a bad musician myself :-(
.var music = LoadSid("Noisy_Pillars_tune_1.sid")

*=$0801 "Basic Upstart"
BasicUpstart(start) // Basic start routine

// Main program
*=$080d "Program"

// ----- helper macros -----
.function pause() {
  .return "                    "
}

.function longPause() {
  .return pause() + pause()
}

// execution starts here -->
start:
  // C64 God Mode:
  sei
  .namespace c64lib {
    // reconfigure C64 memory, we want full ram without BASIC and KERNAL
    configureMemory(RAM_IO_RAM)
    // disable NMI interrupt in a lame way
    disableNMI()
    // disable CIA as interrupt sources
    disableCIAInterrupts()
  }
  cli
  
  // initialize internal data structures  
  lda #00
  sta ANIMATION_IDX
  sta BAR_DEFS_IDX
  sta CYCLE_CNTR
  sta SCROLL_OFFSET

  // initialization routines
  jsr unpack
  jsr initSound
  jsr initScreen
  jsr initCopper

  // initialize and install copper64 IRQ routine
  jsr startCopper
block:
  // go to infinite loop, the rest will be done in interrupts
  jmp block
  

// ----- initalization routines ------

// Does relocation of code into target position (music data & player).
unpack: {
  pushParamW(musicData)
  pushParamW(music.location)
  pushParamW(music.size)
  jsr copyLargeMemForward
  rts
}
// Intro screen set up.
initScreen: 
  .namespace c64lib {
  
    // -- clear screen --
    pushParamW(SCREEN_PTR)
    lda #($20)
    jsr fillScreen
    pushParamW(COLOR_RAM)
    lda #COLOR_4
    jsr fillScreen
    
    // -- tech tech logo --
    pushParamW(vesselData1)
    pushParamW(SCREEN_PTR + getTextOffset(0, LOGO_POSITION))
    jsr outText
    pushParamW(vesselData2)
    pushParamW(SCREEN_PTR + getTextOffset(0, LOGO_POSITION + 5))
    jsr outText
    
    pushParamW(vesselColors1)
    pushParamW(COLOR_RAM + getTextOffset(0, LOGO_POSITION))
    jsr outText
    pushParamW(vesselColors2)
    pushParamW(COLOR_RAM + getTextOffset(0, LOGO_POSITION + 5))
    jsr outText
    
    // -- credits --
    pushParamW(SCREEN_PTR + getTextOffset(0, CREDITS_POSITION - 1))
    ldx #(3*40)
    lda #($20+128)
    jsr fillMem
    
    pushParamW(creditsText1)
    pushParamW(SCREEN_PTR + getTextOffset(0, CREDITS_POSITION))
    jsr outText
    pushParamW(creditsText2)
    pushParamW(SCREEN_PTR + getTextOffset(0, CREDITS_POSITION + 2))
    jsr outText

    pushParamW(COLOR_RAM + getTextOffset(0, CREDITS_POSITION - 1))
    ldx #(4*40)
    lda #COLOR_3
    jsr fillMem
    
    // -- scroll --
       
    // narrow screen to enable scrolling
    lda CONTROL_2
    and #neg(CONTROL_2_CSEL)
    sta CONTROL_2
    
    pushParamW(COLOR_RAM + getTextOffset(0, SCROLL_POSITION))
    ldx #(1*40)
    lda #COLOR_3
    jsr fillMem
    
    pushParamW(SCREEN_PTR + getTextOffset(0, SCROLL_POSITION))
    ldx #(1*40)
    lda #($20+128)
    jsr fillMem
    
    // -- copyright --
    pushParamW(copyrightText)
    pushParamW(SCREEN_PTR + getTextOffset(1, COPYRIGHT_POSITION))
    jsr outText
    
    pushParamW(COLOR_RAM + getTextOffset(1, COPYRIGHT_POSITION))
    ldx #38
    lda #COPYRIGHT_COLOR
    jsr fillMem
    
    rts
  }


// Intialize "copper" list.
initCopper: {
  // set up address of display list
  lda #<copperList
  sta DISPLAY_LIST_PTR_LO
  lda #>copperList
  sta DISPLAY_LIST_PTR_HI
  rts
}

// Initialize music player.
initSound: {
  ldx #0
  ldy #0
  lda #music.startSong-1
  jsr music.init
  rts
}


// ----- custom IRQ handlers -----

// Music player step to be executed at given free raster line.
playMusic: {
  debugBorderStart()
  jsr music.play
  debugBorderEnd()
  rts
}

// Handles scroll to be executed at given free raster line.
doScroll: {
  debugBorderStart()
  lda SCROLL_OFFSET
  cmp #$00
  bne decOffset
  lda #7
  sta SCROLL_OFFSET
  pushParamW(SCREEN_PTR + SCROLL_POSITION_OFFSET)
  pushParamW(scrollText)
  pushParamWInd(scrollPtr)
  jsr scroll
  pullParamW(scrollPtr)
  jmp fineScroll
decOffset:
  sbc #1
  sta SCROLL_OFFSET
fineScroll:
  lda SCROLL_OFFSET
  sta hscroll + 2
  debugBorderEnd()
  rts
}

doCycleAndTechTech: {
  debugBorderStart()
  
  // tech tech
  pushParamW(hscrollMapDef)
  ldx #(TECH_TECH_WIDTH-1)
  jsr rotateMemRight
  
  // c64lib_rotateMemRightFast(hscrollMapDef, TECH_TECH_WIDTH - 1)
  
  // font effects via raster bars
  inc CYCLE_CNTR
  lda CYCLE_CNTR
  cmp #4
  beq doCycle
  debugBorderEnd()
  rts
doCycle:
  lda #0
  sta CYCLE_CNTR
  pushParamW(colorCycleDef + 1)
  ldx #6
  jsr rotateMemRight
  
  // c64lib_rotateMemRightFast(colorCycleDef + 1, 6)
  
  debugBorderEnd()
  rts
}
endOfCode:

// ----- "copper" list, here we define which effects should be executed at which raster line  ------
// ----- or, we also call custom IRQ handlers here such as doScroll, doCycleAndTechTech, etc. ------
.align $100
copperList:
            copperEntry(0,                            c64lib.IRQH_BORDER_BG_0_COL,  COLOR_4, 0)
            copperEntry(4,                            c64lib.IRQH_JSR,              <playMusic, >playMusic)
            copperEntry(40,                           c64lib.IRQH_JSR,              <doScroll, >doScroll)
            copperEntry(LOGO_LINE,                    c64lib.IRQH_HSCROLL_MAP,      <hscrollMapDef, >hscrollMapDef)
            copperEntry(COLOR_SWITCH_1,               c64lib.IRQH_BORDER_BG_0_COL,  COLOR_1, 0)
            copperEntry(COLOR_SWITCH_2,               c64lib.IRQH_BORDER_BG_0_COL,  COLOR_2, 0)
            copperEntry(COLOR_SWITCH_3,               c64lib.IRQH_BORDER_BG_0_COL,  COLOR_3, 0)
            copperEntry(CREDITS_COLOR_BARS_LINE,      c64lib.IRQH_BG_RASTER_BAR,    <colorCycleDef, >colorCycleDef)
            copperEntry(CREDITS_COLOR_BARS_LINE + 16, c64lib.IRQH_BG_RASTER_BAR,    <colorCycleDef, >colorCycleDef)
  hscroll:  copperEntry(SCROLL_HSCROLL_LINE_START,    c64lib.IRQH_HSCROLL,          5, 0)
            copperEntry(SCROLL_COLOR_BARS_LINE,       c64lib.IRQH_BG_RASTER_BAR,    <scrollBarDef, >scrollBarDef)
            copperEntry(SCROLL_HSCROLL_LINE_END,      c64lib.IRQH_HSCROLL,          0, 0)
            copperEntry(SCROLL_HSCROLL_LINE_END + 3,  c64lib.IRQH_JSR,              <doCycleAndTechTech, >doCycleAndTechTech)
            copperLoop()
endOfCopper:

// ----- library hosted functions (here we execute macros that "install" subroutine or just import their code there) -----
beginOfLibs:

  // here we configure subroutines that requies zero page location, calling KA macros configure and install them
  startCopper:    .namespace c64lib { _startCopper(DISPLAY_LIST_PTR_LO, LIST_PTR) }
  scroll:         .namespace c64lib { _scroll1x1(SCROLL_TEMP) }

  // here we just import code of subroutines which do not require any further configuration
  outText:         
                #import "text/lib/sub/out-text.asm"
  fillMem:
                #import "common/lib/sub/fill-mem.asm"
  rotateMemRight: 
                #import "common/lib/sub/rotate-mem-right.asm"
  fillScreen:
                #import "common/lib/sub/fill-screen.asm"
  copyLargeMemForward: 
                #import "common/lib/sub/copy-large-mem-forward.asm"
endOfLibs:

// variables
beginOfVars:
copyrightText: .text "ntsc friendly             (c) 2018 npe"; .byte $ff
scrollText:     incText(
                    pause() +
                    "hallo krzychu! ich gruesse dich und wuensche dich viel spass mit deine neue c64c mit 250466 platine! " +
                    pause() +
                    "that was of course a joke in a very bad taste, so now i will use less cryptic language ;) " +
                    longPause() +
                    "more greetings to the whole team: julka, olga, bartek, jarek, pawel and wiktor " +
                    "and my girls: ania, ola and zuza. and to my old team, who actually gave me first c64 after so many years (especially gosia who got the idea) " +
                    pause() +
                    "and to: basia, jarek and helenka!!! " +
                    pause() +
                    "batman! and jeroen!     " + 
                    "and whole commodore 64 community! including commodore 64/128 fb group" +
                    longPause() +
                    "i have coded this intro in 2 hours and i'm actually quite surprised how smoothly it went. " + 
                    "it was mostly due to the fact, that i copied & pasted my example intro from copper64 and just made new logo plus added some color switches. " +
                    "whole intro and libraries are coded in kickassembler (thanks mads!) " +
                    longPause() +
                    "get source of this intro on github.com/maciejmalecki/bluevessel     " +
                    "access c64lib on github.com/c64lib " +
                    pause() +
                    "bye! " +
                    longPause(),
                    128) 
                .byte $ff
creditsText1:   incText("         coded by  herr architekt      ", 128); .byte $ff
creditsText2:   incText("         music by  jeroen tel          ", 128); .byte $ff                
vesselData1:    .byte $20,$20,$55,$49,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
                .byte $20,$20,$4A,$4B,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$72,$5B,$72,$20,$20,$20,$20,$20,$20,$20,$20,$20
                .byte $20,$20,$50,$4F,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$42,$42,$5D,$76,$77,$77,$77,$77,$A0,$20,$20,$20
                .byte $20,$20,$6A,$74,$20,$20,$20,$20,$20,$20,$66,$A0,$A0,$66,$66,$A0,$66,$A0,$A0,$A0,$20,$20,$20,$20,$20,$20,$20,$20,$59,$42,$47,$20,$61,$68,$66,$66,$A0,$20,$20,$20
                .byte $20,$4D,$6A,$74,$4E,$20,$20,$20,$20,$A0,$A0,$A0,$66,$A0,$A0,$A0,$A0,$A0,$66,$A0,$A0,$66,$A0,$20,$20,$A0,$A0,$20,$6A,$5D,$74,$20,$61,$20,$5C,$5C,$A0,$20,$20,$20, $ff
vesselData2:    .byte $20,$20,$50,$4F,$20,$20,$20,$20,$20,$A0,$66,$A0,$A0,$A0,$66,$A0,$A0,$A0,$A0,$66,$66,$A0,$A0,$20,$A0,$66,$A0,$A0,$66,$42,$20,$20,$61,$68,$68,$66,$A0,$20,$20,$20
                .byte $20,$20,$7C,$7E,$20,$20,$20,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$F6,$20,$20
                .byte $20,$20,$20,$20,$20,$20,$20,$F4,$A0,$82,$8C,$95,$85,$A0,$96,$85,$93,$93,$85,$8C,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$F6,$20,$20
                .byte $20,$20,$20,$20,$20,$20,$20,$F5,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$75,$20,$20
                .byte $20,$20,$20,$20,$20,$20,$20,$E1,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$74,$20,$20,$ff

vesselColors1:  .byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0B,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
                .byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0B,$0B,$0B,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
                .byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0B,$0B,$0B,$0F,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
                .byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$07,$02,$0A,$08,$0F,$06,$0F,$0E,$06,$0F,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0B,$0B,$0B,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
                .byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$02,$04,$03,$05,$0B,$04,$05,$04,$0B,$09,$0B,$03,$05,$03,$0E,$0E,$05,$04,$0E,$0B,$0B,$0B,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E, $ff
vesselColors2:  .byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0A,$07,$0A,$07,$06,$06,$0A,$07,$05,$0E,$0A,$0B,$06,$0A,$0E,$06,$08,$07,$06,$0B,$0B,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
                .byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0B,$0B,$0E,$0E
                .byte $0E,$0E,$0B,$0E,$0E,$0E,$0E,$0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0B,$0B,$0E,$0E
                .byte $0E,$0E,$0B,$0E,$0E,$0E,$0E,$0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0B,$0B,$0E,$0E
                .byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0F,$0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0B,$0B,$0B,$0B,$0B,$0E,$0E, $ff


scrollPtr:      .word scrollText
scrollBarDef:   .byte GREY, LIGHT_GREY, WHITE, WHITE, LIGHT_GREY, GREY, GREY, COLOR_3, $ff
colorCycleDef:  .byte COLOR_3, LIGHT_RED, RED, LIGHT_RED, YELLOW, WHITE, YELLOW, YELLOW, COLOR_3, $ff
hscrollMapDef:  .fill TECH_TECH_WIDTH, round(3.5 + 3.5*sin(toRadians(i*360/TECH_TECH_WIDTH))) ; .byte 0; .byte $ff
endOfVars:

musicData:
.fill music.size, music.getData(i)
endOfMusic:

endOfProg:

.print "=== MEMORY MAP SUMMARY ==="
.print " Begin of code     = $" + toHexString(start, 4)
.print " End of code       = $" + toHexString(endOfCode, 4) + ", Size of code = " + (endOfCode - start)
.print " Begin of libs     = $" + toHexString(beginOfLibs, 4)
.print " End of libs       = $" + toHexString(endOfLibs, 4) + ", Size of libs = " + (endOfLibs - beginOfLibs)
.print " Begin of copper   = $" + toHexString(copperList, 4)
.print " End of copper     = $" + toHexString(endOfCopper, 4) + ", Size of copper list = " + (endOfCopper - copperList)
.print " Begin of vars     = $" + toHexString(beginOfVars, 4)
.print " End of vars       = $" + toHexString(endOfVars, 4) + ", Size of vars = " + (endOfVars - beginOfVars)
.print " Begin of music    = $" + toHexString(musicData, 4)
.print " End of music      = $" + toHexString(endOfMusic, 4) + ", Size of vars = " + (endOfMusic - musicData)

.print " Size of all       = " + (endOfProg - start)
.print "=========================="
