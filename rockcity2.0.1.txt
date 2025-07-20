;*********************************************************
;
;  ROCK CITY
;
;  MSXPen LAST VERSION VER 2.0.1
;
;  PROGRAM by msx2rockcity
;
;  (C) Copyright 1993-2025 msx2rockcity
;
;*********************************************************
;-------------------------------------------
;
;  MAIN1
;
;-------------------------------------------
GTSTCK:   EQU     00D5H
GTTRIG:   EQU     00D8H
NNEG:     EQU     44EDH
BREAKX:   EQU     00B7H
CALSLT:   EQU     001CH
WRTPSG:   EQU	  0093H
EXPTBL:   EQU     0FCC1H
          ORG     09000H
;
;---- SCREEN & COLOR SET ----
;
START:    LD      A,(EXPTBL)
          LD      HL,0006H
          CALL    000CH
          LD      (RDVDP),A
          LD      A,(EXPTBL)
          LD      HL,0007H
          CALL    000CH
          LD      (RDVDP+1),A
          LD      A,7
          LD      (PLDAT),A
          CALL    PALETE
          ;
          LD      A,15
          LD      HL,0
          LD      (0F3E9H),A
          LD      (0F3EAH),HL
          LD      A,(0FFE7H)
          OR      00000010B
          LD      (0FFE7H),A
          LD      A,5
          LD      IX,005FH
          LD      IY,(EXPTBL-1)
          CALL    CALSLT
          ;
          DI
          LD      BC,(RDVDP+1)
          INC     C
          LD      A,22
          OUT     (C),A
          LD      A,23+80H
          OUT     (C),A
          EI
          ;
          LD      (SSTACK),SP
          JP      TITLE
;
;---- MAIN ROUTINE ----
;
MAIN:     PUSH    IX
          PUSH    HL
          PUSH    DE
          PUSH    BC
          ;
MAINS:    PUSH    AF
          LD      IX,BREAKX
          LD      IY,(EXPTBL-1)
          CALL    CALSLT
          JP      C,RETURN
          ;
          CALL    CLS
          LD      A,(SWHICH)
          BIT     0,A
          CALL    NZ,SCALE
          ;
          BIT     1,A
          JR      Z,M1MA0
          LD      IX,MASTER
          CALL    MALTI
          BIT     2,A
          CALL    NZ,MALTI
          ;
M1MA0:    BIT     3,A
          JR      Z,M1MA2
          LD      HL,PORIDAT
          LD      DE,16
          LD      B,E
          PUSH    AF
M1MA1:    LD      A,(HL)
          OR      A
          JR      Z,$+8
          PUSH    HL
          POP     IX
          CALL    MALTI
          ADD     HL,DE
          DJNZ    M1MA1
          POP     AF
          ;
M1MA2:    BIT     6,A
          CALL    NZ,WRLIFE
          ;
          PUSH    AF
          LD      A,(VIJUAL)
          XOR     1
          LD      (VIJUAL),A
          RRCA
          RRCA
          RRCA
          OR      00011111B
          LD      BC,(RDVDP+1)
          INC     C
          DI
          OUT     (C),A
          LD      A,80H+2
          OUT     (C),A
          EI
          POP     AF
          ;
          BIT     4,A
          JR      Z,M1MA3
          LD      A,(LIFE)
          OR      A
          JR      NZ,M1MA3
          LD      HL,(DEADRT)
          JP      (HL)
          ;
M1MA3:    POP     AF
          DEC     A
          JP      NZ,MAINS
          ;
          POP     BC
          POP     DE
          POP     HL
          POP     IX
          RET
          ;
RETURN:   LD      SP,(SSTACK)
          CALL    SDOFF
          JP      START
;
;---- PORY WRITE ----
;
MALTI:    PUSH    AF
          PUSH    BC
          PUSH    DE
          PUSH    HL
          LD      (MALRET+1),SP
          LD      HL,PARET
          PUSH    HL
          LD      H,(IX+6)
          LD      L,(IX+5)
          JP      (HL)
PARET:    BIT     0,(IX+15)
          JP      NZ,MALRET
          ;
          XOR     A
          LD      (IX+2),A
          LD      L,(IX+3)
          LD      H,(IX+4)
          LD      B,(HL)
          INC     HL
          LD      C,(HL)
          INC     HL
          LD      DE,HYOUJI
MLOOP:    PUSH    BC
          PUSH    DE
          PUSH    HL
          PUSH    BC
          PUSH    DE
          LD      DE,WORK
          CALL    TURN
          POP     DE
          POP     BC
          LD      A,B
          CP      C
          LD      HL,WORK
          CALL    NC,MONMAK
          POP     HL
          INC     HL
          INC     HL
          INC     HL
          POP     DE
          INC     DE
          INC     DE
          POP     BC
          DJNZ    MLOOP
          ;
          PUSH    HL
          CALL    TUCH
          POP     BC
SCREEN:   LD      A,(BC)
          ADD     A,A
          LD      HL,WORK+1
          ADD     A,L
          JR      NC,$+3
          INC     H
          LD      L,A
          LD      D,(HL)
          INC     HL
          LD      E,(HL)
M1SC1:    INC     BC
          LD      A,(BC)
          ADD     A,A
          LD      HL,WORK+1
          ADD     A,L
          JR      NC,$+3
          INC     H
          LD      L,A
          PUSH    DE
          LD      D,(HL)
          INC     HL
          LD      E,(HL)
          POP     HL
          ;
          LD      A,(IX+2)
          OR      A
          JR      NZ,BREAK
          BIT     4,(IX+15)
          JR      Z,M1SSET
BREAK:    LD      A,R
          AND     00011111B
          RRA
          JR      NC,$+4
          NEG
          ADD     A,D
          LD      D,A
          ADD     A,119
          AND     00111111B
          RRA
          JR      NC,$+4
          NEG
          ADD     A,L
          LD      L,A
          ;
M1SSET:   LD      (LIDAT),HL
          LD      (LIDAT+2),DE
          CALL    LINE
          INC     BC
          LD      A,(BC)
          DEC     BC
          OR      A
          JR      NZ,M1SC1
          INC     BC
          INC     BC
          LD      A,(BC)
          OR      A
          JR      NZ,SCREEN
          POP     HL
          POP     DE
          POP     BC
          POP     AF
          RET
          ;
MALEND:   XOR     A
          LD      (IX+0),A
MALRET:   LD      SP,0
          POP     HL
          POP     DE
          POP     BC
          POP     AF
          RET
;
; POINT TURN
;
TURN:     PUSH    DE
          LD      B,(HL)
          INC     HL
          LD      C,(HL)
          INC     HL
          LD      A,(IX+10)
          AND     00011111B
          CALL    NZ,KAITEN
          LD      D,B
          LD      B,(HL)
          LD      A,(IX+11)
          AND     00011111B
          CALL    NZ,KAITEN
          LD      E,C
          LD      C,B
          LD      B,D
          LD      A,(IX+12)
          AND     00011111B
          CALL    NZ,KAITEN
          POP     HL
          BIT     1,(IX+15)
          JR      Z,$+8
          SLA     B
          SLA     C
          SLA     E
          BIT     2,(IX+15)
          JR      Z,$+8
          SRA     B
          SRA     C
          SRA     E
          JP      SEARCH
          ;
KAITEN:   PUSH    DE
          PUSH    HL
          LD      HL,SINDAT
          ADD     A,A
          ADD     A,L
          JR      NC,$+3
          INC     H
          LD      L,A
          LD      D,(HL)
          INC     HL
          LD      E,(HL)
          LD      A,D
          LD      H,B
          OR      A
          CALL    NZ,TIMES
          LD      L,A
          LD      A,E
          LD      H,C
          OR      A
          CALL    NZ,TIMES
          LD      H,A
          PUSH    HL
          LD      A,D
          LD      H,C
          OR      A
          CALL    NZ,TIMES
          LD      L,A
          LD      A,E
          LD      H,B
          OR      A
          CALL    NZ,TIMES
          SUB     L
          LD      B,A
          POP     HL
          LD      A,H
          ADD     A,L
          LD      C,A
          POP     HL
          POP     DE
          RET
          ;
TIMES:    INC     H
          DEC     H
          JR      NZ,$+4
          XOR     A
          RET
          PUSH    HL
          PUSH    BC
          PUSH    DE
          LD      D,0
          LD      E,H
          LD      HL,0
          SLA     A   ;SIN<0
          LD      B,A
          JR      NC,$+5
          LD      HL,NNEG
          LD      (NEGPAT),HL
          LD      HL,0
          LD      A,E
          OR      A
          JP      P,$+8
          LD      HL,NNEG
          NEG
          LD      (NEGPT2),HL
          LD      E,A
          LD      A,B
          CP      0FEH  ;SIN=1
          JR      NZ,$+5
          LD      A,E
          JR      NEGPAT
          LD      HL,0
          LD      B,8
M1LP2:    RRA
          JR      NC,$+3
          ADD     HL,DE
          SLA     E
          RL      D
          DJNZ    M1LP2
          LD      A,H
NEGPAT:   NOP
          NOP
NEGPT2:   NOP
          NOP
          POP     DE
          POP     BC
          POP     HL
          RET
SINDAT:
DEFB        0,127, 25,126
DEFB       49,119, 71,107
DEFB       91, 91,107, 71
DEFB      119, 49,126, 25
DEFB      127,  0,126,153
DEFB      119,177,107,199
DEFB       91,219, 71,235
DEFB       49,247, 25,254
DEFB        0,255,153,254
DEFB      177,247,199,235
DEFB      219,219,235,199
DEFB      247,177,254,153
DEFB      255,  0,254, 25
DEFB      247, 49,235, 71
DEFB      219, 91,199,107
DEFB      177,119,153,126
;
; SEARCH IN GAGE
;
SEARCH:   LD      D,B
          LD      A,B
          ADD     A,(IX+7)
          EX      AF,AF'
          RL      D
          JR      NC,$+7
          EX      AF,AF'
          JR      NC,SERRET
          JR      $+5
          EX      AF,AF'
          JR      C,SERRET
          LD      (HL),A
          INC     HL
          LD      D,E
          LD      A,E
          ADD     A,(IX+8)
          EX      AF,AF'
          RL      D
          JR      NC,$+7
          EX      AF,AF'
          JR      NC,SERRET
          JR      $+5
          EX      AF,AF'
          JR      C,SERRET
          LD      (HL),A
          INC     HL
          SRA     C
          LD      D,C
          LD      A,C
          ADD     A,(IX+9)
          EX      AF,AF'
          RL      D
          JR      NC,$+7
          EX      AF,AF'
          JR      NC,SERRET
          JR      $+5
          EX      AF,AF'
          JR      C,SERRET
          LD      (HL),A
          BIT     3,(IX+15)
          RET     NZ
          ;
          LD      DE,GAGE+5
          EX      DE,HL
          CP      (HL)
          RET     NC
          DEC     HL
          CP      (HL)
          RET     C
          LD      A,(IX+2)
          OR      A
          RET     NZ
          EX      DE,HL
          DEC     DE
          DEC     HL
          LD      A,(DE)
          CP      (HL)
          RET     C
          DEC     DE
          LD      A,(DE)
          CP      (HL)
          RET     NC
          DEC     DE
          DEC     HL
          LD      A,(DE)
          CP      (HL)
          RET     C
          DEC     DE
          LD      A,(DE)
          CP      (HL)
          RET     NC
          LD      A,1
          LD      (IX+2),A
          RET
          ;
SERRET:   BIT     5,(IX+15)
          JP      Z,MALEND
          JP      MALRET
;
; TUCH ROUTINE
;
TUCH:     LD      H,0
          LD      L,(IX+13)
          LD      (LIDAT+4),HL
          LD      A,(IX+2)
          OR      A
          RET     Z
          ;
          LD      HL,JPTUCH
          LD      A,(IX+14)
          AND     15
          ADD     A,A
          LD      E,A
          LD      D,0
          ADD     HL,DE
          LD      E,(HL)
          INC     HL
          LD      D,(HL)
          EX      DE,HL
          JP      (HL)
          ;
JPTUCH:   DEFS    32
;
; MONITOR POINT
;
MONMAK:   LD      A,(HL)
          LD      C,0
          INC     HL
          INC     HL
          ADD     A,(HL)
          RL      C
          ADD     A,(HL)
          JR      NC,$+3
          INC     C
          RR      C
          RRA
          RR      C
          RRA
          RR      C
          LD      B,A
          PUSH    DE
          LD      D,0
          LD      A,(HL)
          ADD     A,64
          RL      D
          LD      E,A
          CALL    WARIZU
          POP     DE
          LD      (DE),A
          DEC     HL
          INC     DE
          LD      A,(HL)
          LD      C,0
          INC     HL
          ADD     A,(HL)
          RL      C
          ADD     A,(HL)
          JR      NC,$+3
          INC     C
          RR      C
          RRA
          RR      C
          RRA
          RR      C
          LD      B,A
          PUSH    DE
          LD      D,0
          LD      A,(HL)
          ADD     A,64
          RL      D
          LD      E,A
          CALL    WARIZU
          POP     DE
          LD      (DE),A
          RET
          ;
WARIZU:   PUSH    HL
          LD      H,0
          LD      L,B
          LD      B,8
WALOOP:   RL      C
          RL      L
          RL      H
          OR      A
          SBC     HL,DE
          JR      NC,$+4
          ADD     HL,DE
          SCF
          CCF
          RLA
          DJNZ    WALOOP
          POP     HL
          RET
;
; LINE ROUTINE
;
LINE:     PUSH    AF
          PUSH    BC
          PUSH    DE
          PUSH    HL
          LD      BC,(RDVDP)
          INC     B
          INC     C
          LD      L,C
          LD      C,B
          LD      DE,028FH
          DI
          OUT     (C),D
          OUT     (C),E
          LD      DE,2491H
          OUT     (C),D
          OUT     (C),E
          LD      H,C
          LD      C,L
WAITLI:   IN      A,(C)
          AND     1
          JR      NZ,WAITLI
          LD      C,H
          OUT     (C),A
          LD      A,8FH
          OUT     (C),A
          INC     C
          INC     C
          ;
          LD      HL,(LIDAT)
          LD      DE,(LIDAT+2)
          XOR     A
          OUT     (C),H
          OUT     (C),A
          OUT     (C),L
          LD      A,(VIJUAL)
          XOR     1
          OUT     (C),A
          LD      B,0
          LD      A,D
          SUB     H
          JR      NC,LINE1
          NEG
          SET     2,B
LINE1:    LD      D,A
          LD      A,E
          SUB     L
          JR      NC,LINE2
          NEG
          SET     3,B
LINE2:    LD      E,A
          CP      D
          JR      C,LINE3
          SET     0,B
          LD      A,D
          LD      D,E
          LD      E,A
LINE3:    XOR     A
          OUT     (C),D
          OUT     (C),A
          OUT     (C),E
          OUT     (C),A
          LD      DE,(LIDAT+4)
          OUT     (C),E
          OUT     (C),B
          LD      A,D
          OR      01110000B
          OUT     (C),A
          EI
          POP     HL
          POP     DE
          POP     BC
          POP     AF
          RET
          ;
LIDAT:    DEFB    0,0  ;X ,Y
          DEFB    0,0  ;X',Y'
          DEFB    0,0  ;COLOR
;
; CLS ROUTINE
;
CLS:      PUSH    AF
          PUSH    BC
          PUSH    DE
          PUSH    HL
          LD      A,(VIJUAL)
          XOR     1
          LD      (CMDDAT+3),A
          LD      BC,(RDVDP)
          LD      DE,028FH
          INC     B
          INC     C
          LD      L,C
          LD      C,B
          DI
          OUT     (C),D
          OUT     (C),E
          LD      DE,2491H
          OUT     (C),D
          OUT     (C),E
          INC     C
          INC     C
          LD      H,C
          LD      C,L
WAITCL:   IN      A,(C)
          AND     1
          JR      NZ,WAITCL
          LD      C,H
          LD      HL,CMDDAT
          OUTI
          OUTI
          OUTI
          OUTI
          OUTI
          OUTI
          OUTI
          OUTI
          OUTI
          OUTI
          OUTI
          DEC     C
          DEC     C
          OUT     (C),A
          LD      A,8FH
          OUT     (C),A
          EI
          POP     HL
          POP     DE
          POP     BC
          POP     AF
          RET
          ;
CMDDAT:   DEFW    0,22
          DEFW    256,212
          DEFB    0
          DEFB    00000000B
          DEFB    11000000B
;
; SCALE SUB
;
SCALE:    PUSH    AF
          PUSH    BC
          PUSH    DE
          PUSH    HL
          LD      A,(SCOLOR)
          LD      L,A
          LD      H,0
          LD      (LIDAT+4),HL
          LD      L,154
          LD      (LIDAT),HL
          LD      H,255
          LD      (LIDAT+2),HL
          CALL    LINE
          LD      A,(SCOLOR+1)
          AND     3
          LD      H,A
          LD      A,(POINTA)
          ADD     A,H
          AND     7
          LD      (POINTA),A
          LD      HL,POINTA+1
          ADD     A,L
          JR      NC,$+3
          INC     H
          LD      L,A
          LD      B,4
SCLOOP:   LD      A,(HL)
          LD      E,A
          LD      D,0
          LD      (LIDAT),DE
          LD      D,255
          LD      (LIDAT+2),DE
          CALL    LINE
          LD      DE,8
          ADD     HL,DE
          DJNZ    SCLOOP
          POP     HL
          POP     DE
          POP     BC
          POP     AF
          RET
POINTA:
DEFB      0
DEFB      154,154,155,156
DEFB      157,157,158,159
DEFB      160,161,162,163
DEFB      165,166,168,169
DEFB      171,173,175,177
DEFB      180,182,185,189
DEFB      193,197,202,208
DEFB      214,222,232,243
;
; KEY ROUTINE
;
KEY:      PUSH    IX
          XOR     A
          LD      IX,GTSTCK
          LD      IY,(EXPTBL-1)
          CALL    CALSLT
          OR      A
          JR      NZ,M1JRKE
          INC     A
          LD      IX,GTSTCK
          LD      IY,(EXPTBL-1)
          CALL    CALSLT
M1JRKE:   POP     IX
          ;
          OR      A
          JR      Z,M1TRIG
          DEC     A
          LD      B,A
          LD      D,(IX+7)
          LD      E,(IX+8)
          AND     3
          JR      Z,M1DOWN
          BIT     2,B
          LD      A,D
          JR      NZ,M1LEFT
          ADD     A,16
          CP      225
          JR      NC,M1DOWN
          LD      D,A
          DEC     (IX+10)
          JR      M1DOWN
M1LEFT:   SUB     16
          CP      32
          JR      C,M1DOWN
          LD      D,A
          INC     (IX+10)
M1DOWN:   LD      A,B
          ADD     A,2
          AND     7
          LD      B,A
          AND     3
          JR      Z,M1SET
          BIT     2,B
          LD      A,E
          JR      NZ,M1DW
          ADD     A,16
          CP      225
          JR      NC,M1SET
          LD      E,A
          JR      M1SET
M1DW:     SUB     16
          CP      32
          JR      C,M1SET
          LD      E,A
          ;
M1SET:    LD      (IX+7),D
          LD      (IX+8),E
          ;
