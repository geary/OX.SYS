	page	60,132
	title	AuxDrv - Monochrome AUX driver

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; This device directs AUX output to the Monochrome display, and AUX input to
; the BIOS.  At boot time, it saves the vectors for INT 9 and INT 16h, and
; when AUX input is requested temporarily restores them.  So, it can be used
; for AUX input and output from inside Windows.

; You should still use the /M option with SymDeb rather than /"=AUX", because
; SymDeb has a bug where it puts out memory allocation messages to CON even
; though you said /"=AUX".

; It's also handy in DOS; you can do, for example, TYPE FOO >AUX and it will
; go to the Monochrome screen.	You can even say CTTY AUX if you don't feel
; like saying MODE MONO...

; In case you're wondering why the screen output code is so simple (i.e. there
; is no "current row" variable), it always outputs to the last row of the
; screen, instead of starting at the top.  Don't laugh, it works fine and made
; it easier to code this pup.

; This driver is in the public domain.	If you find it useful, how about
; returning the favor and putting some of your own favorite utilities in
; the public domain, too?  (***with source code!!!***)

; Michael Geary (GEnie: GEARY; BIX: GEARY; CompuServe: 76146,42)

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; Far return so we don't have to use PROCs

retf	MACRO
	db	0CBh
	ENDM

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; request header entries

cmdCode 	equ	2
status		equ	3

ndInputChar	equ	13

brkOff		equ	14
brkSeg		equ	brkOff+2

xferOff 	equ	14
xferSeg 	equ	xferOff+2

xferCount	equ	18

; constants

BS		equ	08h
TAB		equ	09h
LF		equ	0Ah
CR		equ	0Dh

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Zseg	    segment at 0

	    org     9*4
KbdInt	    label   dword
KbdIntOff   dw	    ?
KbdIntSeg   dw	    ?

	    org     16h*4
KbdBios     label   dword
KbdBiosOff  dw	    ?
KbdBiosSeg  dw	    ?

Zseg	    endS

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Cseg	segment para public 'code'

		assume	cs:Cseg, ds:nothing, es:nothing
begin:

; device driver header

nextDev 	dd	-1
attribute	dw	1000100000000000b
strategy	dw	devStrategy
interrupt	dw	devInt
devName 	db	'AUX     '

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

rhAddr		label	dword
rhOff		dw	?
rhSeg		dw	?

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

funTab		label	word
		dw	init
		dw	mediaCheck
		dw	buildBpb
		dw	ioCtlIn
		dw	input
		dw	ndInput
		dw	inStat
		dw	inFlush
		dw	output
		dw	outVerify
		dw	outStat
		dw	outFlush
		dw	ioCtlOut
		dw	open
		dw	close

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

scrMinOff	equ	160*24
scrMaxOff	equ	160*25

scrCurOff	dw	scrMinOff
		dw	0B000h

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

SaveKbdInt	label	dword
SaveKbdIntOff	dw	0
SaveKbdIntSeg	dw	0

SaveKbdBios	label	dword
SaveKbdBiosOff	dw	0
SaveKbdBiosSeg	dw	0

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

devStrategy:
	mov	cs:rhSeg, es
	mov	cs:rhOff, bx
	retf

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

devInt:
	pushf
	push	ds
	push	es
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	cld

	les	bx, cs:rhAddr
	mov	al, es:[bx].cmdCode
	shl	al, 1
	lea	di, funTab
	xor	ah, ah
	add	di, ax
	jmp	word ptr[di]

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

outVerify:
output:
	mov	cx, es:[bx].xferCount	; CX = # bytes to write
	lds	si, es:[bx].xferOff	; DS:SI --> text

	les	di, dword ptr scrCurOff

outLoop:
	lodsb

	cmp	al, CR
	ja	outChar
	je	outCR

	cmp	al, LF
	je	outLF

	cmp	al, TAB
	je	outTAB

	cmp	al, BS
	je	outBS

outChar:
	stosb
	inc	di
	cmp	di, scrMaxOff
	jb	outDone

	mov	di, scrMinOff

outLF:
	push	ds
	push	es
	push	si
	push	di
	push	cx

	mov	ax, es
	mov	ds, ax

	xor	di, di			; Scroll screen
	mov	si, 160
	mov	cx, 24*80
	rep movsw

	mov	ax, 0720h		; Blank bottom line
	mov	cx, 80
	rep stosw

	pop	cx
	pop	di
	pop	si
	pop	es
	pop	ds

	jmp	outDone

