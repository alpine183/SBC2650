;NOFOLD
;$Id: firmware.asm,v 1.6 2024/09/14 15:30:15 seiji Exp seiji $
	CPU	2650
;	INTSYNTAX	$hex
	
TARGET: EQU	"2650"
SERBASE:	EQU	$00
; firmware for the Signetics 2650 single board computer
;
; at start-up a simple menu allows the choice of the PIPBUG monitor 
; or the MicroWorld BASIC interpreter.
;
; PIPBUG has been modified as follows:
;  - the I/O functions 'chin' and 'cout' were re-written for 9600 bps N-8-1.
;  - the 'D' (Dump to paper tape) function has been removed.
;  - the 'L' (Load) function has been re-written to load an Intel hex format file.
;  - the 'chin' function has been modified to convert lower case input to upper case.
;  - entering '?' at the PIPBUG prompt displays a list of PIPBUG commands.
;
; memory map: original
;   0000-03FF   PIPBUG in EPROM
;   0400-043F   PIPBUG scratch pad RAM
;   0440-07FF   available RAM (0500-07FF used by BASIC as scratch pad)
;   0800-1FFF   MicroWorld BASIC interpreter in EPROM
;   2000-5FFF   BASIC source program storage RAM
;   6000-6FFF   Expansion EPROM
;   7000-7EFF   Additional RAM
;   7F00        I/O ports
;
; memory map: 2650A SBC
;   0000-03FF   PIPBUG in EPROM
;   0400-043F   PIPBUG scratch pad RAM
;   0440-07FF   RAM PAGE: available RAM (0500-07FF used by BASIC as scratch pad)
;   0440-05FF   ROM PAGE: available RAM (0500-07FF used by BASIC as scratch pad)
;   0600-06FF	ROM PAGE: expansion EPROM for program selector
;   0800-1FFF   MicroWorld BASIC interpreter in EPROM
;   2000-7FFF   BASIC source program storage RAM

;2650 specific equates
EQ          equ  0
GT          equ  1
LT          equ  2
UN          equ  3            

sense       equ $80                     ;sense bit in program status, upper
flag        equ $40                     ;flag bit in program status, upper
ii          equ $20                     ;interrupt inhibit bit in program status, upper
rs          equ $10                     ;register select bit in program status, lower
wc          equ $08                     ;with/without carry bit in program status,lower

spac        equ $20                     ;ASCII space
dele        equ $7F                     ;ASCII delete
CR          equ $0D                     ;ASCII carriage return
LF          equ $0A                     ;ASCII line feed
BS          equ $08                     ;ASCII line feed

bmax        equ 1                       ;maximum number of breakpoints
blen        equ 20                      ;size of input buffer

LEDport     equ $7F00                   ;output port controlling LEDs

;don't know why, but placing these assembler directives at the beginning of
;the file causes an access violation.
;PAGE 255
;WIDTH 132
;;;functions
low	function	x,(x & 255)
high	function	x,(x >> 8)

            org $0000
onreset:
	    bcta,un transfer
init: 
;	        lodi,r3 63
;           eorz    R0
aini:       stra,R0 com,R3,-
            brnr,R3 aini                ;clear memory $0400-$04FF
            lodi,R0 $077                ;opcode for 'ppsl'
            stra,R0 xgot
            lodi,R0 $1B                 ;opcode for 'bctr,un'
            stra,R0 xgot+2
            lodi,R0 $80
            stra,R0 xgot+3
            bcta,un start               ;do an absolute branch to 'start' function in page 3

vec:        db high(bk01),low(bk01)
            db high(bk02),low(bk02)

;====================================================================
;command handler
;====================================================================
ebug:       lodi,R0 '?'
            bsta,UN cout
mbug:       cpsl    $FF
            bsta,UN crlf
            lodi,R0 '*'
            bsta,UN cout
            bstr,UN line
            eorz    R0
            stra,R0 bptr
            loda,R0 buff
            comi,R0 'A'
            bcta,EQ alte
            comi,R0 'B'
            bcta,EQ bkpt
            comi,R0 'C'
            bcta,EQ clr
            comi,R0 'G'
            bcta,EQ goto
            comi,R0 'L'
            bcta,EQ load
            comi,R0 'S'
            bcta,EQ sreg
            bcta,UN mbug1               ;oops, out of space
            
        ; PIPBUG users expect the 'line' function to be located at $005B
;        if $ > $005B
;            WARNING 'Address MUST be $005A'
;        else                    
;            ds $005B-$,0               
;        endif
	    db	$c0
;	    db	$c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0

	    org $005B