M1TRIG:   PUSH    IX
          XOR     A
          LD      IX,GTTRIG
          LD      IY,(EXPTBL-1)
          CALL    CALSLT
          INC     A
          JR      Z,M1JRTR
          LD      IX,GTTRIG
          LD      IY,(EXPTBL-1)
          CALL    CALSLT
          INC     A
M1JRTR:   POP     IX
          ;
          JR      Z,M1GO
          LD      A,-8
          ADD     A,(IX+9)
          CP      16
          JR      C,M1SET2+3
          JR      M1SET2
M1GO:     LD      A,16
          ADD     A,(IX+9)
          CP      129
          JR      NC,M1SET2+3
M1SET2:   LD      (IX+9),A
          ;
          CALL    SETGAG
          RET
;
; SET GAGE
;
SETGAG:   LD      IY,GAGE
          LD      A,(IX+7)
          ADD     A,24
          LD      (IY+1),A
          SUB     48
          LD      (IY+0),A
          LD      A,(IX+8)
          ADD     A,20
          LD      (IY+3),A
          SUB     38
          LD      (IY+2),A
          LD      A,(IX+9)
          ADD     A,16
          LD      (IY+5),A
          SUB     32
          LD      (IY+4),A
          RET
;
; MOVE SUB
;
MOVE:     PUSH    IX
          POP     HL
          LD      DE,7
          ADD     HL,DE
          POP     DE
          LD      A,(DE)
          ADD     A,(HL)
          LD      (HL),A
          INC     DE
          INC     HL
          LD      A,(DE)
          ADD     A,(HL)
          LD      (HL),A
          INC     DE
          INC     HL
          LD      A,(DE)
          ADD     A,(HL)
          LD      (HL),A
          INC     DE
          INC     HL
          LD      A,(DE)
          ADD     A,(HL)
          LD      (HL),A
          INC     DE
          INC     HL
          LD      A,(DE)
          ADD     A,(HL)
          LD      (HL),A
          INC     DE
          INC     HL
          LD      A,(DE)
          ADD     A,(HL)
          LD      (HL),A
          RET
          ;
RTURN:    EX      (SP),HL
          PUSH    DE
          PUSH    BC
          PUSH    AF
          PUSH    HL
          LD      A,(IX+7)
          SUB     (HL)
          LD      B,A
          INC     HL
          LD      A,(IX+8)
          SUB     (HL)
          LD      C,A
          INC     HL
          LD      A,(IX+9)
          SUB     (HL)
          LD      D,A
          INC     HL
          LD      A,(HL)
          OR      A
          CALL    NZ,KAITEN
          LD      E,B
          LD      B,D
          INC     HL
          LD      A,(HL)
          OR      A
          CALL    NZ,KAITEN
          LD      D,C
          LD      C,B
          LD      B,E
          INC     HL
          LD      A,(HL)
          OR      A
          CALL    NZ,KAITEN
          POP     HL
          LD      A,B
          ADD     A,(HL)
          LD      (IX+7),A
          INC     HL
          LD      A,D
          ADD     A,(HL)
          LD      (IX+8),A
          INC     HL
          LD      A,C
          ADD     A,(HL)
          LD      (IX+9),A
          INC     HL
          INC     HL
          INC     HL
          INC     HL
          POP     AF
          POP     BC
          POP     DE
          EX      (SP),HL
          RET
;
; DATA SET
;
DSET:     EX      (SP),HL
          PUSH    DE
          PUSH    BC
          PUSH    AF
          PUSH    HL
          LD      HL,PORIDAT
          LD      DE,16
          LD      B,E
DSLOOP:   LD      A,(HL)
          OR      A
          JR      Z,DSSET
          ADD     HL,DE
          DJNZ    DSLOOP
          POP     HL
          LD      DE,13
          ADD     HL,DE
          JR      DSRET
          ;
DSSET:    POP     DE
          LD      (HL),1
          INC     HL
          LD      (HL),0
          INC     HL
          LD      (HL),0
          INC     HL
          EX      DE,HL
          LDI
          LDI
          LDI
          LDI
          LDI
          LDI
          LDI
          LDI
          LDI
          LDI
          LDI
          LDI
          LDI
DSRET:    POP     AF
          POP     BC
          POP     DE
          EX      (SP),HL
          RET
          ;
CLSPRI:   XOR     A
          LD      HL,PORIDAT
          LD      DE,PORIDAT+1
          LD      BC,255
          LD      (HL),A
          LDIR
          RET
;
; PALETTE SET
;
PALETE:   PUSH    AF
          PUSH    BC
          PUSH    DE
          PUSH    HL
          LD      BC,(RDVDP+1)
          INC     C
          DI
          XOR     A
          OUT     (C),A
          LD      A,80H+16
          OUT     (C),A
          INC     C
          LD      B,16
          LD      HL,PLDAT
          LD      E,(HL)
PLLOOP:   INC     HL
          LD      A,(HL)
          SUB     E
          JR      NC,$+3
          XOR     A
          RLCA
          RLCA
          RLCA
          RLCA
          LD      D,A
          INC     HL
          LD      A,(HL)
          SUB     E
          JR      NC,$+3
          XOR     A
          OR      D
          OUT     (C),A
          INC     HL
          LD      A,(HL)
          SUB     E
          JR      NC,$+3
          XOR     A
          OUT     (C),A
          DJNZ    PLLOOP
          EI
          POP     HL
          POP     DE
          POP     BC
          POP     AF
          RET
          ;
PLDAT:    DEFB    7
          DEFB    0,0,0,0,0,0
          DEFB    1,1,6,3,3,7
          DEFB    1,7,1,2,7,3
          DEFB    5,1,1,2,7,6
          DEFB    7,1,1,7,3,3
          DEFB    6,1,6,6,3,6
          DEFB    1,1,4,6,5,2
          DEFB    5,5,5,7,7,7
          ;
UNFADE:   CALL    DSET
          DEFW    0,UNFAD
          DEFW    0,0,0,0
          DEFB    00000001B
          RET
UNFAD:    LD      A,(IX+1)
          INC     (IX+1)
          CP      8
          JP      Z,MALEND
          XOR     7
          LD      (PLDAT),A
          CALL    PALETE
          RET
          ;
FADE:     CALL    DSET
          DEFW    0,FAD
          DEFW    0,0,0,0
          DEFB    00000001B
          RET
FAD:      LD      A,(IX+1)
          INC     (IX+1)
          CP      8
          JP      Z,MALEND
          LD      (PLDAT),A
          CALL    PALETE
          RET
;
;---- WORK AREA ----
;
RDVDP:    DEFS    2
WORK:     DEFS    3
HYOUJI:   DEFS    120
VIJUAL:   DEFB    0
STACK:    DEFW    0
SSTACK:   DEFW    0
;
SCROLL:   DEFB    0,0
SCOLOR:   DEFB    3,1
SWHICH:   DEFB    00001001B
CONTRT:   DEFW    00
DEADRT:   DEFW    00
LIFE:     DEFB    16
STOCK:    DEFB    3
SCORE:    DEFW    00
HSCORE:   DEFW    00
GAGE:     DEFB    0,0,0,0,0,0
MASTER:   DEFS    16
PORIDAT:  DEFS    256
;--------------------------------------------
;
; MAIN2
;
;--------------------------------------------
TOP2:	  EQU	  $
;
;---- MOJI HYOUJI ----
;
MHYOUJ:   BIT     5,(IX+15)
          JR      Z,HMOJI
          LD      A,(IX+11)
          OR      A
          JR      NZ,M2ONH
          LD      A,(IX+2)
          OR      A
          JR      Z,M2OFFH
          DEC     (IX+2)
          JR      MJIRET
M2OFFH:   LD      A,(IX+10)
          LD      (IX+2),A
          LD      A,1
          LD      (IX+11),A
          JR      HMOJI
M2ONH:    LD      A,(IX+2)
          DEC     (IX+2)
          OR      A
          JR      NZ,HMOJI
          LD      A,(IX+9)
          LD      (IX+2),A
          XOR     A
          LD      (IX+11),A
          JR      MJIRET
          ;
HMOJI:    LD      E,(IX+7)
          LD      D,0
          LD      (LIDAT+4),DE
          LD      H,(IX+4)
          LD      L,(IX+3)
MJLOOP:   LD      A,(HL)
          OR      A
          JR      Z,MJIRET
          INC     HL
          LD      B,(HL)
          INC     HL
          LD      C,(HL)
          INC     HL
          CALL    CALMOJ
          JR      MJLOOP
          ;
MJIRET:   LD      A,(IX+1)
          INC     (IX+1)
          CP      (IX+8)
          JP      Z,MALEND
          RET
          ;
CALMOJ:   PUSH    HL
          CP      41H
          LD      D,30H
          JR      C,$+4
          LD      D,41H-10
          SUB     D
          ADD     A,A
          LD      HL,MOJIDAT
          ADD     A,L
          JR      NC,$+3
          INC     H
          LD      L,A
          LD      E,(HL)
          INC     HL
          LD      D,(HL)
          EX      DE,HL
          LD      A,B
          ADD     A,(IX+12)
          LD      B,A
          LD      A,C
          ADD     A,(IX+13)
          LD      C,A
          ;
          LD      A,(HL)
          ADD     A,A
          ADD     A,(HL)
          INC     HL
          INC     HL
          LD      E,A
          LD      D,0
          PUSH    HL
          ADD     HL,DE
          POP     DE
          DEC     DE
          DEC     DE
          DEC     DE
          ;
LOOPMJ:   LD      A,(HL)
          ADD     A,A
          ADD     A,(HL)
          PUSH    BC
          PUSH    DE
          ADD     A,E
          JR      NC,$+3
          INC     D
          LD      E,A
          LD      A,(DE)
          INC     DE
          BIT     1,(IX+15)
          JR      Z,$+4
          SLA     A
          BIT     2,(IX+15)
          JR      Z,$+4
          SRA     A
          ADD     A,B
          LD      B,A
          LD      A,(DE)
          BIT     3,(IX+15)
          JR      Z,$+4
          SLA     A
          BIT     4,(IX+15)
          JR      Z,$+4
          SRA     A
          ADD     A,C
          LD      C,A
          LD      (LIDAT),BC
          POP     DE
          POP     BC
          INC     HL
          LD      A,(HL)
          ADD     A,A
          ADD     A,(HL)
          PUSH    BC
          PUSH    DE
          ADD     A,E
          JR      NC,$+3
          INC     D
          LD      E,A
          LD      A,(DE)
          INC     DE
          BIT     1,(IX+15)
          JR      Z,$+4
          SLA     A
          BIT     2,(IX+15)
          JR      Z,$+4
          SRA     A
          ADD     A,B
          LD      B,A
          LD      A,(DE)
          BIT     3,(IX+15)
          JR      Z,$+4
          SLA     A
          BIT     4,(IX+15)
          JR      Z,$+4
          SRA     A
          ADD     A,C
          LD      C,A
          LD      (LIDAT+2),BC
          POP     DE
          POP     BC
          CALL    LINE
          INC     HL
          LD      A,(HL)
          DEC     HL
          OR      A
          JR      NZ,LOOPMJ
          INC     HL
          INC     HL
          LD      A,(HL)
          OR      A
          JR      NZ,LOOPMJ
          POP     HL
          RET
MOJIDAT:
DEFW      M0,M1,M2,M3,M4,M5,M6
DEFW      M7,M8,M9,MA,MB,MC,MD
DEFW      ME,MF,MG,MH,MI,MJ,MK
DEFW      ML,MM,MN,MO,MP,MQ,MR
DEFW      MS,MT,MU,MV,MW,MX,MY
DEFW      MZ
;
; MOJI POINT DATA
;
MA:
DEFB      5,0
DEFB      -12, 16,  0
DEFB       12, 16,  0
DEFB       -8,  6,  0
DEFB        8,  6,  0
DEFB        0,-16,  0
DEFB      1,5,2,0,3,4,0,0
MB:
DEFB      7,0
DEFB      -12,-16,  0
DEFB      -12, 16,  0
DEFB        0, 16,  0
DEFB       12,  8,  0
DEFB        0,  0,  0
DEFB       12, -8,  0
DEFB        0,-16,  0
DEFB      1,2,3,4,5,6,7,1,0,0
MC:
DEFB      6,0
DEFB        0,-16,  0
DEFB      -12, -8,  0
DEFB       12, -8,  0
DEFB      -12,  8,  0
DEFB       12,  8,  0
DEFB        0, 16,  0
DEFB      3,1,2,4,6,5,0,0
MD:
DEFB      6,0
DEFB      -12,-16,  0
DEFB      -12, 16,  0
DEFB        0, 16,  0
DEFB       12,  8,  0
DEFB       12, -8,  0
DEFB        0,-16,  0
DEFB      1,2,3,4,5,6,1,0,0
ME:
DEFB      6,0
DEFB      -11,-16,  0
DEFB       11,-16,  0
DEFB      -11,  0,  0
DEFB       11,  0,  0
DEFB      -11, 16,  0
DEFB       11, 16,  0
DEFB      2,1,5,6,0,3,4,0,0
MF:
DEFB      5,0
DEFB      -12,-16,  0
DEFB       12,-16,  0
DEFB      -12,  0,  0
DEFB        4,  0,  0
DEFB      -12, 16,  0
DEFB      2,1,5,0,3,4,0,0
MG:
DEFB      8,0
DEFB       12, -8,  0
DEFB        0,-16,  0
DEFB      -12, -8,  0
DEFB      -12,  8,  0
DEFB        0, 16,  0
DEFB       12,  8,  0
DEFB       12,  4,  0
DEFB        0,  4,  0
DEFB      1,2,3,4,5,6,7,8,0,0
MH:
DEFB      6,0
DEFB      -12,-16,  0
DEFB       12,-16,  0
DEFB      -12,  0,  0
DEFB       12,  0,  0
DEFB      -12, 16,  0
DEFB       12, 16,  0
DEFB      1,5,0,2,6,0,3,4,0,0
MI:
DEFB      2,0
DEFB        0,-16,  0
DEFB        0, 16,  0
DEFB      1,2,0,0
MJ:
DEFB      4,0
DEFB       12,-16,  0
DEFB       12,  8,  0
DEFB        0, 16,  0
DEFB      -12,  8,  0
DEFB      1,2,3,4,0,0
MK:
DEFB      5,0
DEFB      -12,-16,  0
DEFB      -12,  0,  0
DEFB      -12, 16,  0
DEFB       12,-16,  0
DEFB       12, 16,  0
DEFB      1,3,0,4,2,5,0,0
ML:
DEFB      3,0
DEFB      -12,-16,  0
DEFB      -12, 16,  0
DEFB       12, 16,  0
DEFB      1,2,3,0,0
MM:
DEFB      5,0
DEFB      -12, 16,  0
DEFB       -8,-16,  0
DEFB        0, 16,  0
DEFB        8,-16,  0
DEFB       12, 16,  0
DEFB      1,2,3,4,5,0,0
MN:
DEFB      4,0
DEFB      -12, 16,  0
DEFB      -12,-16,  0
DEFB       12, 16,  0
DEFB       12,-16,  0
DEFB      1,2,3,4,0,0
MO:
DEFB      6,0
DEFB        0,-16,  0
DEFB      -12, -8,  0
DEFB       12, -8,  0
DEFB      -12,  8,  0
DEFB       12,  8,  0
DEFB        0, 16,  0
DEFB      1,2,4,6,5,3,1,0,0
MP:
DEFB      6,0
DEFB      -12, 16,  0
DEFB      -12,-16,  0
DEFB        0,-16,  0
DEFB       12, -8,  0
DEFB        0,  0,  0
DEFB      -12,  0,  0
DEFB      1,2,3,4,5,6,0,0
MQ:
DEFB      8,0
DEFB        0,-16,  0
DEFB      -12, -8,  0
DEFB      -12,  8,  0
DEFB        0, 16,  0
DEFB       12,  8,  0
DEFB       12, -8,  0
DEFB        0,  8,  0
DEFB       12, 16,  0
DEFB      1,2,3,4,5,6,1,0
DEFB      7,8,0,0
MR:
DEFB      6,0
DEFB      -12, 16,  0
DEFB      -12,-16,  0
DEFB        0,-16,  0
DEFB       12, -8,  0
DEFB        0,  0,  0
DEFB       12, 16,  0
DEFB      1,2,3,4,5,6,0,0
MS:
DEFB      6,0
DEFB       12, -8,  0
DEFB        0,-16,  0
DEFB      -12, -8,  0
DEFB       12,  8,  0
DEFB        0, 16,  0
DEFB      -12,  8,  0
DEFB      1,2,3,4,5,6,0,0
MT:
DEFB      4,0
DEFB      -12,-16,  0
DEFB       12,-16,  0
DEFB        0,-16,  0
DEFB        0, 16,  0
DEFB      1,2,0,3,4,0,0
MU:
DEFB      5,0
DEFB      -12,-16,  0
DEFB      -12,  8,  0
DEFB        0, 16,  0
DEFB       12,  8,  0
DEFB       12,-16,  0
DEFB      1,2,3,4,5,0,0
MV:
DEFB      3,0
DEFB      -12,-16,  0
DEFB        0, 16,  0
DEFB       12,-16,  0
DEFB      1,2,3,0,0
MW:
DEFB      5,0
DEFB      -12,-16,  0
DEFB       -8, 16,  0
DEFB        0,-16,  0
DEFB        8, 16,  0
DEFB       12,-16,  0
DEFB      1,2,3,4,5,0,0
MX:
DEFB      4,0
DEFB      -12,-16,  0
DEFB      -12, 16,  0
DEFB       12,-16,  0
DEFB       12, 16,  0
DEFB      1,4,0,2,3,0,0
MY:
DEFB      4,0
DEFB      -12,-16,  0
DEFB       12,-16,  0
DEFB        0,  0,  0
DEFB        0, 16,  0
DEFB      1,3,2,0,3,4,0,0
MZ:
DEFB      4,0
DEFB      -12,-16,  0
DEFB      -12, 16,  0
DEFB       12,-16,  0
DEFB       12, 16,  0
DEFB      1,3,2,4,0,0
M0:
DEFB      6,0
DEFB        0,-16,  0
DEFB       -8, -8,  0
DEFB       -8,  8,  0
DEFB        0, 16,  0
DEFB        8,  8,  0
DEFB        8, -8,  0
DEFB      1,2,3,4,5,6,1,0,0
M1:
DEFB      3,0
DEFB       -4, -8,  0
DEFB        0,-16,  0
DEFB        0, 16,  0
DEFB      1,2,3,0,0
M2:
DEFB      5,0
DEFB       -8, -8,  0
DEFB        0,-16,  0
DEFB        8, -8,  0
DEFB       -8, 16,  0
DEFB        8, 16,  0
DEFB      1,2,3,4,5,0,0
M3:
DEFB      7,0
DEFB       -8, -8,  0
DEFB        0,-16,  0
DEFB        8, -8,  0
DEFB        0,  0,  0
DEFB        8,  8,  0
DEFB        0, 16,  0
DEFB       -8,  8,  0
DEFB      1,2,3,4,5,6,7,0,0
M4:
DEFB      5,0
DEFB        0,-16,  0
DEFB       -8,  8,  0
DEFB        8,  8,  0
DEFB        4, -8,  0
DEFB        4, 16,  0
DEFB      1,2,3,0,4,5,0,0
M5:
DEFB      7,0
DEFB        6,-16,  0
DEFB       -8,-16,  0
DEFB       -8, -4,  0
DEFB        4, -4,  0
DEFB        8,  8,  0
DEFB        0, 16,  0
DEFB       -8, 12,  0
DEFB      1,2,3,4,5,6,7,0,0
M6:
DEFB      8,0
DEFB        8, -8,  0
DEFB        0,-16,  0
DEFB       -8, -8,  0
DEFB       -8,  8,  0
DEFB        0, 16,  0
DEFB        8,  8,  0
DEFB        4,  0,  0
DEFB       -8,  0,  0
DEFB      1,2,3,4,5,6,7,8,0,0
M7:
DEFB      3,0
DEFB       -8,-16,  0
DEFB        8,-16,  0
DEFB        0, 16,  0
DEFB      1,2,3,0,0
M8:
DEFB      6,0
DEFB        0,-16,  0
DEFB       -8, -8,  0
DEFB        8,  8,  0
DEFB        0, 16,  0
DEFB       -8,  8,  0
DEFB        8, -8,  0
DEFB      1,2,3,4,5,6,1,0,0
M9:
DEFB      8,0
DEFB       -8,  8,  0
DEFB        0, 16,  0
DEFB        8,  8,  0
DEFB        8, -8,  0
DEFB        0,-16,  0
DEFB       -8, -8,  0
DEFB       -4,  0,  0
DEFB        8,  0,  0
DEFB      1,2,3,4,5,6,7,8,0,0
;
; MASTER POINT DATA
;
MSDATA:
DEFB      10,0
DEFB      -24,  0, 20
DEFB      -24,-18,-20
DEFB      -24, 20,-20
DEFB      -18,  0,-16
DEFB       24,  0, 20
DEFB       24,-18,-20
DEFB       24, 20,-20
DEFB       18,  0,-16
DEFB        0,-16,-22
DEFB        0,-10, 50
DEFB      1,2,3,1,4,2,0,3,4,9
DEFB      10,4,0,5,6,7,5,8,6,0
DEFB      7,8,10,0,8,9,0,4,8,0,0
;
;---- WRITE LIFE GAGE ----
;
WRLIFE:   PUSH    AF
          PUSH    HL
          LD      HL,0006H
          LD      (LIDAT+4),HL
          LD      H,178
          LD      L,20
          LD      (LIDAT+0),HL
          LD      L,39
          LD      (LIDAT+2),HL
          CALL    LINE
          LD      H,246
          LD      (LIDAT+0),HL
          LD      L,20
          LD      (LIDAT+2),HL
          CALL    LINE
          LD      H,180
          LD      L,30
          LD      (LIDAT+0),HL
          LD      H,244
          LD      (LIDAT+2),HL
          CALL    LINE
          ;
          LD      A,(LIFE)
          RLCA
          RLCA
          ADD     A,180
          LD      H,A
          LD      L,24
          LD      (LIDAT+0),HL
          LD      L,36
          LD      (LIDAT+2),HL
          LD      HL,0009H
          LD      (LIDAT+4),HL
          CALL    LINE
          ;
          CALL    STRIGB ;WSCOREが宣言されてた
          JR      NZ,RETSC
          LD      HL,(SCORE)
          LD      IX,SCOREM+15
          CALL    CHTEN
          LD      A,(STOCK)
          ADD     A,2FH
          LD      (SCOREM+42),A
          LD      IX,MDSCOR
          CALL    MALTI
