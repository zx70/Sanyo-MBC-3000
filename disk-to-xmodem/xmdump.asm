;----------------------------------------------------------------------------
; MBC-3000 xmodem diskdump for built in monitor by Edwin Blink Dec 2008
;----------------------------------------------------------------------------

;this program will read a disk track by track and transferes it at LINE-1
;serial port using xmodem protocol.

;Enter this program at address 0100H using the buildin in monitor program.
;Initialize LINE-1 serial port to 19200-8-N-1 by typing:

; SFF0C[SPACE]0C[SPACE]00[SPACE]FF[CR]

;Clear the LINE-1 reviever register by typing:

; SFF11[SPACE]00[ENTER]

;Execute the program by typing:

; G100[CR]

;start hyper terminal on PC configure com port to 19200-8-N-1 and select recieve
;file from the menu. Select xmodem for protocol. Transfer will start at 3rd attempt
;(only checksum protocol is supported) It takes about 20 mins to send the diskimage.
;Tracks with errors are reported during the transfer. Data at these tracks in the
;transfered image are unreliable.
 
        .org    $0100

SBUF:   .equ    $0200   ;start of track buffer
SBSZ:   .equ    $2000   ;track size is 8Kb

SOH:    .equ    $01     ;Xmoden controls
EOT:    .equ    $04     
ACK:    .equ    $06
NAK:    .equ    $15
CAN:    .equ    $18
  
;start with waiting for reciever to send NAK

START:  call    TNAK    ;wait for NAK
        jnz     START
        
        mvi     a,$01   ;first block
        sta     BLK
        xra     a       ;Start at track 0
       
;read disk track
        
DOTRK:  lxi     b,DSKTR       ;track in disk structure
        stax    b
        mvi     c,DSKCM % 256 ;LSB disk structure
        call    $E45B         ;DiskIO
        lxi     h,SBUF        ;sector buffer
        jz      DOBLK         ;no error,send track
        
;track error, print error

        lda     DSKTR   ;track
        mov     c,a
        call    $E68F
        lxi     h,SBUF+$0080 ;Start of buffer with next corretion
BLKER:        
        lxi     b,$FF80 ;offset to last block
        dad     b       ;point back to start of block

;send xmodem blocks
            
DOBLK:
        lxi      b,$0000+SOH
        call    TXC     ;send SOH
        
;       pop     b
;       push    b
             
BLK:    .equ    $+1     
        mvi     c,0     
        call    TXC     ;send block nr
        mov     a,c
        cma
        mov     c,a
        call    TXC     ;send complemented block nr

;send block data
        
DOBT:   mov     c,m     ;send byte
        inx     h
        call    TXC
        mov     a,b
        add     c       ;SUM=SUM+C
        mov     b,a
        mov     a,l     ;check 128 bytes done
        add     a
        jnz     DOBT    ;do 128 bytes
        mov     c,b
        call    TXC     ;send checksum    
        
;WAIT response
        
        call    TNAK    ;WAIT for ACK NAK
        jz      BLKER   ;retransmit block

;next block

NXTBLK: push    h
        lxi     h,BLK
        inr     m
        pop     h
        mov     a,h
        cpi     (SBUF+SBSZ)/256 ;8K
        jnz     DOBLK    ;loop sector buffer done
        
;Next track
      
        lda     DSKTR  
        inr     a       ;next track
        cpi     $9A     ;last track+1
        jnz     DOTRK   ;more tracks

DOEND:  mvi     c,EOT
        call    TXC
        call    TNAK
        jz      DOEND
        ret
        
;Transmit character in C Reg        
;--------------------------- 
       
TXC:    push    h
        lxi     d,$0006  ;Line-1 output
        call     $E41E   ;Write C
        pop     h
        ret
        
;Test for NAK or CAN    
;-------------------
     
TNAK:   
        lxi     d,$0005 ;Line-1 input device
        push    h
        call     $E42C  ;Read A
        pop     h
        cpi     NAK
        rz              ;Z NAK
        cpi     CAN
        rnz             ;NZ seen as ACK
        
        pop     b       ;cancel so drop return
        ret             ;return to monitor
        
;disk command structure
        
DSKCM:       
        .db     $80    ;normal
DRIVE:  .db     $04    ;read sector drive A
        .db     $08    ;sector count
DSKTR:  .db     $00    ;Track
        .db     $01    ;sector 
        .dw     SBUF  ;DMA address

        .end
        
        