;====================================================================
;input a cmd line into buffer
;code is 1=CR 2=LF 3=MSG+CR 4=MSG+LF
;====================================================================
line:       lodi,R3 $FF
            stra,R3 bptr
llin:       comi,R3 blen
            bctr,EQ elin
            bsta,UN chin
            comi,R0 dele
            bcfr,EQ alin
            comi,R3 $FF
            bctr,EQ llin
            loda,R0 buff,R3
            bsta,UN cout
            subi,R3 1
            bctr,UN llin
            
alin:       comi,R0 CR
            bcfr,EQ blin
elin:       lodi,R1 1
clin:       lodz    R3
            bctr,LT dlin
            addi,R1 2
dlin:       stra,R1 code
            stra,R3 cnt
crlf:       lodi,R0 CR
            bsta,UN cout
            lodi,R0 LF
            bsta,UN cout
            retc,UN
            
blin:       lodi,R1 2
            comi,R0 LF
            bctr,EQ clin
            stra,R0 buff,R3,+
            bsta,UN cout
            bcta,UN llin

;====================================================================
;store two bytes in R1 and R2 into temp and temp+1
;====================================================================
strt:       stra,R1 temp
            stra,R2 temp+1
            retc,UN

;====================================================================
; display and alter memory
;====================================================================            
alte:       bsta,UN gnum
lalt:       bstr,UN strt
            bsta,UN bout
            loda,R1 temp+1
            bsta,UN bout
            bsta,UN form
            loda,R1 *temp
            bsta,UN bout
            bsta,UN form
            bsta,UN line
            loda,R0 code
            comi,R0 2
            bcta,LT mbug
            bctr,EQ dalt
calt:       stra,R0 temr
            bsta,UN gnum
            stra,R2 *temp
            loda,R0 temr
            comi,R0 4
            bcfa,EQ mbug
dalt:       lodi,R2 1
            adda,R2 temp+1
            lodi,R1 0
            ppsl    wc
            adda,R1 temp
            cpsl    wc
            bcta,UN lalt

;====================================================================
; selectively display and alter register
;====================================================================
sreg:       bsta,UN gnum
lsre:       comi,R2 8
            bcta,GT ebug
            stra,R2 temr
            loda,R0 com,R2
            strz    R1
            bsta,UN bout
            bsta,UN form
            bsta,UN line
            loda,R0 code
            comi,R0 2
            bcta,LT mbug
            bctr,EQ csre
asre:       stra,R0 temq
            bsta,UN gnum
            lodz    R2
            loda,R2 temr
            stra,R0 com,R2
            comi,R2 8
            bcfr,EQ bsre
            stra,R0 xgot+1
bsre:       loda,R0 temq
            comi,R0 3
            bcta,EQ mbug
csre:       loda,R2 temr
            addi,R2 1
            bcta,UN lsre

;====================================================================
; goto address
;====================================================================
goto:       bsta,UN gnum                ;get the address
            bsta,UN strt                ;save the address in temp and temp+1   
            loda,R0 com+7
            lpsu                        ;restore program status, upper
            loda,R1 com+1               ;restore R1 in register bank 0
            loda,R2 com+2               ;restore R2 in register bank 0
            loda,R3 com+3               ;restore R3 in register bank 0
            ppsl    rs
            loda,R1 com+4               ;restore R1 in register bank 1
            loda,R2 com+5               ;restore R2 in register bank 1
            loda,R3 com+6               ;restore R3 in register bank 1
            loda,R0 com                 ;restore R0
            cpsl    $FF                 ;clear program status, lower
            bcta,UN xgot                ;branch to the address in 'xgot' which branches to the address in temp and temp+1

;====================================================================
; breakpoint runtime code
;====================================================================
bk01:       stra,R0 com
            spsl
            stra,R0 com+8
            stra,R0 xgot+1
            lodi,R0 0
            bctr,UN bken
bk02:       stra,R0 com
            spsl
            stra,R0 com+8
            stra,R0 xgot+1
            lodi,R0 1
bken:       stra,R0 temr
            spsu
            stra,R0 com+7
            ppsl    rs
            stra,R1 com+4
            stra,R2 com+5
            stra,R3 com+6
            cpsl    rs
            stra,R1 com+1
            stra,R2 com+2
            stra,R3 com+3
            loda,R2 temr
            bstr,UN clbk
            loda,R1 temp
            bsta,UN bout
            loda,R1 temp+1
            bsta,UN bout
            bcta,UN mbug