RETSC:    POP     HL
          POP     AF
          RET
          ;
SCOREM:   DEFB    'S',20,30,'C',35,30,'O',50,30,'R',65,30,'E',80,30
          DEFB     0,107,30,0,119,30,0,131,30,0,143,30,0,155,30
          DEFB    'L',20,50,'E',35,50,'F',50,50,'T',65,50,'3',107,50,0
          ;
STRIGB:   PUSH    BC
          PUSH    DE
          LD      IY,(0FCC0H)
          LD      IX,00D8H
          LD      A,3
          CALL    001CH
          INC     A
          JR      Z,RETSTR
          LD      A,(0FBE5H+6)
          AND     00000100B
RETSTR:   POP     DE
          POP     BC
          RET
          ;
MDSCOR:   DEFB    1,0,0
          DEFW    SCOREM,MHYOUJ
          DEFB    8,1,0,0,0,0,0,0,00010101B
;
;---- CHANGE TEN ----
;
CHTEN:    PUSH    DE
          LD      DE,10000
          CALL    DOWNGE
          LD      (IX+0),A
          LD      DE,1000
          CALL    DOWNGE
          LD      (IX+3),A
          LD      DE,100
          CALL    DOWNGE
          LD      (IX+6),A
          LD      DE,10
          CALL    DOWNGE
          LD      (IX+9),A
          LD      DE,1
          CALL    DOWNGE
          LD      (IX+12),A
          POP     DE
          RET
          ;
DOWNGE:   XOR     A
          OR      A
          SBC     HL,DE
          JR      C,$+5
          INC     A
          JR      DOWNGE+1
          ADD     HL,DE
          ADD     A,30H
          RET
;--------------------------------------------------
;
;  MAIN3
;
;--------------------------------------------------
;
;---- MALTI STAGE SUB ROUTINE ----
;
;
; TRIGER & STICK
;
STRIG:    PUSH    BC
          PUSH    DE
          PUSH    HL
          PUSH    IX
          XOR     A
          LD      IX,GTTRIG
          LD      IY,(EXPTBL-1)
          CALL    CALSLT
          INC     A
          JR      Z,M3STRT
          LD      IX,GTTRIG
          LD      IY,(EXPTBL-1)
          CALL    CALSLT
          INC     A
M3STRT:   POP     IX
          POP     HL
          POP     DE
          POP     BC
          RET
          ;
STICK:    PUSH    BC
          PUSH    DE
          PUSH    HL
          PUSH    IX
          XOR     A
          LD      IX,GTSTCK
          LD      IY,(EXPTBL-1)
          CALL    CALSLT
          OR      A
          JR      NZ,RETSTI
          INC     A
          LD      IX,GTSTCK
          LD      IY,(EXPTBL-1)
          CALL    CALSLT
          OR      A
RETSTI:   POP     IX
          POP     HL
          POP     DE
          POP     BC
          RET
;
; DEAD ROUTINE
;
DEAD:     CALL    EXPLO
		  LD      SP,(STACK)
          LD      HL,DEADPT
          LD      (MASTER+5),HL 
          LD      A,(SWHICH)
          AND     11101111B
          LD      (SWHICH),A
          LD      HL,0
          LD      (GAGE),HL
          LD      A,45
          CALL    MAIN
          CALL    FADE
          LD      A,8
          CALL    MAIN
          LD      A,(STOCK)
          DEC     A
          JP      Z,GMOVER
          LD      (STOCK),A
          CALL    MSSTR
          LD      HL,(CONTRT)
          JP      (HL)
          ;
DEADPT:   LD      A,(IX+9)
          ADD     A,6
          CP      200
          JR      NC,$+12
          LD      (IX+9),A
          INC     (IX+10)
          INC     (IX+10)
          RET
          LD      A,00011000B
          LD      (IX+15),A
          LD      A,(SWHICH)
          AND     11111001B
          LD      (SWHICH),A
          RET
;
; TUCH ROUTINE ( 0 - 4 )
;
TUCH0:    CALL    PISTOL
          RET
          ;
TUCH1:    CALL    PISTOL
          LD      A,(SWHICH)
          BIT     5,A
          RET     NZ
          LD      A,(LIFE)
          OR      A
          JR      Z,$+6
          DEC     A
          LD      (LIFE),A
          XOR     A
          LD      (IX+0),A
          RET
          ;
TUCH2:    CALL    PISTOL
          XOR     A
          LD      (IX+2),A
          LD      A,(MASTER+13)
          LD      (LIDAT+4),A
          LD      A,(SWHICH)
          BIT     5,A
          RET     NZ
          LD      A,(LIFE)
          SUB     2
          JR      NC,$+3
          XOR     A
          LD      (LIFE),A
          RET
          ;
TUCH3:    CALL    ITEMGT
          CALL    MOVESD
          LD      A,(LIFE)
          ADD     A,4
          CP      17
          JR      C,$+4
          LD      A,16
          LD      (LIFE),A
          XOR     A
          LD      (IX+0),A
          LD      (IX+2),A
          RET
          ;
TUCH4:    CALL    ITEMGT
          CALL    MOVESD
          LD      A,(SWHICH)
          XOR     00000100B
          LD      (SWHICH),A
          XOR     A
          LD      (IX+0),A
          LD      (IX+2),A
          RET
;
; MASTER START ROUTINE
;
MSSTR:    LD      HL,MSSTDT
          LD      DE,MASTER
          LD      BC,16
          LDIR
          LD      A,16
          LD      (LIFE),A
          LD      A,(SWHICH)
          OR      00010010B
          LD      (SWHICH),A
          CALL    CLSPRI
          CALL    DSET
          DEFW    STARTM,MHYOUJ
          DEFB    7,24,1,1,0,40
          DEFB    0,0,00110101B
          CALL    UNFADE
          RET
          ;
MSSTDT:   DEFB    1,0,0
          DEFW    MSDATA,STARPT
          DEFB    128,128,128
          DEFB    0,0,0,8,0
          DEFB    00101000B
          ;
STARTM:   DEFB    'G',40,80
          DEFB    'O',55,80
          DEFB    'A',75,80
          DEFB    'H',90,80
          DEFB    'E',105,80
          DEFB    'A',120,80
          DEFB    'D',135,80,0
          ;
STARPT:   LD      A,(IX+9)
          SUB     8
          CP      16
          JR      C,$+6
          LD      (IX+9),A
          RET
          LD      HL,KEY
          LD      (IX+5),L
          LD      (IX+6),H
          RET
;
; TURBO ROUTINE
;
TURBO:    LD      A,0
          INC     A
          LD      (TURBO+1),A
          AND     15
          RET     NZ
          CALL    RND
          CP      200
          JR      NC,$-5
          ADD     A,30
          LD      (TURBRD+4),A
          CALL    RND
          CP      185
          JR      NC,$-5
          ADD     A,40
          LD      (TURBRD+5),A
          CALL    DSET
TURBRD:   DEFW    TURBPT,TURBMV
          DEFB    0,0,255,0,0,0
          DEFB    13,4,00000000B
          RET
          ;
TURBMV:   CALL    MOVE
          DEFB    0,0,-16,0,3,0
          ;
TURBPT:   DEFB    9,0
          DEFB     12,-24,  0
          DEFB    -18,  6,  0
          DEFB      6, 18,  0
          DEFB      3,-36,  0
          DEFB    -21, 12,-18
          DEFB    -21, 12, 18
          DEFB     27,-24,  0
          DEFB      3, 24,-18
          DEFB      3, 24, 18
          DEFB     1,2,3,1,0,4,5,6,4,0
          DEFB     7,8,9,7,0,0
;
; CURE ROUTINE
;
CURE:     LD      A,0
          INC     A
          LD      (CURE+1),A
          AND     31
          RET     NZ
          CALL    RND
          CP      205
          JR      NC,$-5
          ADD     A,25
          LD      (CURERD+4),A
          CALL    RND
          CP      190
          JR      NC,$-5
          ADD     A,33
          LD      (CURERD+5),A
          CALL    DSET
CURERD:   DEFW    CURPD1,CUREMV
          DEFB    0,0,255,0,0,0
          DEFB    9,3,00000000B
          RET
          ;
CUREMV:   LD      A,(IX+1)
          INC     (IX+1)
          LD      HL,CURPD1
          AND     2
          JR      NZ,$+5
          LD      HL,CURPD2
          LD      (IX+4),H
          LD      (IX+3),L
          LD      A,(IX+9)
          SUB     24
          LD      (IX+9),A
          RET
          ;
CURPD1:   DEFB    6,0
          DEFB      0,-18,  0
          DEFB      0, 18,  0
          DEFB      0,  0,-22
          DEFB    -22,  0,  0
          DEFB      0,  0, 22
          DEFB     22,  0,  0
          DEFB    1,4,2,6,1,0,5,4,3,6,5,0
          DEFB    1,3,2,5,1,0,0
          ;
CURPD2:   DEFB    6,0
          DEFB      0,-28,  0
          DEFB      0, 28,  0
          DEFB      0,  0,-12
          DEFB    -12,  0,  0
          DEFB      0,  0, 12
          DEFB     12,  0,  0
          DEFB    1,4,2,6,1,0,5,4,3,6,5,0
          DEFB    1,3,2,5,1,0,0
;
; TECHNOITE ROUTINE
;
TECHPT:   DEFB    6,0
          DEFB    -23,-23,  3
          DEFB      0, 18,  3
          DEFB     18,  0,  3
          DEFB    -23,-23, -3
          DEFB      0, 18, -3
          DEFB     18,  0, -3
          DEFB    1,2,3,1,0,4,5,6,4,0
          DEFB    1,4,0,2,5,0,3,6,0,0
          ;
TECHMV:   CALL    MOVE
          DEFB    0,0,-26,0,0,3
          ;
TECHNO:   CALL    RND
          CP      215
          JR      NC,$-5
          ADD     A,23
          LD      (TECHRD+4),A
          CALL    RND
          CP      215
          JR      NC,$-5
          ADD     A,23
          LD      (TECHRD+5),A
          CALL    RND
          LD      C,8
          AND     15
          JR      Z,M3CJ4
          LD      C,7
          CP      13
          JR      NC,M3CJ4
          LD      C,3
          CP      9
          JR      NC,M3CJ4
          LD      C,10
M3CJ4:    LD      A,C
          LD      (TECHRD+10),A
          CALL    DSET
TECHRD:   DEFW    TECHPT,TECHMV
          DEFB    0,0,255,0,0,0
          DEFB    0,5,00000000B
          RET
          ;
TUCH5:    CALL    ITEMGT
		  CALL	  MOVESD
          LD      A,(IX+13)
          LD      DE,400
          CP      8
          JR      Z,M3TJ5
          LD      DE,200
          CP      7
          JR      Z,M3TJ5
          LD      DE,100
          CP      3
          JR      Z,M3TJ5
          LD      DE,50
M3TJ5:    LD      HL,(SCORE)
          ADD     HL,DE
          JR      NC,$+5
          LD      HL,65535
          LD      (SCORE),HL
          XOR     A
          LD      (IX+0),A
          LD      (IX+2),A
          RET
;
; MINING PARTYPA
;
PARPD1:   DEFB    7,0
          DEFB    -12,  0,-12
          DEFB     -5,  0, 16
          DEFB     20,  0, -2
          DEFB      0,-30,  0
          DEFB      0,-60,  0
          DEFB     20,-52,  0
          DEFB      0,-44,  0
          DEFB    1,2,3,1,4,2,0,3,4,5,6,7,0,0
          ;
PARPD2:   DEFB    7,0
          DEFB      0,-40,  0
          DEFB     12,-40,  0
          DEFB      0,-30,  0
          DEFB    -12,-40,  0
          DEFB      0,-20,  0
          DEFB    -10,  0,  0
          DEFB     10,  0,  0
          DEFB    1,3,5,6,0,4,3,2,0,5,7,0,0
          ;
PARTY:    CALL    RND
          CP      224
          JR      NC,$-5
          ADD     A,12
          LD      (PARRD+4),A
          CALL    RND
          AND     7
          LD      HL,PARPD1
          LD      C,7
          JR      Z,$+7
          LD      HL,PARPD2
          LD      C,6
          LD      (PARRD+0),HL
          LD      A,C
          LD      (PARRD+11),A
          CALL    DSET
PARRD:    DEFW    PARPD1,PARMV
          DEFB    0,255,255,0,0,0
          DEFB    15,6,00000000B
          RET
          ;
PARMV:    LD      A,(IX+9)
          ADD     A,-24
          JP      NC,MALEND
          LD      (IX+9),A
          RET
          ;
TUCH6:    CALL    ITEMGT
          CALL    MOVESD
          LD      A,(IX+14)
          LD      DE,250
          CP      6
          JR      Z,$+5
          LD      DE,500
          LD      HL,(SCORE)
          ADD     HL,DE
          JR      NC,$+5
          LD      HL,65535
          LD      (SCORE),HL
          XOR     A
          LD      (IX+0),A
          LD      (IX+2),A
          RET
;
; RUNDUM ROUTINE
;
RND:      PUSH    BC
          LD      BC,0
          LD      A,R
          ADD     A,C
          ADD     A,B
          LD      C,B
          LD      B,A
          LD      (RND+2),BC
          POP     BC
          RET
;
; HOME POSITION RETURN
;
HOME:     LD      A,3
          LD      (IX+1),A
          LD      A,(IX+7)
          CP      128
          JR      Z,YPOS
          JR      C,M3HJ1
          SUB     16
          LD      (IX+7),A
          INC     (IX+10)
          RET
M3HJ1:    ADD     A,16
          LD      (IX+7),A
          DEC     (IX+10)
          RET
YPOS:     LD      A,2
          LD      (IX+1),A
          LD      A,(IX+8)
          CP      128
          JR      Z,ZPOS
          JR      C,M3HJ2
          SUB     4
          LD      (IX+8),A
          RET
M3HJ2:    ADD     A,4
          LD      (IX+8),A
          RET
ZPOS:     LD      A,1
          LD      (IX+1),A
          LD      A,(IX+9)
          CP      16
          JR      Z,M3HJ3
          SUB     4
          LD      (IX+9),A
          RET
M3HJ3:    XOR     A
          LD      (IX+1),A
          RET
;------------------------------------------------
;
; SOUND 
;
;------------------------------------------------

SDOFF:		CALL	SOUND
			DEFB	0,0H
            DEFB	1,0H
            DEFB	2,0H
            DEFB 	3,0H
            DEFB	4,0H
            DEFB	5,0H
            DEFB	6,0H
			DEFB	7,0FFH
            DEFB	8,0H
            DEFB	9,0H
            DEFB	10,0H
            DEFB	12,0H
            DEFB	13,0H
            DEFB	0FFH
            RET

SDWAIT:     PUSH BC
    		LD   BC,6000
DLOOP:
    		DEC  BC
    		LD   A,B
    		OR   C
    		JR   NZ,DLOOP
    		POP  BC
    		RET
            
MOVESD:		CALL	SOUND
			DEFB	0,28H
            DEFB	1,00H
            DEFB	6,1FH
            DEFB	7,80H
            DEFB	8,6
            DEFB	0FFH
            RET

PISTOL:	 	CALL	SOUND
			DEFB	2,14H
            DEFB	3,01H
            DEFB	6,1FH
            DEFB	7,80H
            DEFB	9,10H
            DEFB	12,20H
            DEFB	13,0H
            DEFB 	0FFH
            RET

PISTOL2:	CALL	SOUND
            DEFB	7,0B7H
            DEFB	6,7H
            DEFB	8,10H
            DEFB	11,0A8H
            DEFB	12,0DH
            DEFB	13,0H
            DEFB	0FFH
            CALL    SDWAIT
            RET
            
EXPLO:		CALL	SOUND
			DEFB	7,0B6H
            DEFB	8,10H
            DEFB	0,0FFH
            DEFB	1,0FH
            DEFB	6,1FH
            DEFB	11,8CH
            DEFB	12,88H
            DEFB	13,0H
            DEFB	0FFH
            RET
            