outBS:
	cmp	di, scrMinOff
	je	outDone
	sub	di, 2
	jmp	outDone

outTAB:
	or	di, 0Eh
	jmp	outDone

outCR:
	mov	di, scrMinOff

outDone:
	loop	outLoop
	mov	scrCurOff, di

	mov	dx, 3B4h
	shr	di, 1			; Set cursor position
	mov	ax, di
	mov	al, 0Eh
	out	dx, ax
	mov	ax, di
	xchg	ah, al
	mov	al, 0Fh
	out	dx, ax

	jmp	exit

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

input:
	call	SetOldKbdInts

	mov	ah, 0
	int	16h

	les	di, es:[bx].xferOff	; ES:DI --> text
	stosb
	mov	byte ptr es:[bx].xferCount, 1

	call	SetNewKbdInts

	jmp	exit

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ndInput:
	call	SetOldKbdInts

	mov	ah, 1
	int	16h
	jz	ndInputNone

	mov	es:[bx].ndInputChar, al

	call	SetNewKbdInts

	jmp	exit

ndInputNone:
	call	SetNewKbdInts

	les	bx, rhAddr
	or	word ptr es:status[bx], 0300h	; set busy flag

	jmp	exit1

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

inStat:
	call	SetOldKbdInts

	mov	ah, 1
	int	16h
	jz	ndInputNone

	call	SetNewKbdInts

	jmp	exit

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

inFlush:
	call	SetOldKbdInts

inFlushLoop:
	mov	ah, 1
	int	16h
	jz	inFlushDone

	mov	ah, 0
	int	16h
	jmp	inFlushLoop

inFlushDone:
	call	SetNewKbdInts

	jmp	exit

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

open:
	mov	dx, 3B4h		; Set standard monochrome cursor
	mov	ax, 0B0Ah
	out	dx, ax
	mov	ax, 0C0Bh
	out	dx, ax

close:
	jmp	exit

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

mediaCheck:
buildBpb:
ioCtlIn:
ioCtlOut:
outStat:
outFlush:

exit:
	les	bx, rhAddr
	or	word ptr es:status[bx], 0100h
exit1:
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	pop	es
	pop	ds
	popf
	retf

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

SetOldKbdInts:

	push	es
	push	ax
	xor	ax, ax
	mov	es, ax
	assume	es:Zseg

	CLI

	mov	ax, SaveKbdIntOff
	xchg	ax, KbdIntOff
	mov	SaveKbdIntOff, ax

	mov	ax, SaveKbdIntSeg
	xchg	ax, KbdIntSeg
	mov	SaveKbdIntSeg, ax

	mov	ax, SaveKbdBiosOff
	xchg	ax, KbdBiosOff
	mov	SaveKbdBiosOff, ax

	mov	ax, SaveKbdBiosSeg
	xchg	ax, KbdBiosSeg
	mov	SaveKbdBiosSeg, ax

	STI

	pop	ax
	pop	es
	assume	es:nothing

	ret

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

SetNewKbdInts:

	push	es
	push	ax
	xor	ax, ax
	mov	es, ax
	assume	es:Zseg

	CLI

	mov	ax, SaveKbdIntOff
	mov	KbdIntOff, ax

	mov	ax, SaveKbdIntSeg
	mov	KbdIntSeg, ax

	mov	ax, SaveKbdBiosOff
	mov	KbdBiosOff, ax

	mov	ax, SaveKbdBiosSeg
	mov	KbdBiosSeg, ax

	STI

	pop	ax
	pop	es
	assume	es:nothing

	ret

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

init:	; everything from here on is discarded

	push	es
	xor	ax, ax
	mov	es, ax
	assume	es:Zseg

	mov	ax, KbdIntOff
	mov	SaveKbdIntOff, ax
	mov	ax, KbdIntSeg
	mov	SaveKbdIntSeg, ax

	mov	ax, KbdBiosOff
	mov	SaveKbdBiosOff, ax
	mov	ax, KbdBiosSeg
	mov	SaveKbdBiosSeg, ax

	pop	es
	assume	es:nothing

	mov	es:brkSeg[bx], cs
	mov	es:word ptr brkOff[bx], offset init

	jmp	exit

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Cseg	endS

	end	begin