;====================================================================
; clear a breakpoint
;====================================================================
clbk:       eorz    R0
            stra,R0 mark,R2
            loda,R0 hadr,R2
            stra,R0 temp
            loda,R0 ladr,R2
            stra,R0 temp+1
            loda,R0 hdat,R2
            stra,R0 *temp
            loda,R0 ldat,R2
            lodi,R3 1
            stra,R0 *temp,R3
            retc,UN

;break point mark indicates if set
;hadr+ladr is breakpoint address hdat+ldat is two byte
clr:        bstr,UN nok
            loda,R0 mark,R2
            bcta,EQ ebug
            bstr,UN clbk
            bcta,UN mbug
            
nok:        bsta,UN gnum
            subi,R2 1
            bcta,LT abrt
            comi,R2 bmax
            bcta,GT abrt
            retc,UN

bkpt:       bstr,UN nok
            loda,R0 mark,R2
            bsfa,EQ clbk
            stra,R2 temr
            bsta,UN gnum
            bsta,UN strt
            loda,R3 temr
            lodz    R2
            stra,R0 ladr,R3
            lodz    R1
            stra,R0 hadr,R3
            loda,R0 *temp
            stra,R0 hdat,R3
            lodi,R1 $9B
            stra,R1 *temp
            lodi,R2 1
            loda,R0 *temp,R2
            stra,R0 ldat,R3
            loda,R0 disp,R3
            stra,R0 *temp,R2
            lodi,R0 $FF
            stra,R0 mark,R3
            bcta,UN mbug

disp:       db  vec+$80
            db  vec+$80+2

;        ; PIPBUG users expect the 'bin' function to be located at $0224
;        if $ > $0224
;            WARNING 'Address MUST be $0224'
;        else
;            ds $0224-$,0                
;        endif


	    org $0224
;====================================================================
; input two hex characters and form a byte in R1
;====================================================================
bin:        bsta,UN chin
            bstr,UN lkup
            rrl,R3
            rrl,R3
            rrl,R3
            rrl,R3
            stra,R3 tems
            bsta,UN chin
            bstr,UN lkup
            iora,R3 tems
            lodz    R3
            strz    R1
            retc,UN

;ran out of space in the command handler function 'mbug', continue here
;display 'help' when '?' is entered            
mbug1:      comi,R0 '?'
            bcta,EQ help
            bcta,UN ebug            

;        ; PIPBUG users expect the 'lkup' function to be located at $0246
;        if $ > $0246
;            WARNING 'Address MUST be $0246'
;        else
;            ds $0246-$,0                
;        endif
            
	    db	$c0,$c0,$c0

	    org $0246
;lookup ASCII char in hex value table
lkup:       lodi,R3 16
alku        coma,R0 ansi,R3,-
            retc,EQ
            comi,R3 1
            bcfr,LT alku

;abort exit from any level of subroutine
;use ras ptr since possible bkpt prog using it
abrt:       loda,R0 com+7
            iori,R0 $40
            spsu
            bcta,UN ebug
            
ansi:       db  "0123456789ABCDEF"

;        ; PIPBUG users expect the 'bout' function to be located at $0269
;        if $ > $0269
;            WARNING 'Address MUST be $0269'
;        else
;            ds $0269-$,0                
;        endif
            

	    org $0269
;====================================================================
; output byte in R1 as 2 hex characters
;====================================================================
bout:       stra,R1 tems
            rrr,R1
            rrr,R1
            rrr,R1
            rrr,R1
            andi,R1 $0F
            loda,R0 ansi,R1
            bsta,UN cout
            loda,R1 tems
            andi,R1 $0F
            loda,R0 ansi,R1
            bsta,UN cout
            retc,UN
            
;        ; PIPBUG users expect the 'chin' function to be located at $0286
;        if $ > $0286
;            WARNING 'Address MUST be $0286'
;        else
;            ds $0286-$,0                
;        endif
	    db	$c0,$c0

	    org $0286
;====================================================================
; pipbug serial input function
;  return a character into R0
;====================================================================
;chin:       ppsl    rs                  ;select register bank 1
;            lodi,R1 0                   ;initialize R1
;            lodi,R2 8                   ;load R2 with the number of bits to receive
;            
;chin1:      spsu                        ;store program status, upper containing the sense input to R0
;            bctr,LT chin1               ;branch back if the sense input is "1" (wait for the start bit)
;            lodi,R3 4
;            bstr,UN dlay                ;delay 1/2 bit time
;            
;chin2:      lodi,R3 4
;            bstr,UN dlay                ;delay 1 bit time
;            nop                         ;timing adjustment
;            spsu                        ;store program status, upper containing the sense input to R0
;            andi,R0 sense               ;mask out all but the sense input
;            rrr,R1                      ;rotate bits into position
;            iorz    R1                  ;OR the received bit into R0        
;            strz    R1                  ;save the result in R1
;            bdrr,R2 chin2               ;branch back for all 8 bits
;            
;            lodi,R3 4
;            bstr,UN dlay                ;delay 1/2 bit time for the stop bit
;            bcta,UN chin3               ;out of space, continue below...
;
;;delay (9*R3)+9 microseconds
;dlay:       bdrr,R3 $
;            retc,UN
chin:	     ppsl    rs
chin1:	     rede,r0 SERBASE+1		; get input buffer status
	     andi,r0 $02		;  .. are there any?
	     bcta,eq chin1		; no. continue loop