WAVE:       CALL    SOUND
            DEFB    7,0B7H
            DEFB    6,7H
            DEFB    8,10H
            DEFB    11,7AH
            DEFB    12,0DAH
            DEFB    13,0EH
            DEFB    0FFH
            RET
            
SOUND1:     CALL    SOUND
            DEFB    1,0E0H  ; チャンネルAの周波数下位バイト（音程）
            DEFB    2,00H   ; チャンネルAの周波数上位バイト
            DEFB    8,18H   ; エンベロープパターン（急速に減衰）
            DEFB    13,0FH  ; 音量を最大に
            DEFB    0FFH
            RET
            
SOUND2:     CALL    SOUND
            DEFB    7,0B7H  ; ノイズチャンネル設定（白ノイズ）
            DEFB    6,01H   ; ノイズ周波数（低い音から開始）
            DEFB    8,10H   ; エンベロープパターン（徐々に減衰）
            DEFB    13,0FH  ; 音量を最大に
            DEFB    0FFH
            RET
            
SOUND3:     CALL    SOUND
            DEFB    1,080H  ; チャンネルAの周波数下位バイト（中音）
            DEFB    2,00H   ; チャンネルAの周波数上位バイト
            DEFB    8,08H   ; エンベロープパターン（定常音）
            DEFB    13,0AH  ; 音量を中程度に
            DEFB    0FFH
            RET
            
SOUND4:     CALL    SOUND
            DEFB    1,07AH  ; チャンネルAの周波数下位バイト（高音）
            DEFB    2,00H   ; チャンネルAの周波数上位バイト
            DEFB    8,10H   ; エンベロープパターン（急速に減衰）
            DEFB    13,0EH  ; 音量を少し下げる
            DEFB    0FFH
            RET
            
SELSOUND:   RET
			CALL    SOUND
            DEFB    7,0B7H
            DEFB    8,10H
            DEFB    6,20H
            DEFB    11,0A8H
            DEFB    12,0DH
            DEFB    13,0EH
            DEFB    0FFH
            RET
            
SOUND:		EX		(SP),HL
            PUSH	DE
            PUSH 	AF
SND1:		LD		A,(HL)
			INC 	HL
            AND		A
            JP		M,SND2
            LD		E,(HL)
            INC		HL
            CALL	WRTPSG
            JR 		SND1
SND2:		POP 	AF
			POP 	DE
            EX 		(SP),HL
            RET
            
KEYOFF:
            DI
            LD      A,07H
            OUT     (99H),A
            LD      A,80H
            OUT     (99H),A 
            LD      A,(9911)
            AND     10111111B
            OUT     (9911),A
            EI
            RET
            
                ; PSGレジスタ書き込み用ポート
PSG_ADDR EQU &HA0      ; PSGアドレスポート
PSG_DATA EQU &HA1      ; PSGデータポート

ITEMGT:
    		; PSG初期化（チャンネルAを有効、ノイズオフ、音量0）
            PUSH AF
            PUSH BC
    		LD   A,7           ; レジスタ7（ミキサー）
    		LD   BC,PSG_ADDR
    		OUT  (C),A
    		LD   A,62          ; 00111110（チャンネルA有効、ノイズオフ）
    		LD   BC,PSG_DATA
    		OUT  (C),A

    		; 音量リセット（チャンネルA）
    		LD   A,8           ; レジスタ8（チャンネルA音量）
    		LD   BC,PSG_ADDR
    		OUT  (C),A
    		LD   A,0           ; 音量0
    		LD   BC,PSG_DATA
    		OUT  (C),A

    		; 1つ目の音（周波数約3700Hz）
    		LD   A,0           ; レジスタ0（チャンネルA周波数下位）
    		LD   BC,PSG_ADDR
    		OUT  (C),A
    		LD   A,120         ; 周波数120
    		LD   BC,PSG_DATA
    		OUT  (C),A
    		LD   A,1           ; レジスタ1（チャンネルA周波数上位）
    		LD   BC,PSG_ADDR
    		OUT  (C),A
    		LD   A,0           ; 上位0
    		LD   BC,PSG_DATA
    		OUT  (C),A
    		; 音量オン
    		LD   A,8
    		LD   BC,PSG_ADDR
    		OUT  (C),A
    		LD   A,15          ; 音量最大
    		LD   BC,PSG_DATA
    		OUT  (C),A
    		; ディレイ
    		CALL DELAY

    		; 2つ目の音（周波数約4400Hz）
    		LD   A,0
    		LD   BC,PSG_ADDR
    		OUT  (C),A
    		LD   A,100         ; 周波数100
    		LD   BC,PSG_DATA
    		OUT  (C),A
    		LD   A,1
    		LD   BC,PSG_ADDR
    		OUT  (C),A
    		LD   A,0
    		LD   BC,PSG_DATA
    		OUT  (C),A
    		CALL DELAY

    		; 3つ目の音（周波数約5500Hz）
    		LD   A,0
    		LD   BC,PSG_ADDR
    		OUT  (C),A
    		LD   A,80          ; 周波数80
    		LD   BC,PSG_DATA
    		OUT  (C),A
    		LD   A,1
    		LD   BC,PSG_ADDR
    		OUT  (C),A
    		LD   A,0
    		LD   BC,PSG_DATA
    		OUT  (C),A
    		CALL DELAY

    		; 音を停止
    		LD   A,8
    		LD   BC,PSG_ADDR
    		OUT  (C),A
    		LD   A,0           ; 音量0
    		LD   BC,PSG_DATA
    		OUT  (C),A
            POP  BC
            POP  AF

    		; プログラム終了
    		RET

    		; ディレイサブルーチン（約20ms）
DELAY:
    		PUSH BC
    		LD   BC,5000       ; ディレイ調整（MSX2の3.58MHzで約20ms）
DELAY_LOOP:
    		DEC  BC
    		LD   A,B
    		OR   C
    		JR   NZ,DELAY_LOOP
    		POP  BC
    		RET

;------------------------------------------------
;
; TITLE DEMO
;
;------------------------------------------------
;
;---- TITLE DEMO ----
;
TITLE:    LD      IX,SCOLOR
          LD      A,2
          LD      (IX+0),A
          LD      A,1
          LD      (IX+1),A
          LD      A,00001001B
          LD      (IX+2),A
          ;
MENSET:   CALL    CLSPRI
          CALL    UNFADE
          LD      A,4
          CALL    MAIN
          CALL    DSSS   ;MOJI
          DEFW    MR
          DEFB    44,70
          CALL    DSSS
          DEFW    MO
          DEFB    100,70
          CALL    DSSS
          DEFW    MC
          DEFB    156,70
          CALL    DSSS
          DEFW    MK
          DEFB    212,70
          LD      A,3
          CALL    MAIN
          CALL    DSSS
          DEFW    MC
          DEFB     44,178
          CALL    DSSS
          DEFW    MI
          DEFB    100,178
          CALL    DSSS
          DEFW    MT
          DEFB    156,178
          CALL    DSSS
          DEFW    MY
          DEFB    212,178
          LD      A,77
          CALL    MAIN
          ;
          CALL    DSET
          DEFW    MSDATA,PATER2
          DEFB    128,128,255
          DEFB    0,0,0,3,0
          DEFB    00101000B
          LD      A,34
          CALL    MAIN
          CALL    DSET
          DEFW    STMESG,MJIPAT
          DEFB    3,255,0,2,0,50
          DEFB    50,0,00100101B
          ;
          LD      B,0
LOSTI:    CALL    STRIG
          JP      Z,NEXTGO
          CALL    MAIN
          DJNZ    LOSTI
          CALL    FADE
          LD      A,10
          CALL    MAIN
          CALL    WSCORE
          JP      TITLE
          ;
NEXTGO:   CALL    ITEMGT
          CALL    FADE
          LD      A,16
          CALL    MAIN
          JP      SELECT
          ;
DSSS:     POP     HL
          LD      E,(HL)
          INC     HL
          LD      D,(HL)
          INC     HL
          LD      C,(HL)
          INC     HL
          LD      B,(HL)
          INC     HL
          LD      (DSSD+0),DE
          LD      (DSSD+4),BC
          CALL    DSET
DSSD:     DEFW    0,PATER1,0
          DEFB    250,0,0,16,3,0
          DEFB    001010B
          PUSH    HL
          LD      A,1
          CALL    MAIN
          RET
          ;
STMESG:   DEFB    'P',15,30
          DEFB    'U',30,30
          DEFB    'S',45,30
          DEFB    'H',60,30
          DEFB    'S',90,30
          DEFB    'P',105,30
          DEFB    'A',120,30
          DEFB    'C',135,30
          DEFB    'E',150,30,0
          ;
MJIPAT:   LD      A,(IX+1)
          AND     3
          RLCA
          RLCA
          RLCA
          OR      00100101B
          LD      (IX+15),A
          JP      MHYOUJ
;
;---- TITLE DEMO PATERN ROUTINE ----
;
PATER1:   LD      A,(IX+1)
          INC     (IX+1)
          CP      8
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,-26
          DEFB    0,-4,2
          CP      30
          JR      NC,TDPJ1
          AND     2
          JR      Z,$+11
          CALL    MOVE
          DEFB    0,4,0
          DEFB    0,0,0
          CALL    MOVE
          DEFB    0,-4,0
          DEFB    0,0,0
TDPJ1:    CP      66
          JR      NC,$+20
          CALL    RTURN
          DEFB    128,128,128
          DEFB    0,2,0
          CALL    MOVE
          DEFB    0,0,0
          DEFB    0,2,0
          CALL    MOVE
          DEFB    0,0,16
          DEFB    1,2,2
          ;
PATER2:   LD      A,(IX+1)
          INC     (IX+1)
          CP      16
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,-10
          DEFB    2,0,0
          JR      NZ,TDPJ2
          SET     1,(IX+15)
          LD      A,200
          LD      (IX+9),A
          LD      A,16
TDPJ2:    CP      34
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,-8
          DEFB    2,0,0
          CP      70
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,0
          DEFB    0,-1,-1
          CP      120
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,0
          DEFB    0,0,-1
          CP      190
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,0
          DEFB    -1,0,0
          LD      A,34
          LD      (IX+1),A
          JR      PATER2
;
; --- GAME SELECT ROUTINE ---
;
SELECT:   CALL    CLSPRI
          LD      A,00001001B
          LD      (SWHICH),A
          LD      A,13
          LD      (SCOLOR),A
          CALL    DSET
          DEFW    GAMEM,MOJIMV
          DEFB    9,200,0,0,0,66
          DEFB    100,0,00010001B
          CALL    DSET
          DEFW    PRACTM,MOJIMV
          DEFB    11,200,0,0,0,60
          DEFB    150,0,00010101B
          CALL    DSET
          DEFW    WALLPT,WALLMV
          DEFB    135,75,60,0,0,0
          DEFB    9,0,00001000B
          CALL    DSET
          DEFW    WALLPT,WALLMV
          DEFB    135,170,60,0,0,0
          DEFB    11,0,00001001B
          CALL    UNFADE
          LD      A,8
          CALL    MAIN
          ;
          LD      C,0
LPSLCT:   LD      A,2
          CALL    MAIN
          CALL    STRIG
          OR      A
          JR      Z,JUMPSL
          CALL    STICK
          OR      A
          JR      Z,LPSLCT
          LD      A,C
          XOR     1
          LD      C,A
          LD      A,(PORIDAT+63)
          LD      B,A
          LD      A,(PORIDAT+47)
          LD      (PORIDAT+63),A
          LD      A,B
          LD      (PORIDAT+47),A
          JP      LPSLCT
          ;
JUMPSL:   CALL    FADE
          LD      A,10
          CALL    ITEMGT
          CALL    MAIN
          LD      HL,0
          LD      (SCORE),HL
          LD      A,9
          LD      (STOCK),A
          LD      A,C
          OR      A
          JP      NZ,PRATCE
          ;
GAME:     LD      HL,GMOUT
          LD      (JPDEAD),HL
          CALL    STAGE1
          CALL    STAGE2
          CALL    STAGE3
          CALL    STAGE4
          CALL    ENDING
          CALL    WSCORE
          JP      TITLE
          ;
GMOUT:    CALL    GMOVER
          CALL    WSCORE
          JP      TITLE
          ;
JPDEAD    DEFW    0
GAMEM:    DEFB    'G',20,0,'A',50,0,'M',80,0,'E',110,0,0
PRACTM:   DEFB    'P',20,0,'R',35,0,'A',50,0,'C',65,0,'T',80,0
          DEFB    'I',95,0,'C',110,0,'E',125,0,0
          ;
WALLPT:   DEFB    8,0
          DEFB    -120,  30, 5
          DEFB    -120, -30, 5
          DEFB     120, -30, 5
          DEFB     120,  30, 5
          DEFB    -120,  30,-5
          DEFB    -120, -30,-5
          DEFB     120, -30,-5
          DEFB     120,  30,-5
          DEFB    1,2,3,4,1,0
          DEFB    5,6,7,8,5,0,0
          ;
WALLMV:   CALL    MOVE
          DEFB    0,0,0,0,1,0
          ;
MOJIMV:   INC     (IX+1)
          JP      MHYOUJ
;
; --- PRACTICE ROUTINE ---
;
PRATCE:   CALL    CLSPRI
          LD      A,00001001B
          LD      (SWHICH),A
          LD      A,1
          LD      (SCOLOR+1),A
          CALL    DSET
          DEFW    PRATM,PRAMJV
          DEFB    9,200,0,0,0,76
          DEFB    100,0,00010001B
          CALL    DSET
          DEFW    M1,SJIMV
          DEFB    0,0,0,0,0,0
          DEFB    10,0,00001010B
          CALL    DSET
          DEFW    M4,SJIMV
          DEFB    0,0,0,0,0,0
          DEFB    8,8,00001010B
          CALL    DSET
          DEFW    M3,SJIMV
          DEFB    0,0,0,0,0,0
          DEFB    5,16,00001010B
          CALL    DSET
          DEFW    M2,SJIMV
          DEFB    0,0,0,0,0,0
          DEFB    3,24,00001010B
          CALL    UNFADE
          LD      C,0
PRLOOP:   LD      A,1
          CALL    MAIN
          CALL    STRIG
          JP      Z,JPPRCT
          CALL    STICK
          CP      3
          JR      NZ,PRJP2
          LD      B,8
PRJP1:    INC     C
          LD      A,1
          CALL    MAIN
          DJNZ    PRJP1
          JR      PRLOOP
PRJP2:    CP      7
          JR      NZ,PRLOOP
          LD      B,8
PRJP3:    DEC     C
          LD      A,1
          CALL    MAIN
          DJNZ    PRJP3
          JP      PRLOOP
          ;
JPPRCT:   LD      B,10
          CALL    FADE
		  CALL    ITEMGT
JPPRJ1:   LD      A,1
          CALL    MAIN
          DJNZ    JPPRJ1
          LD      HL,PRART
          LD      (JPDEAD),HL
          LD      A,9
          LD      (STOCK),A
          LD      HL,0
          LD      (SCORE),HL
          LD      A,C
          SRL     A
          SRL     A
          SRL     A
          AND     3
          JR      NZ,JPCT1
          CALL    STAGE1
          JP      PRATCE
JPCT1:    CP      1
          JR      NZ,JPCT2
          CALL    STAGE2
          JP      PRATCE
JPCT2:    CP      2
          JR      NZ,JPCT3
          CALL    STAGE3
          JP      PRATCE
JPCT3:    CALL    STAGE4
          CALL    ENDING
          JP      TITLE
          ;
PRART:	  POP	  HL
		  JP	  TITLE
		  ;
SJIMV:    LD      (IX+7),128
          LD      (IX+8),160
          LD      (IX+9),10
          LD      A,C
          ADD     A,(IX+14)
          AND     31
          LD      (TDSJI1+2),A
          LD      (IX+12),A
          CALL    RTURN
          DEFB    128,100,128
TDSJI1:   DEFB    0,0,0
          CALL    MOVE
          DEFB    0,0,0
          DEFB    1,0,0
          ;
PRATM:    DEFB    'Z',20,0,'O',40,5,'N',60,2,'E',85,0,0
          ;
PRAMJV:   INC     (IX+1)
          LD      A,C
          AND     31
          SRL     A
          SRL     A
          SRL     A
          LD      H,0
          LD      L,A
          LD      DE,TBLCOR
          ADD     HL,DE
          LD      A,(HL)
          LD      (SCOLOR),A
          LD      (IX+7),A
          JP      MHYOUJ

TBLCOR:   DEFB    11,2,4,6
;--------------------------------------------------
;
; ENDING DEMO
;
;--------------------------------------------------
;
; GAME CLEAR
;
ENDING:   CALL    CLSPRI
          LD      A,8
          CALL    MAIN
          LD      A,00001001B
          LD      (SWHICH),A
          LD      HL,0203H
          LD      (SCOLOR),HL
          LD      HL,0
          LD      (GAGE),HL
          ;
          CALL    DSET
          DEFW    MSDATA,EMSPT1
          DEFB    128,160,16,0,1,0
          DEFB    3,0,00001000B
          CALL    UNFADE
          LD      A,24
          CALL    MAIN
          CALL    DSET
          DEFW    PRODUM,MHYOUJ
          DEFB    2,34,0,0,0,75
          DEFB    80,0,00000101B
          LD      A,36
          CALL    MAIN
          CALL    DSET
          DEFW    MSX2ROC,MHYOUJ
          DEFB    2,34,0,0,0,73
          DEFB    80,0,00000101B
          LD      A,36
          CALL    MAIN
          CALL    DSET
          DEFW    ROCKM ,MHYOUJ
          DEFB    2,34,0,0,0,73
          DEFB    80,0,00000101B
          LD      A,36
          CALL    MAIN
          CALL    DSET
          DEFW    THEENM,MHYOUJ
          DEFB    2,34,0,0,0,82
          DEFB    80,0,00000101B
          LD      A,36
          CALL    MAIN
          XOR     A
          LD      (PORIDAT+1),A
          LD      HL,EMSPT2
          LD      (PORIDAT+5),HL
          LD      A,32
          CALL    MAIN
          CALL    FADE
          LD      A,16
          CALL    MAIN
          LD      A,00001000B
          LD      (SWHICH),A
          CALL    DSET
          DEFW    MSXM,MHYOUJ
          DEFB    15,230,0,0,0,98
          DEFB    110,0,00010001B
          CALL    DSET
          DEFW    FOREVM,MHYOUJ
          DEFB    15,230,0,0,0,83
          DEFB    150,0,00010101B
          CALL    UNFADE
          LD      A,150
          CALL    MAIN
          CALL    FADE
          LD      A,8
          CALL    MAIN
          RET
          ;
EMSPT1:   LD      A,(IX+1)
          INC     (IX+1)
          CP      6
          JR      NC,$+11
          CALL    MOVE
          DEFB    -16,0,0,1,0,0
          CP      18
          JR      NC,$+11
          CALL    MOVE
          DEFB    16,0,0,-1,0,0
          CP      24
          JR      NC,$+11
          CALL    MOVE
          DEFB    -16,0,0,1,0,0
          XOR     A
          LD      (IX+1),A
          JR      EMSPT1
          ;
