;;; L-chika for Sig 2650A
;;; 2023/09/21 efialtes_htn
;;;
	CPU	2650
	INTSYNTAX +H'hex'
;	
TARGET:	EQU	"2650"
;

STARTUP: ORG	0
	lodz	r0
	lodz	r3
	lpsu
	bcta,un	CSTART
;
	ORG	H'0080'
CSTART:	
CSS1:	lodi,r2 0
CSS2:	lodi,r1	0
CSS3:	subi,r1 1
	brnr,r1	CSS3
	subi,r2	1
	brnr,r2	CSS2
	spsu
	eori,r0 H'40'
	lpsu
	bcta,un	CSTART
	end