chin2:	     rede,r1 SERBASE		; get character
	     comi,r1 'a'		; branch if the character is less than 'a'
	     bctr,LT chin4
	     comi,r1 'z'		; branch if the character is greater than 'z'
	     bctr,GT chin4		; else - subtract $20 to capitalize
	     subi,R1 $20
chin4:	     lodz    R1
	     cpsl    rs
	     retc,UN
	     
;            
;        ; PIPBUG users expect the 'cout' function to be located at $02B4
;        if $ > $02B4
;            WARNING 'Address MUST be $02B4'
;        else
;            ds $02B4-$,0                
;        endif
            
	    db	$c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0
	    db	$c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0
	    db	$c0,$c0,$c0,$c0,$c0

	    org $02B4
;====================================================================
; pipbug serial output function
;  output a character in R0 to serial console
;====================================================================
;cout:       ppsl    rs                  ;select register bank 1
;            ppsu    flag                ;set FLAG output to "1" (send MARK)
;            strz    R2                  ;save the character (now in R0) in R2
;            lodi,R1 8                   ;load R1 with the number of bits to send
;            cpsu    flag                ;clear the FLAG output (send start bit)
;            nop                         ;timing adjustments
;            nop
;            nop
;            
;cout1:      lodi,R3 4
;            bstr,UN dlay                ;delay one bit time
;            rrr,R2                      ;rotate the next bit of R2 into bit 7  
;            bctr,LT cout2               ;branch if bit 7 was "1"
;            cpsu    flag                ;else, send "0" (SPACE)
;            bctr,UN cout3
;cout2:      ppsu    flag                ;send "1" (MARK)
;            bctr,UN cout3
;cout3:      bdrr,R1 cout1               ;loop until all 8 bits are sent
;
;            lodi,R3 6
;            bstr,UN dlay                ;delay one bit time
;            ppsu    flag                ;preset the FLAG output (send stop bit)
;            lodi,R3 5
;            bstr,UN dlay                ;delay 1/2 bit time            
;            cpsl    rs                  ;select register bank 0
;            retc,UN                     ;return to caller
cout:       ppsl    rs                  ;select register bank 1
            strz    R2                  ;save the character (now in R0) in R2
cout1:	    rede,r3 SERBASE+1		;get transmit flags
	    andi,r3 $01			; ... and test it.
	    bcta,eq cout1		; if transmit reg full then wait
	    wrte,r2 SERBASE		; transmit
	    cpsl    rs			; return to register bank 0
	    retc,UN

;continuation of the 'chin' function above
;chin3:      comi,R1 'a'
;            bctr,LT chin4               ;branch if the character is less than 'a'
;            comi,R1 'z'
;            bctr,GT chin4               ;branch if the character is greater than 'z'
;            subi,R1 $20                 ;else, subtract $20 to convert lower case to upper
;chin4:      lodz    R1                  ;load the character (now in R1) into R0
;            cpsl    rs+wc               ;select register bank 0
;            retc,UN                     ;return to caller            

;get a number from the buffer into R1-R2
dnum:       loda,R0 code
            bctr,EQ lnum
            retc,UN

gnum:       eorz    R0
            strz    R1
            strz    R2
            stra,R0 code
lnum:       loda,R3 bptr
            coma,R3 cnt
            retc,EQ
            loda,R0 buff,R3,+
            stra,R3 bptr
            comi,R0 spac
            bctr,EQ dnum
bnum:       bsta,UN lkup
cnum:       lodi,R0 $0F
            rrl,R2
            rrl,R2
            rrl,R2
            rrl,R2
            andz    R2
            rrl,R1
            rrl,R1
            rrl,R1
            rrl,R1
            andi,R1 $F0
            andi,R2 $F0
            iorz    R1
            strz    R1
            lodz    R3
            iorz    R2
            strz    R2
            lodi,R0 1
            stra,R0 code
            bctr,UN lnum