EMSPT2:   LD      A,(IX+1)
          INC     (IX+1)
          CP      12
          JR      NC,$+11
          CALL    MOVE
          DEFB    -5,-2,16,0,0,0
          CP      16
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,0,0,-1,-3
          CALL    MOVE
          DEFB    8,-6,-24,0,0,0
          ;
PRODUM:   DEFB   'P',0,0,'R',15,0,'O',30,0,'D',45,0,'U',60,0,'C',75,0
          DEFB   'E',90,0,'D',105,0,'B',45,50,'Y',60,50,0
MSX2ROC:  DEFB   'M',-30,0,'S',-15,3,'X',0,6,'2',15,9,'R',30,12,'O',45,15
          DEFB   'C',60,18,'K',75,21,'C',90,24,'I',105,27,'T',120,30,'Y',135,33,0
ROCKM:    DEFB   'R',0,0,'O',15,0,'C',30,0,'K',45,0,'C',65,0,'I',80,0
          DEFB   'T',95,0,'Y',110,0,0
THEENM:   DEFB   'T',0,0,'H',15,0,'E',30,0,'E',55,0,'N',70,0,'D',85,0,0
MSXM:     DEFB   'M',0,0,'S',30,0,'X',60,0,0
FOREVM:   DEFB   'F',0,0,'O',15,0,'R',30,0,'E',45,0,'V',60,0,'E',75,0
          DEFB   'R',90,0,0
;
; SCORE ROUTINE
;
WSCORE:   CALL    CLSPRI
          LD      HL,(SCORE)
          LD      IX,NSCORM
          CALL    CHTEN
          CALL    DSET
          DEFW    NSCORM,MHYOUJ
          DEFB    15,80,0,0,0,140
          DEFB    140,0,00010001B
          LD      HL,(HSCORE)
          LD      DE,(SCORE)
          OR      A
          SBC     HL,DE
          PUSH    AF
          ADD     HL,DE
          POP     AF
          LD      C,15
          JR      NC,$+4
          EX      DE,HL
          LD      C,8
          LD      A,C
          LD      (HSCORD+4),A
          LD      (HSCORE),HL
          LD      IX,HSCORM
          CALL    CHTEN
          CALL    DSET
HSCORD:   DEFW    HSCORM,MHYOUJ
          DEFB    15,80,0,0,0,140
          DEFB    100,0,00010001B
          CALL    DSET
          DEFW    HSCOR2,MHYOUJ
          DEFB    14,80,0,0,0,20
          DEFB    100,0,00010101B
          CALL    DSET
          DEFW    SCORE2,MHYOUJ
          DEFB    14,80,0,0,0,20
          DEFB    140,0,00010101B
          CALL    UNFADE
          LD      A,00001000B
          LD      (SWHICH),A
          CALL    UNFADE
          LD      A,50
          CALL    MAIN
          CALL    FADE
          LD      A,8
          CALL    MAIN
          JP      TITLE
          ;
NSCORM:   DEFB    '0',0,0,'0',20,0,'0',40,0,'0',60,0,'0',80,0,0
HSCORM:   DEFB    '0',0,0,'0',20,0,'0',40,0,'0',60,0,'0',80,0,0
HSCOR2:   DEFB    'H',0,0,'I',12,0,'S',30,0,'C',45,0,'O',60,0
          DEFB    'R',75,0,'E',90,0,0
SCORE2:   DEFB    'S',0,0,'C',15,0,'O',30,0,'R',45,0,'E',60,0,0
;
; GAME OVER
;
GMOVER:   CALL    CLSPRI
          LD      A,14
          CALL    MAIN
          CALL    DSET
          DEFW    GMOVEM,MHYOUJ
          DEFB    8,40,0,0,0,80
          DEFB    90,0,00000001B
          CALL    UNFADE
          LD      A,00001000B
          LD      (SWHICH),A
          LD      A,32
          CALL    MAIN
          CALL    FADE
          LD      A,20
          CALL    MAIN
          JP      WSCORE
          ;
GMOVEM:   DEFB    'G',0,0,'A',30,0,'M',60,0,'E',90,0
          DEFB    'O',0,80,'V',30,80,'E',60,80,'R',90,80,0
         

;-----------------------------------------------------------
;
; STAGE 1
;
;-----------------------------------------------------------
;
;---- STAGE1 PROGRAM ----
;
STAGE1:   CALL    CLSPRI
		  LD	  (STACK),SP
          LD      A,00001000B
          LD      (SWHICH),A
          CALL    DSET
          DEFW    S1STAGM1,MHYOUJ
          DEFB    11,40,0,0,0,44
          DEFB    0,0,00010101B
          CALL    DSET
          DEFW    S1STAGM2,MHYOUJ
          DEFB    11,40,0,0,0,40
          DEFB    50,0,00010001B
          CALL    UNFADE
          LD      A,32
          CALL    MAIN
          CALL    FADE
          LD      A,8
          CALL    MAIN
          CALL    MSSTR
          ;
S1CONT:   CALL	  MOVESD
		  LD      HL,S1STAGD1
          LD      DE,SCROLL
          LD      BC,9
          LDIR
          LD      HL,S2JPDAT1
          LD      DE,JPTUCH
          LD      BC,32
          LDIR
          LD      A,24
          CALL    MAIN
          LD      B,192
S1LOOP:   LD      HL,S1RETLOP
          PUSH    HL
          CALL    RND
          CP      90
          JP      C,S1CHARA1
          CP      150
          JP      C,S1CHARA2
          CP      200
          JP      C,S1CHARA3
          CP      240
          JP      C,TECHNO
          JP      PARTY
S1RETLOP: CALL    TURBO
          CALL    CURE
          LD      A,B
          RLCA
          RLCA
          AND     3
          INC     A
          INC     A
          CALL    MAIN
          DJNZ    S1LOOP
          ;
          LD      A,(SWHICH)
          AND     11111110B
          LD      (SWHICH),A
          LD      HL,S1CONT2
          LD      (CONTRT),HL
S1CONT2:  CALL    MOVESD
		  LD      A,28
          CALL    MAIN
          LD      B,40
S1LOOP2:  CALL    S1CHARA3
          CALL    S1CHARA3
          LD      A,2
          CALL    MAIN
          DJNZ    S1LOOP2
          LD      B,50
S1LOOP3:  CALL    S1CHARA1
          CALL    S1CHARA1
          CALL    CURE
          CALL    TURBO
          LD      A,2
          CALL    MAIN
          DJNZ    S1LOOP3
          LD      A,16
          CALL    MAIN
          JP      S1BOSS
;
; STAGE1 DATA
;
S1STAGD1: DEFB    32,5,11,2
          DEFB    01011011B
          DEFW    S1CONT,DEAD
          ;
S1JPDAT1: DEFW    TUCH0,TUCH1
          DEFW    TUCH2,TUCH3
          DEFW    TUCH4,TUCH5
          DEFW    TUCH6,TUCH6
          DEFW    TUCH17,TUCH18
          DEFW    TUCH0,TUCH0
          DEFW    TUCH0,TUCH0
          DEFW    TUCH0,TUCH0
          ;
S1STAGM1: DEFB    'Z',60,80
          DEFB    'O',75,80
          DEFB    'N',90,80
          DEFB    'E',105,80
          DEFB    '1',120,80,0
S1STAGM2: DEFB    'P',30,80
          DEFB    'L',60,80
          DEFB    'A',90,80
          DEFB    'N',120,80
          DEFB    'E',150,80,0
;
; STAGE 1 -- CHARACTER 1
;
S1CHARA1: CALL    RND
          CP      186
          JR      NC,$-5
          ADD     A,38
          LD      (S1CHARD1+4),A
          CALL    RND
          CP      196
          JR      NC,$-5
          ADD     A,44
          LD      (S1CHARD1+5),A
          CALL    DSET
S1CHARD1: DEFW    S1CHAPT1,S1CHAMV1
          DEFB    0,0,250,0,0,0
          DEFB    10,1,00000000B
          RET
          ;
S1CHAMV1: CALL    MOVE
          DEFB    0,0,-32,0,0,-2
          ;
S1CHAPT1: DEFB    4,0
          DEFB    -32, 18, 18
          DEFB     32, 18, 18
          DEFB      0,-36, 18
          DEFB      0,  0,-36
          DEFB    1,2,3,1,4,2,0
          DEFB    4,3,0,0
;
; STAGE 1 -- CHARACTER 2
;
S1CHARA2: CALL    RND
          AND     127
          ADD     A,64
          LD      (S1CHARD2+4),A
          CALL    RND
          AND     127
          ADD     A,64
          LD      (S1CHARD2+5),A
          CALL    DSET
S1CHARD2: DEFW    S1CHAPT2,S1CHAMV2
          DEFB    0,0,255,0,0,0
          DEFB    2,2,00000000B
          RET
          ;
S1CHAPT2: DEFB    11,3
          DEFB    -12,-48,-12
          DEFB    -12,-48, 12
          DEFB     12,-48, 12
          DEFB     12,-48,-12
          DEFB    -12, 48,-12
          DEFB    -12, 48, 12
          DEFB     12, 48, 12
          DEFB     12, 48,-12
          DEFB      0, 24,  0
          DEFB      0,-24,  0
          DEFB      0,  0,  0
          DEFB    1,2,3,4,1,5,6
          DEFB    7,8,5,0,4,8,0
          DEFB    3,7,0,2,6,0,0
          ;
S1CHAMV2: CALL    MOVE
          DEFB    0,0,-16,2,0,0
;
; STAGE 1 -- CHARACTER 3
;
S1CHARA3: CALL    RND
          LD      (S1CHARD3+4),A
          CALL    RND
          AND     127
          ADD     A,64
          LD      (S1CHARD3+5),A
          CALL    DSET
S1CHARD3: DEFW    S1CHAPT2,S1CHAMV3
          DEFB    128,128,255
          DEFB    0,0,0,2,2,00000000B
          RET
          ;
S1CHAMV3: LD      A,(IX+9)
          SUB     32
          LD      (IX+9),A
          RET
;
; STAGE 1 -- BOSS
;
S1BOSSPT: DEFB    10,0
          DEFB      0,-48, 17
          DEFB      0,-61,  0
          DEFB    -13,-48,  0
          DEFB      0,-35,  0
          DEFB     13,-48,  0
          DEFB      0, 48, 17
          DEFB      0, 61,  0
          DEFB    -13, 48,  0
          DEFB      0, 35,  0
          DEFB     13, 48,  0
          DEFB    2,3,4,5,2,0,2,1,4,0
          DEFB    3,1,5,0,7,8,9,10,7,0
          DEFB    7,6,9,0,8,6,10,0,0
          ;
S1BOSMV1: LD      A,(PORIDAT)
          OR      A
          JR      Z,S1ENDMV1
          LD      A,(IX+1)
          INC     (IX+1)
          CP      16
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,-8,2,0,0
          CP      32
          JR      NC,$+11
          CALL    MOVE
          DEFB    -4,0,0,0,0,0
          CP      64
          JR      NC,$+11
          CALL    MOVE
          DEFB    4,0,0,0,2,0
          CP      80
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,-4,0,0,0
          CP      112
          JR      NC,$+11
          CALL    MOVE
          DEFB    -4,0,0,0,-2,0
          CP      144
          JR      NC,$+11
          CALL    MOVE
          DEFB    2,0,6,1,-2,0
          XOR     A
          LD      (IX+1),A
          JR      S1BOSMV1
S1ENDMV1: XOR     A
          LD      (IX+0),A
          RET
          ;
S1BOSMV2: LD      A,(PORIDAT)
          OR      A
          JR      Z,S1ENDMV2
          LD      A,(IX+1)
          INC     (IX+1)
          CP      16
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,-8,0,0,2
          CP      32
          JR      NC,$+11
          CALL    MOVE
          DEFB    -4,0,0,0,0,3
          CP      64
          JR      NC,$+11
          CALL    MOVE
          DEFB    4,0,0,0,0,0
          CP      80
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,-4,0,0,-3
          CP      112
          JR      NC,$+11
          CALL    MOVE
          DEFB    -4,0,0,0,0,1
          CP      144
          JR      NC,$+11
          CALL    MOVE
          DEFB    2,0,6,-1,0,2
          XOR     A
          LD      (IX+1),A
          JR      S1BOSMV2
S1ENDMV2: XOR     A
          LD      (IX+0),A
          RET
          ;
S1BOSS:   CALL    DSET
          DEFW    S1ATACKM,MHYOUJ
          DEFB    9,16,1,1,0
          DEFB    68,80,0,00100101B
          LD      A,17
          CALL    MAIN
          CALL    CLSPRI
          CALL    DSET
          DEFW    S1COREPT,S1BOSMV2
          DEFB    128,128,230
          DEFB    0,0,0,9,9,00000000B
          CALL    DSET
          DEFW    S1BOSSPT,S1BOSMV1
          DEFB    128,128,230
          DEFB    0,0,0,5,8,00000000B
          CALL    DSET
          DEFW    S1BOSSPT,S1BOSMV2
          DEFB    128,128,230
          DEFB    8,0,0,5,8,00000000B
S1LOOP8:  LD      A,1
          CALL    MAIN
          LD      A,(PORIDAT)
          OR      A
          JR      NZ,S1LOOP8
          LD      HL,HOME
          LD      (MASTER+5),HL
S1LOOP9:  LD      A,1
          CALL    MAIN
          LD      A,(MASTER+1)
          OR      A
          JR      NZ,S1LOOP9
          ;
          CALL    DSET
          DEFW    S1STAGM1,MHYOUJ
          DEFB    10,24,0,0,0,38,8
          DEFB    0,00000101B
          CALL    DSET
          DEFW    S1CLEARM,MHYOUJ
          DEFB    10,24,0,0,0,38,134
          DEFB    0,00000101B
          LD      A,28
          CALL    MAIN
          CALL    DSET
          DEFW    S1BONUSM,MHYOUJ
          DEFB    10,24,0,0,0,0,55
          DEFB    0,00000101B
          CALL    DSET
          DEFW    S1SCOREM,MHYOUJ
          DEFB    10,24,0,0,0,8,80
          DEFB    0,00010101B
          LD      HL,(SCORE)
          LD      DE,1000
          ADD     HL,DE
          JR      NC,$+5
          LD      HL,65535
          LD      (SCORE),HL
          LD      A,(STOCK)
          INC     A
          CP      10
          JR      C,$+4
          LD      A,9
          LD      (STOCK),A
          LD      A,30
          CALL    MAIN
          CALL    FADE
          LD      A,24
          CALL    MAIN
          CALL    SDOFF
          RET
          ;
TUCH17:	  CALL	  TUCH2
          LD      A,(MASTER+9)
          XOR     127
          ADD     A,17
          LD      (MASTER+9),A
          RET
          ;
TUCH18    CALL    PISTOL
          LD      A,64
          LD      (MASTER+8),A
          LD      A,(IX+13)
          CP      9
          JR      NZ,$+8
          LD      A,8
          LD      (IX+13),A
          RET
          CP      8
          JR      NZ,$+8
          LD      A,6
          LD      (IX+13),A
          RET
          XOR     A
          LD      (IX+0),A
          RET
          ;
S1COREPT: DEFB    6,0
          DEFB      0,-24,  0
          DEFB      0, 24,  0
          DEFB      0,  0,-13
          DEFB    -14,  0,  0
          DEFB      0,  0, 13
          DEFB     13,  0,  0
          DEFB    1,4,2,6,1,0,5,4,3,6,5,0
          DEFB    1,3,2,5,1,0,0
          ;
S1ATACKM: DEFB    'A',20,0,'T',40,0,'A',60,0,'C',80,0,'K',100,0,0
S1CLEARM: DEFB    'C',60,30,'L',75,30,'E',90,30,'A',105,30,'R',120,30,0
S1BONUSM: DEFB    'B',88,30,'O',108,30,'N',128,30,'U',148,30,'S',168,30,0
S1SCOREM: DEFB    '1',98,60,'0',113,60,'0',128,60,'0',142,60
          DEFB    '1',98,90,'U',113,90,'P',128,90,0


;-----------------------------------------------------------
;
; STAGE 2
;
;-----------------------------------------------------------
;
;---- STAGE2 PROGRAM ----
;
STAGE2:   CALL    CLSPRI
		  LD	  (STACK),SP
          LD      A,00001000B
          LD      (SWHICH),A
          CALL    DSET
          DEFW    S2STAGM1,MHYOUJ
          DEFB    12,40,0,0,0,44
          DEFB    0,0,00010101B
          CALL    DSET
          DEFW    S2STAGM2,MHYOUJ
          DEFB    12,40,0,0,0,26
          DEFB    50,0,00000101B
          CALL    UNFADE
          LD      A,32
          CALL    MAIN
          CALL    FADE
          LD      A,8
          CALL    MAIN
          CALL    MSSTR
          ;
S2CONT:   CALL	  MOVESD
		  LD      HL,S2STAGD1
          LD      DE,SCROLL
          LD      BC,9
          LDIR
          LD      HL,S2JPDAT1
          LD      DE,JPTUCH
          LD      BC,32
          LDIR
          LD      A,24
          CALL    MAIN
         
          LD      B,128
S2LOOP:   LD      HL,S2RETLOP
          PUSH    HL
          CALL    TURBO
          CALL    CURE
          LD      A,B
          CP      64
          JP      Z,S2CHARA2
          JR      C,S2J1
          CALL    RND
          CP      100
          JP      C,S2CHARA3
          CP      150
          JP      C,S2CHARA6
          CP      180
          JP      C,TECHNO
          CP      215
          JP      C,PARTY
          RET
          ;
S2J1:     CP      48
          RET     NC
          CP      40
          JP      NC,S2CHARA4
          CP      32
          JP      NC,S2CHARA5
          CP      28
          RET     NC
          CP      20
          JP      Z,S2CHARA2
          JP      NC,S2CHARA1
          POP     HL
          ;
S2RETLOP: CALL    RND
          AND     3
          ADD     A,2
          CALL    MAIN
          DJNZ    S2LOOP
          ;
          LD      A,(SWHICH)
          AND     11111110B
          LD      (SWHICH),A
          LD      HL,S2CONT2
          LD      (CONTRT),HL
S2CONT2:  CALL	  MOVESD
		  LD      A,24
          CALL    MAIN
          LD      B,192
S2LOOP2:  CALL    TURBO
          CALL    CURE
          LD      HL,S2RETLP3
          PUSH    HL
          CALL    RND
          CP      80
          JP      C,S2CHARA3
          CP      110
          JP      C,S2CHARA6
          CP      135
          JP      C,S2CHARA4
          CP      145
          JP      C,S2CHARA5
          CP      155
          JP      C,S2CHARA1
          CP      190
          JP      C,TECHNO
          CP      220
          JP      C,PARTY
          POP     HL
S2RETLP3: LD      A,B
          RLCA
          RLCA
          AND     3
          ADD     A,2
          CALL    MAIN
          DJNZ    S2LOOP2
          LD      A,32
          CALL    MAIN
          JP      S2BOSS
;
; STAGE2 DATA
;
S2STAGD1: DEFB    32,5,12,2
          DEFB    01011011B
          DEFW    S2CONT,DEAD
          ;