;subroutine for outputing blanks
form:       lodi,R3 3
agap:       lodi,R0 spac
            bsta,UN cout
            bdrr,R3 agap
            retc,UN

;====================================================================
; load an Intel Hex format file
; '#' is the prompt to start the hex file download.
; print '.' for each record downloaded successfully.
; print 'E' for each record downloaded with a checksum error.
;====================================================================
load:       lodi,R0 '#'
            bsta,UN cout            ;prompt for a record
wait:       bsta,UN chin            ;get the first character of the record
            comi,R0 ':'             ;is it the start code ':'?
            bcfr,EQ wait            ;if not, go back for another character
            bsta,UN bin             ;get the byte count
            stra,R1 bytcnt          ;save the byte count
            stra,R1 cksum           ;initialize the checksum
            comi,R1 0               ;is the byte count zero?
            bcta,EQ lastrec         ;last record has byte count of zero
            bsta,UN bin             ;get the high byte of the address
            stra,R1 addhi           ;save the high byte of the address
            adda,R1 cksum           ;add the high byte to the checksum
            stra,R1 cksum           ;save the new checksum
            bsta,UN bin             ;get the low byte of the address
            stra,R1 addlo           ;save the low byte of the address
            adda,R1 cksum           ;add the low byte to the checksum
            stra,R1 cksum           ;save the new checksum
            bsta,UN bin             ;get the record type
            stra,R1 rectyp          ;save the record type
            adda,R1 cksum           ;add the record type to the checksum
            stra,R1 cksum           ;save the new checksum
            lodi,R2 0               ;clear R2
nextbyte:   coma,R2 bytcnt          ;compare the index in R2 to the count
            bctr,EQ checksum        ;equal means finished with this record
            bsta,UN bin             ;else, get the next data byte
            stra,R1 hdata           ;save the data byte
            adda,R1 cksum           ;add the data byte to the checksum
            stra,R1 cksum           ;save the new checksum
            loda,R0 hdata           ;load the data byte into R0
            stra,R0 *addhi,R2       ;store the data byte (in R0) into memory indexed by R2
            birr,R2 nextbyte        ;increment the count in R2 and branch back for another byte
checksum:   bsta,UN bin             ;get the record's checksum
            bsta,UN chin            ;get the carriage return at the end of the line
            adda,R1 cksum           ;add the record's checksum to the computed checksum
            comi,R1 0               ;is the sum zero?
            bcta,EQ checksum1       ;zero means the checksum is OK
            lodi,R0 'E'             ;else, 'E' for checksum error
            bctr,UN checksum2
checksum1:  lodi,R0 '.'
checksum2:  bsta,UN cout            ;print '.' or 'E' after each record
            bcta,UN wait            ;branch back for another data byte

lastrec:    bsta,UN bin             ;get the high byte of the address of the last record
            stra,R1 addhi           ;save the high byte of the address
            adda,R1 cksum           ;add the high byte of the address to the checksum
            stra,R1 cksum           ;save the new checksum
            bsta,UN bin             ;get the low byte of the address of the last record
            stra,R1 addlo           ;save the low byte of the address
            adda,R1 cksum           ;add the low byte of the address to the checksum
            stra,R1 cksum           ;save the new checksum
            bsta,UN bin             ;get the record type of the last record
            adda,R1 cksum           ;add the record type to the checksum
            stra,R1 cksum           ;save the new checksum
            bsta,UN bin             ;get the record's checksum
            bsta,UN chin            ;get the carriage return at the end of the line
            adda,R1 cksum           ;add the record's checksum to the computed checksum
            comi,R1 0               ;is the sum zero?
            bcta,EQ lastrec1        ;zero means the chesksum is OK
            lodi,R0 'E'             ;else, 'E' for checksum error
            bctr,UN lastrec2
lastrec1:   lodi,R0 '.'
lastrec2:   bsta,UN cout            ;echo the carriage return of the last record
            bsta,UN crlf            ;new line
            loda,R0 addhi           
            loda,R1 addlo
            iorz    R1
            bcfr,EQ gotoaddr        ;if addrhi and addrlo are not zero, branch to the address in addhi,addlo
            bcta,UN mbug            ;else, branch back to PIPBUG
            
gotoaddr:   bcta,UN *addhi          ;branch to the address in the last record         
          
;====================================================================
;delay 1 millisecond (996 microseconds) times value in R0
;uses R0 and R1 in register bank 1
;====================================================================          
delay:      ppsl    rs              ;9 select register bank 1
delay1:     lodi,R1 106             ;6
            bdrr,R1 $               ;954 microseconds
            bdrr,R0 delay1          ;9
            cpsl    rs              ;9 select register bank 0             
            retc,UN                 ;9
            