S2JPDAT1: DEFW    TUCH0,TUCH1
          DEFW    TUCH2,TUCH3
          DEFW    TUCH4,TUCH5
          DEFW    TUCH6,TUCH6
          DEFW    TUCH27,TUCH28
          DEFW    TUCH0,TUCH0
          DEFW    TUCH0,TUCH0
          DEFW    TUCH0,TUCH0
          ;
S2STAGM1: DEFB    'Z',60,80
          DEFB    'O',75,80
          DEFB    'N',90,80
          DEFB    'E',105,80
          DEFB    '2',120,80,0
S2STAGM2: DEFB    'F',30,80
          DEFB    'O',60,80
          DEFB    'R',90,80
          DEFB    'E',120,80
          DEFB    'S',150,80
          DEFB    'T',180,80,0
;
; STAGE 2 -- CHARACTER 1
;
S2CHARA1: CALL    RND
          AND     127
          ADD     A,90
          LD      (S2CHARD1+4),A
          CALL    DSET
S2CHARD1: DEFW    S2CHPD11,S2CHARP1
          DEFB    0,225,245,0,0,0
          DEFB    13,1,00000000B
          RET
          ;
S2CHPD11: DEFB    6,0
          DEFB      0,  0,-20
          DEFB    -30,-10,-10
          DEFB     30,-10,-10
          DEFB      0,  0, 40
          DEFB    -10,-16,-20
          DEFB     10,-16,-20
          DEFB    1,2,4,3,1,4,0,5,1,6,0,0
          ;
S2CHPD12: DEFB    6,0
          DEFB      0,  0,-20
          DEFB    -20, 20,-10
          DEFB     20, 20,-10
          DEFB      0,  0, 40
          DEFB    -10,-16,-20
          DEFB     10,-16,-20
          DEFB    1,2,4,3,1,4,0,5,1,6,0,0
          ;
S2HABATA: LD      A,(IX+1)
          INC     (IX+1)
          LD      C,A
          LD      HL,S2CHPD11
          AND     2
          JR      Z,$+5
          LD      HL,S2CHPD12
          LD      (IX+3),L
          LD      (IX+4),H
          LD      A,C
          RET
          ;
S2CHARP1: CALL    S2HABATA
          CP      8
          JR      NC,$+11
          LD      A,(IX+9)
          SUB     16
          LD      (IX+9),A
          RET
          CP      40
          JR      NC,$+20
          CALL    RTURN
          DEFB    128,128,128,0,2,0
          CALL    MOVE
          DEFB    -2,0,0,0,2,0
          LD      A,(IX+9)
          SUB     16
          LD      (IX+9),A
          RET
;
; STAGE 2 -- CHARACTER 2
;
S2CHARA2: CALL    RND
          AND     31
          ADD     A,112
          LD      (S2CHARD2+4),A
          LD      (S2CHAR22+4),A
          CALL    DSET
S2CHARD2: DEFW    S2CHAPD2,S2CHARP2
          DEFB    128,128,245,0,0,0
          DEFB    12,2,00000010B
          CALL    DSET
S2CHAR22: DEFW    S2CHAPD2,S2CHARP2
          DEFB    128,128,245,8,0,0
          DEFB    12,2,00000010B
          RET
          ;
S2CHAPD2: DEFB    11,3
          DEFB     -8,-50, -8
          DEFB     -8,-50,  8
          DEFB      8,-50,  8
          DEFB      8,-50, -8
          DEFB     -8, 50, -8
          DEFB     -8, 50,  8
          DEFB      8, 50,  8
          DEFB      8, 50, -8
          DEFB      0, 24,  0
          DEFB      0,-24,  0
          DEFB      0,  0,  0
          DEFB    1,2,3,4,1,5,6
          DEFB    7,8,5,0,4,8,0
          DEFB    3,7,0,2,6,0,0
          ;
S2CHARP2: LD      A,(IX+13)
          XOR     15
          LD      (IX+13),A
          LD      A,(IX+1)
          INC    (IX+1)
          CP      8
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,-24,2,0,0
          CP      40
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,0,1,-2,-1
          CP      72
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,0,2,1,2
          CALL    MOVE
          DEFB    0,0,-8,2,0,0
;
; STAGE 2 -- CHARACTER 3
;
S2CHARA3: CALL    RND
          CP      200
          JR      NC,$-5
          ADD     A,25
          LD      (S2CHARD3+4),A
          LD      HL,S2CHRP31
          CALL    RND
          AND     00010100B
          JR      Z,$+5
          LD      HL,S2CHRP32
          LD      (S2CHARD3+2),HL
          CALL    DSET
S2CHARD3: DEFW    S2CHAPD3,S2CHRP31
          DEFB    128,225,255
          DEFB    0,0,0,12,2,00000000B
          RET
          ;
S2CHRP32: LD      A,(IX+9)
          SUB     24
          LD      (IX+9),A
          RET
          ;
S2CHRP31: LD      A,(IX+1)
          CP      1
          JR      Z,S2CJ5
          LD      A,(IX+9)
          SUB     24
          LD      (IX+9),A
          LD      C,A
          LD      A,(MASTER+9)
          NEG
          ADD     A,C
          CP      60
          RET     NC
          LD      A,1
          LD      (IX+1),1
          RET
S2CJ5:    LD      A,(IX+9)
          SUB     16
          LD      (IX+9),A
          LD      A,(IX+7)
          CP      128
          LD      A,(IX+10)
          JR      NC,S2CJ52
          CP      8
          RET     NC
          ADD     A,2
          LD      (IX+10),A
          RET
S2CJ52:   SUB     2
          AND     31
          CP      24
          RET     C
          LD      (IX+10),A
          RET
          ;
S2CHAPD3: DEFB    10,0
          DEFB      0,-127, 0
          DEFB    -17,  0, 17
          DEFB     -7,  0,-23
          DEFB     23,  0,  7
          DEFB    -11,-43,  0
          DEFB     -5,-43,  0
          DEFB     16,-43,  0
          DEFB     -8,-86,  0
          DEFB     -2,-86,  0
          DEFB      8,-86,  0
          DEFB    1,2,3,1,4,2,0,4,3,0,0
;
; STAGE 2 -- BOSS
;
S2BOSS:   CALL    DSET
          DEFW    S2ATACKM,MHYOUJ
          DEFB    9,16,1,1,0
          DEFB    72,80,0,00100101B
          LD      A,17
          CALL    MAIN
          CALL    CLSPRI
          CALL    DSET
          DEFW    S2COREPT,S2BOSMV2
          DEFB    128,56,64
          DEFB    0,0,0,9,9,00000000B
          CALL    DSET
          DEFW    S2CHPD11,S2BOSMV3
          DEFB    128,32,64
          DEFB    0,0,0,9,8,00000010B
          LD      HL,4005H
          CALL    S2BOSS2
          LD      A,8
          CALL    MAIN
          LD      HL,0C00DH
          CALL    S2BOSS2
          LD      A,8
          CALL    MAIN
          LD      HL,800BH
          CALL    S2BOSS2
S2LOOP8:  LD      A,1
          CALL    MAIN
          LD      A,(PORIDAT)
          OR      A
          JR      NZ,S2LOOP8
          LD      HL,HOME
          LD      (MASTER+5),HL
S2LOOP9:  LD      A,1
          CALL    MAIN
          LD      A,(MASTER+1)
          OR      A
          JR      NZ,S2LOOP9
          ;
          CALL    DSET
          DEFW    S2STAGM1,MHYOUJ
          DEFB    2,24,0,0,0,38,8
          DEFB    0,00000101B
          CALL    DSET
          DEFW    S2CLEARM,MHYOUJ
          DEFB    2,24,0,0,0,38,134
          DEFB    0,00000101B
          LD      A,28
          CALL    MAIN
          CALL    DSET
          DEFW    S2BONUSM,MHYOUJ
          DEFB    2,24,0,0,0,0,55
          DEFB    0,00000101B
          CALL    DSET
          DEFW    S2SCOREM,MHYOUJ
          DEFB    2,24,0,0,0,8,80
          DEFB    0,00010101B
          LD      HL,(SCORE)
          LD      DE,2000
          ADD     HL,DE
          JR      NC,$+5
          LD      HL,65535
          LD      (SCORE),HL
          LD      A,(STOCK)
          INC     A
          CP      10
          JR      C,$+4
          LD      A,9
          LD      (STOCK),A
          LD      A,30
          CALL    MAIN
          CALL    FADE
          LD      A,24
          CALL    SDOFF
          CALL    MAIN
          RET
          ;
TUCH27:   CALL    TUCH2
          LD      A,(MASTER+9)
          XOR     127
          ADD     A,17
          LD      (MASTER+9),A
          RET
          ;
TUCH28:   CALL   PISTOL
          LD     A,32
          LD     (MASTER+8),A
          LD     A,(IX+13)
          CP     9
          JR     NZ,$+8
          LD     A,8
          LD     (IX+13),A
          RET
          CP     8
          JR     NZ,$+8
          LD     A,6
          LD     (IX+13),A
          RET
          XOR    A
          LD     (IX+0),A
          RET
          ;       
S2COREPT: DEFB    6,0
          DEFB      0,-24,  0
          DEFB      0, 24,  0
          DEFB      0,  0,-13
          DEFB    -13,  0,  0
          DEFB      0,  0, 13
          DEFB     13,  0,  0
          DEFB    1,4,2,6,1,0,5,4,3,6,5,0
          DEFB    1,3,2,5,1,0,0
          ;
S2ATACKM:  DEFB    'A',9,0,'T',32,0,'A',55,0,'C',79,0,'K',106,0,0
S2CLEARM:  DEFB 'C',60,30,'L',75,30,'E',90,30,'A',105,30,'R',120,30,0
S2BONUSM:  DEFB    'B',88,30,'O',108,30,'N',128,30,'U',148,30,'S',168,30,0
S2SCOREM:  DEFB    '2',98,60,'0',113,60,'0',128,60,'0',142,60
           DEFB    '1',98,90,'U',113,90,'P',128,90,0
;
; STAGE 2 -- CHARACTER 5
;
S2CHARA5: CALL    RND
          LD      (S2CHARD5+4),A
          CALL    DSET
S2CHARD5: DEFW    S2CHPD11,S2CHARP5
          DEFB    0,215,245,0,0,0
          DEFB    5,1,00000000B
          RET
          ;
S2CHARP5: CALL    S2HABATA
          CP      4
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,-22,-8,0,2,0
          CP      8
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,-22,-8,0,-2,0
          CP      12
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,22,-8,0,-2,0
          CP      16
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,22,-8,0,2,0
          XOR     A
          LD      (IX+1),A
          JR      S2CHARP5
;
; STAGE 2 -- CHARACTER 4
;
S2CHARP4: CALL    S2HABATA
          CALL    RTURN
          DEFB    128,128,128,2,0,0
          CALL    MOVE
          DEFB    0,0,-8,2,0,0
          ;
S2CHARA4: CALL    RND
          AND     127
          ADD     A,64
          LD      (S2CHARD4+4),A
          CALL    RND
          AND     31
          ADD     A,180
          LD      (S2CHARD4+5),A
          CALL    DSET
S2CHARD4: DEFW    S2CHPD11,S2CHARP4
          DEFB    0,0,240,0,0,0
          DEFB    11,1,00000000B
          RET
;
; STAGE 2 -- CHARACTER 6
;
S2CHARA6: CALL    RND
          CP      190
          JR      NC,$-5
          ADD     A,35
          LD      (S2CHARD6+4),A
          CALL    RND
          CP      190
          JR      NC,$-5
          ADD     A,25
          LD      (S2CHARD6+5),A
          CALL    DSET
S2CHARD6: DEFW    S2CHPD11,S2CHARP6
          DEFB    0,0,255,0,0,0
          DEFB    9,1,00000000B
          RET
          ;
S2CHARP6: CALL    S2HABATA
          LD      A,(IX+9)
          SUB     24
          LD      (IX+9),A
          RET
;
; STAGE 2 -- BOSS
;
S2BOSS2:  LD      A,H
          LD      (S2BOSRD2+5),A
          LD      A,L
          LD      (S2BOSRD2+10),A
          CALL    DSET
S2BOSRD2: DEFW    S2CHPD11,S2BOSMV
          DEFB    192,128,102,0,0,0
          DEFB    7,8,00000000B
          RET
          ;
S2BOSMV:  LD      A,(PORIDAT)
          OR      A
          JR      NZ,$+6
          LD      (IX+0),A
          RET
          CALL    RND
          AND     31
          CALL    Z,S2FUN
          CALL    S2HABATA
          CP      4
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,-18,0,0,-2
          CP      12
          JR      NC,$+11
          CALL    MOVE
          DEFB    -18,0,0,0,0,-1
          CP      16
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,18,0,0,-2
          CP      24
          JR      NC,$+11
          CALL    MOVE
          DEFB    18,0,0,0,0,-1
          XOR     A
          LD      (IX+1),A
          JR      S2BOSMV
          ;
S2BOSMV2: LD      A,(IX+1)
          INC     (IX+1)
          CP      16
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,8,0,0,0,1
          CP      32
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,-8,0,0,0,1
          XOR     A
          LD      (IX+1),A
          JR      S2BOSMV2
          ;
S2BOSMV3: LD      A,(PORIDAT)
          OR      A
          JR      NZ,$+6
          LD      (IX+0),A
          RET
          CALL    S2HABATA
          CP      16
          JR      NC,$+11
          LD      A,(IX+8)
          ADD     A,8
          LD      (IX+8),A
          RET
          CP      32
          JR      NC,$+11
          LD      A,(IX+8)
          SUB     8
          LD      (IX+8),A
          RET
          XOR     A
          LD      (IX+1),A
          JR      S2BOSMV3
;
; STAGE2 BOSS - FUN
;
S2FUN:    LD      A,(IX+7)
          LD      (S2FUNRD+4),A
          LD      A,(IX+8)
          LD      (S2FUNRD+5),A
          LD      A,(IX+9)
          LD      (S2FUNRD+6),A
          CALL    DSET
S2FUNRD:  DEFW    S2FUNPD,S2FUNMV
          DEFB    0,0,0,0,0,0
          DEFB    8,1,00000000B
          RET
          ;
S2FUNMV:  LD      A,(IX+8)
          ADD     A,16
          LD      (IX+8),A
          RET
          ;
S2FUNPD:  DEFB    4,0
          DEFB     -8,  5, -5
          DEFB      8,  5, -5
          DEFB      0,  5,  9
          DEFB      0, -9,  0
          DEFB    1,2,3,1,4,2,0
          DEFB    4,3,0,0
          
;-----------------------------------------------------------
;
; STAGE 3
;
;-----------------------------------------------------------
;
;---- STAGE3 PROGRAM ----
;
STAGE3:   CALL    CLSPRI
		  LD      (STACK),SP
          LD      A,00001000B
          LD      (SWHICH),A
          CALL    DSET
          DEFW    S3STAGM1,MHYOUJ
          DEFB    7,40,0,0,0,44
          DEFB    0,0,00010101B
          CALL    DSET
          DEFW    S3STAGM2,MHYOUJ
          DEFB    7,40,0,0,0,46
          DEFB    55,0,00000101B
          CALL    UNFADE
          LD      A,32
          CALL    MAIN
          CALL    FADE
          LD      A,8
          CALL    MAIN
          CALL    MSSTR  
          ;
S3CONT:   CALL	  MOVESD
		  LD      HL,S3STAGD1
          LD      DE,SCROLL
          LD      BC,9
          LDIR
          LD      HL,S3JPDAT1
          LD      DE,JPTUCH
          LD      BC,32
          LDIR
          LD      A,24
          CALL    MAIN
          LD      B,192
S3LOOP:   LD      HL,S3RETLOP
          PUSH    HL
          CALL    CURE
          CALL    TURBO
          CALL    RND
          CP      40
          CALL    C,TECHNO
          CALL    RND
          CP      30
          CALL    C,PARTY
          LD      A,B
          CP      160
          JR      C,S3SJ1
          CALL    S3CHARA1
          JP      S3CHARA6
          ;
S3SJ1:    CP      90
          JR      C,S3SJ2
          CALL    RND
          CP      120
          CALL    C,S3CHARA1
          CALL    RND
          CP      100
          JP      C,S3CHARA6
          CP      180
          JP      C,S3CHARA3
          JP      S3CHARA4
          ;
S3SJ2:    CP      15
          JR      C,S3SJ3
          AND     15
          CALL    Z,S3CHARA5
          CALL    RND
          CP      100
          CALL    C,S3CHARA1
          CALL    RND
          CP      60
          JP      C,S3CHARA6
          CP      120
          JP      C,S3CHARA3
          CP      180
          JP      C,S3CHARA4
          CP      190
          JP      C,S3CHARA2
          RET
          ;
S3SJ3:    CP      14
          CALL    Z,S3CHARA8
          RET
          ;
S3RETLOP: LD      A,4
          CALL    MAIN
          DJNZ    S3LOOP
          ;
          LD      A,(SWHICH)
          AND     11111110B
          LD      (SWHICH),A
          LD      HL,S3CONT2
          LD      (CONTRT),HL
          ;
S3CONT2:  CALL	  MOVESD
		  LD      A,32
          CALL    MAIN
          LD      B,192
S3LOOP2:  CALL    TURBO
          CALL    CURE
          LD      HL,S3RETLP2
          PUSH    HL
          LD      A,B
          AND     31
          JP      Z,S3CHARA8
          CALL    RND
          CP      80
          CALL    C,S3CHARA1
          CALL    RND
          CP      70
          JP      C,S3CHARA6
          CP      115
          JP      C,S3CHARA4
          CP      145
          JP      C,S3CHARA3
          CP      155
          JP      C,S3CHARA2
          CP      165
          JP      C,S3CHARA7
          CP      200
          JP      C,TECHNO
          CP      240
          JP      C,PARTY
          CP      248
          JP      C,S3CHARA5
          RET
          ;
S3RETLP2: LD      A,B
          RLCA
          RLCA
          AND     3
          ADD     A,3
          CALL    MAIN
          DJNZ    S3LOOP2
          LD      A,32
          CALL    MAIN
          JP      S3BOSS
;
; STAGE3 DATA
;
S3STAGD1: DEFB    32,5,5,2
          DEFB    01011011B
          DEFW    S3CONT,DEAD
          ;
S3JPDAT1: DEFW    TUCH0,TUCH1
          DEFW    TUCH2,TUCH3
          DEFW    TUCH4,TUCH5
          DEFW    TUCH6,TUCH6
          DEFW    TUCH0,TUCH0
          DEFW    TUCH0,TUCH0
          DEFW    TUCH0,TUCH0
          DEFW    TUCH0,TUCH0
          ;
S3STAGM1: DEFB    'Z',60,80
          DEFB    'O',75,80
          DEFB    'N',90,80
          DEFB    'E',105,80
          DEFB    '3',120,80,0
S3STAGM2: DEFB    'I',30,80
          DEFB    'C',45,80
          DEFB    'E',60,80
          DEFB    'L',90,80
          DEFB    'A',105,80
          DEFB    'N',120,80
          DEFB    'D',135,80,0
;
; STAGE 3 -- CHARACTER 1
;
S3CHARA1: CALL    RND
          LD      (S3CHARD1+4),A
          CALL    RND
          AND     31
          LD      (S3CHARD1+5),A
          LD      HL,S3CHARP1
          AND     1
          JR      Z,$+5
          LD      HL,S3CHRP12
          LD      (S3CHARD1+2),HL
          CALL    DSET
S3CHARD1: DEFW    S3CHAPD1,S3CHARP1
          DEFB    0,20,255,0,0,0
          DEFB    7,1,00000000B
          RET
          ;
S3CHAPD1: DEFB    6,2
          DEFB    -10,  0, 10
          DEFB     10,  0, 10
          DEFB      0,  0,-10
          DEFB      0, 80,  0
          DEFB      0, 25, -6
          DEFB      0, 50, -3
          DEFB    1,2,3,1,4,3,0,2,4,0,0
          ;
S3CHPD12: DEFB    6,2
          DEFB    -10,  0, 10
          DEFB     10,  0, 10
          DEFB      0,  0,-10
          DEFB      0,-80,  0
          DEFB      0,-25, -6
          DEFB      0,-50, -3
          DEFB    1,4,3,0,4,2,0,0,4,0,0
          ;
S3CHARP1: LD      A,(IX+1)
          CP      1
          JR      Z,S3CHRP1J
          LD      A,(IX+9)
          SUB     24
          LD      (IX+9),A
          LD      A,(MASTER+9)
          XOR     (IX+9)
          CP      40
          RET     NC
          LD      A,1
          LD      (IX+1),A
          RET
S3CHRP1J: LD      A,(IX+8)
          ADD     A,32
          LD      (IX+8),A
          RET
          ;
S3CHRP12: LD      A,(IX+9)
          SUB     24
          LD      (IX+9),A
          RET
;
; STAGE 3 -- CHARACTER 2
;
S3CHARA2: CALL    RND
          AND     63
          ADD     A,64
          LD      (S3CHARD2+4),A
          ADD     A,32
          LD      (S3CHAR22+4),A
          CALL    RND
          AND     127
          ADD     A,64
          LD      (S3CHARD2+5),A
          LD      (S3CHAR22+5),A
          CALL    DSET
S3CHARD2: DEFW    S3CHAPD2,S3CHARP2
          DEFB    128,128,245,0,0,0
          DEFB    7,2,00000010B
          CALL    DSET
S3CHAR22: DEFW    S3CHAPD2,S3CHRP22
          DEFB    128,128,245,0,0,0
          DEFB    7,2,00000010B
          RET
          ;
S3CHAPD2: DEFB    10,2
          DEFB     -6,-28, -6
          DEFB     -6,-28,  6
          DEFB      6,-28,  6
          DEFB      6,-28, -6
          DEFB     -6, 28, -6
          DEFB     -6, 28,  6
          DEFB      6, 28,  6
          DEFB      6, 28, -6
          DEFB      0,  0,  0
          DEFB      0, -9,  0
          DEFB    1,2,3,4,1,5,6
          DEFB    7,8,5,0,4,8,0
          DEFB    3,7,0,2,6,0,0
          ;
S3CHARP2: LD      A,(IX+1)
          INC     (IX+1)
          CP      3
          JR      NC,$+11
          CALL    MOVE
          DEFB    -16,0,-10,0,0,0
          CP      6
          JR      NC,$+11
          CALL    MOVE
          DEFB    16,0,-10,0,0,0
          XOR     A
          LD      (IX+1),A
          JR      S3CHARP2
          ;
S3CHRP22: LD      A,(IX+1)
          INC     (IX+1)
          CP      3
          JR      NC,$+11
          CALL    MOVE
          DEFB    16,0,-10,0,0,0
          CP      6
          JR      NC,$+11
          CALL    MOVE
          DEFB    -16,0,-10,0,0,0
          XOR     A
          LD      (IX+1),A
          JR      S3CHRP22
;
; STAGE3 -- CHARACTER 3
;
S3CHARA3: CALL    RND
          CP      210
          JR      NC,$-5
          ADD     A,20
          LD      (S3CHARD3+4),A
          CALL    RND
          CP      210
          JR      NC,$-5
          ADD     A,20
          LD      (S3CHARD3+5),A
          CALL    DSET
S3CHARD3: DEFW    S3CHAPD3,S3CHARP3
          DEFB    0,0,245,0,0,0
          DEFB    7,1,00000000B
          RET
          ;
S3CHARP3: LD      A,(IX+9)
          SUB     33
          LD      (IX+9),A
          LD      A,(IX+8)
          XOR     16
          LD      (IX+8),A
          LD      A,(IX+13)
          XOR     2
          LD      (IX+13),A
          RET
          ;
S3CHAPD3: DEFB    9,1
          DEFB    -16,-16,-16
          DEFB     16,-16,-16
          DEFB    -16, 16,-16
          DEFB     16, 16,-16
          DEFB    -16,-16, 16
          DEFB     16,-16, 16
          DEFB    -16, 16, 16
          DEFB     16, 16, 16
          DEFB      0,  0,  0
          DEFB    1,2,4,3,7,5,1,3,0
          DEFB    5,6,8,7,0,6,2,0,8,4,0,0
;
; STAGE 3 -- BOSS
;
S3BOSS:   LD      A,(SWHICH)
          OR      00000001B
          LD      (SWHICH),A
          LD      A,24
          CALL    MAIN
          CALL    CLSPRI
          ;
          LD      A,1
          LD      (SCOLOR+1),A
          LD      A,1
          LD      HL,HOME
          LD      (MASTER+5),HL
          LD      A,1
          CALL    MAIN
          LD      A,(MASTER+1)
          OR      A
          JR      NZ,$-9
          ;
          CALL    DSET
          DEFW    PARPD1,S3CLPTR2
          DEFB    128,255,240,0,0,0
          DEFB    11,0,00001010B
          LD      A,20
          CALL    MAIN
          LD      HL,S3CLPTR
          LD      (MASTER+5),HL
          XOR     A
          LD      (SCOLOR+1),A
          LD      A,32
          CALL    MAIN
          ;
          CALL    DSET
          DEFW    S3STAGM1,MHYOUJ
          DEFB    7,24,0,0,0,38,8
          DEFB    0,00000101B
          CALL    DSET
          DEFW    S3CLEARM,MHYOUJ
          DEFB    7,24,0,0,0,38,134
          DEFB    0,00000101B
          LD      A,28
          CALL    MAIN
          CALL    DSET
          DEFW    S3BONUSM,MHYOUJ
          DEFB    7,24,0,0,0,0,55
          DEFB    0,00000101B
          CALL    DSET
          DEFW    S3SCOREM,MHYOUJ
          DEFB    7,24,0,0,0,8,80
          DEFB    0,00010101B
          LD      HL,(SCORE)
          LD      DE,3000
          ADD     HL,DE
          JR      NC,$+5
          LD      HL,65535
          LD      (SCORE),HL
          LD      A,(STOCK)
          ADD     A,2
          CP      10
          JR      C,$+4
          LD      A,9
          LD      (STOCK),A
          LD      A,30
          CALL    MAIN
          CALL    FADE
          LD      A,24
          CALL    SDOFF
          CALL    MAIN
          RET
          ;
S3CLPTR:  LD      A,(IX+1)
          INC     (IX+1)
          CP      8
          JR      NC,$+11
          LD      A,(IX+9)
          ADD     A,6
          LD      (IX+9),A
          RET
          CP      16
          RET     NC
          LD      A,(IX+8)
          ADD     A,12
          LD      (IX+8),A
          INC     (IX+12)
          RET
          ;
S3CLPTR2: LD      A,(IX+1)
          INC     (IX+1)
          CP      16
          RET     NC
          LD      A,(IX+9)
          SUB     6
          LD      (IX+9),A
          RET
          ;
S3ATACKM: DEFB  'A',9,0,'T',32,0,'A',55,0,'C',79,0,'K',106,0,0
S3CLEARM: DEFB  'C',60,30,'L',75,30,'E',90,30,'A',105,30,'R',120,30,0
S3BONUSM: DEFB  'B',88,30,'O',108,30,'N',128,30,'U',148,30,'S',168,30,0
S3SCOREM: DEFB  '3',98,60,'0',113,60,'0',128,60,'0',142,60
          DEFB  '2',98,90,'U',113,90,'P',128,90,0
;
; STAGE 3 -- CHARACTER 5
;
S3CHARA5: CALL    DSET
          DEFW    S3CHAPD5,S3CHARP5
          DEFB    128,128,255,0,0,0
          DEFB    7,2,00000010B
          RET
          ;
S3CHAPD5: DEFB    10,4
          DEFB      0,-30,-10
          DEFB     26,-15,  0
          DEFB     26, 15,-10
          DEFB      0, 30,  0
          DEFB    -26, 15,-10
          DEFB    -26,-15,  0
          DEFB      0,  0,  0
          DEFB    -16,  0, -5
          DEFB      8,-15, -5
          DEFB      8, 15, -5
          DEFB    1,2,5,6,3,4,1,0,0
          ;
S3CHARP5: LD      A,(LIFE)
          OR      A
          JR      Z,S3RP5END
          LD      A,(IX+1)
          INC     (IX+1)
          AND     3
          LD      HL,HOME
          JR      Z,$+5
          LD      HL,KEY
          LD      (MASTER+5),HL
S3RP5END: LD      A,(IX+13)
          XOR     2
          LD      (IX+13),A
          CALL    MOVE
          DEFB    0,0,-8,3,0,0
;
; STAGE 3 -- CHARACTER 4
;
S3CHAPD4:   DEFB    5,1
          DEFB    -25,-25,  0
          DEFB     25,-25,  0
          DEFB     25, 25,  0
          DEFB    -25, 25,  0
          DEFB      0,  0,  0
          DEFB    1,2,3,4,1,0,0
          ;
S3CHARP4: LD      A,(IX+13)
          XOR     2
          LD      (IX+13),A
          CALL    MOVE
          DEFB    0,0,-32,2,0,3
          ;
S3CHRP42: LD      A,(IX+13)
          XOR     2
          LD      (IX+13),A
          CALL    MOVE
          DEFB    0,0,-32,0,-3,0
          ;
S3CHARA4: CALL    RND
          LD      (S3CHARD4+4),A
          CALL    RND
          LD      (S3CHARD4+5),A
          LD      HL,S3CHARP4
          AND     1
          JR      Z,$+5
          LD      HL,S3CHRP42
          LD      (S3CHARD4+2),HL
          CALL    DSET
S3CHARD4: DEFW    S3CHAPD4,S3CHRP42
          DEFB    0,0,255,0,0,0
          DEFB    7,1,00000000B
          RET
;
; STAGE 3 -- CHARACTER 6
;
S3CHARA6: CALL    RND
          LD      (S3CHARD6+4),A
          CALL    DSET
S3CHARD6: DEFW    S3CHPD12,S3CHARP6
          DEFB    0,235,255,0,0,0
          DEFB    7,1,00000000B
          RET
          ;
S3CHARP6: LD      A,(IX+9)
          SUB     24
          LD      (IX+9),A
          RET
;
; STAGE 3 -- CHARACTER 7
;
S3CHARA7: CALL    RND
          AND     127
          ADD     A,64
          LD      (S3CHARD7+5),A
          CALL    DSET
S3CHARD7: DEFW    S3CHAPD2,S3CHARP7
          DEFB    30,128,255,0,0,0
          DEFB    7,2,00000010B
          RET
          ;
S3CHARP7:   LD      A,(IX+11)
          ADD     A,3
          LD      (IX+11),A
          LD      A,(IX+1)
          INC     (IX+1)
          CP      5
          JR      NC,$+5
          JP      S3CHARP6
          CP      29
          JR      NC,S3CHARP6
          CALL    RTURN
          DEFB    128,128,144,0,0,2
          INC     (IX+12)
          INC     (IX+12)
          RET
;
; STAGE 3 -- CHARACTER 8
;
S3CHARA8: CALL    DSET
          DEFW    S3CHAPD8,S3CHRP81
          DEFB    128,20,40,0,0,0
          DEFB    11,2,00000000B
          CALL    DSET
          DEFW    S3CHAPD5,S3CHRP82
          DEFB    128,20,40,0,8,0
          DEFB    11,2,00000000B
          RET
          ;
S3CHARP8: LD      A,(IX+1)
          INC     (IX+1)
          CP      46
          JR      NC,$+11
          LD      A,(IX+8)
          ADD     A,4
          LD      (IX+8),A
          RET
          CALL    RTURN
          DEFB    128,128,128,2,0,0
          LD      A,(IX+9)
          ADD     A,8
          LD      (IX+9),A
          RET
          ;
S3CHRP81: CALL    S3CHARP8
          LD      A,(IX+1)
          CP      46
          RET     C
          JP      S3BACURA
          ;
S3CHRP82: CALL    S3CHARP8
          LD      A,(IX+10)
          ADD     A,3
          LD      (IX+10),A
          RET
          ;
S3CHAPD8: DEFB    7,0
          DEFB    -15,  5,-10
          DEFB    -15, 35,-10
          DEFB     15,  5,-10
          DEFB     15, 35,-10
          DEFB      0, 20, 40
          DEFB      0, -5,  0
          DEFB      0, 10,  0
          DEFB    1,2,4,3,1,5,2,0
          DEFB    3,5,4,0,6,7,0,0
;
; STAGE 3 -- BACURA
;
S3BACURA: LD      A,(IX+7)
          LD      (S3BACURD+4),A
          LD      A,(IX+8)
          LD      (S3BACURD+5),A
          LD      A,(IX+9)
          LD      (S3BACURD+6),A
          CALL    DSET
S3BACURD: DEFW    S3CHAPD4,S3BACURP
          DEFB    0,0,0,0,0,0
          DEFB    10,1,00000100B
          RET
          ;
S3BACURP: LD      A,(IX+10)
          SUB     3
          LD      (IX+10),A
          LD      A,(IX+9)
          SUB     24
          JP      C,MALEND
          LD      (IX+9),A
          RET

;-----------------------------------------------------------
;
; STAGE 4
;
;-----------------------------------------------------------
;
;---- STAGE4 PROGRAM ----
;
STAGE4:   CALL    CLSPRI
          LD	  (STACK),SP
          LD      A,00001000B
          LD      (SWHICH),A
          CALL    DSET
          DEFW    S4STAGM1,MHYOUJ
          DEFB    8,40,0,0,0,44
          DEFB    0,0,00010101B
          CALL    DSET
          DEFW    S4STAGM2,MHYOUJ
          DEFB    8,40,0,0,0,10
          DEFB    60,0,00000101B
          CALL    UNFADE
          LD      A,32
          CALL    MAIN
          CALL    FADE
          LD      A,8
          CALL    MAIN
          CALL    MSSTR
          ;
S4CONT:   CALL    MOVESD
          LD      HL,S4STAGD1
          LD      DE,SCROLL
          LD      BC,9
          LDIR
          LD      HL,S4JPDAT1
          LD      DE,JPTUCH
          LD      BC,32
          LDIR
          LD      A,13
          LD      (MASTER+13),A
          LD      A,24
          CALL    MAIN
           ;
          LD      B,32
S4LOOP0:  CALL    S4CHARA1
          CALL    CURE
          LD      A,3
          CALL    MAIN
          DJNZ    S4LOOP0
          CALL    S4CHARA6
          ;
          LD      B,128
S4LOOP:   LD      HL,S4RETLOP
          PUSH    HL
          CALL    CURE
          CALL    TURBO
          LD      A,B
          CP      92
          JR      C,S4SJ1
          CALL    S4CHARA1
          CALL    RND
          CP      50
          JP      C,S4CHARA3
          CP      90
          JP      C,S4CHAR51
          CP      150
          JP      C,TECHNO
          CP      200
          JP      C,PARTY
          RET
          ;
S4SJ1:    CP      70
          JR      C,S4SJ2
          CALL    S4CHARA1
          JP      S4CHARA4
          ;
S4SJ2:    CP      48
          JR      C,S4SJ3
          CALL    S4CHARA1
          JP      S4CHAR51
          ;
S4SJ3:    AND     15
          JP      Z,S4CHARA6
          CALL    S4CHARA1
          JP      C,PARTY
          CALL    RND
          CP      40
          JP      C,S4CHARA3
          CP      80
          JP      C,S4CHARA4
          CP      120
          JP      C,S4CHAR51
          CP      140
          JP      C,S4CHARA7
          CP      185
          JP      C,TECHNO
          CP      225
          JP      C,PARTY
          RET
          ;
S4RETLOP: LD      A,6
          CALL    MAIN
          DJNZ    S4LOOP
          ;
          LD      A,(SWHICH)
          AND     11111110B
          LD      (SWHICH),A
          LD      HL,S4CONT2
          LD      (CONTRT),HL
          ;
S4CONT2:  CALL    MOVESD
          LD      A,13
          LD      (MASTER+13),A
          LD      A,32
          CALL    MAIN
          CALL    S4CHARA5
          LD      A,24
          CALL    MAIN
          LD      B,128
S4LOOP2:  CALL    TURBO
          CALL    CURE
          CALL    CURE
          LD      HL,S4RETLP2
          PUSH    HL
          LD      A,B
          AND     31
          CALL    Z,S4CHARA6
          LD      A,B
          AND     28
          RET     Z
          CALL    RND
          AND     1
          CALL    Z,S4CHARA1
          CALL    RND
          CP      35
          JP      C,S4CHARA3
          CP      80
          JP      C,S4CHARA4
          CP      125
          JP      C,S4CHAR51
          CP      145
          JP      C,S4CHARA7
          CP      185
          JP      C,S4CHRA72
          CP      230
          JP      C,TECHNO
          JP      PARTY
          ;
S4RETLP2: LD      A,B
          RLCA
          RLCA
          AND     3
          ADD     A,3
          CALL    MAIN
          DJNZ    S4LOOP2
          LD      A,32
          CALL    MAIN
          JP      S4BOSS
;
; STAGE4 DATA
;
S4STAGD1: DEFB    32,5,6,2
          DEFB    01011011B
          DEFW    S4CONT,DEAD
          ;
S4JPDAT1: DEFW    TUCH0,TUCH1
          DEFW    TUCH2,TUCH3
          DEFW    TUCH4,TUCH5
          DEFW    TUCH6,TUCH6
          DEFW    TUCH47,TUCH48
          DEFW    TUCH0,TUCH0
          DEFW    TUCH0,TUCH0
          DEFW    TUCH0,TUCH0
          ;
S4STAGM1: DEFB    'Z',60,80
          DEFB    'O',75,80
          DEFB    'N',90,80
          DEFB    'E',105,80
          DEFB    '4',120,80,0
S4STAGM2: DEFB    'V',69,80
          DEFB    'O',86,80
          DEFB    'L',103,80
          DEFB    'C',120,80
          DEFB    'A',137,80
          DEFB    'N',154,80
          DEFB    'O',171,80,0
;
; STAGE 4 -- CHARACTER 1
;
S4CHARA1: CALL    RND
          AND     127
          ADD     A,90
          LD      (S4CHARD1+4),A
          CALL    RND
          AND     00000010B
          LD      (S4CHARD1+12),A
          CALL    DSET
S4CHARD1: DEFW    S4CHAPD1,S4CHARP1
          DEFB    0,235,180,0,0,0
          DEFB    8,2,00000000B
          RET
          ;