;            ds  $0800-$,0           ;fill empty space with zeros
            
	    db	$c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0
;	    db	$c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0
;	    db	$c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0

            org $400

;RAM definitions
com:        ds  1                   ;R0 saved here
            ds  1                   ;R1 in register bank 0 saved here
            ds  1                   ;R2 in register bank 0 saved here
            ds  1                   ;R3 in register bank 0 saved here
            ds  1                   ;R1 in register bank 1 saved here
            ds  1                   ;R2 in register bank 0 saved here
            ds  1                   ;R3 in register bank 0 saved here
            ds  1                   ;program status, upper saved here
            ds  1                   ;program status, lower saved here
xgot:       ds  2
            ds  2
temp:       ds  2                   ;addresses stored here
temq        ds  2
temr        ds  1
tems        ds  1
buff        ds  blen                ;input buffer
bptr        ds  1
cnt         ds  1
code        ds  1
mark        ds  bmax+1              ;used by breakpoint
hdat        ds  bmax+1              ;used by breakpoint
ldat        ds  bmax+1              ;used by breakpoint
hadr        ds  bmax+1              ;used by breakpoint
ladr        ds  bmax+1              ;used by breakpoint

hdata:      ds  1                   ;used by hex load - hex data byte
cksum:      ds  1                   ;used by hex load - checksum
bytcnt:     ds  1                   ;used by hex load - byte count
addhi:      ds  1                   ;used by hex load - address hi byte
addlo:      ds  1                   ;used by hex load - address lo byte
rectyp:     ds  1                   ;used by hex load - record type

	    org $480
transfer:
	lodi,r0	$AE	; serial interface initialize
	wrte,r0 SERBASE+2	; async, nopar, 8bit 16x rate
	lodi,r0 $FE		; 19200bps, 16x, BKDET
	wrte,r0 SERBASE+2
	lodi,r0	$37		; /RTS, /DTR low, error reset, TX/RX enable
	wrte,r0	SERBASE+3
    cpsl    rs			; set to register bank 0
TSTART:	
	eorz	r0
	strz	r2	; clear counter
	lodi,r1	$FF	; 0 - 1
;
TLOOP:
	loda,r0	*TADR0,r1,+
	stra,r0 *TADR0,r1
	loda,r0	*TADR1,r1
	stra,r0 *TADR1,r1
	loda,r0	*TADR2,r1
	stra,r0 *TADR2,r1
	loda,r0	*TADR3,r1
	stra,r0 *TADR3,r1
	loda,r0	*TADR4,r1
	stra,r0 *TADR4,r1
	loda,r0	*TADR5,r1
	stra,r0 *TADR5,r1
	loda,r0	*TADR6,r1
	stra,r0 *TADR6,r1
	loda,r0	*TADR7,r1
	stra,r0 *TADR7,r1
	loda,r0	*TADR8,r1
	stra,r0 *TADR8,r1
	loda,r0	*TADR9,r1
	stra,r0 *TADR9,r1
	loda,r0	*TADR10,r1
	stra,r0 *TADR10,r1
	loda,r0	*TADR11,r1
	stra,r0 *TADR11,r1
	loda,r0	*TADR12,r1
	stra,r0 *TADR12,r1
	loda,r0	*TADR13,r1
	stra,r0 *TADR13,r1
	loda,r0	*TADR14,r1
	stra,r0 *TADR14,r1
	loda,r0	*TADR15,r1
	stra,r0 *TADR15,r1
	loda,r0	*TADR16,r1
	stra,r0 *TADR16,r1
	loda,r0	*TADR17,r1
	stra,r0 *TADR17,r1
	loda,r0	*TADR18,r1
	stra,r0 *TADR18,r1
	loda,r0	*TADR19,r1
	stra,r0 *TADR19,r1
	loda,r0	*TADR20,r1
	stra,r0 *TADR20,r1
	loda,r0	*TADR21,r1
	stra,r0 *TADR21,r1
	loda,r0	*TADR22,r1
	stra,r0 *TADR22,r1
	loda,r0	*TADR23,r1
	stra,r0 *TADR23,r1
	loda,r0	*TADR24,r1
	stra,r0 *TADR24,r1
	loda,r0	*TADR25,r1
	stra,r0 *TADR25,r1
	loda,r0	*TADR26,r1
	stra,r0 *TADR26,r1
	loda,r0	*TADR27,r1
	stra,r0 *TADR27,r1
	loda,r0	*TADR28,r1
	stra,r0 *TADR28,r1
	loda,r0	*TADR29,r1
	stra,r0 *TADR29,r1
	loda,r0	*TADR30,r1
	stra,r0 *TADR30,r1
	loda,r0	*TADR31,r1
	stra,r0 *TADR31,r1
	lodi,r0	$2A		; asterisk
	bsta,UN	cout
	subi,r2	1
	bcfa,eq	TLOOP