S4CHAPD1: DEFB    14,5
          DEFB      0,-60, -6
          DEFB      0,-25,-12
          DEFB      0,  0,-25
          DEFB     -6,-60,  5
          DEFB    -12,-25, 10
          DEFB    -25,  0, 20
          DEFB      6,-60,  5
          DEFB     12,-25, 10
          DEFB     25,  0, 20
          DEFB      0,-42, -9
          DEFB     -9,-42,  8
          DEFB      9,-42,  8
          DEFB    -12,-12,  8
          DEFB     12,-12,  8
          DEFB    1,2,3,0,4,5,6,0
          DEFB    7,8,9,0,1,4,7,1,0,0
          ;
S4CHARP1: LD      A,(IX+9)
          SUB     16
          LD      (IX+9),A
          LD      A,(IX+15)
          AND     00000010B
          RET     Z
          CALL    RND
          AND     15
          CALL    Z,S4CHARA2
          RET
;
; STAGE 4 -- CHARACTER 2
;
S4CHARA2: LD      A,(IX+7)
          LD      (S4CHARD2+4),A
          LD      (S4CHAR22+4),A
          LD      (S4CHAR23+4),A
          LD      A,(IX+9)
          LD      (S4CHARD2+6),A
          LD      (S4CHAR22+6),A
          LD      (S4CHAR23+6),A
          CALL    DSET
S4CHARD2: DEFW    S4CHAPD2,S4CHRP21
          DEFB    0,112,0,0,0,0
          DEFB    8,1,00000000B
          CALL    DSET
S4CHAR22: DEFW    S4CHAPD2,S4CHRP22
          DEFB    0,112,0,0,0,0
          DEFB    8,1,00000000B
          CALL    DSET
S4CHAR23: DEFW    S4CHAPD2,S4CHRP23
          DEFB    0,112,0,0,0,0
          DEFB    8,1,00000000B
          RET
          ;
S4CHAPD2: DEFB    4,0
          DEFB    -12,  8, -8
          DEFB     12,  8, -8
          DEFB      0,  8, 12
          DEFB      0,-13,  0
          DEFB    1,2,3,1,4,2,0
          DEFB    4,3,0,0
          ;
S4CHRP21: CALL    S4CHARP2
          CALL    MOVE
          DEFB    4,0,2,0,0,0
          ;
S4CHRP22: CALL    S4CHARP2
          CALL    MOVE
          DEFB    -4,0,2,0,0,0
          ;
S4CHRP23: CALL    S4CHARP2
          CALL    MOVE
          DEFB    0,0,-6,0,0,0
          ;
S4CHARP2: LD      A,(IX+1)
          INC     (IX+1)
          OR      A
          RET     Z
          CP      8
          JR      NC,S4CJ2
          LD      B,A
          LD      A,-64
          SRA     A
          DJNZ    $-2
          ADD     A,(IX+8)
          JP      NC,MALEND
          LD      (IX+8),A
          RET
S4CJ2:    SUB     7
          LD      B,A
          LD      A,2
          RLCA
          DJNZ    $-1
          ADD     A,(IX+8)
          JP      C,MALEND
          LD      (IX+8),A
          RET
;
; STAGE 4 -- CHARACTER 3
;
S4CHARA3: CALL    RND
          LD      (S4CHARD3+4),A
          CALL    RND
          AND     127
          ADD     A,127
          LD      (S4CHARD3+6),A
          CALL    DSET
S4CHARD3: DEFW    S4CHAPD3,S4CHARP3
          DEFB    0,127,0,0,0,0
          DEFB    8,2,00000010B
          RET
          ;
S4CHARP3: LD      A,(IX+7)
          XOR     15
          LD      (IX+7),A
          LD      A,(IX+13)
          XOR     1
          LD      (IX+13),A
          LD      A,(IX+9)
          SUB     12
          JP      C,MALEND
          LD      (IX+9),A
          LD      A,(IX+1)
          INC     (IX+1)
          AND     8
          RET     NZ
          LD      A,(IX+15)
          XOR     1
          LD      (IX+15),A
          RET
          ;
S4CHAPD3: DEFB    9,0
          DEFB     -5,-60,  0
          DEFB      5,-45,  0
          DEFB     -5,-30,  0
          DEFB      5,-15,  0
          DEFB     -5,  0,  0
          DEFB      5, 15,  0
          DEFB     -5, 30,  0
          DEFB      5, 45,  0
          DEFB     -5, 60,  0
          DEFB    1,2,3,4,5,6,7,8,9,0,0
;
; STAGE 4 -- BOSS
;
S4BOSS:   CALL    DSET
          DEFW    S4ATACKM,MHYOUJ
          DEFB    9,16,1,1,0
          DEFB    72,80,0,00100101B
          LD      A,17
          CALL    MAIN
          CALL    CLSPRI
          CALL    DSET
          DEFW    S4COREPT,S4CORERP
          DEFB    128,128,64,0,0,0
          DEFB    9,9,00000000B
          CALL    S4MAHOU
          CALL    DSET
          DEFW    S4BOSPD2,S4BOSSRP
          DEFB    128,128,64,0,0,0
          DEFB    8,8,00000000B
          CALL    DSET
          DEFW    S4BOSPD2,S4BOSSRP
          DEFB    128,128,64,0,11,0
          DEFB    8,8,00000000B
          CALL    DSET
          DEFW    S4BOSPD2,S4BOSSRP
          DEFB    128,128,64,0,22,0
          DEFB    8,8,00000000B
S4BOSLOP: CALL    RND
          AND     15
          CALL    Z,S4CHARA4
          LD      A,1
          CALL    MAIN
          LD      A,(PORIDAT+1)
          OR      A
          JR      Z,S4BOSLOP
          ;
          LD      HL,HOME
          LD      (MASTER+5),HL
S4LOOP8:  LD      A,1
          CALL    MAIN
          LD      A,(MASTER+1)
          OR      A
          JR      NZ,S4LOOP8
          ;
          LD      HL,S4CORRP2
          LD      (PORIDAT+5),HL
          LD      A,80
          CALL    MAIN
          ;
S4BOSM:   CALL    DSET
          DEFW    S4STAGM1,MHYOUJ
          DEFB    8,24,0,0,0,38,8
          DEFB    0,00000101B
          CALL    DSET
          DEFW    S4CLEARM,MHYOUJ
          DEFB    8,24,0,0,0,38,134
          DEFB    0,00000101B
          LD      A,28
          CALL    MAIN
          CALL    DSET
          DEFW    S4MISSIM,S4MJIPTR
          DEFB    10,46,0,0,0,70,55
          DEFB    0,00000101B
          CALL    DSET
          DEFW    S4ENDM,S4MJIPTR
          DEFB    10,46,0,0,0,14,80
          DEFB    0,00000101B
          LD      A,38
          CALL    MAIN
          CALL    FADE
          LD      A,24
          CALL    SDOFF
          CALL    MAIN
          RET
          ;
TUCH47:	  CALL    TUCH2
          LD      A,(MASTER+9)
          XOR     127
          ADD     A,17
          LD      (MASTER+9),A
          RET
          ;
TUCH48:   CALL    PISTOL
	      LD      A,32
          LD      (MASTER+8),A
          LD      A,(IX+13)
          CP      9
          JR      NZ,$+8
          LD      A,8
          LD      (IX+13),A
          RET
          CP      8
          JR      NZ,$+8
          LD      A,6
          LD      (IX+13),A
          RET
          XOR     A
          LD      (IX+2),A
          INC     A
          LD      (IX+1),A
          LD      A,00001000B
          LD      (IX+15),A 
          RET
          ;
S4COREPT: DEFB    6,0
          DEFB      0,-24,  0
          DEFB      0, 24,  0
          DEFB      0,  0,-13
          DEFB    -13,  0,  0
          DEFB      0,  0, 13
          DEFB     13,  0,  0
          DEFB    1,4,2,6,1,0,5,4,3,6,5,0
          DEFB    1,3,2,5,1,0,0
          ;
S4ATACKM: DEFB    'A',9,0,'T',32,0,'A',55,0,'C',79,0,'K',106,0,0
S4CLEARM: DEFB    'C',60,30,'L',75,30,'E',90,30,'A',105,30,'R',120,30,0
S4MISSIM: DEFB    'M',20,30,'I',31,30,'S',42,30,'S',57,30,'I',68,30
          DEFB    'O',79,30,'N',94,30,0
S4ENDM:   DEFB    'E',98,90,'N',113,90,'D',128,90,0
;
; STAGE 4 -- CHARACTER 4
;
S4CHARA4: CALL    RND
          AND     127
          ADD     A,64
          LD      (S4CHARD4+4),A
          CALL    RND
          AND     127
          ADD     A,64
          LD      (S4CHARD4+5),A
          CALL    RND
          AND     63
          ADD     A,32
          LD      (S4CHARD4+6),A
          CALL    RND
          AND     7
          ADD     A,A
          LD      HL,S4RNDPT4
          ADD     A,L
          JR      NC,$+3
          INC     H
          LD      L,A
          LD      E,(HL)
          INC     HL
          LD      D,(HL)
          EX      DE,HL
          LD      (S4CHARD4+2),HL
          CALL    DSET
S4CHARD4: DEFW    S4CHAPD4,S4CHARP4
          DEFB    0,0,0,0,0,0
          DEFB    8,1,00011000B
          RET
          ;
S4CHAPD4: DEFB    6,0
          DEFB      0,-18,  0
          DEFB      0, 18,  0
          DEFB      0,  0,-18
          DEFB    -18,  0,  0
          DEFB      0,  0, 18
          DEFB     18,  0,  0
          DEFB    1,4,2,6,1,0,5,4,3,6,5,0
          DEFB    1,3,2,5,1,0,0
          ;
S4RNDPT4: DEFW    S4CHRP41,S4CHRP42,S4CHRP43,S4CHRP44
          DEFW    S4CHRP45,S4CHRP46,S4CHRP47,S4CHRP48
          ;
S4CHARP4: LD      A,(IX+13)
          XOR     1
          LD      (IX+13),A
          LD      A,(IX+1)
          INC     (IX+1)
          CP      2
          RET     NC
          POP     HL
          CP      1
          RET     C
          XOR     A
          LD      (IX+15),A
          RET
          ;
S4CHRP41: CALL    S4CHARP4
          CALL    MOVE
          DEFB    18,2,-8,0,0,0
          ;
S4CHRP42: CALL    S4CHARP4
          CALL    MOVE
          DEFB    -10,3,-15,0,0,0
          ;
S4CHRP43: CALL    S4CHARP4
          CALL    MOVE
          DEFB    11,-12,-8,0,0,0
          ;
S4CHRP44: CALL    S4CHARP4
          CALL    MOVE
          DEFB    12,21,-8,0,0,0
          ;
S4CHRP45: CALL    S4CHARP4
          CALL    MOVE
          DEFB    -8,13,-12,0,0,0
          ;
S4CHRP46: CALL    S4CHARP4
          CALL    MOVE
          DEFB    -18,-12,1,0,0,0
          ;
S4CHRP47: CALL    S4CHARP4
          CALL    MOVE
          DEFB    6,-18,-7,0,0,0
          ;
S4CHRP48: CALL    S4CHARP4
          CALL    MOVE
          DEFB    -10,-18,-16,0,0,0
;
; STAGE 4 -- CHARACTER 5
;
S4CHAPD5: DEFB    12,4
          DEFB    -10,-48,-10
          DEFB    -10, 48,-10
          DEFB     10,-48,-10
          DEFB     10, 48,-10
          DEFB    -10,-48, 10
          DEFB    -10, 48, 10
          DEFB     10,-48, 10
          DEFB     10, 48, 10
          DEFB    -10,  0,-10
          DEFB    -10,  0, 10
          DEFB     10,  0,-10
          DEFB     10,  0, 10
          DEFB    1,2,4,3,1,5,7,8,6,5,0
          DEFB    6,2,0,8,4,0,7,3,0,0
          ;
S4CHARP5: LD      A,(IX+9)
          SUB     16
          LD      (IX+9),A
          LD      A,(IX+13)
          XOR     1
          LD      (IX+13),A
          LD      A,(IX+1)
          OR      A
          JR      NZ,S4UP
          LD      A,(IX+8)
          ADD     A,32
          CP      200
          JR      NC,$+6
          LD      (IX+8),A
          RET
          LD      A,1
          LD      (IX+1),A
          RET
S4UP:     LD      A,(IX+8)
          SUB     32
          CP      50
          JR      C,$+6
          LD      (IX+8),A
          RET
          XOR     A
          LD      (IX+1),A
          RET
          ;
S4CHAR52: LD      (S4CHARD5+4),A
          CALL    RND
          AND     127
          ADD     A,64
          AND     11111000B
          LD      (S4CHARD5+5),A
          CALL    DSET
S4CHARD5: DEFW    S4CHAPD5,S4CHARP5
          DEFB    128,128,240,0,0,0
          DEFB    9,2,00000000B
          RET
          ;
S4CHARA5: PUSH    BC
          LD      B,8
          LD      C,32
          LD      A,16
S4DJ5:    ADD     A,C
          PUSH    AF
          CALL    S4CHAR52
          POP     AF
          DJNZ    S4DJ5
          POP     BC
          RET
          ;
S4CHAR51: CALL    RND
          CALL    S4CHAR52
          RET
;
; STAGE 4 -- CHARACTER 6
;
S4CHAPD6: DEFB    10,4
          DEFB     15,-15,-15
          DEFB     15,-15, 15
          DEFB     15,120,  0
          DEFB    -15,-15,-15
          DEFB    -15,-15, 15
          DEFB    -15,120,  0
          DEFB    -15, 40,-10
          DEFB    -15, 80, -5
          DEFB     15, 40,-10
          DEFB     15, 80, -5
          DEFB    1,2,3,1,4,5,6,4,0
          DEFB    2,5,0,3,6,0,0
          ;
S4CHARP6:  LD      A,(IX+1)
          INC     (IX+1)
          CP      3
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,5,-10,0,-1,0
          CP      6
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,-5,-10,0,1,0
          CP      9
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,5,-10,0,1,0
          CP      12
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,-5,-10,0,-1,0
          XOR     A
          LD      (IX+1),A
          JR      S4CHARP6
          ;
S4CHARA6: CALL    RND
          AND     127
          ADD     A,64
          LD      (S4CHARD6+4),A
          ADD     A,30
          LD      (S4CHRD62+4),A
          CALL    DSET
S4CHARD6: DEFW    S4CHAPD6,S4CHARP6
          DEFB    50,130,225,0,0,0
          DEFB    8,2,00000000B
          CALL    DSET
S4CHRD62: DEFW    S4CHAPD6,S4CHARP6
          DEFB    80,130,225,0,0,16
          DEFB    8,2,00000000B
          RET
;
; STAGE 4 -- CHARACTER 7
;
S4CHARA7: CALL    RND
          AND     7
          LD      (S4CHARD7+8),A
          CALL    DSET
S4CHARD7: DEFW    S4CHAPD5,S4CHARP7
          DEFB    55,128,240,0,0,0
          DEFB    8,2,00000000B
          RET
          ;
S4CHARP7: CALL    RTURN
          DEFB    128,128,128,3,0,0
          CALL    MOVE
          DEFB    0,0,-12,-3,0,0
          ;
S4CHRA72:  CALL    RND
          AND     127
          ADD     A,64
          LD      (S4CHRD72+4),A
          CALL    RND
          AND     127
          ADD     A,64
          LD      (S4CHRD72+5),A
          CALL    RND
          AND     2
          LD      A,8
          JR      Z,$+3
          XOR     A
          LD      (S4CHRD72+7),A
          CALL    DSET
S4CHRD72: DEFW    S4CHAPD5,S4CHRP72
          DEFB    0,0,255,0,0,0
          DEFB    8,2,00000000B
          RET
          ;
S4CHRP72:   LD      A,(IX+9)
          SUB     42
          LD      (IX+9),A
          LD      A,(IX+13)
          XOR     1
          LD      (IX+13),A
          RET
;
; STAGE4 -- BOSS
;
S4BOSSRP: LD      A,(IX+13)
          XOR     1
          LD      (IX+13),A
          LD      A,(PORIDAT+1)
          OR      A
          JR      Z,$+12
          XOR     A
          LD      (IX+0),A
          LD      A,00011000B
          LD      (IX+15),A
          RET
S4BOSRJ:  LD      A,(IX+1)
          INC     (IX+1)
          CP      8
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,0H,3,0,0
          CP      40
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,0,0,3,0
          CP      72
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,0,0,0,3
          CP      88
          JR      NC,$+11
          CALL    MOVE
          DEFB    0,0,0,2,2,2
          XOR     A
          LD      (IX+1),A
          JR      S4BOSRJ
          ;
S4BOSPD2: DEFB    8,0
          DEFB    -40,0F6H,40
          DEFB    -40,0F6H,60
          DEFB    -40,0AH,40
          DEFB    -40,0AH,60
          DEFB    40,0F6H,40
          DEFB    40,0F6H,60
          DEFB    40,0AH,40
          DEFB    40,0AH,60
          DEFB    1,2,4,3,7,5,1,3,0
          DEFB    5,6,8,7,0,2,6,0,4,8,0,0
          ;
S4CORERP: INC     (IX+12)
          RET
          ;
S4CORRP2: INC     (IX+12)
          INC     (IX+8)
          LD      A,(IX+13)
          XOR     15
          LD      (IX+13),A
          LD      A,(IX+1)
          INC     (IX+1)
          CP      40
          JR      NC,S4COJ1
          AND     3
          LD      A,00011000B
          JR      Z,$+4
          LD      A,00001000B
          LD      (IX+15),A
          RET
S4COJ1:   XOR     A
          LD      (IX+0),A
          LD      A,00011000B
          LD      (IX+15),A
          RET
;
; MAHOUJIN
;
S4MAHOU:  CALL    DSET
          DEFW    S4MAHOPD,S4DEMO21
          DEFB    128,255,128,0,0,0
          DEFB    5,0,00101000B
          RET
          ;
S4MAHOPD: DEFB    7,0
          DEFB      0,  0,  0
          DEFB   -104,  0,-60
          DEFB   -104,  0, 60
          DEFB      0,  0,120
          DEFB    104,  0, 60
          DEFB    104,  0,-60
          DEFB      0,  0,-120
          DEFB    2,3,4,5,6,7,2,0
          DEFB    2,4,6,2,0,3,5,7,3,0,0
          ;
S4DEMO21: LD      A,(PORIDAT+1)
          OR      A
          RET     Z
          LD      HL,S4DEMO22
          LD      (IX+5),L
          LD      (IX+6),H
          RET
          ;
S4DEMO22: LD      A,(PORIDAT+0)
          OR      A
          JR      Z,S4DEMJ
          INC     (IX+12)
          LD      A,(IX+13)
          XOR     15
          LD      (IX+13),A
          RET
S4DEMJ:   LD      A,(IX+1)
          INC     (IX+1)
          CP      8
          JR      NC,$+8
          LD      A,7
          LD      (IX+13),A
          RET
          CP      16
          JR      NC,$+8
          LD      A,5
          LD      (IX+13),A
          RET
          CP      24
          JP      NC,MALEND
          LD      A,4
          LD      (IX+13),A
          RET
          ;
S4MJIPTR: LD      A,(IX+7)
          XOR     15
          LD      (IX+7),A
          JP      MHYOUJ
          ;
ROCKEND:  EQU	  $