;
	lodi,r1 $00
	lodi,r0 $07	;lodi,r3 63
	stra,r0 *TADR0,r1
	lodi,r0 $3F
	stra,r0 *TADR0,r1,+
	lodi,r0 $20	; eorz r0
	stra,r0 *TADR0,r1,+
;	lodi,r0	$00
;	stra,r0 $0004,r1
;	lodi,r0 $80
;	stra,r0 $0005,r1
	wrtc,r0		;dummy write to set RAM
	lodi,r0	$0D
	bsta,UN	cout
	lodi,r0	$0A
	bsta,UN	cout
        lodi,r3 63
        eorz    R0
	bcta,un init
;	***

TADR0: DB	$00,$00
TADR1: DB	$01,$00
TADR2: DB	$02,$00
TADR3: DB	$03,$00
TADR4: DB	$04,$00
TADR5: DB	$05,$00
TADR6: DB	$06,$00
TADR7: DB	$07,$00
TADR8: DB	$08,$00
TADR9: DB	$09,$00
TADR10: DB	$0A,$00
TADR11: DB	$0B,$00
TADR12: DB	$0C,$00
TADR13: DB	$0D,$00
TADR14: DB	$0E,$00
TADR15: DB	$0F,$00
TADR16: DB	$10,$00
TADR17: DB	$11,$00
TADR18: DB	$12,$00
TADR19: DB	$13,$00
TADR20: DB	$14,$00
TADR21: DB	$15,$00
TADR22: DB	$16,$00
TADR23: DB	$17,$00
TADR24: DB	$18,$00
TADR25: DB	$19,$00
TADR26: DB	$1A,$00
TADR27: DB	$1B,$00
TADR28: DB	$1C,$00
TADR29: DB	$1D,$00
TADR30: DB	$1E,$00
TADR31: DB	$1F,$00

            org $600
            
;====================================================================
; menu displayed on start-up.
;====================================================================
start:      cpsl    $FF                 ;clear all flags in program status, lower
            ppsu    ii                  ;set Interrupt Inhibit bit in program status, upper
            cpsu    flag                ;clear serial output low or send 'SPACE'
            eorz    R0
;            stra,R0 LEDport             ;turn off LEDs            
            bdrr,R0 $                   ;delay 9 * 256 = 2304 microseconds                
            ppsu    flag                ;set serial output high or send 'MARK'
            lodi,R3 $FF                 ;R3 = -1
start1:     loda,R0 starttxt,R3,+       ;load the character into R0 from the text below indexed by R3
            comi,R0 $00                 ;is it zero? (end of string)
            bctr,EQ start2              ;skip the next part if zero
            bsta,UN cout                ;else, print the character using pipbug serial output
            bctr,UN start1              ;loop back for the next character in the string

start2:     bsta,UN chin                ;get a character using pipbug serial input
            comi,R0 '1'                 ;is it "1"?
            bcta,EQ gopip               ;yes, branch
            comi,R0 '2'                 ;is it "2"?
            bcta,EQ gocold              ;yes, branch
            comi,R0 '3'                 ;is it "3"?
            bcta,EQ gowarm              ;yes, branch
            bctr,UN start2              ;no matches, branch back for another character
            
gopip:      bsta,UN crlf                ;new line
            bcta,UN mbug                ;branch to PIPBUG
            
gocold:     lodi,R3 $FF                 ;R3 is pre-incremented in the instruction below
gocold1:    loda,R0 bastxt,R3,+         ;load the character into R0 from the text below indexed by R3
            comi,R0 $00                 ;is it zero? (end of string)
            bcta,EQ basic               ;branch to BASIC cold start
            bsta,UN cout                ;else, print the character using pipbug serial output
            bctr,UN gocold1             ;loop back for the next character in the string
            
gowarm:     bsta,UN crlf                ;new line
            bcta,UN basic+$0D           ;branch to BASIC warm start
            
starttxt:   db CR,LF,LF
            db "2650 Single Board Computer",CR,LF,LF
            db "1 - PIPBUG",CR,LF
            db "2 - BASIC Cold Start",CR,LF
            db "3 - BASIC Warm Start",CR,LF
            db "Choice? (1-3)",0
            
bastxt      db CR,LF,LF,"Remember to type 'NEW'",0            

;====================================================================
; help displayed when '?' is entered at the PIPBUG prompt
;====================================================================
help:       bsta,UN crlf                ;start on a new line
            lodi,R3 $FF                 ;R3 is pre-incremented in the instruction below
help1:      loda,R0 helptxt,R3,+        ;load the character into R0 from the text below indexed by R3
            comi,R0 $00                 ;is it zero? (end of string)
            bcta,EQ mbug                ;branch back to pipbug when done
            bsta,UN cout                ;else, print the character using pipbug serial output
            bctr,UN help1               ;loop back for the next character in the string

helptxt:    db "PIPBUG Commands:",CR,LF,LF
            db "Alter Memory aaaa  Aaaaa<CR>",CR,LF
            db "Set Breakpoint n   Bn aaaa<CR>",CR,LF
            db "Clear Breakpoint n Cn<CR>",CR,LF
            db "Goto Address aaaa  Gaaaa<CR>",CR,LF            
            db "Load Hex File      L<CR>",CR,LF
            db "See Register Rn    Sn<CR>",CR,LF,LF,0
            
;====================================================================            
;wait for a serial input character. echo the character bit by bit. 
;return the character in R0.
;uses R0, R1 and R2 in register bank 1
;====================================================================
;chio:       ppsl    rs              ;select register bank 1
;            cpsl    WC
;            lodi,R1 0
;            lodi,R2 9               ;8 bits plus stop bit
;chio1:      spsu                    ;test for the start bit
;            bctr,LT chio1           ;branch back until the start bit is detected
;            bsta,UN chio5           ;delay to middle of the start bit
;            cpsu    FLAG            ;echo the start bit by clearing the flag bit
;            nop                     ;timing adjustment
;            nop
;            nop
;         
;chio2:      bsta,UN chio5           ;9 one bit time delay
;            spsu                    ;6 read the sense flag by store program status in R0
;            andi,R0 $80             ;6 mask off everthing except the sense flag
;            rrr,R1                  ;6 rotate right one position
;            iorz    R1              ;6 OR with bits already received in R1
;            strz    R1              ;6 store the result in R1
;            bctr,LT chio3           ;9 branch if the received bit was one
;            cpsu    FLAG            ;9 else, echo '0' by clearing the flag bit
;            bctr,UN chio4           ;9
;chio3:      ppsu    FLAG            ;9 echo '1' by setting the flag bit
;            bctr,UN chio4           ;9
;chio4:      bdrr,R2 chio2           ;9 branch back for all 9 bits
;            lodz    R1              ;load the character (now in R1) into R0
;            cpsl    rs              ;select register bank 0
;            retc,UN
;            
;;timing for 9600 bps
;chio5:      lodi,R0 1               ;6
;            nop
;            bdrr,R0 $               ;117 or 72
;            retc,UN                 ;9               
chio:	     bcta,UN	chin
            
            ;MicroWorld BASIC
            org $0800
basic:      db $3F,$15,$8E,$CE,$67,$48,$FA,$7B,$04,$04,$3F,$08,$59,$04,$40,$92
            db $04,$02,$93,$3F,$13,$FA,$04,$3E,$CC,$07,$69,$04,$20,$3F,$09,$53
            db $3F,$08,$A9,$9E,$14,$15,$3F,$09,$6B,$0C,$07,$6C,$64,$01,$CC,$07
            db $6C,$1B,$5A,$3B,$35,$0E,$67,$49,$CF,$67,$49,$0E,$27,$49,$CF,$27
...
			get microworld basic from https://github.com/jim11662418/Signetics_2650_Single_Board_Computer
...
            db $FB,$6D,$1F,$1E,$A7,$04,$B6,$05,$04,$8D,$45,$C5,$94,$CD,$65,$C5
            db $04,$66,$59,$75,$B5,$01,$16,$3B,$09,$3B,$1C,$17,$CE,$05,$CF,$CD
            db $05,$CE,$05,$04,$06,$01,$0E,$A5,$CD,$50,$CE,$E5,$CD,$EE,$05,$CF
            db $98,$74,$75,$01,$F9,$6E,$17,$0C,$85,$CD,$75,$01,$84,$01,$CC,$85
            db $CD,$17,$3F,$1D,$95,$04,$04,$CC,$05,$CF,$0C,$05,$C3,$1E,$1E,$BC
            db $77,$08,$E4,$06,$9E,$1E,$A7,$3B,$49,$3B,$5C,$1B,$75,$1F,$08,$33
            
;            ds  $6000-$,0               ;fill empty space with zeros
            
            end
