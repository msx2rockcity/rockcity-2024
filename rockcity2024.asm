;**********************************************************
;
;  ROCK CITY
;
;  MSXPen LAST VERSION VER 3.2.0
;
;  PROGRAM by msx2rockcity
;
;  (C) Copyright 1993-2026 msx2rockcity
;
;**********************************************************
;-------------------------------------------
;
;  MAIN1
;
;-------------------------------------------
GTSTCK:  EQU     00D5H   ; [BIOS] ジョイスティック(または矢印キー)の状態を取得
                         ; AレジスタにIDを入れ呼び出すと、方向(0-8)が返ります。
GTTRIG:  EQU     00D8H   ; [BIOS] トリガーボタン(スペースキー/ジョイボタン)の状態を取得
                         ; ボタンが押されているかどうかを確認するためのルーチンです。
NNEG:    EQU     44EDH   ; [MATH-ROM] 浮動小数点数(または数値)の符号を反転させる
                         ; おそらく演算ライブラリ内のサブルーチンを直接叩いています。
BREAKX:  EQU     00B7H   ; [BIOS] CTRL+STOPキーの押下チェック
                         ; 実行中にユーザーが中断を試みたかどうかを判定します。
CALSLT:  EQU     001CH   ; [BIOS] 別のスロットにあるルーチンを呼び出す（インタースロット・コール）
                         ; 拡張カートリッジや裏側のROMにあるプログラムを呼ぶ際に必須のゲートです。
WRTPSG:  EQU     0093H   ; [BIOS] PSG(音源チップ AY-3-8910)のレジスタにデータを書き込む
                         ; 音の高さ、音量、ノイズ、エンベロープなどを制御する司令塔です。
EXPTBL:  EQU     0FCC1H  ; [WORK AREA] 基本スロットの拡張フラグが格納されているワークエリア
                         ; MSXのメモリマップは複雑なので、CALSLTを使う際にここを参照して
                         ; 「どのスロットが拡張されているか」を確認するために使われます。
CLIKSW:   EQU     0F3DBH ; クリック音を消すかどうか
MJVER:    EQU     '3'    ; メジャーバージョン
MIVER:    EQU     '2'    ; マイナーバージョン
PTVER:    EQU     '0'    ; パッチバージョン
DSTOCK    EQU     7      ; デフォルト自機数（最大9機）
          ORG     08200H ; 開始アドレス（限界まで削った）
;
;---- SCREEN & COLOR SET ----
;
START:    LD      A,(EXPTBL)    ; メインスロットの拡張テーブルを取得
          LD      HL,0006H      ; BIOSの「VDP読み取りポート」のアドレスを指定
          CALL    000CH         ; RDSLT（他スロットのメモリ読み出し）をコール
          LD      (RDVDP),A     ; 取得したVDP読み取りポート番号をメモリに保存
          LD      A,(EXPTBL)    ; 再度、拡張テーブルを取得
          LD      HL,0007H      ; BIOSの「VDP書き込みポート」のアドレスを指定
          CALL    000CH         ; RDSLTを実行
          LD      (RDVDP+1),A   ; 取得したVDP書き込みポート番号（#99等）を保存
          LD      A,7           ; パレット番号7を指定
          LD      (PLDAT),A     ; パレットデータのインデックスにセット
          CALL    PALETE        ; 自作のパレット変更サブルーチンを呼ぶ
          ;
          LD      A,15          ; 文字色（白に近い色）を15番に
          LD      HL,0          ; 背景色と周辺色を0番（黒）に
          LD      (0F3E9H),A    ; FORCLR（文字色）ワークエリアに書き込み
          LD      (0F3EAH),HL   ; BAKCLR（背景）とBDRCLR（周辺）を一括書き込み
          ;
          LD      A,(0FFE7H)    ; MSX2+以降の横方向スクロール等のフラグを取得
          OR      00000010B     ; 第4ビット（VDP 60Hz/50Hz設定など）を操作
          LD      (0FFE7H),A    ; ワークエリアを更新
          ;
          XOR     A
          LD      (CLIKSW),A    ; クリック音を消す
          ;
          LD      A,5           ; SCREEN 5（256x212ドット、16色）を指定
          LD      IX,005FH      ; BIOSのCHGMOD（画面モード変更）のアドレス
          LD      IY,(EXPTBL-1) ; BIOSが載っているスロット情報を取得
          CALL    CALSLT        ; インタースロットコールで画面をSCREEN 5に切り替え
          ;   
          LD      A, 15         ; ページ3へ全256文字を 16x16 で展開
          LD      (WK_FG), A
          CALL    FT_EXPAND_256
          ;
          DI                    ; 割り込み禁止（デリケートなVDP操作開始）
          LD      BC,(RDVDP+1)  ; VDPのコントロールポート（#99）をBCに
          INC     C             ; ポートを微調整
          LD      A,22          ; VDPレジスタ #22
          OUT     (C),A         ; 書き込み先を指定
          LD      A,23+80H      ; レジスタ #23（垂直オフセット）に80H（リセット等）を書き込み
          OUT     (C),A         ; VDPに直接命令を送る
          EI                    ; 割り込み許可
          ;
          LD      (SSTACK),SP   ; 現在のスタックポインタを保存（後で戻れるように）
          JP      LICENSE_DEMO      ; ライセンスデモ（メイン処理）へ
;
;---- MAIN ROUTINE ----
;
; SWITCHフラグの機能
;
; bit0  地平線表示のON/OFF                1なら表示
; bit1  自機の表示のON/OFF                1なら表示
; bit2  自機がスピードアップ状態かどうか  1なら2重表示
; bit3  敵オブジェクトを表示するかどうか  1なら表示
; bit4  ゲームオーバー判定フラグ          1ならライフ0のとき自機の爆破処理を行う
; bit5  無敵状態かのフラグ                1なら無敵状態
; bit6  ライフゲージを表示するかどうか    1なら表示
; bit7  全破壊フラグ（破壊してクリア）    1なら破壊を実行して0に
;
;----------------------
MAIN:     PUSH    IX            ; メインに入る前のレジスタを全て保存
          PUSH    HL            ; 
          PUSH    DE            ; 
          PUSH    BC            ; 
          ;
MAINS:    PUSH    AF            ; ループカウンタ(AF)を保存
          LD      IX,BREAKX     ; 中断チェック用のルーチンアドレスを設定
          LD      IY,(EXPTBL-1) ; BIOSの拡張スロットテーブルを参照
          CALL    CALSLT        ; キー入力や割り込みによる中断を確認
          JP      C,RETURN      ; キャリーが立てば（中断なら）終了処理へ
          ;
          CALL    CLS           ; 非表示側の画面をクリア（消去）
          LD      A,(SWITCH)    ; システムスイッチの状態をロード
          BIT     0,A           ; bit0: 地平線表示処理が必要か
          CALL    NZ,SCALE      ; 必要なら地平線表示を実行
          ;
          BIT     1,A           ; bit1: マスターオブジェクトの描画フラグ
          JR      Z,M1MA0       ; 0ならスキップ
          LD      IX,MASTER     ; 自機などのマスターオブジェクトをセット
          CALL    MULTI         ; AI実行 ＆ 3D描画！
          BIT     2,A           ; bit2: スピードアップ状態かのフラグ
          CALL    NZ,MULTI      ; 必要なら自機を2重に描画
          ;
          BIT     5,A           ; bit5: 無敵状態かどうか
          CALL    NZ,GOD_MAIN   ; 無敵処理
          ;
          LD      A,(SWITCH)
          BIT     7,A           ; 全破壊処理を行うかどうか
          CALL    NZ,ALLBREAK   ; 全破壊処理コール
          RES     7,A           ; フラグリセット
          LD      (SWITCH),A    ;
          ;
          ;
M1MA0:    BIT     3,A           ; bit3: オブジェクトワークエリアのキャラを描画するか
          JR      Z,M1MA2       ; 0ならスキップ
          LD      HL,PORIDAT    ; オブジェクト群のデータ先頭アドレス
          LD      DE,16         ; 1オブジェクトあたりのワークサイズ（16バイト）
          LD      B,E           ; ループ回数を16（最大数）に設定
          PUSH    AF            ; フラグ退避
M1MA1:    LD      A,(HL)        ; オブジェクトが有効(非0)かチェック
          OR      A             ; 
          JR      Z,$+8         ; 無効なら次のスロットへ
          PUSH    HL            ; 
          POP     IX            ; IXにワークのアドレスをセット
          CALL    MULTI         ; AI実行 ＆ 3D描画！
          ADD     HL,DE         ; 次のオブジェクトワークへ進む
          DJNZ    M1MA1         ; 全スロット分繰り返す
          POP     AF            ; フラグ復帰
          ;
M1MA2:    BIT     6,A           ; bit6: ライフゲージなどのUI表示フラグ
          CALL    NZ,WRLIFE     ; 必要ならライフを描画
          
          ;--- アスキーフォント点数表示 ---
          BIT     6,A
          JR      Z,ASCIDISP
          
          PUSH    AF
          PUSH    BC
          PUSH    DE
          PUSH    IX
          
          CALL    STRIGB
          JR      Z,SKIP_ASC
          
          LD      DE,ST_SCORE+9 ; スコア表示
          LD      A,(SCORE)
          LD      L,A
          LD      A,(SCORE+1)
          LD      H,A
          CALL    BIN2DEC_16
          LD      HL,ST_SCORE
          CALL    PRINT_STR_FAST
          
          LD      DE,ST_LIFE+8 ; ライフ表示
          LD      A,(STOCK)
          LD      L,A
          LD      H,0
          CALL    BIN2DEC_16
          LD      HL,ST_LIFE
          CALL    PRINT_STR_FAST
          
SKIP_ASC: POP     IX
          POP     DE
          POP     BC
          POP     AF
        
          ;--- アスキーフォント1行表示ルーチン ---
ASCIDISP: PUSH    AF           
          PUSH    HL
          LD      A,(ASCOUNT)   ; フォントがあれば最後に表示
          OR      A
          JR      Z,M1MA4
          LD      HL,(ASCFONT)
          PUSH    BC
          PUSH    DE
          PUSH    IX
          CALL    PRINT_STR          
          POP     IX
          POP     DE
          POP     BC
          LD      A,(ASCOUNT)
          DEC     A
          LD      (ASCOUNT),A
M1MA4:    POP     HL
          POP     AF
          
          ;--- FPS などデバッグ表示 ---
          PUSH    AF
          PUSH    BC
          PUSH    DE
          PUSH    IX
          CALL    COUNT_FRAME     ; フレームを1つカウント          
          CALL    CALC_FPS        ; 1秒経っていたらFPSを確定させる
          LD      A,(CUR_FPS)
          LD      L,A
          XOR     A
          LD      H,A
          LD      DE,ST_FPS+7
          CALL    BIN2DEC_16
          LD      HL,ST_FPS
          CALL    PRINT_STR_FAST
          POP     IX
          POP     DE
          POP     BC
          POP     AF
          
          ; --- VRAM表示ページの切り替え（ダブルバッファリング） ---
          PUSH    AF            ; 
          LD      A,(VIJUAL)    ; 現在の表示ページ（0 or 1）を取得
          XOR     1             ; ページを反転
          LD      (VIJUAL),A    ; 新しい表示ページを保存
          RRCA
          RRCA
          RRCA                  ; ページ番号をVDPレジスタR#2のビット位置へ移動
          OR      00011111B     ; 他のビットと合成（パターン名テーブルアドレス）
          LD      BC,(RDVDP+1)  ; VDPポートアドレスを取得
          INC     C             ; コントロールポートへ
          DI                    ; レジスタ書き換え中の割り込みを禁止
          OUT     (C),A         ; VDP R#2（表示ページ設定）を書き換え
          LD      A,80H+2       ; レジスタ指定(R#2)
          OUT     (C),A         ; 
          EI                    ; 割り込み許可
          POP     AF            ; 
          ;
          BIT     4,A           ; bit4: ゲームオーバー判定フラグ
          JR      Z,M1MA3       ; 
          LD      A,(LIFE)      ; プレイヤーの残りライフを確認
          OR      A             ; 
          JR      NZ,M1MA3      ; ライフがあれば続行
          LD      HL,(DEADRT)   ; 死亡時のジャンプ先アドレスをロード
          JP      (HL)          ; 死亡処理ルーチンへ（南無！）
          ;
M1MA3:    POP     AF            ; メインループの回数を確認
          DEC     A             ; 
          JP      NZ,MAINS      ; まだ回数があるならMAINSへ戻る
          ;
          POP     BC            ; 全てのレジスタを復帰
          POP     DE            ; 
          POP     HL            ; 
          POP     IX            ; 
          RET                   ; 呼び出し元へ戻る
          ;
RETURN:   LD      SP,(SSTACK)   ; 中断時：スタックポインタを安全な場所へ戻す
          CALL    SDOFF         ; サウンドを停止
          JP      START         ; タイトル画面や最初へ戻る
;
ST_SCORE: DEFB 4+64, 24, 15, "SCORE        ",0
ST_LIFE:  DEFB 4,    24, 15, "LEFT   ",0
ST_FPS:   DEFB 4,208+16, 15, "FPS    ",0 

;==============================================================================
; BIN2DEC_16 - 16bit数値(HL)を10進変換 (ゼロサプレスあり)
; 入力: HL = 変換する数値 (0-65535)
;       DE = 格納先メモリアドレス
;==============================================================================
BIN2DEC_16:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        PUSH    AF

        ; --- ゼロサプレス用フラグ初期化 (0 = まだ数字を書いていない) ---
        XOR     A
        LD      (SUPPRESS_FLG), A

        LD      BC, 10000
        CALL    OUT_DIGIT
        LD      BC, 1000
        CALL    OUT_DIGIT
        LD      BC, 100
        CALL    OUT_DIGIT
        LD      BC, 10
        CALL    OUT_DIGIT

        ; --- 最後の1の位 (ここだけは0でも必ず書く) ---
        LD      A, L
        ADD     A, '0'
        LD      (DE), A
        INC     DE
        XOR     A
        LD      (DE), A         ; 終端NULL
        
        POP     AF
        POP     BC
        POP     DE
        POP     HL
        RET

; --- 各桁の算出サブルーチン ---
OUT_DIGIT:
        LD      A, '0'          ; '0'からスタート
DIGIT_LOOP:
        OR      A               ; キャリークリア
        SBC     HL, BC          ; HL = HL - BC
        JR      NC, DIGIT_COUNT ; 引けたらカウントアップへ
        
        ; --- 引けなくなった時の処理 ---
        ADD     HL, BC          ; 引きすぎた分を1回足して戻す
        
        CP      '0'             ; 今回の計算結果が '0' か？
        JR      NZ, WRITE_VAL   ; '0' 以外（1-9）なら書き込みへ
        
        ; '0' だった場合、過去に有効な数字を書いたかチェック
        PUSH    AF
        LD      A, (SUPPRESS_FLG)
        OR      A
        JR      NZ, SKIP_PUSH   ; すでに数字を書いていれば '0' を書く
        POP     AF
        RET                     ; まだ何も書いてなければ、この '0' は無視して終了

SKIP_PUSH:
        POP     AF
WRITE_VAL:
        LD      (DE), A         ; 数字をメモリに格納
        INC     DE
        LD      A, 1
        LD      (SUPPRESS_FLG), A ; 「有効な数字を書いた」フラグを立てる
        RET

DIGIT_COUNT:
        INC     A               ; 数字を +1
        JR      DIGIT_LOOP      ; まだ引けるかループ

; --- ワークエリア ---
SUPPRESS_FLG: DEFB 0            ; 0=抑制中, 1=書き込み開始済み

;==============================================================================
; FPS COUNTER SYSTEM
;==============================================================================

JIFFY   EQU     0FC9EH          ; MSXシステム変数 (1/60秒ごとにカウントアップ)

; --- フレーム加算ルーチン ---
COUNT_FRAME:
        LD      HL, FRAME_CNT
        INC     (HL)            ; 256FPS以上は想定しないので1バイトでOK
        RET

; --- FPS計算ルーチン (1秒ごとに実行) ---
CALC_FPS:
        LD      A, (JIFFY)      ; JIFFYのLSBを確認
        SUB     60              ; 60フレーム(1秒)経ったか？
        RET     C               ; 60未満なら何もしない
        
        ; 1秒経過した時の処理
        DI
        XOR     A
        LD      (JIFFY), A      ; JIFFYをリセット(正確にはLBCもリセットすべきだが簡易的に)
        
        LD      A, (FRAME_CNT)
        LD      (CUR_FPS), A    ; 現在のFPSを保存
        XOR     A
        LD      (FRAME_CNT), A
        EI
        RET

; --- ワークエリア ---
FRAME_CNT: DEFB 0               ; 毎フレーム加算するカウンター
CUR_FPS:   DEFB 0               ; 確定したFPS値

;---- PORY WRITE ----
;
; オブジェクトワークエリアシステム
; 1オブジェクトあたり16バイトの領域で、最大16個のオブジェクトを生成できる
; 16バイトの領域説明（IX=オブジェクトワーク先頭アドレス）
;
; (IX+0) 出現フラグ　0の時は使われていない。1の時はオブジェクト処理をする
; (IX+1) 主に移動プログラムがカウンターや状態フラグとして使用する
; (IX+2) SEARCH内で当たりフラグとして使用される
; ------------- ここからの13バイトがDSETルーチンでセットされる -------------
; (IX+3) キャラクターモデリングデータの先頭アドレス(2バイト）
; (IX+4)
; (IX+5) キャラクター移動ルーチンの先頭アドレス（2バイト）
; (IX+6)
; (IX+7)  座標 X
; (IX+8)  座標 Y
; (IX+9)  座標 Z
; (IX+10) 回転角 RX
; (IX+11) 回転角 RY
; (IX+12) 回転角 RZ
; (IX+13) オブジェクトの色（1オブジェクト1色）
; (IX+14) オブジェクトの属性（当たり判定処理の分岐に使われる）
; (IX+15) オブジェクトのフラグ（下で説明）
;
; オブジェクトシステム （IX+15)のフラグ機能
;
; bit0  表示禁止フラグ    1なら表示しない(移動ルーチンはコールされる）
; bit1  拡大表示フラグ    1なら2.0倍
; bit2  縮小表示フラグ    1なら0.5倍
; bit3  当たり判定フラグ  1ならしない
; bit4  爆発表示フラグ    1なら爆発表示
; bit5  画面外にでたら消去するかどうか 0なら消去,1なら消去しない（使われてない）
;
; オブジェクトの当たり属性　(IX+14)
;
; 決定した当たり属性
; 0 無敵アイテム　　　　　　　　　一定時間無敵になる
; 1 破壊オブジェクト　　　　　　　ダメージ1食らう
; 2 破壊不能オブジェクト　　　　　ダメージ2食らう
; 3 回復アイテム　　　　　　　　　ライフが4回復
; 4 スピードアップアイテム　　　　取るたびにスピードアップのON/OFF
; 5 テクノイト（得点アイテム）　　色によって点数が異なる
; 6 救助を待つパーティー（得点）　Y座標で人間かキャンプかを判断して違う点数を加算
; 7 全破壊アイテム　　　　　　　　取った瞬間の画面中の敵オブジェクトを一掃
;
; 各ステージ固有の当たり属性は8以上を使用する
; 8 敵ガードオブジェクト　　（例）
; 9 クリスタルオブジェクト　（例）
;
;--------------------
MULTI:    PUSH    AF            ; レジスタをすべて保存
          PUSH    BC            ; 
          PUSH    DE            ; 
          PUSH    HL            ; 
          LD      (MULRET+1),SP ; 現在のスタックポインタを保存（強制復帰用）
          LD      HL,PALETTE      ; 戻り先をPALETTEに設定して
          PUSH    HL            ; スタックに積む
          LD      H,(IX+6)      ; オブジェクト固有のAIルーチン
          LD      L,(IX+5)      ; アドレッシングをロード
          JP      (HL)          ; 固有ルーチン（移動計算など）を実行

PALETTE:  BIT     0,(IX+15)     ; 描画禁止フラグをチェック
          JP      NZ,MULRET     ; フラグが立っていれば描画せずに終了へ
          ; --- 3D頂点変換開始 ---
          XOR     A             ; A=0
          LD      (IX+2),A      ; 画面外フラグなどをクリア
          LD      L,(IX+3)      ; 3Dモデルデータの開始アドレス
          LD      H,(IX+4)      ; 
          LD      B,(HL)        ; 頂点数をBにロード
          INC     HL            ; 
          LD      C,(HL)        ; 面（または線）の定義数をCにロード
          INC     HL            ; 
          LD      DE,POSITION   ; 座標変換後の格納先アドレス
MLOOP:    PUSH    BC            ; ループカウンタ保存
          PUSH    DE            ; 
          PUSH    HL            ; 頂点データポインタ保存
          PUSH    BC            ; 
          PUSH    DE            ; 
          LD      DE,WORK       ; 変換用の一時ワーク
          CALL    TURN          ; ★前述の回転・スケーリング・投影を実行！
          POP     DE            ; 
          POP     BC            ; 
          LD      A,B           ; 
          CP      C             ; 
          LD      HL,WORK       ; 
          CALL    NC,MONMAK     ; 座標を2D画面座標系へ変換
          POP     HL            ; 
          INC     HL            ; 次の頂点データへ（X, Y, Zの3バイト分）
          INC     HL            ; 
          INC     HL            ; 
          POP     DE            ; 
          INC     DE            ; 表示用ワークのポインタ更新
          INC     DE            ; 
          POP     BC            ; 
          DJNZ    MLOOP         ; 全頂点の変換が終わるまでループ
          ; --- 線引き（コネクト）開始 ---
          PUSH    HL            ; 接続リストのポインタを保存
          CALL    TUCH          ; 描画準備
          POP     BC            ; 接続リスト（BC）
SCREEN:   LD      A,(BC)        ; 始点となる頂点番号をロード
          ADD     A,A           ; 1点2バイトなので2倍
          LD      HL,WORK+1     ; 変換済み座標テーブルを参照
          ADD     A,L           ; 
          JR      NC,$+3        ; 
          INC     H             ; 
          LD      L,A           ; 
          LD      D,(HL)        ; D = 始点X
          INC     HL            ; 
          LD      E,(HL)        ; E = 始点Y
M1SC1:    INC     BC            ; 次の頂点番号へ
          LD      A,(BC)        ; 終点となる頂点番号をロード
          ADD     A,A           ; 
          LD      HL,WORK+1     ; 
          ADD     A,L           ; 
          JR      NC,$+3        ; 
          INC     H             ; 
          LD      L,A           ; 
          PUSH    DE            ; 始点を保存
          LD      D,(HL)        ; D = 終点X
          INC     HL            ; 
          LD      E,(HL)        ; E = 終点Y
          POP     HL            ; HL = 始点座標(X,Y)
          ; --- 爆発・破壊演出（BREAK） ---
          LD      A,(IX+2)      ; オブジェクトの状態をチェック
          OR      A             ; 
          JR      NZ,BREAK      ; 破壊フラグがあれば火花散らしへ
          BIT     4,(IX+15)     ; 特殊エフェクトビット
          JR      Z,M1SSET      ; 通常時はそのまま線引きへ
BREAK:    LD      A,R           ; ★CPUのRレジスタ（乱数）を取得！
          AND     00011111B     ; 5bitにマスク
          RRA                   ; 
          JR      NC,$+4        ; 
          NEG                   ; ランダムに符号反転
          ADD     A,D           ; X座標をランダムに揺らす
          LD      D,A           ; 
          ADD     A,119         ; 適当なオフセットでYも揺らす
          AND     00111111B     ; 
          RRA                   ; 
          JR      NC,$+4        ; 
          NEG                   ; 
          ADD     A,L           ; 
          LD      L,A           ; 
          ; --- VRAMへ描画命令発行 ---
M1SSET:   LD      (LIDAT),HL    ; 始点をセット
          LD      (LIDAT+2),DE  ; 終点をセット
          CALL    LINE          ; ★VDPに線を引く（MSX2のLINE相当）
          INC     BC            ; 
          LD      A,(BC)        ; 接続データが続くか確認
          DEC     BC            ; 
          OR      A             ; 
          JR      NZ,M1SC1      ; 0でなければ現在の始点からさらに線を引く
          INC     BC            ; 
          INC     BC            ; 
          LD      A,(BC)        ; 次の図形があるか
          OR      A             ; 
          JR      NZ,SCREEN     ; 0でなければ次のポリゴン（線リスト）へ
          POP     HL            ; 
          POP     DE            ; 
          POP     BC            ; 
          POP     AF            ; 
          RET                   ; 

MULEND:   XOR     A             ; オブジェクト消去処理
          LD      (IX+0),A      ; ワークの先頭を0にして「空き」にする
MULRET:   LD      SP,0          ; スタックポインタを保存した値で復帰（自己書き換え）
          POP     HL            ; レジスタ復帰
          POP     DE            ; 
          POP     BC            ; 
          POP     AF            ; 
          RET                   ;
;
; POINT TURN
;
; 頂点の3軸回転ルーチン
;
TURN:     PUSH    DE            ; レジスタDEを保護
          LD      B,(HL)        ; 頂点データの第1成分(X)をBにロード
          INC     HL            ; ポインタを次の成分へ
          LD      C,(HL)        ; 頂点データの第2成分(Y)をCにロード
          INC     HL            ; ポインタを次の成分へ
          ; --- 第1平面の回転 ---
          LD      A,(IX+10)     ; オブジェクトの回転角(1軸目)を取得
          AND     00011111B     ; 32段階(5bit)に制限
          CALL    NZ,ROTATE     ; 角度があれば回転演算を実行
          ; --- 座標を入れ替えて第2平面の回転 ---
          LD      D,B           ; 計算結果のBをDへ退避
          LD      B,(HL)        ; 頂点データの第3成分(Z)をBにロード
          LD      A,(IX+11)     ; 回転角(2軸目)を取得
          AND     00011111B     ; 
          CALL    NZ,ROTATE     ; 2軸目の回転を実行
          ; --- 座標を並べ替えて第3平面の回転 ---
          LD      E,C           ; 
          LD      C,B           ; 
          LD      B,D           ; 各成分を各軸の役割に振り直す
          LD      A,(IX+12)     ; 回転角(3軸目)を取得
          AND     00011111B     ; 
          CALL    NZ,ROTATE     ; 3軸目の回転を実行
          ; --- 仕上げ：スケーリング調整 ---
          POP     HL            ; 頂点データポインタを復帰
          BIT     1,(IX+15)     ; 拡大ビット(bit1)をチェック
          JR      Z,$+8         ; 立っていなければジャンプ
          SLA     B
          SLA     C
          SLA     E             ; 各座標を2倍にする(左シフト)
          BIT     2,(IX+15)     ; 縮小ビット(bit2)をチェック
          JR      Z,$+8         ; 立っていなければジャンプ
          SRA     B
          SRA     C
          SRA     E             ; 各座標を1/2にする(符号付き右シフト)
          JP      SEARCH        ; 回転後の座標(B,C,E)を投影ルーチンへ渡す
          ;
ROTATE:   PUSH    DE            ; レジスタDEを保護
          PUSH    HL            ; 頂点ポインタを保護
          LD      HL,SINDAT     ; サインテーブルの先頭アドレスをセット
          ADD     A,A           ; 1角度につき2バイト(sin/cos)なので角度を2倍
          ADD     A,L           ; 下位アドレス加算
          JR      NC,$+3        ; 桁上げがなければジャンプ
          INC     H             ; 桁上げがあれば上位アドレス加算
          LD      L,A           ; HL = 参照するサインデータのアドレス
          LD      D,(HL)        ; D = sinθ を取得
          INC     HL            ; 
          LD      E,(HL)        ; E = cosθ を取得
          ; --- 積和計算：第1成分 ---
          LD      A,D           ; sinθをAへ
          LD      H,B           ; 座標1をHへ
          OR      A             ; 0チェック
          CALL    NZ,MULT8      ; 座標1 * sinθ を計算
          LD      L,A           ; 結果をLへ
          LD      A,E           ; cosθをAへ
          LD      H,C           ; 座標2をHへ
          OR      A             ; 
          CALL    NZ,MULT8      ; 座標2 * cosθ を計算
          LD      H,A           ; 結果をHへ
          PUSH    HL            ; (成分1, 成分2)の中間結果を保存
          ; --- 積和計算：第2成分 ---
          LD      A,D           ; sinθ
          LD      H,C           ; 座標2
          OR      A             ; 
          CALL    NZ,MULT8      ; 座標2 * sinθ
          LD      L,A           ; 
          LD      A,E           ; cosθ
          LD      H,B           ; 座標1
          OR      A             ; 
          CALL    NZ,MULT8      ; 座標1 * cosθ
          SUB     L             ; A = Xcos - Ysin (回転の基本公式)
          LD      B,A           ; 新しい座標1を確定
          POP     HL            ; 中間結果を復帰
          LD      A,H           ; 
          ADD     A,L           ; A = Ycos + Xsin
          LD      C,A           ; 新しい座標2を確定
          POP     HL            ; ポインタ復帰
          POP     DE            ; 
          RET                   ; 戻る
          ;
MULT8:    INC     H             ; 座標値Hが0かどうかをチェック
          DEC     H             ; 
          JR      NZ,$+4        ; 0でなければ演算開始
          XOR     A             ; 0なら結果も0
          RET                   ; 
          PUSH    HL            ; レジスタ退避
          PUSH    BC            ; 
          PUSH    DE            ; 
          LD      D,0           ; 加算用上位レジスタをクリア
          LD      E,H           ; DE = 座標値
          LD      HL,0          ; 計算用ワークをリセット
          SLA     A             ; A(sin値)の正負を確認(bit7をキャリーへ)
          LD      B,A           ; AをBに待避
          JR      NC,$+5        ; 正ならスキップ
          LD      HL,NNEG       ; ★負なら計算後に反転処理(NNEG)へ飛ばす準備
          LD      (NEGPAT),HL   ; ★自己書き換え：NOPをJP NNEG等に変える
          LD      HL,0          ; 
          LD      A,E           ; 座標値
          OR      A             ; 
          JP      P,$+8         ; 座標が正ならスキップ
          LD      HL,NNEG       ; ★座標も負なら反転準備
          NEG                   ; 座標値を正の数にする
          LD      (NEGPT2),HL   ; ★自己書き換え箇所の設定
          LD      E,A           ; DEに正体化した値をセット
          LD      A,B           ; サイン値を戻す
          CP      0FEH          ; 1.0(127)に近いかチェック？
          JR      NZ,$+5        ; 1.0でなければ通常ループ
          LD      A,E           ; 1.0倍ならそのまま返す
          JR      NEGPAT        ; 終了処理へ
          ; --- ビットシフト加算 ---
          LD      HL,0          ; 
          RRA                   ; bit0 倍率Aを右シフトして1ビットずつ確認
          JR      NC,$+3        ; ビットが立っていなければ加算スキップ
          ADD     HL,DE         ; ビットが立っていれば加算
          SLA     E             ; 次のビットのために2倍にする
          RL      D             ; 
          RRA                   ; bit1
          JR      NC,$+3        ; 
          ADD     HL,DE         ; 
          SLA     E             ; 
          RL      D             ; 
          RRA                   ; bit2
          JR      NC,$+3        ;
          ADD     HL,DE         ;
          SLA     E             ;
          RL      D             ; 
          RRA                   ; bit3
          JR      NC,$+3        ; 
          ADD     HL,DE         ;
          SLA     E             ;
          RL      D             ; 
          RRA                   ; bit4
          JR      NC,$+3        ;
          ADD     HL,DE         ;
          SLA     E             ;
          RL      D             ; 
          RRA                   ; bit5
          JR      NC,$+3        ;
          ADD     HL,DE         ;
          SLA     E             ;
          RL      D             ; 
          RRA                   ; bit6
          JR      NC,$+3        ;
          ADD     HL,DE         ;
          SLA     E             ; 
          RL      D             ; 
          RRA                   ; bit7
          JR      NC,$+3        ;
          ADD     HL,DE         ;       
          ;
          LD      A,H           ; 上位8bitを固定小数点の計算結果として採用
NEGPAT:   NOP                   ; ★実行時に反転命令が書き込まれる場所
          NOP                   ; 
NEGPT2:   NOP                   ; ★同様
          NOP                   ; 
          POP     DE            ; レジスタ復帰
          POP     BC            ; 
          POP     HL            ; 
          RET                   ; 戻る
SINDAT:
DEFB        0,127,  25,126   ; 0度(sin 0, cos 1.0), 11.25度
DEFB       49,119,  71,107   ; 22.5度, 33.75度
DEFB       91, 91, 107, 71   ; 45度(sin 0.7, cos 0.7), 56.25度
DEFB      119, 49, 126, 25   ; 67.5度, 78.75度
DEFB      127,  0, 126,153   ; 90度(sin 1.0, cos 0), 101.25度...
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
; 当たり判定ルーチン
;
SEARCH:   LD      D,B           ; X軸：相対座標BをDにコピー（符号チェック用）
          LD      A,B           ; 相対座標BをAへ
          ADD     A,(IX+7)      ; 相対座標 + 中心座標 = 絶対座標を算出
          EX      AF,AF'        ; 計算結果（フラグ込）を裏レジスタへ退避
          RL      D             ; D（元の相対値）を回転させ符号をキャリーへ
          JR      NC,$+7        ; 正の数なら前進（クリッピング判定へ）
          EX      AF,AF'        ; 負の場合：裏レジスタから計算結果を戻す
          JR      NC,SERRET     ; 0未満（画面外左）なら中断処理へ
          JR      $+5           ; 
          EX      AF,AF'        ; 正の場合：裏レジスタから計算結果を戻す
          JR      C,SERRET      ; 255を超えた（画面外右）なら中断処理へ
          LD      (HL),A        ; 画面内なら2D座標バッファ(HL)に保存
          INC     HL            ; 次の格納先（Y座標）へ

          LD      D,E           ; Y軸：相対座標EをDにコピー
          LD      A,E           ; 
          ADD     A,(IX+8)      ; 相対座標 + 中心座標 = 絶対座標
          EX      AF,AF'        ; 裏レジスタへ退避
          RL      D             ; 符号チェック
          JR      NC,$+7        ; 
          EX      AF,AF'        ; 
          JR      NC,SERRET     ; 0未満（画面外上）なら中断へ
          JR      $+5           ; 
          EX      AF,AF'        ; 
          JR      C,SERRET      ; 画面外下なら中断へ
          LD      (HL),A        ; 画面内ならバッファに保存
          INC     HL            ; 次の格納先（Z座標）へ

          SRA     C             ; Z軸：奥行きCを右シフト（半分にする、あるいは精度調整）
          LD      D,C           ; 
          LD      A,C           ; 
          ADD     A,(IX+9)      ; 相対距離 + 中心距離
          EX      AF,AF'        ; 裏レジスタへ退避
          RL      D             ; 符号チェック
          JR      NC,$+7        ; 
          EX      AF,AF'        ; 
          JR      NC,SERRET     ; 奥行きがマイナスなら中断
          JR      $+5           ; 
          EX      AF,AF'        ; 
          JR      C,SERRET      ; 遠すぎたら中断
          LD      (HL),A        ; Z座標を保存

          BIT     3,(IX+15)     ; フラグチェック（判定スキップ設定か？）
          RET     NZ            ; スキップならここで終了

          ; --- ここから当たり判定 (GAGEとの照合) ---
          LD      DE,GAGE+5     ; 判定範囲データ(GAGE)の末尾（Z最大）を指定
          EX      DE,HL         ; HLをGAGEポインタ、DEを現在の座標ポインタに
          CP      (HL)          ; A（頂点Z）と GAGE+5（Z最大）を比較
          RET     NC            ; Zが最大値を超えていればリターン
          DEC     HL            ; GAGE+4（Z最小）を指す
          CP      (HL)          ; 比較
          RET     C             ; Zが最小値に届いていなければリターン

          LD      A,(IX+2)      ; 当たりフラグ用ワークエリアを取得
          OR      A             ; 
          RET     NZ            ; すでに「当たり」なら重複を避けてリターン

          EX      DE,HL         ; ポインタを入れ替え（DE=GAGE, HL=頂点バッファ）
          DEC     DE            ; GAGEポインタをY最大へ
          DEC     HL            ; 頂点ポインタをY座標へ
          LD      A,(DE)        ; GAGEのY最大値をロード
          CP      (HL)          ; 頂点Yと比較
          RET     C             ; 範囲外ならリターン
          DEC     DE            ; GAGEポインタをY最小へ
          LD      A,(DE)        ; GAGEのY最小値をロード
          CP      (HL)          ; 頂点Yと比較
          RET     NC            ; 範囲外ならリターン

          DEC     DE            ; GAGEポインタをX最大へ
          DEC     HL            ; 頂点ポインタをX座標へ
          LD      A,(DE)        ; GAGEのX最大値をロード
          CP      (HL)          ; 頂点Xと比較
          RET     C             ; 範囲外ならリターン
          DEC     DE            ; GAGEポインタをX最小へ
          LD      A,(DE)        ; GAGEのX最小値をロード
          CP      (HL)          ; 頂点Xと比較
          RET     NC            ; 範囲外ならリターン

          LD      A,1           ; 全ての条件をクリア！「当たり」の「1」をセット
          LD      (IX+2),A      ; ワークエリアの+2番目に「当たり」を記録
          RET                   ; 終了

SERRET:   BIT     5,(IX+15)     ; 画面外へ消えた時の特殊処理フラグ確認
          JP      Z,MULEND      ; フラグがなければ終了処理へ
          JP      MULRET        ; フラグがあれば復帰ルーチンへ
;
; TUCH ROUTINE
;
; 当たった物体のタイプ毎に違う処理へジャンプする
;
TUCH:     LD      H,0           ; 描画色の設定準備（上位バイトを0に）
          LD      L,(IX+13)     ; ワークエリアの+13番目から「オブジェクトの色」をロード
          LD      (LIDAT+4),HL  ; LINEコマンド用の色指定エリア(LIDAT+4)へ格納
          LD      A,(IX+2)      ; 前のSEARCHルーチンで書き込まれた「当たりフラグ」をロード
          OR      A             ; フラグが0（当たっていない）かどうかチェック
          RET     Z             ; 当たっていなければ、何もせずメインループへ戻る
          ; --- ここから「当たった時」の処理 ---
          LD      HL,JPTUCH     ; ジャンプ先のアドレスが並んでいるテーブルの先頭をセット
          LD      A,(IX+14)     ; オブジェクトの種類（ID）をロード
          AND     15            ; 下位4ビット（0-15の範囲）に限定する
          ADD     A,A           ; 2倍にする（アドレスは2バイト単位なのでオフセット計算）
          LD      E,A           ; 計算したオフセットをDEレジスタの下位へ
          LD      D,0           ; 上位Dを0に
          ADD     HL,DE         ; テーブルの先頭アドレス + オブセット = 目的のデータ位置
          LD      E,(HL)        ; テーブルからジャンプ先アドレスの下位バイトを読み出す
          INC     HL            ; 次のバイトへ
          LD      D,(HL)        ; ジャンプ先アドレスの上位バイトを読み出す
          EX      DE,HL         ; 読み出したジャンプ先アドレスをHLレジスタへ入れ替え
          JP      (HL)          ; 確定したアドレス（爆発や消滅処理など）へジャンプ！
          ;
JPTUCH:   DEFS    32            ; ジャンプテーブル本体（16個分のサブルーチンアドレスを格納）
;
; MONITOR POINT
;
; 画面座標生成ルーチン
;
MONMAK:   LD      A,(HL)        ; 3Dデータの「X座標」をAレジスタに読み込む
          LD      C,0           ; 16ビット演算・シフト用のワークレジスタCを0に
          INC     HL            ; データポインタを次へ
          INC     HL            ; さらに次へ（Z座標の参照準備）
          ADD     A,(HL)        ; X座標にZ座標の影響を加算（パースの予備計算）
          RL      C             ; 桁上がりをCに保管（精度の保持）
          ADD     A,(HL)        ; さらにZの影響を加算（倍率の調整）
          JR      NC,$+3        ; 桁上がりがなければ次のINC Cをスキップ
          INC     C             ; 桁上がりがあれば上位バイトCを増やす
          RR      C             ; CとAをセットで右回転（÷2）
          RRA                   ; Aを右回転（÷2：ビットを右へ流す）
          RR      C             ; 再度Cを回転
          RRA                   ; Aを回転（精度を落とさず分子を1/4に調整）
          RR      C             ; 
          LD      B,A           ; 調整が終わった「分子（X成分）」をBに格納
          PUSH    DE            ; 2D座標保存先アドレス(DE)を一時退避
          LD      D,0           ; 除算の準備：DEレジスタの上位Dを0に
          LD      A,(HL)        ; 奥行き「Z座標」をAに読み込む
          ADD     A,64          ; カメラからの基本距離（オフセット）を足す
          RL      D             ; 桁上がりをDに反映（16ビットの除数を作成）
          LD      E,A           ; 距離の合計をEにセット（DE = Z + 64）
          CALL    DIVIDE8        ; 【割り算実行】 A = B(X成分) / DE(Z距離)
          POP     DE            ; 保存先アドレス(DE)を復帰
          LD      (DE),A        ; 算出した2Dの「x座標」をメモリに書き込む
          DEC     HL            ; ポインタを戻してY座標の計算準備
          INC     DE            ; 2D座標保存先を次のバイト（y用）に進める
          ; --- ここからY座標の投影計算（Xと同様の工程） ---
          LD      A,(HL)        ; 3Dデータの「Y座標」を読み込む
          LD      C,0           ; Cをリセット
          INC     HL            ; Z座標を指すように調整
          ADD     A,(HL)        ; Y座標にZの影響を加算
          RL      C             ; 
          ADD     A,(HL)        ; 
          JR      NC,$+3        ; 
          INC     C             ; 
          RR      C             ; 
          RRA                   ; 
          RR      C             ; 
          RRA                   ; 分子（Y成分）のビットシフト調整
          RR      C             ; 
          LD      B,A           ; 調整後の値をBにセット
          PUSH    DE            ; 保存先アドレスを退避
          LD      D,0           ; 
          LD      A,(HL)        ; Z座標を読み込む
          ADD     A,64          ; Zにカメラオフセット64を足す
          RL      D             ; 
          LD      E,A           ; 
          CALL    DIVIDE8        ; 【割り算実行】 A = B(Y成分) / DE(Z距離)
          POP     DE            ; アドレス復帰
          LD      (DE),A        ; 算出した2Dの「y座標」をメモリに書き込む
          RET                   ; 頂点1つ分の投影完了！
          ;
; --- DIVIDE8 (8bit / 16bit 高速除算・完全版) ---
; 入力: B = 被除数 (分子)
;       DE = 除数 (分母)
; 出力: A = 商
; ----------------------------------------------
DIVIDE8:
          PUSH    HL
          PUSH    BC            ; Cを商の保持に使うため退避
          LD      H,0
          LD      L,B           ; HL = 被除数
          LD      C,0           ; C = 商の蓄積用 (0クリア)

          ; --- 1ビット目 ---
          ADD     HL,HL         ; 被除数を2倍に
          AND     A             ; Carryをクリア
          SBC     HL,DE         ; 引いてみる
          JR      NC,W_BIT1     ; 引けたら(Carry=0)ジャンプ
          ADD     HL,DE         ; 引けなければ(Carry=1)戻す
          SCF                   ; Carryを1にセットして
          CCF                   ; 反転(0にする)
          JR      W_NEXT1
W_BIT1:   SCF                   ; 引けたのでCarryを1に
W_NEXT1:  RL      C             ; Cにビットを詰め込む

          ; --- 2ビット目 ---
          ADD     HL,HL
          AND     A
          SBC     HL,DE
          JR      NC,W_BIT2
          ADD     HL,DE
          AND     A             ; Carryを0にする
          JR      W_NEXT2
W_BIT2:   SCF
W_NEXT2:  RL      C

          ; --- 3ビット目 ---
          ADD     HL,HL
          AND     A
          SBC     HL,DE
          JR      NC,W_BIT3
          ADD     HL,DE
          AND     A
          JR      W_NEXT3
W_BIT3:   SCF
W_NEXT3:  RL      C

          ; --- 4ビット目 ---
          ADD     HL,HL
          AND     A
          SBC     HL,DE
          JR      NC,W_BIT4
          ADD     HL,DE
          AND     A
          JR      W_NEXT4
W_BIT4:   SCF
W_NEXT4:  RL      C

          ; --- 5ビット目 ---
          ADD     HL,HL
          AND     A
          SBC     HL,DE
          JR      NC,W_BIT5
          ADD     HL,DE
          AND     A
          JR      W_NEXT5
W_BIT5:   SCF
W_NEXT5:  RL      C

          ; --- 6ビット目 ---
          ADD     HL,HL
          AND     A
          SBC     HL,DE
          JR      NC,W_BIT6
          ADD     HL,DE
          AND     A
          JR      W_NEXT6
W_BIT6:   SCF
W_NEXT6:  RL      C

          ; --- 7ビット目 ---
          ADD     HL,HL
          AND     A
          SBC     HL,DE
          JR      NC,W_BIT7
          ADD     HL,DE
          AND     A
          JR      W_NEXT7
W_BIT7:   SCF
W_NEXT7:  RL      C

          ; --- 8ビット目 ---
          ADD     HL,HL
          AND     A
          SBC     HL,DE
          JR      NC,W_BIT8
          ADD     HL,DE
          AND     A
          JR      W_NEXT8
W_BIT8:   SCF
W_NEXT8:  RL      C

          LD      A,C           ; 商をAにセット
          POP     BC
          POP     HL
          RET
;
; LINE ROUTINE
;
; 線描画ルーチン
;
LINE:     PUSH    AF            ; レジスタ退避：A（計算用）を保存
          PUSH    BC            ; レジスタ退避：BC（VDPポート・フラグ用）を保存
          PUSH    DE            ; レジスタ退避：DE（レジスタ指定用）を保存
          PUSH    HL            ; レジスタ退避：HL（座標データ用）を保存
          LD      BC,(RDVDP)    ; VDPのベースポート番号を取得
          INC     B             ; ポートを +1（通常は#99：コントロールポート）
          INC     C             ; ポートをさらに +1（通常は#9A：パレット/レジスタ間接）
          LD      L,C           ; 間接ポート番号をLに保管
          LD      C,B           ; コントロールポート（#99）をCにセット
          LD      DE,028FH      ; 「ステータスレジスタ#2」を読み取るための設定値
          DI                    ; 割り込み禁止（VDPとの通信中に邪魔が入らないように）
          OUT     (C),D         ; VDPレジスタ #15 を指定
          OUT     (C),E         ; 「ステータスレジスタ#2」の読み取りを開始
          LD      DE,2491H      ; 「レジスタ#17」に「コマンドレジスタ#36」を指定する設定値
          OUT     (C),D         ; VDPレジスタ #17 を指定
          OUT     (C),E         ; 「レジスタ#36」からの連続書き込み準備完了
          LD      H,C           ; コントロールポート（#99）をHに一時退避
          LD      C,L           ; データポート（#98/読み取り用）をCにセット
WAITLI:   IN      A,(C)         ; VDPのステータスを読み出す
          AND     1             ; CEビット（描画中フラグ）だけを抽出
          JR      NZ,WAITLI     ; VDPが前の仕事で忙しければ待つ
          LD      C,H           ; ポートをコントロール（#99）に戻す
          OUT     (C),A         ; VDPレジスタを一旦リセット（Aは0）
          LD      A,8FH         ; ステータス読み取り先を元に戻す命令
          OUT     (C),A         ; レジスタ #15 の設定を解除
          INC     C             ; ポートをコマンドレジスタ間接（#9B）に進める
          INC     C             ; ※ここはハードウェアの仕様に合わせたポート調整
          ;
          LD      HL,(LIDAT)    ; 始点座標 (X, Y) を読み込む
          LD      DE,(LIDAT+2)  ; 終点座標 (X', Y') を読み込む
          XOR     A             ; Aを0にする
          OUT     (C),H         ; R#32：始点X（下位）を書き込み
          OUT     (C),A         ; R#33：始点X（上位）は0固定
          OUT     (C),L         ; R#34：始点Y（下位）を書き込み
          LD      A,(VIJUAL)    ; 現在表示中のページを取得
          XOR     1             ; ページを反転（0ページ表示なら1ページに描画）
          OUT     (C),A         ; R#35：始点Y（上位/ページ指定）を書き込み
          LD      B,0           ; 方向フラグ（ARGレジスタ用）を初期化
          LD      A,D           ; 終点XをAに
          SUB     H             ; 終点X - 始点X (DX)
          JR      NC,LINE1      ; 結果が正なら右方向なのでジャンプ
          NEG                   ; 負なら反転して正の数（距離）にする
          SET     2,B           ; ARGのDIXビットを立てる（「左方向」へ描画）
LINE1:    LD      D,A           ; 確定したDX（Xの距離）をDに保存
          LD      A,E           ; 終点YをAに
          SUB     L             ; 終点Y - 始点Y (DY)
          JR      NC,LINE2      ; 結果が正なら下方向なのでジャンプ
          NEG                   ; 負なら反転して正の数（距離）にする
          SET     3,B           ; ARGのDIYビットを立てる（「上方向」へ描画）
LINE2:    LD      E,A           ; 確定したDY（Yの距離）をEに保存
          CP      D             ; DX と DY の長さを比較
          JR      C,LINE3       ; DXの方が長ければそのままジャンプ
          SET     0,B           ; DYの方が長ければARGのMAJビットを立てる
          LD      A,D           ; 長い方（DY）をDXレジスタに入れるためにスワップ開始
          LD      D,E           ; E (DY) を D (DX) に
          LD      E,A           ; A (旧DX) を E (DY) に
LINE3:    XOR     A             ; Aを0にする
          OUT     (C),D         ; R#36：長い方の距離 (DX) 下位を書き込み
          OUT     (C),A         ; R#37：DX上位 (0)
          OUT     (C),E         ; R#38：短い方の距離 (DY) 下位を書き込み
          OUT     (C),A         ; R#39：DY上位 (0)
          LD      DE,(LIDAT+4)  ; 色データ (Color) を読み込む
          OUT     (C),E         ; R#44：色コードを書き込み
          OUT     (C),B         ; R#45：ARG（計算した方向と軸フラグ）を書き込み
          LD      A,D           ; 指定された論理演算（IMPなど）をAに
          OR      01110000B     ; LINEコマンドコード（7）を合体
          OUT     (C),A         ; R#46：コマンド実行！ 描画がスタートする
          EI                    ; 割り込みを許可に戻す
          POP     HL            ; レジスタ復帰
          POP     DE            ;
          POP     BC            ;
          POP     AF            ;
          RET                   ; メインルーチンへ戻る
          ;
LIDAT:    DEFB    0,0  ;X ,Y
          DEFB    0,0  ;X',Y'
          DEFB    0,0  ;COLOR
;
; CLS ROUTINE
;
; 画面消去
;
CLS:      PUSH    AF            ; レジスタ退避：メイン処理に影響を与えないよう保存
          PUSH    BC            ; 
          PUSH    DE            ; 
          PUSH    HL            ; 
          LD      A,(VIJUAL)    ; 現在「表示中」のページ番号を取得
          XOR     1             ; 0と1を反転させ「裏ページ」の番号を作る
          LD      (CMDDAT+3),A  ; 描画先Y座標のハイバイト（ページ指定）として書き込み
          LD      BC,(RDVDP)    ; 事前に調べておいたVDPポート番号を取得
          LD      DE,028FH      ; R#15にステータスレジスタ#2を指定するための値
          INC     B             ; ポートを #99（コントロール）に調整
          INC     C             ; ポートを #9A（間接/レジスタ）に調整
          LD      L,C           ; 間接アクセス用ポート番号をLに保存
          LD      C,B           ; Cをコントロールポート（#99）にセット
          DI                    ; 割り込み禁止（VDP通信の整合性を守る）
          OUT     (C),D         ; VDPレジスタ #15 を選択
          OUT     (C),E         ; 「ステータスレジスタ#2」を読み取れる状態にする
          LD      DE,2491H      ; R#17に「コマンドレジスタの先頭(#32)」を指定する値
          OUT     (C),D         ; VDPレジスタ #17 を選択
          OUT     (C),E         ; パラメータの連続転送準備（オートインクリメント）
          INC     C             ; ポートを #9B（コマンド転送専用ポート）に進める
          INC     C             ; ※機種依存を避けるための丁寧な調整
          LD      H,C           ; コマンドポート（#9B）をHに保存
          LD      C,L           ; データポート（#98）を読み取り用にセット
WAITCL:   IN      A,(C)         ; VDPの状態を読み込む
          AND     1             ; CEビット（コマンド実行中か）をチェック
          JR      NZ,WAITCL     ; 前の描画が終わっていなければループして待つ
          LD      C,H           ; ポートをコマンド転送用の #9B に戻す
          LD      HL,CMDDAT     ; 転送するデータ（11バイト）のアドレス
          OUTI                  ; 1バイト目：X開始位置(L)
          OUTI                  ; 2バイト目：X開始位置(H)
          OUTI                  ; 3バイト目：Y開始位置(L)
          OUTI                  ; 4バイト目：Y開始位置(H / ページ番号)
          OUTI                  ; 5バイト目：幅X(L)
          OUTI                  ; 6バイト目：幅X(H)
          OUTI                  ; 7バイト目：高さY(L)
          OUTI                  ; 8バイト目：高さY(H)
          OUTI                  ; 9バイト目：色データ（0=黒）
          OUTI                  ; 10バイト目：未使用/方向
          OUTI                  ; 11バイト目：コマンド実行（HMMV）
          DEC     C             ; ポートをコントロール（#99）側へ戻す
          DEC     C             ; 
          OUT     (C),A         ; A（0）を書き込んでレジスタ選択をリセット
          LD      A,8FH         ; ステータスレジスタの読み取り先を#0に戻す
          OUT     (C),A         ; レジスタ #15 を解除
          EI                    ; 割り込み許可
          POP     HL            ; レジスタ復帰
          POP     DE            ; 
          POP     BC            ; 
          POP     AF            ; 
          RET                   ; 呼び出し元へ戻る
          ;
CMDDAT:   DEFW    0,22          ; 転送先X=0, Y=22
          DEFW    256,212       ; 消去サイズ 横256, 縦212ドット
          DEFB    0             ; 塗りつぶす色（0番＝通常は黒）
          DEFB    00000000B     ; 転送方向（通常設定）
          DEFB    11000000B     ; コマンドコード「HMMV」（VRAM高速埋め尽くし）
;
; SCALE SUB
;
; 地平線表示ルーチン
;
SCALE:    PUSH    AF            ; レジスタ退避：メインの計算に影響しないように保存
          PUSH    BC            ; 
          PUSH    DE            ; 
          PUSH    HL            ; 
          LD      A,(SCOLOR)    ; 地面の描画色を取得
          LD      L,A           ; Lレジスタに色をセット
          LD      H,0           ; Hを0に（HLで色の設定を作る）
          LD      (LIDAT+4),HL  ; LINEコマンド用の色データ領域(LIDAT+4)へ保存
          LD      L,154         ; Y座標の基準値 154 をセット
          LD      (LIDAT),HL    ; LINE始点のY座標として保存（Xは0）
          LD      H,255         ; X終点を 255（画面右端）にセット
          LD      (LIDAT+2),HL  ; LINE終点の座標として保存（Yは始点と同じ154）
          CALL    LINE          ; 地平線の基準となる1本目を描画
          ; --- スクロールのインデックス計算 ---
          LD      A,(SCOLOR+1)  ; スクロールの速度成分を取得
          AND     3             ; 0?3の範囲に限定（マスク処理）
          LD      H,A           ; 増分をHにセット
          LD      A,(POINTA)    ; 現在のスクロール位置（0?7）を取得
          ADD     A,H           ; 位置を更新（速度分だけ進める）
          AND     7             ; 0?7の範囲でループさせる（8段階アニメーション）
          LD      (POINTA),A    ; 更新した位置を保存
          ; --- テーブルの参照アドレス計算 ---
          LD      HL,POINTA+1   ; パーステーブルの先頭アドレスをHLに
          ADD     A,L           ; 現在のスクロール位置(0-7)を足して参照開始点を決める
          JR      NC,$+3        ; 桁上がり（キャリー）がなければ次へ
          INC     H             ; 桁上がりがあればアドレスのハイバイトを調整
          LD      L,A           ; テーブル内の読み出し開始位置が確定
          LD      B,4           ; ループ回数：パース線を4本引く
SCLOOP:   LD      A,(HL)        ; テーブルからY座標を読み出す
          LD      E,A           ; EにY座標をセット
          LD      D,0           ; D=0 (X始点=0)
          LD      (LIDAT),DE    ; LINEコマンドの始点座標へ
          LD      D,255         ; D=255 (X終点=255)
          LD      (LIDAT+2),DE  ; LINEコマンドの終点座標へ（水平線）
          CALL    LINE          ; パースのついた水平線を描画
          LD      DE,8          ; 次のパース線までのオフセット（8段階分飛ばす）
          ADD     HL,DE         ; HLを次の線のデータ位置へ進める
          DJNZ    SCLOOP        ; Bレジスタを減らして、4本引くまでループ
          POP     HL            ; レジスタ復帰
          POP     DE            ; 
          POP     BC            ; 
          POP     AF            ; 
          RET                   ; 呼び出し元へ戻る
          ;
POINTA:
DEFB      0						; 現在のスクロール状態（0?7）
; 以下、奥から手前へ広がるY座標のリスト（8段階のアニメーションを内包）
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
; キー入力ルーチン
;
KEY:      PUSH    IX            ; IXレジスタ（ワークエリア用）を保存
          XOR     A             ; A=0 (ジョイスティック0番＝カーソルキー指定)
          LD      IX,GTSTCK     ; BIOSのGTSTCK関数のアドレス(#00D5)をセット
          LD      IY,(EXPTBL-1) ; BIOSスロット情報を取得
          CALL    CALSLT        ; キー入力を読み出す
          OR      A             ; 入力があったかチェック
          JR      NZ,M1JRKE     ; 入力があれば次へ
          INC     A             ; A=1 (ジョイスティック1番)に切り替え
          LD      IX,GTSTCK     ; 
          LD      IY,(EXPTBL-1) ; 
          CALL    CALSLT        ; ジョイスティック1番も読みに行く
M1JRKE:   POP     IX            ; IXを復帰（ここからIX+nでオブジェクトのワークを操作）
          OR      A             ; 入力（方向）を確認（0=入力なし, 1=上, 3=右, 5=下, 7=左）
          JR      Z,M1TRIG      ; 入力がなければボタンチェックへ
          DEC     A             ; 0-7の範囲に調整
          LD      B,A           ; Bに入力方向を保存
          LD      D,(IX+7)      ; 現在のX座標をDにロード
          LD      E,(IX+8)      ; 現在のY座標をEにロード
          AND     3             ; 上下の動きを除去して左右成分を抽出
          JR      Z,M1DOWN      ; 左右の入力がなければ次へ
          BIT     2,B           ; 左方向（方向5,6,7あたり）かどうか判定
          LD      A,D           ; X座標をAへ
          JR      NZ,M1LEFT     ; 左ならM1LEFTへジャンプ
          ADD     A,16          ; 【右移動】16ドット右へ
          CP      225           ; 画面端（225）を超えないかチェック
          JR      NC,M1DOWN     ; 超えるなら移動キャンセル
          LD      D,A           ; X座標を更新
          DEC     (IX+10)       ; RX回転角度を減らす
          JR      M1DOWN        ; Y軸計算へ
M1LEFT:   SUB     16            ; 【左移動】16ドット左へ
          CP      32            ; 左端（32）より小さくならないかチェック
          JR      C,M1DOWN      ; 
          LD      D,A           ; X座標を更新
          INC     (IX+10)       ; RX回転角度を増やす          
M1DOWN:   LD      A,B           ; 保存していた方向を戻す
          ADD     A,2           ; 方向を90度ずらして上下判定をしやすくする
          AND     7             ; 
          LD      B,A           ; 
          AND     3             ; 
          JR      Z,M1SET       ; 上下の入力がなければ保存へ
          BIT     2,B           ; 上下どっちか判定
          LD      A,E           ; Y座標をAへ
          JR      NZ,M1DW       ; 上ならM1DWへジャンプ
          ADD     A,16          ; 【下移動】16ドット下へ
          CP      225           ; 画面下端チェック
          JR      NC,M1SET      ; 
          LD      E,A           ; Y座標を更新
          JR      M1SET         ; 
M1DW:     SUB     16            ; 【上移動】16ドット上へ
          CP      32            ; 上端チェック
          JR      C,M1SET       ; 
          LD      E,A           ; Y座標を更新
M1SET:    LD      (IX+7),D      ; 確定したX座標を保存
          LD      (IX+8),E      ; 確定したY座標を保存
          ;
M1TRIG:   PUSH    IX            ; 再びIX退避
          XOR     A             ; A=0 (スペースキー/ボタン1)
          LD      IX,GTTRIG     ; BIOSのGTTRIG関数のアドレス(#00D8)
          LD      IY,(EXPTBL-1) ; 
          CALL    CALSLT        ; ボタン状態を取得
          INC     A             ; ボタンが押されているか判定
          JR      Z,M1JRTR      ; 
          LD      IX,GTTRIG     ; Aボタン(1)を読みに行く
          LD      IY,(EXPTBL-1) ; 
          CALL    CALSLT        ; 
          INC     A             ; 
M1JRTR:   POP     IX            ; 
          ;
          JR      Z,M1GO        ; ボタンが押されていればM1GOへ
          LD      A,-8          ; 【ボタンなし時】値を-8（戻るような動き）
          ADD     A,(IX+9)      ; 
          CP      16            ; 
          JR      C,M1SET2+3    ; 
          JR      M1SET2        ; 
M1GO:     LD      A,16          ; 【ボタンあり時】値を+16（進むような動き）
          ADD     A,(IX+9)      ; 
          CP      129           ; 最大値129でリミッター
          JR      NC,M1SET2+3   ; 
M1SET2:   LD      (IX+9),A      ; 更新した値を保存
          ;
          ; 自機の微細な振動テスト
          ;
;          LD      A,(IX+1)      ; カウンタ値ゲット
;          INC     (IX+1)        ; カウンタを増やす
;          AND     3
;          LD      HL,M1TURNTBL  ; 揺れのテーブル
;          LD      E,A
;          LD      D,0
;          ADD     HL,DE
;          LD      A,(HL)        ; 現在の揺れ値をゲット
;          LD      (IX+12),A
          ;
          CALL    SETGAG        ; 当たり判定ボックス生成ルーチン
          RET
          
;M1TURNTBL: DEFB 0,-1,0,1
;
; SET GAGE
;
; 当たり判定ボックス生成ルーチン
;
SETGAG:   LD      IY,GAGE       ; 計算結果を格納するワークエリア「GAGE」のアドレスをIYにセット
          ; --- X軸の範囲計算 ---
          LD      A,(IX+7)      ; KEYルーチンで更新された「現在のX座標」をロード
          ADD     A,24          ; X座標に +24 する（右側の限界値を計算）
          LD      (IY+1),A      ; GAGEの2番目のバイト（X最大値）に保存
          SUB     48            ; 現在のA(X+24)から 48 引く（つまり X-24：左側の限界値）
          LD      (IY+0),A      ; GAGEの1番目のバイト（X最小値）に保存
          ; --- Y軸の範囲計算 ---
          LD      A,(IX+8)      ; 「現在のY座標」をロード
          ADD     A,20          ; Y座標に +20 する（下側の限界値を計算）
          LD      (IY+3),A      ; GAGEの4番目のバイト（Y最大値）に保存
          SUB     38            ; 現在のA(Y+20)から 38 引く（つまり Y-18：上側の限界値）
          LD      (IY+2),A      ; GAGEの3番目のバイト（Y最小値）に保存
          ; --- 特殊パラメータ（Z軸やパワーなど）の範囲計算 ---
          LD      A,(IX+9)      ; ボタン入力等で変化する「第3のパラメータ」をロード
          ADD     A,16          ; +16 する（最大幅）
          LD      (IY+5),A      ; GAGEの6番目のバイトに保存
          SUB     32            ; 現在のAから 32 引く（つまり元の値から -16：最小幅）
          LD      (IY+4),A      ; GAGEの5番目のバイトに保存
          RET                   ; 計算完了、戻る
;
; MOVE SUB
;
MOVE:     PUSH    IX            ; 現在のオブジェクトのワークエリア先頭(IX)を保存
          POP     HL            ; 保存したアドレスをHLレジスタにコピー
          LD      DE,7           ; オフセット値「7」をセット
          ADD     HL,DE         ; HL = IX + 7（座標データが始まる位置までポインタを移動）
          POP     DE            ; ★重要：呼び出し元がスタックに積んだ「移動量データのアドレス」を取得
          ; --- 1項目目（X座標など）の更新 ---
          LD      A,(DE)        ; 移動量データの1バイト目を読み込む
          ADD     A,(HL)        ; 現在の値（IX+7）に加算する
          LD      (HL),A        ; 加算後の値を書き戻す
          INC     DE            ; 移動量データのポインタを次へ
          INC     HL            ; オブジェクト側のポインタを次へ（IX+8へ）
          ; --- 2項目目（Y座標など）の更新 ---
          LD      A,(DE)        ; 移動量データの2バイト目を読み込む
          ADD     A,(HL)        ; 現在の値（IX+8）に加算
          LD      (HL),A        ; 書き戻し
          INC     DE            ; 
          INC     HL            ; 次へ（IX+9へ）
          ; --- 3項目目（Z座標など）の更新 ---
          LD      A,(DE)        ; 
          ADD     A,(HL)        ; 
          LD      (HL),A        ; (IX+9)を更新
          INC     DE            ; 
          INC     HL            ; 次へ（IX+10へ）
          ; --- 4項目目（回転角など）の更新 ---
          LD      A,(DE)        ; 
          ADD     A,(HL)        ; 
          LD      (HL),A        ; (IX+10)を更新
          INC     DE            ; 
          INC     HL            ; 次へ（IX+11へ）
          ; --- 5項目目（予備パラメータ1）の更新 ---
          LD      A,(DE)        ; 
          ADD     A,(HL)        ; 
          LD      (HL),A        ; (IX+11)を更新
          INC     DE            ; 
          INC     HL            ; 次へ（IX+12へ）
          ; --- 6項目目（予備パラメータ2）の更新 ---
          LD      A,(DE)        ; 
          ADD     A,(HL)        ; 
          LD      (HL),A        ; (IX+12)を更新
          ;
          INC	  DE            ; スタックを調整
          PUSH    DE
          RET                   ; データの後に戻る
;
; TURN SUB 
;
; 相対回転サブルーチン
;
RTURN:    EX      (SP),HL       ; スタックトップ（戻り先＝データポインタ）とHLを入れ替え
          PUSH    DE            ; レジスタ退避
          PUSH    BC            ; 
          PUSH    AF            ; 
          PUSH    HL            ; データの開始アドレスを一時保存
          ; --- 回転の中心点からの相対座標を算出 ---
          LD      A,(IX+7)      ; 現在の絶対X座標をロード
          SUB     (HL)          ; データの中心点Xを引く（相対Xを算出）
          LD      B,A           ; B = 相対X
          INC     HL            ; 次のデータ（中心点Y）へ
          LD      A,(IX+8)      ; 現在の絶対Y座標をロード
          SUB     (HL)          ; データの中心点Yを引く（相対Yを算出）
          LD      C,A           ; C = 相対Y
          INC     HL            ; 次のデータ（中心点Z）へ
          LD      A,(IX+9)      ; 現在の絶対Z座標をロード
          SUB     (HL)          ; データの中心点Zを引く（相対Zを算出）
          LD      D,A           ; D = 相対Z
          ; --- 3軸回転処理の開始 ---
          INC     HL            ; 次のデータ（X軸回転角）へ
          LD      A,(HL)        ; 回転角をロード
          OR      A             ; 角度が0かどうかチェック
          CALL    NZ,ROTATE     ; 0でなければ回転サブルーチン実行！
          ; 軸の入れ替え（レジスタの役割をスライドさせる）
          LD      E,B           ; Bを退避
          LD      B,D           ; 
          INC     HL            ; 次のデータ（Y軸回転角）へ
          LD      A,(HL)        ; 
          OR      A             ; 
          CALL    NZ,ROTATE     ; 2軸目の回転実行！
          ; 再び軸の入れ替え
          LD      D,C           ; 
          LD      C,B           ; 
          LD      B,E           ; 
          INC     HL            ; 次のデータ（Z軸回転角）へ
          LD      A,(HL)        ; 
          OR      A             ; 
          CALL    NZ,ROTATE     ; 3軸目の回転実行！
          ; --- 回転後の相対座標に中心点を足し戻す ---
          POP     HL            ; データの開始アドレス（中心点）を復帰
          LD      A,B           ; 回転後のX座標
          ADD     A,(HL)        ; 中心点Xを足して絶対座標に戻す
          LD      (IX+7),A      ; 更新されたX座標を保存
          INC     HL            ; 
          LD      A,D           ; 回転後のY座標
          ADD     A,(HL)        ; 中心点Yを足す
          LD      (IX+8),A      ; 更新されたY座標を保存
          INC     HL            ; 
          LD      A,C           ; 回転後のZ座標
          ADD     A,(HL)        ; 中心点Zを足す
          LD      (IX+9),A      ; 更新されたZ座標を保存
          ; --- 後処理 ---
          INC     HL            ; 
          INC     HL            ; 使用したデータ分だけHLを進める
          INC     HL            ; （このHLが呼び出し元への戻り先になる）
          INC     HL            ; 
          POP     AF            ; レジスタ復帰
          POP     BC            ; 
          POP     DE            ; 
          EX      (SP),HL       ; 更新されたポインタをスタックに戻し、元のHLを復帰
          RET                   ; 呼び出し元へ
;
; DATA SET
;
; オブジェクトワークエリアセットルーチン
;
DSET:     EX      (SP),HL       ; スタックトップ（データのポインタ）とHLを入れ替え
          PUSH    DE            ; レジスタ退避
          PUSH    BC            ; 
          PUSH    AF            ; 
          PUSH    HL            ; データの開始アドレスを一時保存
          LD      HL,PORIDAT    ; オブジェクトワークエリア(PORIDAT)の先頭をセット
          LD      DE,16          ; 1つあたりのデータサイズ（16バイト）をセット
          LD      B,E           ; 最大16個のスロットをチェックするループカウンタ
DSLOOP:   LD      A,(HL)        ; ワークエリアの先頭バイト（使用フラグ）を読み込む
          OR      A             ; フラグが0（空きスロット）かどうか確認
          JR      Z,DSSET       ; 空いていれば、データ書き込み(DSSET)へジャンプ
          ADD     HL,DE         ; 使用中なら、次のスロットへポインタを進める
          DJNZ    DSLOOP        ; 空きが見つかるまでループ
          ; --- 空きが見つからなかった場合 ---
          POP     HL            ; 保存していたデータポインタを戻す
          LD      DE,13          ; データのサイズ（13バイト分）だけ進める
          ADD     HL,DE         ; 
          JR      DSRET         ; 何もせず終了処理へ
          ; --- データ書き込み処理 ---
DSSET:    POP     DE            ; 保存していた「コピー元データ」のポインタをDEへ
          LD      (HL),1        ; 使用フラグを「1（使用中）」にする
          INC     HL            ; 
          LD      (HL),0        ; 汎用カウンタをリセット
          INC     HL            ; 
          LD      (HL),0        ; 当たりフラグリセット
          INC     HL            ; 
          EX      DE,HL         ; LDIを使うためにDE(コピー先)とHL(コピー元)を調整
          ; 怒涛のLDI（高速メモリ転送） 呼び出し側から13バイトをスロットへコピー
          LDI                   ; 1バイト転送 (X座標?)
          LDI                   ; 2バイト転送 (Y座標?)
          LDI                   ; 3バイト転送 (Z座標?)
          LDI                   ; 4バイト転送 (移動速度/角度?)
          LDI                   ; 5バイト転送
          LDI                   ; 6バイト転送
          LDI                   ; 7バイト転送
          LDI                   ; 8バイト転送
          LDI                   ; 9バイト転送
          LDI                   ; 10バイト転送
          LDI                   ; 11バイト転送
          LDI                   ; 12バイト転送
          LDI                   ; 13バイト転送
DSRET:    POP     AF            ; レジスタ復帰
          POP     BC            ; 
          POP     DE            ; 
          EX      (SP),HL       ; 更新されたポインタをスタックに戻し、元のHLを復帰
          RET                   ; 呼び出し元へ
;
; OBJ WORK CLEAR
;
; オブジェクトワークエリア全消去ルーチン
;
CLSPRI:   XOR     A             ; Aレジスタを0にする（消去用の値）
          LD      HL,PORIDAT    ; 塗りつぶしの「起点」となるアドレスをセット
          LD      DE,PORIDAT+1  ; 「書き込み先」を1バイトずらしてセット
          LD      BC,255        ; 塗りつぶす範囲（バイト数）を指定
          LD      (HL),A        ; 最初の1バイト（PORIDATの先頭）に0を書き込む
          LDIR                  ; HLからDEへ転送を繰り返す（0が次々と隣へコピーされる）
          RET                   ; 初期化完了、戻る
;
; PALETTE SET
;
; パレット処理
;
PALETE:   PUSH    AF            ; レジスタをすべて保護
          PUSH    BC            ; 
          PUSH    DE            ; 
          PUSH    HL            ; 
          LD      BC,(RDVDP+1)  ; BIOSワークエリアからVDPポートのアドレスを取得
          INC     C             ; ポートをコントロール用(通常#99)に調整
          DI                    ; 割り込み禁止（VDPレジスタ操作中の安全確保）
          ; --- パレットレジスタのポインタを0番にセット ---
          XOR     A             ; A = 0
          OUT     (C),A         ; パレット番号0を指定
          LD      A,80H+16      ; VDPレジスタ16番（パレットポインタ）を指定
          OUT     (C),A         ; 
          INC     C             ; ポートをデータ用(通常#9A)に調整
          ; --- パレットデータの転送ループ ---
          LD      B,16          ; 16色分繰り返す
          LD      HL,PLDAT      ; パレットデータの先頭アドレス
          LD      E,(HL)        ; ★データの最初の1バイト(7)を「減算値」として読み込む
PLLOOP:   INC     HL            ; 次のデータ（赤・緑成分）へ
          ; --- 緑(Green)成分の処理 ---
          LD      A,(HL)        ; 緑の輝度をロード
          SUB     E             ; 減算値を引く（暗くする）
          JR      NC,$+3        ; 結果がマイナスにならなければOK
          XOR     A             ; マイナスなら0でクランプ（真っ暗）
          RLCA                  ; 緑は上位4ビットなので左へ4回シフト
          RLCA                  ; 
          RLCA                  ; 
          RLCA                  ; 
          LD      D,A           ; 緑成分をDに一時保存
          ; --- 赤(Red)成分の処理 ---
          INC     HL            ; 
          LD      A,(HL)        ; 赤の輝度をロード
          SUB     E             ; 減算値を引く
          JR      NC,$+3        ; 
          XOR     A             ; マイナスなら0
          OR      D             ; 保存していた緑成分と合成
          OUT     (C),A         ; VDPへ書き込み (1バイト目：RB)
          ; --- 青(Blue)成分の処理 ---
          INC     HL            ; 
          LD      A,(HL)        ; 青の輝度をロード
          SUB     E             ; 減算値を引く
          JR      NC,$+3        ; 
          XOR     A             ; マイナスなら0
          OUT     (C),A         ; VDPへ書き込み (2バイト目：-B)
          DJNZ    PLLOOP        ; 16色終わるまでループ
          EI                    ; 割り込み許可
          POP     HL            ; レジスタ復帰
          POP     DE            ; 
          POP     BC            ; 
          POP     AF            ; 
          RET                   ; 終了
          ;
PLDAT:    DEFB    7             ; この値が全ての輝度から引かれる（今は7なので全部真っ暗になる！）
          DEFB    0,0,0,0,0,0   ; 0?2色目のRGBデータ（以下同様）
          DEFB    1,1,6,3,3,7
          DEFB    1,7,1,2,7,3
          DEFB    5,1,1,2,7,6
          DEFB    7,1,1,7,3,3
          DEFB    6,1,6,6,3,6
          DEFB    1,1,4,6,5,2
          DEFB    5,5,5,7,7,7
;  
; FADE IN 
; 
; だんだん明るくする処理のオブジェクトを作成
;
UNFADE:   CALL    DSET          ; 空きスロットを探して新しいタスクを登録
          DEFW    0,UNFAD       ; (IX+1)=0（初期状態）, 実行アドレス=UNFAD を設定
          DEFW    0,0,0,0       ; 座標などのパラメータ（今回は未使用なので0）
          DEFB    00000001B     ; オブジェクト属性（フラグ）を設定
          RET                   ; 登録完了！あとはメインループが勝手にUNFADを呼ぶ
          ;  
          ; フェードインオブジェクトのコールバック処理
          ;
UNFAD:    LD      A,(IX+1)      ; ワークエリアから現在の経過フレーム（輝度段階）をロード
          INC     (IX+1)        ; 次のフレームのためにカウントアップ
          CP      8             ; 輝度が最大（8段階目）に達したかチェック
          JP      Z,MULEND      ; 最大なら、このフェードインタスクを自身で消去して終了
          ; --- パレットの減算値を計算 ---
          XOR     7             ; 0→7, 1→6... という具合に「7からの逆順」に変換
          LD      (PLDAT),A     ; 計算した値をPALETEルーチンが参照する減算用メモリに書き込む
          CALL    PALETE        ; 実際にパレットを更新（画面が一段階明るくなる）
          RET                   ; 今回の処理終了（また次のフレームで呼ばれる）
;
; FADE OUT
;
; 画面をだんだんと暗くする処理のオブジェクトを生成
;
FADE:     CALL    DSET          ; 空きスロットにフェードアウト・タスクを登録
          DEFW    0,FAD         ; (IX+1)=0, 実行アドレス=FAD（フェードアウト本体）
          DEFW    0,0,0,0       ; 座標等のパラメータ（未使用）
          DEFB    00000001B     ; オブジェクト属性フラグ
          RET                   ; メインループに処理を任せて戻る
          ;
          ; フェードアウトオブジェクトのコールバック処理
          ;
FAD:      LD      A,(IX+1)      ; 現在のフェード段階（0?7）をロード
          INC     (IX+1)        ; 次のフレームのために段階を進める
          CP      8             ; 8段階（完全に真っ暗）に達したかチェック
          JP      Z,MULEND      ; 完了したら、このオブジェクトを消去（MULEND）して終了
          ; --- パレットの減算値をセット ---
          LD      (PLDAT),A     ; カウント値Aをそのまま減算値として書き込む
                                ; (0=通常, 1=少し暗い ... 7=真っ暗)
          CALL    PALETE        ; パレット更新ルーチンを呼び出し、実際に画面を暗くする
          RET                   ; 次のフレームまで待機
;
; GOD MODE SET
;
; 無敵セットとリセット
;
GOD_TIME: EQU     48 ; 無敵時間

; 無敵をセットする（アイテム当たりプログラムから呼ばれる)
GOD_SET:
          PUSH    AF
          LD      A,(SWITCH)
          BIT     5,A          ; 既に無敵なら色をコピーするのはジャンプ
          JR      NZ,GODJP1
          SET     5,A
          LD      (SWITCH),A
          LD      A,(MASTER+13)
          LD      (MCOLOR),A
GODJP1    LD      A,GOD_TIME
          LD      (MCOUNT),A
          POP     AF
          RET
          
; MAINから呼ばれる無敵カウントダウンプログラム
GOD_MAIN:
          PUSH    AF
          LD      A,(MCOUNT)    ; 無敵カウントをAへ
          BIT     0,A
          JR      NZ,GJR1
          LD      (IX+13),7     ; 無敵状態は黄色と水色を交互に点滅
          JR      GJR2
GJR1:     LD      (IX+13),11
GJR2:     DEC     A
          LD      (MCOUNT),A    ; カウンタを更新
          OR      A
          JR      NZ,GJR3
          LD      A,(SWITCH)
          RES     5,A
          LD      (SWITCH),A
          LD      A,(MCOLOR)
          LD      (MASTER+13),A      
GJR3      POP     AF
          RET
          
; 念のために死亡プログラムから無敵状態を解除
GOD_RESET:
          PUSH    AF
          XOR     A
          LD      (MCOUNT),A
          LD      A,(MCOLOR)
          LD      (IX+13),A
          LD      A,(SWITCH)
          RES     5,A
          LD      (SWITCH),A
          POP     AF
          RET
          
;---------------------------------------------
;
; WORK AREA
;
;---------------------------------------------
; --- システムワーク ---
SYSWORK:  EQU     $
RDVDP:    DEFS    2             ; VDPのポートアドレス（ベース）格納用
                                ; (MAINルーチンで BC,(RDVDP+1) として使用)
WORK:     DEFS    3             ; 3D回転演算（TURN）時の一時的な座標置き場
                                ; (X, Y, Z の3バイト分)
POSITION: DEFS    120           ; 変換後の2D座標を格納するテーブル
                                ; (最大で60頂点分、または複数の物体用)
VIJUAL:   DEFB    0             ; 現在表示中のVRAMページ番号（0 または 1）
                                ; (ダブルバッファリングの切り替えに使用)
STACK:    DEFW    0             ; ゲーム内スタックの退避用
SSTACK:   DEFW    0             ; システム（BIOS）スタックの退避用
                                ; (エラー時や中断時の復帰ポイント)
; --- ゲーム・コントロール ---
GAMEWORK: EQU     $
MCOLOR:   DEFB    0             ; 無敵時の自機の色保存用
MCOUNT:   DEFB    0             ; 無敵カウンター
SCOLOR:   DEFB    3,1           ; 地平線描画色、スクロール速度
SWITCH:   DEFB    00001001B     ; ★システム制御フラグ
                                ; (bit0:スケーリング, bit3:ザコ敵描画 ...等のスイッチ)
CONTRT:   DEFW    00            ; コントロールルーチンのアドレス
DEADRT:   DEFW    00            ; プレイヤー死亡（LIFE=0）時のジャンプ先
LIFE:     DEFB    16            ; プレイヤーの耐久力（16段階）
STOCK:    DEFB    DSTOCK        ; 残機
SCORE:    DEFW    00            ; 現在のスコア
HSCORE:   DEFW    00            ; ハイスコア
GAGE:     DEFB    0,0,0,0,0,0   ; 当たり判定ボックス
MASTER:   DEFS    16            ; 自機（マスターオブジェクト）専用のワーク
                                ; (座標、AIポインタ、フラグ、回転角など)
PORIDAT:  DEFS    256           ; ★エネミー・タスク・エリア
                                ; (16バイトのワーク × 最大16個分)
ASCOUNT:  DEFB    0             ; フォントカウンタ
ASCFONT:  DEFW    0             ; フォントアドレス
;--------------------------------------------
;
; MAIN2
;
;--------------------------------------------
TOP2:	  EQU	  $
;
;---- MOJI HYOUJI ----
;
; 文字列表示ルーチン
;
; ※オブジェクトワークの使い方が敵オブジェクトとは異なります
;
; IX+2   カウンター
; IX+3,4 表示モデルデータアドレス
; IX+5,6 MHYOUJアドレス
; IX+7   文字の色
; IX+8   消滅設定時間（寿命）
; IX+9   消灯時間の長さ（ウェイト値）
; IX+10  点灯時間の長さ（ウェイト値）
; IX+11 （0:消灯中 / 1:点灯中）
; IX+12  文字列のX座標
; IX+13  文字列のY座標
; IX+14  未使用？
; IX+15  フラグ
;
; ※(IX+15) フラグの機能
;
; bit0 MULTIルーチンをスキップさせるため常に1
; bit1 x座標2倍拡大表示
; bit2 x座標0.5倍縮小表示
; bit3 y座標2倍拡大表示
; bit4 y座標0.5倍縮小表示
; bit5 点滅表示フラグ
;
;--------------------
MHYOUJ:   BIT     5,(IX+15)     ; 点滅フラグ(bit5)を確認
          JR      Z,HMOJI       ; フラグが0なら点滅させずに表示へ
          ; --- 点滅処理開始 ---
          LD      A,(IX+11)     ; 現在の状態（0:消灯中 / 1:点灯中）をロード
          OR      A             ; 状態をチェック
          JR      NZ,M2ONH      ; 点灯中なら「消去タイマー」へジャンプ
          LD      A,(IX+2)      ; 消灯期間のカウンタをロード
          OR      A             ; 0かどうかチェック
          JR      Z,M2OFFH      ; 0になったら点灯状態へ切り替え
          DEC     (IX+2)        ; カウンタを減らす
          JR      MJIRET        ; 今回は何も表示せずに終了
M2OFFH:   LD      A,(IX+10)     ; 点灯時間の長さ（ウェイト値）をロード
          LD      (IX+2),A      ; カウンタにセット
          LD      A,1           ; 状態を「点灯(1)」に設定
          LD      (IX+11),A     ; ワークに保存
          JR      HMOJI         ; 表示処理へ進む
M2ONH:    LD      A,(IX+2)      ; 点灯期間のカウンタをロード
          DEC     (IX+2)        ; カウンタを減らす
          OR      A             ; 0になったかチェック
          JR      NZ,HMOJI      ; まだ点灯期間内なら表示処理へ
          LD      A,(IX+9)      ; 消灯時間の長さ（ウェイト値）をロード
          LD      (IX+2),A      ; カウンタにセット
          XOR     A             ; 状態を「消灯(0)」に設定
          LD      (IX+11),A     ; ワークに保存
          JR      MJIRET        ; 終了へ
          ; --- 文字列の読み込み ---
HMOJI:    LD      E,(IX+7)      ; 文字の色（パレット番号）を取得
          LD      D,0           ; 
          LD      (LIDAT+4),DE  ; VDP描画用カラーをセット
          LD      H,(IX+4)      ; 表示文字列データのアドレス（上位）
          LD      L,(IX+3)      ; ポインタの下位
MJLOOP:   LD      A,(HL)        ; 文字コード（'A'など）を1つ読み込む
          OR      A             ; 0（終端）かどうかチェック
          JR      Z,MJIRET      ; 0なら全ての文字を表示し終えたので終了
          INC     HL            ; 次のデータ（X座標オフセット）へ
          LD      B,(HL)        ; X相対座標をロード
          INC     HL            ; 次のデータ（Y座標オフセット）へ
          LD      C,(HL)        ; Y相対座標をロード
          INC     HL            ; 次の文字コードへポインタを進める
          CALL    CALMOJ        ; 1文字分の線引き演算を実行
          JR      MJLOOP        ; 文字列が終わるまで繰り返す
          ; --- ルーチン終了判定 ---
MJIRET:   LD      A,(IX+1)      ; 表示されてからの累積時間を確認
          INC     (IX+1)        ; 時間を進める
          CP      (IX+8)        ; 消滅設定時間（寿命）に達したか？
          JP      Z,MULEND      ; 寿命ならオブジェクトを消去
          RET                   ; 戻る
          ;
CALMOJ:   PUSH    HL            ; 文字列ポインタを壊さないよう保存
          CP      41H           ; 'A' (ASCII 41h) より小さいか？
          LD      D,30H         ; 数字（'0'?）用の補正値を仮セット
          JR      C,$+4         ; 'A'未満ならそのまま
          LD      D,41H-10      ; 英字用の補正値に書き換え
          SUB     D             ; インデックス（00h?）に変換
          ADD     A,A           ; アドレス表は2バイト単位なので2倍にする
          LD      HL,MOJIDAT    ; フォントのアドレス・テーブル
          ADD     A,L           ; テーブル内のオフセットを加算
          JR      NC,$+3        ; 桁上げチェック
          INC     H             ; 
          LD      L,A           ; HL = 定義アドレスが格納されている場所
          LD      E,(HL)        ; 文字定義の開始アドレス（低位）を取得
          INC     HL            ; 
          LD      D,(HL)        ; 文字定義の開始アドレス（高位）を取得
          EX      DE,HL         ; HL = 文字を構成する線データの先頭アドレス
          ; --- 描画位置の基準設定 ---
          LD      A,B           ; 文字列内でのXオフセット
          ADD     A,(IX+12)     ; オブジェクト自体の中心X座標を加算
          LD      B,A           ; B = 描画開始基準点X
          LD      A,C           ; 文字列内でのYオフセット
          ADD     A,(IX+13)     ; オブジェクト自体の中心Y座標を加算
          LD      C,A           ; C = 描画開始基準点Y
          ; --- 線データのヘッダ解析 ---
          LD      A,(HL)        ; データの構成要素数を取得
          ADD     A,A           ; 
          ADD     A,(HL)        ; 3倍にする（3バイト1セット管理用）
          INC     HL            ; 
          INC     HL            ; 
          LD      E,A           ; 
          LD      D,0           ; 
          PUSH    HL            ; 
          ADD     HL,DE         ; 実際の座標成分が格納されている場所を計算
          POP     DE            ; 
          DEC     DE            ; ポインタ微調整
          DEC     DE            ; 
          DEC     DE            ; 
          ; --- 文字を形作る線の描画ループ ---
LOOPMJ:   LD      A,(HL)        ; 線の始点インデックスを取得
          ADD     A,A           ; 
          ADD     A,(HL)        ; 3倍にする
          PUSH    BC            ; 基準座標(BC)を保存
          PUSH    DE            ; データポインタを保存
          ADD     A,E           ; 座標データの場所を特定
          JR      NC,$+3        ; 
          INC     D             ; 
          LD      E,A           ; DE = 始点の座標データアドレス
          LD      A,(DE)        ; 相対X座標を取得
          INC     DE            ; 
          ; --- 拡大・縮小処理（始点X） ---
          BIT     1,(IX+15)     ; 拡大ビット確認
          JR      Z,$+4         ; 
          SLA     A             ; 2倍にする
          BIT     2,(IX+15)     ; 縮小ビット確認
          JR      Z,$+4         ; 
          SRA     A             ; 1/2にする
          ADD     A,B           ; 基準座標Bを加算
          LD      B,A           ; B = 最終的な始点X
          LD      A,(DE)        ; 相対Y座標を取得
          ; --- 拡大・縮小処理（始点Y） ---
          BIT     3,(IX+15)     ; 拡大ビット確認
          JR      Z,$+4         ; 
          SLA     A             ; 2倍にする
          BIT     4,(IX+15)     ; 縮小ビット確認
          JR      Z,$+4         ; 
          SRA     A             ; 1/2にする
          ADD     A,C           ; 基準座標Cを加算
          LD      C,A           ; C = 最終的な始点Y
          LD      (LIDAT),BC    ; VDP用データ構造に始点(X,Y)を格納
          POP     DE            ; 保存したポインタを戻す
          POP     BC            ; 基準座標を戻す
          ; --- 終点データの計算 ---
          INC     HL            ; 次のデータ（終点インデックス）へ
          LD      A,(HL)        ; 終点インデックスを取得
          ADD     A,A           ; 始点と同様に3倍計算
          ADD     A,(HL)        ; 
          PUSH    BC            ; 
          PUSH    DE            ; 
          ADD     A,E           ; 終点の座標データアドレス特定
          JR      NC,$+3        ; 
          INC     D             ; 
          LD      E,A           ; DE = 終点の座標データアドレス
          LD      A,(DE)        ; 相対X座標を取得
          INC     DE            ; 
          ; --- 拡大・縮小処理（終点X） ---
          BIT     1,(IX+15)     ; 
          JR      Z,$+4         ; 
          SLA     A             ; 
          BIT     2,(IX+15)     ; 
          JR      Z,$+4         ; 
          SRA     A             ; 
          ADD     A,B           ; 
          LD      B,A           ; B = 最終的な終点X
          LD      A,(DE)        ; 相対Y座標を取得
          ; --- 拡大・縮小処理（終点Y） ---
          BIT     3,(IX+15)     ; 
          JR      Z,$+4         ; 
          SLA     A             ; 
          BIT     4,(IX+15)     ; 
          JR      Z,$+4         ; 
          SRA     A             ; 
          ADD     A,C           ; 
          LD      C,A           ; C = 最終的な終点Y
          LD      (LIDAT+2),BC  ; VDP用データ構造に終点(X,Y)を格納
          POP     DE            ; 
          POP     BC            ; 
          ; --- 実描画 ---
          CALL    LINE          ; ★VDPへLINEコマンドを送信！
          INC     HL            ; 次の線データへ
          LD      A,(HL)        ; まだ線があるかチェック
          DEC     HL            ; 
          OR      A             ; 
          JR      NZ,LOOPMJ     ; 0でなければループ継続
          INC     HL            ; 
          INC     HL            ; 
          LD      A,(HL)        ; 文字全体の終了チェック
          OR      A             ; 
          JR      NZ,LOOPMJ     ; 
          POP     HL            ; 文字列ポインタを復帰
          RET                   ; 戻る
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
; ライフゲージとスコアの表示
;
WRLIFE:   PUSH    AF            ; AFレジスタを保存
          PUSH    HL            ; HLレジスタを保存
          LD      HL,0006H      ; 色コード（6:ダークレッド付近？）をセット
          LD      (LIDAT+4),HL  ; LINE命令のカラー引数に格納
          LD      H,178         ; ゲージ左端のX座標
          LD      L,20          ; ゲージ上端のY座標
          LD      (LIDAT+0),HL  ; 始点(X,Y)としてセット
          LD      L,39          ; 下端のY座標
          LD      (LIDAT+2),HL  ; 終点(X,Y)としてセット
          CALL    LINE          ; 左側の縦線を引く
          LD      H,246         ; ゲージ右端のX座標
          LD      (LIDAT+0),HL  ; 始点(X,Y)としてセット
          LD      L,20          ; 
          LD      (LIDAT+2),HL  ; 
          CALL    LINE          ; 右側の縦線を引く
          LD      H,180         ; 横線の左端
          LD      L,30          ; 中央付近の高さ
          LD      (LIDAT+0),HL  ; 
          LD      H,244         ; 横線の右端
          LD      (LIDAT+2),HL  ; 
          CALL    LINE          ; 中央の水平線を引く（ゲージの土台）
          ;
          LD      A,(LIFE)      ; 現在のライフ値をロード
          RLCA                  ; 2倍にする
          RLCA                  ; さらに2倍（計4倍）にして長さを計算
          ADD     A,180         ; ゲージの開始位置(X=180)を加算
          LD      H,A           ; H = 現在のライフに応じた右端X座標
          LD      L,24          ; ゲージ中身の上端Y
          LD      (LIDAT+0),HL  ; 始点(X,Y)をセット
          LD      L,36          ; ゲージ中身の下端Y
          LD      (LIDAT+2),HL  ; 終点(X,Y)をセット
          LD      HL,0009H      ; 中身の色（9:ライトレッド付近？）
          LD      (LIDAT+4),HL  ; 
          CALL    LINE          ; ライフ残量を示す縦線を引く
          ;
          CALL    STRIGB        ; ジョイスティック・ボタンBの状態をチェック
          JR      NZ,RETSC      ; 押されていなければ表示をスキップ
          LD      HL,(SCORE)    ; 現在のスコアをロード
          LD      IX,SCOREM+15  ; スコア数字を表示する文字列バッファの位置
          CALL    CHTEN         ; 数値を表示用テキスト（ASCII）に変換
          LD      A,(STOCK)     ; 残機（STOCK）をロード
          ADD     A,2FH         ; ASCIIコードの数字（'0'は30H）に変換（1減算済みの補正）
          LD      (SCOREM+42),A ; バッファ内の 'LEFT' の後の数字を書き換え
          LD      IX,MDSCOR     ; スコア表示用オブジェクトの定義をロード
          CALL    MULTI         ; ★ベクタフォントとして画面に描画！
RETSC:    POP     HL            ; HLを復帰
          POP     AF            ; AFを復帰
          RET                   ; 戻る
          ;
SCOREM:   DEFB    'S',20,30,'C',35,30,'O',50,30,'R',65,30,'E',80,30
          DEFB     0,107,30,0,119,30,0,131,30,0,143,30,0,155,30 ; ←ここにスコア数字が入る
          DEFB    'L',20,50,'E',35,50,'F',50,50,'T',65,50,'3',107,50,0 ; 'LEFT'
          ;
MDSCOR:   DEFB     1,0,0        ; オブジェクト有効フラグなど
          DEFW     SCOREM,MHYOUJ; 描画データ（SCOREM）と描画関数（MHYOUJ）へのポインタ
          DEFB     8,1,0,0,0,0,0,0,00010101B ; 拡大率や属性フラグ
;
;---- CHANGE TEN ----
; 
; 10進数に変換するルーチン
;
CHTEN:    PUSH    DE            ; DEレジスタを保存
          LD      DE,10000      ; 万の桁を求めるために10000をセット
          CALL    DOWNGE        ; 10000がいくつあるか計算
          LD      (IX+0),A      ; 結果（ASCII文字）をバッファの1桁目に格納
          LD      DE,1000       ; 千の桁を求めるために1000をセット
          CALL    DOWNGE        ; 1000がいくつあるか計算
          LD      (IX+3),A      ; 結果をバッファの2桁目に格納（※3バイト飛ばしは文字・X・Y構成のため）
          LD      DE,100        ; 百の桁を求めるために100をセット
          CALL    DOWNGE        ; 100がいくつあるか計算
          LD      (IX+6),A      ; 結果をバッファの3桁目に格納
          LD      DE,10         ; 十の桁を求めるために10をセット
          CALL    DOWNGE        ; 10がいくつあるか計算
          LD      (IX+9),A      ; 結果をバッファの4桁目に格納
          LD      DE,1          ; 一の桁を求めるために1をセット
          CALL    DOWNGE        ; 1がいくつあるか計算
          LD      (IX+12),A     ; 結果をバッファの5桁目に格納
          POP     DE            ; DEレジスタを復帰
          RET                   ; 呼び出し元（WRLIFEなど）へ戻る
          ;
DOWNGE:   XOR     A             ; Aレジスタ（カウント用）を0にクリア
          OR      A             ; キャリーフラグをクリア
          SBC     HL,DE         ; HLからDE（桁の重み）を引く
          JR      C,$+5         ; もし引ききれなくなったら（負になったら）ループ脱出
          INC     A             ; 引けた回数を1増やす
          JR      DOWNGE+1      ; 再び引き算（OR Aの次へジャンプしてループ）
          ADD     HL,DE         ; 引きすぎた分を足して元に戻す（余りが出る）
          ADD     A,30H         ; 引けた回数に'0'の文字コード(30H)を足してASCII化
          RET                   ; 1つの桁の計算を終了して戻る
          ;
;--------------------------------------------------
;
;  MAIN3
;
;--------------------------------------------------
;===========================================
; MULTI STAGE SUB ROUTINE
;===========================================
;
; スコア加算　DE = 加算するスコア
;
SCOREUP: 
          PUSH    HL
          LD      HL,(SCORE)      ; 現在のスコアを取得
          ADD     HL,DE           ; 足し算
          JR      NC,$+5          ; オーバーフロー（桁あふれ）してなければスキップ
          LD      HL,65535        ; あふれていたら最大値で固定
          LD      (SCORE),HL      ; スコア保存
          POP     HL
          RET
;
; 残機加算　A = 加算する残機
;
STOCKUP:
          PUSH    BC
          LD      C,A
          LD      A,(STOCK)       ; 残機（ストック）を取得
          ADD     A,C
          CP      10              ; 10機以上か？
          JR      C,$+4           ; 10未満ならスキップ
          LD      A,9             ; 10以上なら最大値9で固定
          LD      (STOCK),A       ; 残機保存
          POP     BC
          RET
;
; LIFEUUP  A = 加算するライフ
; 
LIFEUP:   PUSH    BC
          LD      C,A
          LD      A,(LIFE)      ; 現在のライフをロード
          ADD     A,C           ; ライフを回復
          CP      17            ; 最大値（16）を超えたかチェック
          JR      C,$+4         ; 超えていなければそのまま
          LD      A,16          ; 最大値を16に固定
          LD      (LIFE),A      ; ライフ更新
          POP     BC
          RET
;
; LIFEDOWN A = 減算するライフ
;
LIFEDOWN: PUSH    BC
          LD      C,A
          LD      A,(LIFE)      ; ライフをロード
          SUB     C             ; ライフを減らす
          JR      NC,$+3        ; マイナスにならなければOK
          XOR     A             ; マイナスなら0に固定
          LD      (LIFE),A      ; ライフを保存
          POP     BC
          RET
;
; TRIGER CHECK
;
; Aボタン、またはスペースキーのチェック
;
STRIG:    PUSH    BC            ; レジスタを破壊しないよう保存
          PUSH    DE            ; 
          PUSH    HL            ; 
          PUSH    IX            ; 
          ;
          XOR     A             ; A = 0 (トリガー0：スペースキーまたはジョイスティック1のボタンA)
          LD      IX,GTTRIG     ; BIOSのGTTRIG(00D8H)ルーチンアドレスを指定
          LD      IY,(EXPTBL-1) ; メインスロット（BIOSがあるスロット）の情報をロード
          CALL    CALSLT        ; スロットを切り替えてBIOSルーチンを実行
                                ; 戻り値 A: 00H(オフ) / FFH(オン)
          INC     A             ; AがFFHならINC Aで0(ZフラグON)になる
          JR      Z,M3STRT      ; もしボタンが押されていたら、あとのチェックを飛ばして終了へ
          ;
          LD      IX,GTTRIG     ; (冗長に見えるが、確実に再チェックまたは
          LD      IY,(EXPTBL-1) ; 別の入力系統を想定している可能性あり)
          CALL    CALSLT        ; 再度トリガー状態を確認
          INC     A             ; 
          ;
M3STRT:   POP     IX            ; 保存していたレジスタを全て復帰
          POP     HL            ; 
          POP     DE            ; 
          POP     BC            ; 
          RET                   ; Zフラグ等の状態を持って戻る
;
; Bボタンの入力チェック
;
STRIGB:   PUSH    BC            ; 
          PUSH    DE            ; 
          LD      IY,(0FCC0H)   ; EXPTBL: BIOSのあるスロットを取得
          LD      IX,00D8H      ; GTTRIG: BIOSのトリガーチェックルーチン
          LD      A,3           ; 3 = ジョイスティック2のボタンB（または特定の入力）
          CALL    001CH         ; CALSLT: スロットをまたいでBIOS呼び出し
          INC     A             ; 
          JR      Z,RETSTR      ; 
          LD      A,(0FBE5H+6)  ; キーボード・ジョイスティックのワークエリア参照
          AND     00000100B     ; 特定のビット（ボタン状態）をマスク
RETSTR:   POP     DE            ; 
          POP     BC            ; 
          RET                   ;
;
; STICK CHECK
;
; カーソルキーまたはジョイパッドの十字キーチェック
;
STICK:    PUSH    BC            ; BCレジスタを保存
          PUSH    DE            ; DEレジスタを保存
          PUSH    HL            ; HLレジスタを保存
          PUSH    IX            ; IXレジスタを保存
          ; --- まずはカーソルキー(0)をチェック ---
          XOR     A             ; A = 0 (カーソルキーを指定)
          LD      IX,GTSTCK     ; BIOSのGTSTCK(00D4H)ルーチンアドレスを設定
          LD      IY,(EXPTBL-1) ; BIOSがあるスロット情報をロード
          CALL    CALSLT        ; スロットをまたいでBIOSを実行
          OR      A             ; Aの結果（0:停止, 1-8:方向）をチェック
          JR      NZ,RETSTI     ; 0以外（入力あり）なら、その値を保持して終了へ
          ; --- 入力がなければジョイスティック1(1)をチェック ---
          INC     A             ; A = 1 (ジョイスティック1を指定)
          LD      IX,GTSTCK     ; 再度GTSTCKのアドレスを設定
          LD      IY,(EXPTBL-1) ; 
          CALL    CALSLT        ; スロットをまたいでBIOSを実行
          OR      A             ; Aの結果をチェック（0 or 方向値）
          ; --- レジスタ復帰と終了 ---
RETSTI:   POP     IX            ; 保存していたレジスタを全て復帰
          POP     HL            ; 
          POP     DE            ; 
          POP     BC            ; 
          RET                   ; Aに入力値（方向）を入れた状態で戻る
;
; DEAD ROUTINE
;
; 死亡時に呼ばれるルーチン
;
DEAD:     CALL    CHASHSD       ; 爆発音または爆発エフェクトを呼び出し
          LD      SP,(STACK)    ; スタックポインタをゲーム開始時の状態に復帰
          LD      HL,DEADPT     ; 自機用の「撃墜時専用AIルーチン」のアドレスをロード
          LD      (MASTER+5),HL ; 自機(MASTER)のプログラムポインタを書き換え
          LD      A,(SWITCH)    ; システムスイッチをロード
          RES     4,A           ; bit4をオフにする（ゲームオーバー判定を停止）
          LD      (SWITCH),A    ; スイッチを更新
          BIT     5,A           ; 無敵状態だったらリセットする（念のために）
          CALL    NZ,GOD_RESET  ;
          LD      HL,0          ; 
          LD      (GAGE),HL     ; パワーアップゲージ等をリセット
          LD      A,45          ; 45フレーム分の待ち時間を設定
          CALL    MAIN          ; MAINループを回して爆発中の画面を表示し続ける
          CALL    FADE          ; 画面を暗転（フェードアウト）させる
          LD      A,8           ; 8フレーム分の待ち時間
          CALL    MAIN          ; 暗転状態で少し待機
          LD      A,(STOCK)     ; 残機（ストック）をロード
          DEC     A             ; 1つ減らす
          JP      Z,GMOVER      ; 残機が0になったらゲームオーバールーチンへ
          LD      (STOCK),A     ; 残った機数を保存
          CALL    MSSTR         ; 自機の初期位置・状態を再設定（再スタート準備）
          LD      HL,(CONTRT)   ; コンティニューアドレスをロード
          JP      (HL)          ; アドレスへ復帰
;
; 自機の破壊移動ルーチン
;
DEADPT:   LD      A,(IX+9)      ; Z座標をロード
          ADD     A,6           ; 遠ざかる
          CP      200           ; Zが一定値（200）に達したかチェック
          JR      NC,$+12       ; 達していれば、下の「消滅処理」へスキップ
          LD      (IX+9),A      ; 更新したZ値を保存
          INC     (IX+10)       ; 回転させる
          INC     (IX+10)       ; 
          RET                   ; 
          ; --- 消滅処理 ---
          LD      A,00011000B   ; 特殊なフラグ（描画オフなど）をセット
          LD      (IX+15),A     ; 
          LD      A,(SWITCH)    ; システムスイッチをロード
          AND     11111001B     ; bit1, bit2などをオフにして自機の描画を完全に止める
          LD      (SWITCH),A    ; 
          RET                   ; 戻る
;
; 爆発モデル表示ルーチン 　　IX<-オブジェクトデータ
;
; 主にボスのオブジェクトがコール。自分を消して、自分自身のコピーオブジェクトを
; 爆発フラグを立てて作成する
;
BOMBOBJ:  LD      HL,BOBJPTR
          LD      A,(IX+3)      ; 表示オブジェクトデータ
          LD      (HL),A
          INC     HL
          LD      A,(IX+4)
          LD      (HL),A
          INC     HL
          INC     HL
          INC     HL
          LD      A,(IX+7)      ; X
          LD      (HL),A
          INC     HL
          LD      A,(IX+8)      ; Y
          LD      (HL),A
          INC     HL
          LD      A,(IX+9)      ; Z
          LD      (HL),A
          INC     HL
          LD      A,(IX+10)     ; RX
          LD      (HL),A
          INC     HL
          LD      A,(IX+11)     ; RY
          LD      (HL),A
          INC     HL
          LD      A,(IX+12)     ; RZ
          LD      (HL),A
          INC     HL
          LD      A,(IX+13)     ; RX
          LD      (HL),A
          INC     HL
          LD      A,(IX+14)     ; RX
          LD      (HL),A
          INC     HL
          LD      A,(IX+15)     ; フラグ（拡大表示などをしている場合があるので）
          SET     3,A           ; 当たり判定をしない
          SET     4,A           ; 爆発オブジェクト表示
          LD      (HL),A
          ;          
	      CALL    DSET          ; 表示タスク登録（メッセージ表示用）
BOBJPTR:  DEFW    0,BOMOBJMV      ; 表示データ(STARTM)と描画関数(MHYOUJ)を指定
          DEFB    0,0,0,0,0,0   ; x,y,z,rx,ry,rz
          DEFB    0,0,0         ; 色、属性、フラグ設定
          RET
;
; 爆発オブジェクト移動ルーチン
;
BOMOBJMV:
          LD     A,(IX+1)
          INC    A
          LD     (IX+1),A
          CP     1
          JR     C,BOMBRET
          XOR    A
          LD    (IX+0),A
BOMBRET:  RET
;
; ALL OBJ BREAK
;
; 全敵オブジェクト破壊ルーチン
;
ALLBREAK: PUSH    AF            ; レジスタ退避
          PUSH    BC            ; 
          PUSH    DE            ; 
          PUSH    HL            ; データの開始アドレスを一時保存
          LD      HL,PORIDAT    ; オブジェクトワークエリア(PORIDAT)の先頭をセット
          LD      DE,16         ; 1つあたりのデータサイズ（16バイト）をセット
          LD      B,E           ; 最大16個のスロットをチェックするループカウンタ
BKLOOP:   LD      A,(HL)        ; ワークエリアの先頭バイト（使用フラグ）を読み込む
          OR      A             ; フラグが0（空きスロット）かどうか確認
          CALL    NZ,SETBREAK   ; 破壊データ書き込みコール
          ADD     HL,DE         ; 次のスロットへポインタを進める
          DJNZ    BKLOOP        ; 全スロットチェックループ
          POP     HL
          POP     DE
          POP     BC
          POP     AF
          RET
          
          ; --- 破壊データ書き込み処理 ---
SETBREAK:
          PUSH    AF
          PUSH    IX
          PUSH    HL
          POP     IX            ; HL->IX
          LD      A,(IX+14)      ; 敵属性が3以下なら
          CP      2
          CALL    Z,JRSETBK
          CP      1
          CALL    Z,JRSETBK
          POP     IX
          POP     AF
          RET
          ; 
JRSETBK   
          PUSH    HL
          SET     3,(IX+15)      ; 当たり判定OFF
          SET     4,(IX+15)      ; 爆発表示ON
          LD      HL,BKOBJMV     ; 爆発オブジェクト移動ルーチン
          LD      (IX+1),0
          LD      (IX+5),L
          LD      (IX+6),H
          POP     HL
          RET
;
; 爆発オブジェクト移動ルーチン
;
BKOBJMV:
          LD     A,(IX+1)
          INC    A
          LD     (IX+1),A
          CP     1
          JR     C,BKOBJRET
          XOR    A
          LD    (IX+0),A
BKOBJRET: RET
;
; TUCH ROUTINE ( 0 - 4 )
;
;---- 空アイテム ----
TUCHNONE:
          RET
;---- 無敵アイテム ----
TUCH0:    CALL    ITEMGT        ; 被弾音（または火花エフェクト）を呼び出し
          CALL    MOVESD
          CALL    GOD_SET       ; 無敵セット
          
          LD      A,2
          LD      HL,GODSTR
          CALL    FONT_SET
          
          XOR     A             ; 
          LD      (IX+0),A      ; アイテムオブジェクトを消滅させる
          LD      (IX+2),A      ; 
          RET                   ; 戻る
          
GODSTR:  DEFB    96, 120, 7, "GOD MODE", 0
          ;
;---- 破壊オブジェクトに当たった処理　ダメージ1 ----
TUCH1:    CALL    DAMAGESD        ; 被弾音を鳴らす
          LD      A,(SWITCH)    ; システムスイッチをロード
          BIT     5,A           ; bit5: 無敵フラグ（？）をチェック
          RET     NZ            ; 無敵状態ならダメージ処理をスキップ
          LD      A,1
          CALL    LIFEDOWN
          XOR     A             ; 
          LD      (IX+0),A      ; アイテムオブジェクトを消滅させる
          RET                   ; 戻る
          ;
;---- 破壊不能オブジェクトに当たった処理　ダメージ2 ----
TUCH2:    CALL    DAMAGESD        ; 被弾音を鳴らす
          XOR     A             ; 
          LD      (IX+2),A      ; オブジェクトの特定パラメータをリセット
          LD      A,(MASTER+13) ; 自機の属性（色？）を取得
          LD      (LIDAT+4),A   ; 描画用の色としてセット（被弾フラッシュ用？）
          LD      A,(SWITCH)    ; システムスイッチをロード
          BIT     5,A           ; 無敵チェック
          RET     NZ            ; 無敵なら戻る
          LD      A,2
          CALL    LIFEDOWN      
          RET                   ; 戻る
          ;
;---- 回復アイテム（キュアー）に当たった処理
TUCH3:    CALL    ITEMGT        ; アイテム取得音を鳴らす
          CALL    MOVESD        ; 移動音（または取得演出）を呼び出し
          LD      A,4           ; 
          CALL    LIFEUP        ;

          LD      A,2
          LD      HL,CURSTR
          CALL    FONT_SET
          
          XOR     A             ; 
          LD      (IX+0),A      ; アイテムオブジェクトを消滅させる
          LD      (IX+2),A      ; 
          RET                   ; 戻る
          ;
CURSTR:  DEFB    100, 120, 9, "LIFE UP", 0
          
;---- スピードアップアイテムに当たった処理
TUCH4:    CALL    ITEMGT        ; アイテム取得音を鳴らす
          CALL    MOVESD        ; 
          LD      A,(SWITCH)    ; システムスイッチをロード
          XOR     00000100B     ; bit2を反転（スピードアップフラグを反転）
          LD      (SWITCH),A    ; スイッチを更新
          
          LD      HL,TB_STR1
          BIT     2,A
          JR      Z,JR_TBSTR
          LD      HL,TB_STR2
         
JR_TBSTR: 
          LD      A,2
          CALL    FONT_SET
          XOR     A             ; 
          LD      (IX+0),A      ; アイテムオブジェクトを消滅させる
          LD      (IX+2),A      ; 
          RET                   ; 戻る
          ;

TB_STR1:  DEFB    92, 120, 13, "TURBO OFF", 0          
TB_STR2:  DEFB    96, 120, 13, "TURBO ON", 0        
;
; MASTER START ROUTINE
;
; 自機のスタート演出ルーチン
;
MSSTR:    LD      HL,MSSTDT     ; 自機の初期状態データ（16バイト）のアドレス
          LD      DE,MASTER     ; 自機のメインワークエリア
          LD      BC,16         ; 転送サイズ
          LDIR                  ; 初期データをワークへ一括コピー
          LD      A,16          ; 
          LD      (LIFE),A      ; ライフを最大値(16)に回復
          LD      A,(SWITCH)    ; システムスイッチをロード
          OR      00010010B     ; bit1(自機描画), bit4(死亡判定)をONにする
          LD      (SWITCH),A    ; スイッチを更新
          CALL    CLSPRI        ; オブジェクトワークエリア全消去
          ; --- 「GO AHEAD」メッセージのセット ---
          CALL    DSET          ; 表示タスク登録（メッセージ表示用）
          DEFW    STARTM,MHYOUJ ; 表示データ(STARTM)と描画関数(MHYOUJ)を指定
          DEFB    7,24,1,1,0,40 ; 色、寿命、拡大率などのパラメータ
          DEFB    0,0,00110101B ; フラグ設定
          CALL    UNFADE        ; 暗転していた画面を徐々に明るくする
          RET                   ; メインへ戻る
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
STARPT:   LD      A,(IX+9)      ; 自機のZ座標（または距離）をロード
          SUB     8             ; 値を減らす（奥から手前に近づく）
          CP      16            ; 所定の位置（16）まで来たかチェック
          JR      C,$+6         ; 到達していれば、次の「操作開始」処理へ
          LD      (IX+9),A      ; 到達していなければ、更新したZ座標を保存
          RET                   ; 1フレーム終了
          ; --- 操作開始（演出終了） ---
          LD      HL,KEY        ; 通常時の操作ルーチン（キー入力受付）のアドレス
          LD      (IX+5),L      ; 自機のAIポインタを書き換える（上位・下位）
          LD      (IX+6),H      ; これにより次フレームからプレイヤーが操縦可能に！
          RET                   ; 戻る
;
; TURBO ROUTINE
;
; ターボアイテム作成ルーチン
;
TURBO:    LD      A,0           ; カウンタ（この'0'の部分が下のINC Aで書き換わる）
          INC     A             ; カウンタを増やす
          LD      (TURBO+1),A   ; ★自己書き換え：INCした値を上の'LD A,n'のnに書き戻す
          AND     15            ; 下位4ビットをチェック（16フレームに1回を判定）
          RET     NZ            ; 0でなければ（16の倍数フレーム以外）何もしない
          ; --- 出現X座標の決定 ---
          CALL    RND           ; 乱数を取得
          CP      175           ; 画面端に寄りすぎないよう制限
          JR      NC,$-5        ; 200以上なら乱数をやり直し
          ADD     A,40          ; 座標をオフセット（画面内に収める）
          LD      (TURBRD+4),A  ; 生成データ(TURBRD)のX座標を書き換え
          ; --- 出現Y座標の決定 ---
          CALL    RND           ; 乱数を取得
          CP      175           ; Y座標の範囲制限
          JR      NC,$-5        ; 範囲外ならやり直し
          ADD     A,40          ; 座標をオフセット
          LD      (TURBRD+5),A  ; 生成データ(TURBRD)のY座標を書き換え
          ; --- オブジェクト登録 ---
          CALL    DSET          ; タスクエリアへ新しいオブジェクトを登録
TURBRD:   DEFW    TURBPT,TURBMV ; 形状データ(TURBPT)と移動関数(TURBMV)のポインタ
          DEFB    0,0,255,0,0,0 ; パラメータ群（Z座標など）
          DEFB    13,4,00000000B; 色（13:マゼンタ系？）やフラグ
          RET                   ; 終了
          ;
TURBMV:   CALL    MOVE          ; 座標移動ルーチンを呼び出し
          DEFB    0,0,-16,0,3,0 ; 相対移動量（Z方向に-16、高速で手前に迫る！）
          RET
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
; ライフ回復アイテム作成ルーチン
;
CURE:     LD      A,0           ; カウンタ（下のINCで書き換わる）
          INC     A             ; カウンタを増やす
          LD      (CURE+1),A    ; ★自己書き換え：値を保存
          AND     31            ; 32フレームに1回かどうか判定
          RET     NZ            ; 0以外なら生成せずに終了
          ; --- 出現X座標の決定 ---
          CALL    RND           ; 乱数取得
          CP      205           ; 範囲チェック
          JR      NC,$-5        ; 範囲外ならやり直し
          ADD     A,25          ; 座標オフセット
          LD      (CURERD+4),A  ; 生成データ(CURERD)のX座標を書き換え
          ; --- 出現Y座標の決定 ---
          CALL    RND           ; 乱数取得
          CP      190           ; 範囲チェック
          JR      NC,$-5        ; 
          ADD     A,33          ; 座標オフセット
          LD      (CURERD+5),A  ; 生成データ(CURERD)のY座標を書き換え
          ; --- アイテム登録 ---
          CALL    DSET          ; オブジェクトをタスクに登録
CURERD:   DEFW    CURPD1,CUREMV ; 形状1(CURPD1)と移動AI(CUREMV)を指定
          DEFB    0,0,255,0,0,0 ; Z座標など(奥の255からスタート)
          DEFB    9,3,00000000B ; 色(9:ライトレッド/回復っぽい色)
          RET
          ;
CUREMV:   LD      A,(IX+1)      ; オブジェクトの経過フレーム数をロード
          INC     (IX+1)        ; フレームを進める
          LD      HL,CURPD1     ; 基本形状1を仮セット
          AND     2             ; ビット1をチェック（数フレームごとに切り替え）
          JR      NZ,$+5        ; ビットが立っていれば形状1のまま
          LD      HL,CURPD2     ; ビットが立っていなければ形状2に差し替え
          ; --- 形状データのポインタをリアルタイム更新 ---
          LD      (IX+4),H      ; ワークエリア内の形状ポインタ(上位)を書き換え
          LD      (IX+3),L      ; 形状ポインタ(下位)を書き換え
          ; --- 移動処理 ---
          LD      A,(IX+9)      ; 現在のZ座標をロード
          SUB     24            ; 手前に 20 移動
          LD      (IX+9),A      ; 更新
          RET                   ; 終了
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
; 得点アイテム(テクノイト）作成ルーチン
;
TECHNO:   CALL    RND           ; 乱数でX座標を決定
          CP      200           ; 
          JR      NC,$-5        ; 
          ADD     A,28          ; 
          LD      (TECHRD+4),A  ; X座標セット
          CALL    RND           ; 乱数でY座標を決定
          CP      200           ; 
          JR      NC,$-5        ; 
          ADD     A,28          ; 
          LD      (TECHRD+5),A  ; Y座標セット
          ; --- ここから色の抽選 ---
          CALL    RND           ; 乱数取得
          LD      C,8           ; 基本色を 8 (400点) に設定
          AND     15            ; 1/16の確率をチェック
          JR      Z,M3CJ4       ; 当たりなら 8 のまま確定
          LD      C,7           ; 次の候補を 7 (200点) に設定
          CP      10            ; 
          JR      NC,M3CJ4      ; 
          LD      C,3           ; 次の候補を 3 (100点) に設定
          CP      5             ; 
          JR      NC,M3CJ4      ; 
          LD      C,10          ; どれにも漏れたら 10 (50点)
M3CJ4:    LD      A,C           ; 決定した色コードをAへ
          LD      (TECHRD+10),A ; オブジェクトの色(IX+13相当)として保存
          CALL    DSET          ; オブジェクト登録
          ; --- 登録データ ---
TECHRD:   DEFW    TECHPT,TECHMV ; 
          DEFB    0,0,255,0,0,0 ; 
          DEFB    0,5,00000000B ; ※ここの10バイト目が色に書き換わる
          RET
          ;
TECHPT:   DEFB    6,0           ; 頂点数: 6個
          ; --- 頂点座標 (X, Y, Z) ---
          DEFB    -23,-23,  3   ; 頂点1（前面）
          DEFB      0, 18,  3   ; 頂点2
          DEFB     18,  0,  3   ; 頂点3
          DEFB    -23,-23, -3   ; 頂点4（背面）
          DEFB      0, 18, -3   ; 頂点5
          DEFB     18,  0, -3   ; 頂点6
          ; --- コネクションリスト ---
          DEFB    1,2,3,1,0     ; 前面の三角形
          DEFB    4,5,6,4,0     ; 背面の三角形
          DEFB    1,4,0,2,5,0,3,6,0,0 ; 前後を結ぶ柱（厚みを出す）

TECHMV:   CALL    MOVE          ; 移動ルーチン呼び出し
          DEFB    0,0,-28,0,0,3 ; Z方向に -28
          RET
;
; テクノイト専用当たり処理ルーチン
;
TUCH5:    CALL    ITEMGT        ; 取得音
          CALL    MOVESD        ; 演出音
          LD      A,(IX+13)     ; このアイテムの色を取得
          LD      DE,400        ; 色が 8 なら 400点
          LD      HL,SCSTR_400
          CP      8             ; 
          JR      Z,M3TJ5       ; 
          LD      DE,200        ; 色が 7 なら 200点
          LD      HL,SCSTR_200
          CP      7             ; 
          JR      Z,M3TJ5       ; 
          LD      DE,100        ; 色が 3 なら 100点
          LD      HL,SCSTR_100
          CP      3             ; 
          JR      Z,M3TJ5       ; 
          LD      DE,50         ; それ以外（10）なら 50点
          LD      HL,SCSTR_50
M3TJ5:    CALL    SCOREUP       ; スコア加算

          PUSH    IY
          PUSH    HL
          POP     IY
          LD      A,(IX+13)
          LD      (IY+2),A    
          LD      A,2
          CALL    FONT_SET
          
          XOR     A
          LD      (IX+0),A      ; アイテム消去
          LD      (IX+2),A      ; 
          POP     IY
          RET                   ;
          ;
SCSTR_50:  DEFB    108, 120, 0, " 50PT", 0
SCSTR_100: DEFB    108, 120, 0, "100PT", 0
SCSTR_200: DEFB    108, 120, 0, "200PT", 0
SCSTR_400: DEFB    108, 120, 0, "400PT", 0
;
; MINING PARTY ROUTINE
;
; 救助を待つ人間＆キャンプの生成ルーチン
;
PARTY:    CALL    RND           ; 乱数取得
          CP      224           ; X座標の範囲チェック
          JR      NC,$-5        ; 
          ADD     A,12          ; 
          LD      (PARRD+4),A   ; 出現X座標をセット
          CALL    RND           ; もう一度乱数取得
          AND     3             ; 確率1/4をチェック
          LD      HL,PARPD1     ; パターン1（静止体）を仮セット
          LD      DE,PARMV      ; 移動ルーチン1を仮セット
          LD      C,255         ; Y座標を255に設定
          JR      Z,PARJP1      ; 1/4の確率に当たればパターン1で確定
          LD      HL,PARPD2     ; それ以外ならパターン2（アニメーション体）
          LD      DE,PARMV2     ; 移動ルーチン2（アニメ変更あり）
          LD      C,253         ; Y座標を253に設定
PARJP1:   LD      (PARRD+0),HL  ; 生成データ(PARRD)の形状ポインタを書き換え
          LD      (PARRD+2),DE  ; 生成データの移動AIポインタを書き換え
          LD      A,C           ; 
          LD      (PARRD+5),A   ; 生成データのY座標を書き換え
          CALL    DSET          ; オブジェクトをタスクに登録
PARRD:    DEFW    PARPD1,PARMV  ; （ここが上の処理でリアルタイムに書き換わる）
          DEFB    0,0,255,0,0,0 ; Z座標：奥(255)からスタート
          DEFB    15,6,00000000B; 
          RET                   ;
          ; --- パターン1：単純移動 ---
PARMV:    LD      A,(IX+9)      ; Z座標をロード
          ADD     A,-16         ; 手前に高速移動
          JP      NC,MULEND     ; 手前を通り過ぎたらオブジェクト消去
          LD      (IX+9),A      ; 座標更新
          RET                   ; 
          ; --- パターン2：形状切り替え＋移動 ---
PARMV2:   LD      A,(IX+1)      ; 経過フレーム数をロード
          INC     (IX+1)        ; 
          LD      HL,PARPD2     ; 形状Aを仮セット
          AND     2             ; アニメーション速度調整
          JR      Z,PARJP2      ; 
          LD      HL,PARPD3     ; 形状Bに切り替え
PARJP2:   LD      (IX+4),H      ; 現在のオブジェクトの形状ポインタを書き換え
          LD      (IX+3),L      ; 
          LD      A,(IX+9)      ; 
          ADD     A,-16         ; 手前に移動
          JP      NC,MULEND     ; 消去判定
          LD      (IX+9),A      ; 
          RET                   ;
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
PARPD2:   DEFB    9,0
          DEFB      0,-30,  0
          DEFB      0,-25,  0
          DEFB     10,-20,  0
          DEFB    -10,-35,  0
          DEFB      0,-40,  0
          DEFB     -5,-30,  0
          DEFB      0,-15,  0
          DEFB      5,  0,  0
          DEFB     -5,  0,  0
          DEFB    1,2,3,0,2,4,5,6,0,2,7,8,0,7,9,0,0
          ;
PARPD3:   DEFB    9,0
		  DEFB      0,-30,  0
          DEFB      0,-25,  0
          DEFB     10,-35,  0
          DEFB    -10,-20,  0
          DEFB    -10,-30,  0
          DEFB     -5,-25,  0
          DEFB      0,-15,  0
          DEFB      5,  0,  0
          DEFB     -5,  0,  0
          DEFB    1,2,3,0,2,4,5,6,0,2,7,8,0,7,9,0,0  
;
; 人間＆キャンプ用の当たりルーチン
;
TUCH6:    CALL    ITEMGT        ; アイテム取得音
          CALL    MOVESD        ; 演出音
          LD      A,(IX+8)      ; オブジェクトのY座標を確認
          LD      HL,SCSTR_250
          LD      DE,250        ; 基本は250点
          CP      253           ; Y座標が253（パターン2）なら
          JR      Z,SCCALC      ; ジャンプ 
          LD      HL,SCSTR_500
          LD      DE,500        ; 違うならキャンプだから500点にアップ！
SCCALC:   CALL    SCOREUP       ; スコア加算
          
          PUSH    IY
          PUSH    HL
          POP     IY
          LD      A,(IX+13)
          LD      (IY+2),A
          
          LD      A,2
          CALL    FONT_SET
          
          XOR     A             ; 
          LD      (IX+0),A      ; オブジェクト消去
          LD      (IX+2),A      ; 
          POP     IY
          RET                   

SCSTR_250: DEFB   108, 120, 0, "250PT", 0
SCSTR_500: DEFB   108, 120, 0, "500PT", 0
;
; GOD_MODE ITEM ROUTINE
;
; 無敵アイテム作成ルーチン
;
GOD_ITEM: LD      A,0           ; カウンタ（下のINCで書き換わる）
          INC     A             ; カウンタを増やす
          LD      (GOD_ITEM+1),A; ★自己書き換え：値を保存
          AND     63            ; 64フレームに1回かどうか判定
          ADD     A,24          ; ずれを作る
          CP      63
          RET     NZ            ; 0以外なら生成せずに終了
          ; --- 出現X座標の決定 ---
          CALL    RND           ; 乱数取得
          CP      180           ; 範囲チェック
          JR      NC,$-5        ; 範囲外ならやり直し
          ADD     A,35          ; 座標オフセット
          LD      (GODRD+4),A   ; 生成データ(GODRD)のX座標を書き換え
          ; --- 出現Y座標の決定 ---
          CALL    RND           ; 乱数取得
          CP      180           ; 範囲チェック
          JR      NC,$-5        ; 
          ADD     A,35          ; 座標オフセット
          LD      (GODRD+5),A   ; 生成データ(GODRD)のY座標を書き換え
          ; --- アイテム登録 ---
          CALL    DSET           ; オブジェクトをタスクに登録
GODRD:    DEFW    GODPD,GODMV   ; 形状1(GODPD1)と移動AI(GODMV)を指定
          DEFB    0,0,255,0,0,0  ; Z座標など(奥の255からスタート)
          DEFB    7,0,00000000B ; 色(9:ライトレッド/回復っぽい色),属性0,フラグ
          RET
          ;
GODMV:    LD      A,(IX+1)      ; オブジェクトの経過フレーム数をロード
          INC     (IX+1)        ; フレームを進める
          LD      A,7           ; 黄色を仮セット
          BIT     1,(IX+1)      ; ビット1をチェック（数フレームごとに切り替え）
          JR      NZ,$+4        ; ビットが立ってたら黄色で
          LD      A,4           ; ビットが立っていなければ薄い黄色へ
          LD      (IX+13),A     ; ワークエリア内の色を書き換え
          CALL    MOVE          ; 移動ルーチン呼び出し
          DEFB    0,0,-20,1,0,4 ; Z方向に -20
          RET                   ; 終了
          ;
GODPD     DEFB    5,0
          DEFB    0,  30,   0   ; 頂点1 (上)
          DEFB   29,   9,   0   ; 頂点2 (右上)
          DEFB   18, -24,   0   ; 頂点3 (右下)
          DEFB  -18, -24,   0   ; 頂点4 (左下)
          DEFB  -29,   9,   0   ; 頂点5 (左上)
          DEFB  1, 2, 3, 4, 5, 1,0
          DEFB  3, 5, 2, 4, 1,3, 0,0
            
;
; ALL BOMB ROUTINE
;
; 全破壊アイテム作成ルーチン
;
ALL_BOMB: LD      A,0           ; カウンタ（この'0'の部分が下のINC Aで書き換わる）
          INC     A             ; カウンタを増やす
          LD      (ALL_BOMB+1),A   ; ★自己書き換え：INCした値を上の'LD A,n'のnに書き戻す
          AND     63            ; 下位4ビットをチェック（64フレームに1回を判定）
          ADD     A,48
          CP      63
          RET     NZ            ; 0でなければ何もしない
          ; --- 出現X座標の決定 ---
          CALL    RND           ; 乱数を取得
          CP      180           ; 画面端に寄りすぎないよう制限
          JR      NC,$-5        ; 200以上なら乱数をやり直し
          ADD     A,35          ; 座標をオフセット（画面内に収める）
          LD      (BOMBRD+4),A  ; 生成データ(BOMBRD)のX座標を書き換え
          ; --- 出現Y座標の決定 ---
          CALL    RND           ; 乱数を取得
          CP      180           ; Y座標の範囲制限
          JR      NC,$-5        ; 範囲外ならやり直し
          ADD     A,35          ; 座標をオフセット
          LD      (BOMBRD+5),A  ; 生成データ(BOMBRD)のY座標を書き換え
          ; --- オブジェクト登録 ---
          CALL    DSET          ; タスクエリアへ新しいオブジェクトを登録
BOMBRD:   DEFW    BOMBPT,BOMBMV ; 形状データ(BOMBPT)と移動関数(BOMBMV)のポインタ
          DEFB    0,0,255,0,0,0 ; パラメータ群（Z座標など）
          DEFB    6,7,00000000B; 色、属性やフラグ
          RET                   ; 終了
          ;
BOMBMV:   LD      A,(IX+1)      ; オブジェクトの経過フレーム数をロード
          INC     (IX+1)        ; フレームを進める
          LD      A,3;6           ; 黄色を仮セット
          BIT     1,(IX+1)      ; ビット1をチェック（数フレームごとに切り替え）
          JR      NZ,$+4        ; ビットが立ってたら黄色で
          LD      A,12;9           ; ビットが立っていなければ薄い黄色へ
          LD      (IX+13),A     ; ワークエリア内の色を書き換え
          CALL    MOVE          ; 座標移動ルーチンを呼び出し
          DEFB    0,0,-24,2,2,0 ; 相対移動量（Z方向に-24、高速で手前に迫る！）
          RET
          ;
BOMBPT:   
          DEFB  14,0
          DEFB  -10, -10, -10   ; 頂点1 (手前左下)
          DEFB   10, -10, -10   ; 頂点2 (手前右下)
          DEFB   10,  10, -10   ; 頂点3 (手前右上)
          DEFB  -10,  10, -10   ; 頂点4 (手前左上)
          DEFB  -10, -10,  10   ; 頂点5 (奥左下)
          DEFB   10, -10,  10   ; 頂点6 (奥右下)
          DEFB   10,  10,  10   ; 頂点7 (奥右上)
          DEFB  -10,  10,  10   ; 頂点8 (奥左上)
          DEFB    0,   0, -30   ; 頂点9  (手前・前)
          DEFB    0,   0,  30   ; 頂点10 (奥・後)
          DEFB    0, -30,   0   ; 頂点11 (下)
          DEFB    0,  30,   0   ; 頂点12 (上)
          DEFB  -30,   0,   0   ; 頂点13 (左)
          DEFB   30,   0,   0   ; 頂点14 (右)
          DEFB  2, 9, 1, 13, 4, 9, 3, 14, 2, 11, 1, 0
          DEFB  6, 10, 5, 13, 8, 10, 7, 14, 6, 11, 5, 0
          DEFB  4, 12, 3, 0
          DEFB  8, 12, 7, 0, 0
;
; 全破壊アイテム用当たり処理
;
TUCH7:
          CALL    VOLCANO       ; サウンドコール
          CALL    MOVESD
          LD      A,(SWITCH)    ; 全破壊フラグを立てる
          SET     7,A
          LD      (SWITCH),A
       ;   CALL    ALLBREAK      ; 全オブジェクト破壊
          XOR     A
          LD      (IX+0),A      ; オブジェクト消去
          LD      (IX+2),A      
          LD      HL,KEY        ; STAGE3の吸い込み敵が書き替えた場合があるから
          LD      (MASTER+5),HL ; 念のために自機の移動ルーチンを戻す
          ;
          LD      A,2
          LD      HL,BOMBSTR
          CALL    FONT_SET
          RET                   
          ;         
BOMBSTR:  DEFB    104,120, 3, "BOMB!!", 0
;
; RANDOM ROUTINE
;
; 乱数生成ルーチン
;
RND:      PUSH    BC            ; BCレジスタを破壊しないよう保存
          LD      BC,0          ; ★自己書き換え対象：ここには「前回の乱数値」が蓄積される
          LD      A,R           ; Z80のRレジスタ（リフレッシュレジスタ）の値をロード
                                ; ※Rレジスタはメモリのリフレッシュ用に常に高速にカウントアップしている
          ADD     A,C           ; 前回の乱数(C)を今のRレジスタに加算
          ADD     A,B           ; さらに前回の乱数(B)も加算して混ぜ合わせる
          LD      C,B           ; Bの値をCにスライド（フィボナッチ的な混合）
          LD      B,A           ; 新しく計算されたA（乱数）をBに保存
          LD      (RND+2),BC    ; ★自己書き換え：次回の計算のため、BCの値を上の「LD BC,0」の0の部分に書き込む
          POP     BC            ; BCレジスタを復帰
          RET                   ; Aレジスタに乱数が入った状態で戻る
;
; HOME POSITION RETURN
;
; 自動で自機をホームポジションに戻すルーチン
;    ZONE3の扇風機状の物体でも使用する
;
HOME:     LD      A,3           ; ステータス「3」をセット（X軸調整中）
          LD      (IX+1),A      ; 
          LD      A,(IX+7)      ; 現在のX座標をロード
          CP      128           ; 中心（128）にあるか比較
          JR      Z,YPOS        ; ぴったりなら次のY軸チェックへ
          JR      C,M3HJ1       ; 128より小さければ右へ移動（加算）へ
          SUB     16            ; 128より大きいので左へ16ドット寄せる
          LD      (IX+7),A      ; X座標を更新
          INC     (IX+10)       ; 帰還中の演出用（回転角などを増やす）
          RET                   ; 1フレーム終了
M3HJ1:    ADD     A,16          ; 128より小さいので右へ16ドット寄せる
          LD      (IX+7),A      ; 
          DEC     (IX+10)       ; 帰還中の演出用（回転角を減らす）
          RET                   ;
          ;
YPOS:     LD      A,2           ; ステータス「2」をセット（Y軸調整中）
          LD      (IX+1),A      ; 
          LD      A,(IX+8)      ; 現在のY座標をロード
          CP      128           ; 中心（128）にあるか比較
          JR      Z,ZPOS        ; ぴったりなら次のZ軸チェックへ
          JR      C,M3HJ2       ; 128より小さければ下へ移動へ
          SUB     4             ; 128より大きいので上へ4ドット寄せる
          LD      (IX+8),A      ; Y座標を更新
          RET                   ; 
M3HJ2:    ADD     A,4           ; 128より小さいので下へ4ドット寄せる
          LD      (IX+8),A      ; 
          RET                   ;
          ;
ZPOS:     LD      A,1           ; ステータス「1」をセット（Z軸調整中）
          LD      (IX+1),A      ; 
          LD      A,(IX+9)      ; 現在のZ座標（距離）をロード
          CP      16            ; 前方の定位置（16）にあるか比較
          JR      Z,M3HJ3       ; ぴったりなら完了へ
          SUB     4             ; まだ遠くにいるなら手前へ4近づける
          LD      (IX+9),A      ; Z座標を更新
          RET                   ; 
          ; --- 全ての軸がホームに到達 ---
M3HJ3:    XOR     A             ; ステータスを「0」にリセット
          LD      (IX+1),A      ; 帰還完了フラグ
          RET                   ;
;------------------------------------------------
;
; SOUND 
;
;------------------------------------------------
;
;サウンドオールOFF
;
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
;
; エンジン音
;
MOVESD:		CALL	SOUND
			DEFB	0,28H
            DEFB	1,00H
            DEFB	6,1FH
            DEFB	7,80H
            DEFB	8,6
            DEFB	0FFH
            RET
;
; ダメージ音
;
DAMAGESD:	CALL	SOUND
			DEFB	2,14H
            DEFB	3,01H
            DEFB	6,1FH
            DEFB	7,80H
            DEFB	9,10H
            DEFB	12,20H
            DEFB	13,0H
            DEFB 	0FFH
            RET
;
; 自機の破壊音
;
CHASHSD:    CALL	SOUND
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
            ;
;
; ショット音
;
SHOT:       CALL    SOUND
            DEFB    7, 0B6H     ; チャンネルAのみ音を出す（ミキサー設定）
            DEFB    8, 10H      ; チャンネルAをエンベロープ指定に
            DEFB    0, 20H      ; 音程（低め：周期長め）
            DEFB    1, 00H      ; 音程
            DEFB    11, 00H     ; エンベロープ周期（速め）
            DEFB    12, 05H     ; エンベロープ周期
            DEFB    13, 09H     ; 減衰パターン（一回切り下げ）
            DEFB    0FFH
            RET
;
; アイテムゲット
;
GET_ITEM:   CALL    SOUND
            DEFB    7, 0B6H     ; ミキサー
            DEFB    8, 0FH      ; 音量最大
            DEFB    0, 40H      ; 高い音
            DEFB    1, 00H
            DEFB    13, 00H     ; エンベロープをリセット
            DEFB    0FFH
            RET
;
; 敵爆発
;
ENEMY_EXP:  CALL    SOUND
            DEFB    7, 036H     ; チャンネルAにノイズを混合
            DEFB    8, 10H      ; エンベロープ使用
            DEFB    6, 10H      ; ノイズ周波数（少し高め）
            DEFB    11, 00H     ; 
            DEFB    12, 10H     ; 
            DEFB    13, 00H     ; 減衰
            DEFB    0FFH
            RET
;
; 火山の爆発音（地響きを伴う重低音）
;
VOLCANO:    CALL    SOUND
            DEFB    7,  0B7H    ; チャンネルAをノイズのみに設定(10110111B)
            DEFB    8,  10H     ; チャンネルAの音量をエンベロープ指定
            DEFB    6,  1FH     ; ノイズ周波数：00?1FH (1FHが最も低く太い音)
            DEFB    11, 00H     ; エンベロープ周期 L（ゆっくり減衰）
            DEFB    12, 40H     ; エンベロープ周期 H（大きな値ほど長く響く）
            DEFB    13, 00H     ; 減衰パターン（一回切り下げ：＼）
            DEFB    0FFH
            RET
;
; 火山の爆発音2チャンネル版
;
VOLCANOV:
            CALL    SOUND
            DEFB    7,  0B0H    ; チャンネルA, B, Cすべてノイズ
            DEFB    8,  10H     ; A: エンベロープ
            DEFB    9,  10H     ; B: エンベロープ
            DEFB    6,  1FH     ; 最低音ノイズ
            DEFB    11, 00H
            DEFB    12, 60H     ; 長めに響かせる
            DEFB    13, 00H
            DEFB    0FFH
            RET
;
; サウンドレジスタセットルーチン
;
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
;
; アイテムゲット音ORセレクトサウンド
;            
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
            
;---------------------------------
;
; 未使用サウンドルーチン
;
;---------------------------------
SDWAIT:     PUSH BC
    		LD   BC,6000
DLOOP:
    		DEC  BC
    		LD   A,B
    		OR   C
    		JR   NZ,DLOOP
    		POP  BC
    		RET
            ;
DAMAGESD2:	CALL	SOUND
            DEFB	7,0B7H
            DEFB	6,7H
            DEFB	8,10H
            DEFB	11,0A8H
            DEFB	12,0DH
            DEFB	13,0H
            DEFB	0FFH
            CALL    SDWAIT
            RET
            ;
WAVE:       CALL    SOUND
            DEFB    7,0B7H
            DEFB    6,7H
            DEFB    8,10H
            DEFB    11,7AH
            DEFB    12,0DAH
            DEFB    13,0EH
            DEFB    0FFH
            RET
            ;
SOUND1:     CALL    SOUND
            DEFB    1,0E0H  ; チャンネルAの周波数下位バイト（音程）
            DEFB    2,00H   ; チャンネルAの周波数上位バイト
            DEFB    8,18H   ; エンベロープパターン（急速に減衰）
            DEFB    13,0FH  ; 音量を最大に
            DEFB    0FFH
            RET
            ;
SOUND2:     CALL    SOUND
            DEFB    7,0B7H  ; ノイズチャンネル設定（白ノイズ）
            DEFB    6,01H   ; ノイズ周波数（低い音から開始）
            DEFB    8,10H   ; エンベロープパターン（徐々に減衰）
            DEFB    13,0FH  ; 音量を最大に
            DEFB    0FFH
            RET
            ;
SOUND3:     CALL    SOUND
            DEFB    1,080H  ; チャンネルAの周波数下位バイト（中音）
            DEFB    2,00H   ; チャンネルAの周波数上位バイト
            DEFB    8,08H   ; エンベロープパターン（定常音）
            DEFB    13,0AH  ; 音量を中程度に
            DEFB    0FFH
            RET
            ;
SOUND4:     CALL    SOUND
            DEFB    1,07AH  ; チャンネルAの周波数下位バイト（高音）
            DEFB    2,00H   ; チャンネルAの周波数上位バイト
            DEFB    8,10H   ; エンベロープパターン（急速に減衰）
            DEFB    13,0EH  ; 音量を少し下げる
            DEFB    0FFH
            RET
            ;
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
            ;
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
            
;---------------------------------------------------------------------
;
; MSX2 SCREEN5 256文字展開 & VDPコマンド表示
;
;---------------------------------------------------------------------
        
VDP_REG  EQU    099H
VDP_DATA EQU    098H
VDP_VCM  EQU    09BH            ; VDPコマンドレジスタ用ポート (重要)
CSLOT    EQU    0F91FH
CGPNT    EQU    0F920H

;==============================================================================
; PRINT_STR - 文字列描画メイン
;==============================================================================
PRINT_STR:
        LD      A, (HL)
        INC     HL
        LD      (CUR_X), A
        LD      A, (HL)
        INC     HL
        LD      (CUR_Y), A
        LD      A, (HL)
        INC     HL
        LD      (CUR_CLR), A
STR_LP:
        LD      A, (HL)
        OR      A
        RET     Z
        PUSH    HL
        LD      (CUR_CHR), A
        CALL    DRAW_CHAR
        ; Xを8ドット進める
        LD      A, (CUR_X)
        ADD     A, 8
        LD      (CUR_X), A
        POP     HL
        INC     HL
        JR      STR_LP

;==============================================================================
; PRINT_STR_FAST - 高速文字列描画メイン
;==============================================================================
PRINT_STR_FAST:
        LD      A, (HL)
        INC     HL
        LD      (CUR_X), A
        LD      A, (HL)
        INC     HL
        LD      (CUR_Y), A
        LD      A, (HL)
        INC     HL
        LD      (CUR_CLR), A
STR_LPF:
        LD      A, (HL)
        OR      A
        RET     Z
        PUSH    HL
        LD      (CUR_CHR), A
        CALL    DRAW_CHAR_FAST
        ; Xを8ドット進める
        LD      A, (CUR_X)
        ADD     A, 8
        LD      (CUR_X), A
        POP     HL
        INC     HL
        JR      STR_LPF
;==============================================================================
; DRAW_CHAR - 1文字描画
;==============================================================================
DRAW_CHAR:
        LD      HL, 8
        LD      (V_NX), HL
        LD      (V_NY), HL

        ; --- 1. ワークエリアを塗りつぶし ---
        CALL    WAIT_VDP
        LD      HL, 0
        LD      (V_DX), HL
        LD      HL, 1016
        LD      (V_DY), HL
        LD      A, (CUR_CLR)
        RLCA
        RLCA
        RLCA
        RLCA
        LD      B, A
        LD      A, (CUR_CLR)
        AND     0FH
        OR      B
        LD      (V_CLR), A
        LD      A, 0C0H
        LD      (V_CMD), A
        CALL    SEND_VCMD

        ; --- 2. フォントをANDで重ねる ---
        CALL    WAIT_VDP
        LD      A, (CUR_CHR)
        AND     0FH
        ADD     A, A
        ADD     A, A
        ADD     A, A
        LD      L, A
        LD      H, 0
        LD      (V_SX), HL
        LD      A, (CUR_CHR)
        AND     0F0H
        SRL     A
        LD      L, A
        LD      H, 0
        LD      DE, 768
        ADD     HL, DE
        LD      (V_SY), HL
        LD      HL, 0
        LD      (V_DX), HL
        LD      HL, 1016
        LD      (V_DY), HL
        LD      A, 091H
        LD      (V_CMD), A
        CALL    SEND_VCMD

        ; --- 3. 画面へ透明転送 ---
        CALL    WAIT_VDP
        LD      HL, 0
        LD      (V_SX), HL
        LD      HL, 1016
        LD      (V_SY), HL
        LD      A, (CUR_X)
        LD      L, A
        LD      H, 0
        LD      (V_DX), HL
        LD      A, (CUR_Y)
        LD      L, A
        LD      H, 0
        LD      A,(VIJUAL)
        CP      1
        JR      Z,PAGE0
        LD      DE,256 ; ページ１へ描画するにはＹ座標に256を足す
        ADD     HL,DE
PAGE0:        
        LD      (V_DY), HL
        LD      A, 098H
        LD      (V_CMD), A
        CALL    SEND_VCMD
        RET
;==============================================================================
; DRAW_CHAR_FAST - 1文字高速描画 (白固定・LMMM転送)
;==============================================================================
DRAW_CHAR_FAST:
        ; 転送サイズ 8x8 固定
        LD      HL, 8
        LD      (V_NX), HL
        LD      (V_NY), HL

        ; --- ソース座標計算 (DRAW_CHARと同じロジック) ---
        ; X座標: (CUR_CHR AND 0FH) * 8
        LD      A, (CUR_CHR)
        AND     0FH             ; 下位4bitが列番号(0-15)
        ADD     A, A
        ADD     A, A
        ADD     A, A            ; *8ドット
        LD      L, A
        LD      H, 0
        LD      (V_SX), HL

        ; Y座標: (CUR_CHR AND 0F0H) / 16 * 8 + 768 (Page 3領域)
        LD      A, (CUR_CHR)
        AND     0F0H            ; 上位4bitが行番号
        SRL     A               ; /16 * 8 なので結局 /2 と同じ
        LD      L, A
        LD      H, 0
        LD      DE, 768         ; Page 3の開始位置 (256 * 3)
        ADD     HL, DE
        LD      (V_SY), HL

        ; --- 画面(Destination)座標設定 ---
        LD      A, (CUR_X)
        LD      L, A
        LD      H, 0
        LD      (V_DX), HL

        LD      A, (CUR_Y)
        LD      L, A
        LD      H, 0
        ; ページ判定 (VIJUALが1ならPage 0、それ以外ならPage 1へ)
        LD      A, (VIJUAL)
        CP      1
        JR      Z, PAGE0_F
        LD      DE, 256         ; Page 1へ描画
        ADD     HL, DE
PAGE0_F:
        LD      (V_DY), HL

        ; --- VDPコマンド実行 (LMMM: 高速矩形コピー) ---
        CALL    WAIT_VDP
        XOR     A
        LD      (V_ARG), A
        LD      A, 0D0H         ; LMMM (High speed move)
        LD      (V_CMD), A
        CALL    SEND_VCMD
        RET
;==============================================================================
; VDP共通ルーチン
;==============================================================================
WAIT_VDP:
        DI
        LD      A, 2
        OUT     (VDP_REG), A
        LD      A, 143          ; R#15
        OUT     (VDP_REG), A
        IN      A, (VDP_REG)
        PUSH    AF
        LD      A, 0
        OUT     (VDP_REG), A
        LD      A, 143          ; R#15
        OUT     (VDP_REG), A
        EI
        POP     AF
        AND     1
        JR      NZ, WAIT_VDP
        RET

SEND_VCMD:
        DI
        LD      A, 32           ; R#32
        OUT     (VDP_REG), A
        LD      A, 145          ; R#17
        OUT     (VDP_REG), A
        LD      C, VDP_VCM      ; Port 9BH
        LD      HL, V_SX
        LD      B, 15
V_S_LP:
        OUTI
        JR      NZ, V_S_LP
        EI
        RET

;==============================================================================
; フォント展開
;==============================================================================
FT_EXPAND_256:
        LD      A, 0
        LD      (WK_CHR), A
FT_LP:
        LD      A, (WK_CHR)
        AND     0FH
        ADD     A, A
        ADD     A, A
        LD      (WK_X), A
        LD      A, (WK_CHR)
        AND     0F0H
        SRL     A
        LD      (WK_Y), A
        LD      A, (WK_CHR)
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        ADD     HL, HL
        ADD     HL, HL
        LD      DE, (CGPNT)
        ADD     HL, DE
        LD      DE, FONT_TMP
        LD      B, 8
FT_GET:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      A, (CSLOT)
        CALL    000CH
        LD      C, A
        POP     HL
        POP     DE
        LD      A, C
        LD      (DE), A
        INC     DE
        INC     HL
        POP     BC
        DJNZ    FT_GET
        LD      IX, FONT_TMP
        LD      B, 8
FT_LINE:
        PUSH    BC
        LD      A, (WK_Y)
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        ADD     HL, HL
        ADD     HL, HL
        ADD     HL, HL
        ADD     HL, HL
        ADD     HL, HL
        ADD     HL, HL
        LD      A, (WK_X)
        LD      E, A
        LD      D, 0
        ADD     HL, DE
        DI
        LD      A, 6            ; VRAM Address 18000H (Page 3)
        OUT     (VDP_REG), A
        LD      A, 142          ; R#14
        OUT     (VDP_REG), A
        LD      A, L
        OUT     (VDP_REG), A
        LD      A, H
        OR      40H
        OUT     (VDP_REG), A
        LD      A, (IX)
        INC     IX
        LD      C, A
        LD      D, 4
FT_EXP:
        XOR     A
        SLA     C
        JR      NC, FT_L0
        LD      A, (WK_FG)
        SLA     A
        SLA     A
        SLA     A
        SLA     A
FT_L0:
        PUSH    AF
        SLA     C
        LD      A, 0
        JR      NC, FT_R0
        LD      A, (WK_FG)
        AND     0FH
FT_R0:
        LD      H, A
        POP     AF
        OR      H
        OUT     (VDP_DATA), A
        DEC     D
        JR      NZ, FT_EXP
        EI
        LD      A, (WK_Y)
        INC     A
        LD      (WK_Y), A
        POP     BC
        DJNZ    FT_LINE
        LD      A, (WK_Y)
        SUB     8
        LD      (WK_Y), A
        LD      A, (WK_CHR)
        INC     A
        LD      (WK_CHR), A
        CP      0
        JP      NZ, FT_LP
        RET

; --- FONT WORK ---
WK_X:     DEFB 0
WK_Y:     DEFB 0
WK_CHR:   DEFB 0
WK_FG:    DEFB 0
CUR_X:    DEFB 0
CUR_Y:    DEFB 0
CUR_CLR:  DEFB 0
CUR_CHR:  DEFB 0
FONT_TMP: DEFS 8
V_SX:     DEFW 0
V_SY:     DEFW 0
V_DX:     DEFW 0
V_DY:     DEFW 0
V_NX:     DEFW 0
V_NY:     DEFW 0
V_CLR:    DEFB 0
V_ARG:    DEFB 0
V_CMD:    DEFB 0
;------------------------------------------------
;
; ASCII FONT DISPFUNC
;
;------------------------------------------------
ASCII_DISP:
          PUSH    AF
          PUSH    HL
          LD      A,(IX+3)
          LD      L,A
          LD      A,(IX+4)
          LD      H,A
          
          PUSH    AF
          PUSH    BC
          PUSH    DE
          PUSH    IX
          LD      A,(IX+14)
          OR      A
          JR      NZ,F_FAST
          CALL    PRINT_STR
          JR      F_END
F_FAST:   CALL    PRINT_STR_FAST
F_END:
          POP     IX
          POP     DE
          POP     BC
          POP     AF
          
          INC     (IX+1)
          LD      A,(IX+1)
          SUB     (IX+10)
          JR      NZ,NOERASE
          XOR     A
          LD      (IX+0),A
NOERASE:  POP     HL
          POP     AF
          RET
          
FONT_SET:
          LD      (ASCOUNT),A
          LD      (ASCFONT),HL
          RET
          
;------------------------------------------------
;
; LICENSE DEMO
;
;------------------------------------------------

LICENSE_DEMO:
          PUSH    AF
          LD      IX,SCOLOR     ; 色管理ワークエリアのベースアドレスをセット
          LD      A,15          ; 白色（パレット15）
          LD      (IX+0),A      ; ターゲット色設定
          LD      A,1           ; 
          LD      (IX+1),A      ; フラグまたは増分設定
          LD      A,00001000B   ; ビット属性設定
          LD      (IX+2),A      
          ;
          CALL    CLSPRI        ; オブジェクトワークエリア全消去
          CALL    DSET
          DEFW    L_MSG0,ASCII_DISP
          DEFB    0,0,0,48,0,0
          DEFB    0,0,00000001B     
          CALL    DSET
          DEFW    L_MSG1,ASCII_DISP
          DEFB    0,0,0,48,0,0
          DEFB    0,0,00000001B  
          CALL    DSET
          DEFW    L_MSG2,ASCII_DISP
          DEFB    0,0,0,48,0,0
          DEFB    0,1,00000001B          ; (IX+14)を1にすると高速文字表示（白限定）
          CALL    DSET
          DEFW    L_MSG3,ASCII_DISP
          DEFB    0,0,0,48,0,0
          DEFB    0,1,00000001B          
          CALL    DSET
          DEFW    L_MSG4,ASCII_DISP
          DEFB    0,0,0,48,0,0
          DEFB    0,1,00000001B          
          CALL    DSET
          DEFW    L_MSG5,ASCII_DISP
          DEFB    0,1,0,48,0,0
          DEFB    0,0,00000001B

          CALL    UNFADE        ; フェードイン開始（画面を明るくする）
          LD      A,20           ; 
          CALL    MAIN          ; 40フレームMAIN実行          
          CALL    FADE          ; フェードアウト開始
          LD      A,8           ; 8フレームMAIN実行
          CALL    MAIN
          CALL    CLSPRI  
          POP     AF
          JP      LOGODEMO      ; タイトル画面ルーチンへ遷移
          ;
L_MSG0: DEFB 32, 60, 13, "<<< ROCK CITY 2024 >>>", 0
L_MSG1: DEFB 40, 100, 11, "- SOFTWARE LICENSE -", 0
L_MSG2: DEFB 36, 134, 15, "Copyright (C) 1993-2026", 0
L_MSG3: DEFB 4,  154, 15, "Licensed under the MIT License.", 0
L_MSG4: DEFB 24, 164, 15, "THIS SOFTWARE IS PROVIDED", 0
L_MSG5: DEFB 30, 174, 15, "\"AS IS\" WITHOUT WARRANTY", 0
;------------------------------------------------
;
; LOGO DEMO
;
;------------------------------------------------
;
LOGODEMO: 
          LD      IX,SCOLOR     ; 色管理ワークエリアのベースアドレスをセット
          LD      A,15          ; 白色（パレット15）
          LD      (IX+0),A      ; ターゲット色設定
          LD      A,1           ; 
          LD      (IX+1),A      ; フラグまたは増分設定
          LD      A,00001000B   ; ビット属性設定
          LD      (IX+2),A      
          ;
          CALL    CLSPRI        ; オブジェクトワークエリア全消去
          CALL    UNFADE        ; フェードイン開始（画面を明るくする）
          LD      A,8           ; 
          CALL    MAIN          ; 8フレームMAIN実行
          ;
          ; ロゴのメイン移動設定
          CALL    DSET          ; 表示オブジェクト(タスク)の登録
          DEFW    LOGODATA,LOGOMV2 ; データ定義と移動ルーチン(LOGOMV2)を指定
          DEFB    128,128,160,-30,0,0 ; X, Y, Z, 移動速度などの初期パラメータ
          DEFB    15,0,00101000B ; 色、属性など
          ;
          LD      A,24          ; 24フレームMAIN実行
          CALL    MAIN
          CALL    FADE          ; フェードアウト開始
          LD      A,10          ; 10フレームMAIN実行
          CALL    MAIN
          JP      TITLE         ; タイトル画面ルーチンへ遷移
          ;          
; --- Mの移動 ---
LOGOMV11:  
          CALL    MOVE          ; 座標更新ルーチン呼び出し
          DEFB    -1,0,20       ; X速度:-1, Y速度:0, 期間:20
          DEFB     2,3,0        ; 加速度などのパラメータ
          RET
; --- Sの移動 ---
LOGOMV12:  
          CALL    MOVE
          DEFB     0,1,20       ; X速度:0, Y速度:1, 期間:20
          DEFB     0,3,2
          RET
; --- Xの移動 ---
LOGOMV13:  
          CALL    MOVE
          DEFB     1,0,20       ; X速度:1, Y速度:0, 期間:20
          DEFB     3,0,2
          RET
; --- MSXロゴの移動ルーチン ---
LOGOMV2:  LD      A,(IX+9)      ; ワークエリアから現在の内部状態を取得
          CP      10            ; 状態が10に達したか？
          JR      Z,MV2JR       ; 達していれば移動スキップ
          CALL    MOVE          ; 通常移動処理
          DEFB    0,0,-15       ; Z軸方向（奥・手前）の動き
          DEFB    3,-0,0
          RET
          ;
MV2JR:    INC     (IX+1)        ; カウンタをインクリメント
          LD      A,(IX+1)
          
          PUSH    AF
          PUSH    BC
          PUSH    DE
          PUSH    IX
          LD      HL,VERSTR
          CALL    PRINT_STR_FAST       
          POP     IX
          POP     DE
          POP     BC
          POP     AF
          
          CP      16            ; カウンタが16になったか？
          JR      NZ,MV2JR2     ; 16未満ならテキスト表示へ
          ; --- カウンタ16到達時：ロゴを3つのパーツに分離して再登録 ---
          CALL    DSET          ; パーツ(M)登録
          DEFW    LGMDATA,LOGOMV11
          DEFB    58,128,10,0,0,0
          DEFB    15,0,00101000B
          CALL    DSET          ; パーツ(S)登録
          DEFW    LGSDATA,LOGOMV12
          DEFB    128,128,10,0,0,0
          DEFB    15,0,00101000B
          CALL    DSET          ; パーツ(X)登録
          DEFW    LGXDATA,LOGOMV13
          DEFB    193,128,10,0,0,0
          DEFB    15,0,00101000B
          JP      MULEND        ; このオブジェクト（親ロゴ）を消去して終了
MV2JR2:   ; 
          CALL    DSET
          DEFW    LGDEMOMJ,MHYOUJ ; テキストデータと表示ルーチン(MHYOUJ)
          DEFB    15,0,0,0,0,0
          DEFB    0,0,00010101B 
          RET
          
LGDEMOMJ: DEFB 'M',10+46,175,'S',10+62,175,'X',10+78,175,'2',10+94,175,'G',10+126,175,'A',10+142,175,'M',10+158,175,'E',10+174,175,'S',10+188,175,0
		  DEFB MJVER,60+158,220,MIVER,60+170,220,PTVER,60+182,220,0

VERSTR    DEFB 80,220,15, "ROCKCITY2024 ver",MJVER,".",MIVER,".",PTVER,0
;
;---- M POINT DATA ----
;
LGMDATA:  DEFB    13,0
          DEFB	  -20,-40,0
          DEFB    -40,+40,0
          DEFB    -25,+40,0
          DEFB    -15,  0,0
          DEFB     -5,+40,0
          DEFB     +5,+40,0
          DEFB    +15,  0,0
          DEFB    +25,+40,0
          DEFB    +40,+40,0
          DEFB    +20,-40,0 
          DEFB    +10,-40,0
          DEFB      0,  0,0
          DEFB    -10,-40,0
          DEFB    1,2,3,4,5,6,7,8,9,10,11,12,13,1,0,0
;
;---- S POINT DATA ----
;
LGSDATA:  DEFB    14,0
          DEFB	  -20,-40,0
          DEFB    -40,-15,0
          DEFB    -20,+10,0
          DEFB    +20,+10,0
          DEFB    +20,+20,0
          DEFB    -40,+20,0
          DEFB    -30,+40,0
          DEFB    +20,+40,0
          DEFB    +40,+15,0
          DEFB    +20,-10,0 
          DEFB    -15,-10,0
          DEFB    -15,-20,0
          DEFB    +40,-20,0
          DEFB    +30,-40,0
          DEFB    1,2,3,4,5,6,7,8,9,10,11,12,13,14,1,0,0
;
;---- X POINT DATA ----
;
LGXDATA:  DEFB    12,0
          DEFB	  -40,-40,0
          DEFB    -10,  0,0
          DEFB    -40,+40,0
          DEFB    -20,+40,0
          DEFB      0,+15,0
          DEFB    +20,+40,0
          DEFB    +40,+40,0
          DEFB    +10,  0,0
          DEFB    +40,-40,0
          DEFB    +20,-40,0 
          DEFB      0,-15,0
          DEFB    -20,-40,0
          DEFB    1,2,3,4,5,6,7,8,9,10,11,12,1,0,0
;
;---- MSX LOGO POINT DATA ----
;
LOGODATA: DEFB    35,0
		  DEFB	  -90,-40,0
          DEFB   -110,+40,0
          DEFB    -95,+40,0
          DEFB    -85,  0,0
          DEFB    -75,+40,0          
          DEFB    -65,+40,0
          DEFB    -55,  0,0
          DEFB    -45,+40,0
          DEFB    +20,+40,0
          DEFB    +40,+15,0
          DEFB    +20,-10,0
          DEFB    -15,-10,0
          DEFB    -15,-20,0
          DEFB    +40,-20,0
          DEFB    +56, -0,0
          DEFB    +25,+40,0
          DEFB    +45,+40,0
          DEFB	  +65,+15,0
          DEFB    +85,+40,0
          DEFB   +105,+40,0
          DEFB    +75,  0,0
          DEFB   +105,-40,0
          DEFB    +85,-40,0
          DEFB    +65,-12,0
          DEFB    +45,-40,0
          DEFB    -20,-40,0
          DEFB    -35,-15,0
          DEFB    -20,+10,0
          DEFB    +20,+10,0
          DEFB    +20,+20,0
          DEFB    -35,+20,0
          DEFB    -50,-40,0
          DEFB    -60,-40,0
          DEFB    -70,  0,0
          DEFB    -80,-40,0
          DEFB    1,2,3,4,5,6,7,8,9,10,11,12,13,14
          DEFB    15,16,17,18,19,20,21,22,23,24,25
          DEFB    26,27,28,29,30,31,32,33,34,35,1,0,0
          

;------------------------------------------------
;
; TITLE DEMO
;
;------------------------------------------------
TITLE:    LD      IX,SCOLOR     ; 色管理ワークエリア設定
          LD      A,2           ; ターゲット色をカラー2に変更
          LD      (IX+0),A
          LD      A,1
          LD      (IX+1),A
          LD      A,00001001B   ; 属性設定
          LD      (IX+2),A
          ;
MENSET:   CALL    CLSPRI        ; オブジェクトワークエリア全消去
          CALL    UNFADE        ; フェードイン開始
          LD      A,4           ; 4フレームMAINを実行
          CALL    MAIN
          
          ; --- タイトルロゴ（上段）の描画 ---
          ; DSSSを使い、MR, MO, MC, MK という文字データを順に配置
          CALL    DSSS
          DEFW    MR            ; 'R'
          DEFB    44,70         ; X, Y座標
          CALL    DSSS
          DEFW    MO            ; 'O'
          DEFB    100,70
          CALL    DSSS
          DEFW    MC            ; 'C'
          DEFB    156,70
          CALL    DSSS
          DEFW    MK            ; 'K'
          DEFB    212,70
          ;
          LD      A,3           ; 3フレームMAINを実行
          CALL    MAIN
          ;
          ; --- タイトルロゴ（下段）の描画 ---
          CALL    DSSS
          DEFW    MC            ; 'C'
          DEFB     44,178
          CALL    DSSS
          DEFW    MI            ; 'I'
          DEFB    100,178
          CALL    DSSS
          DEFW    MT            ; 'T'
          DEFB    156,178
          CALL    DSSS
          DEFW    MY            ; 'Y'
          DEFB    212,178
          ;
          LD      A,77          ; 77フレームMAINを実行
          CALL    MAIN
          ;
          ; --- 自機オブジェクトの表示 ---
          CALL    DSET
          DEFW    MSDATA,PATER2
          DEFB    128,128,255
          DEFB    0,0,0,3,0
          DEFB    00101000B
          ;
          LD      A,34          ; 34フレームMAINを実行
          CALL    MAIN
          ;
          ; --- 「PUSH SPACE」メッセージオブジェクトの登録 ---
          CALL    DSET
          DEFW    STMESG,MJIPAT
          DEFB    3,255,0,2,0,50
          DEFB    50,0,00100101B
          ;
          ; --- 入力待ちループ ---
          LD      B,0           ; ループカウンタ(256回)
LOSTI:    CALL    STRIG         ; ジョイスティック/スペースキーの入力チェック
          JP      Z,NEXTGO      ; 入力があればゲーム開始(NEXTGO)へ
          CALL    MAIN          ; 入力がなければメインループ続行
          DJNZ    LOSTI         ; Bが0になるまで繰り返し
          ;
          ; --- 一定時間入力がない場合はデモへ戻る ---
          CALL    FADE          ; フェードアウト
          LD      A,10          ; 10フレームMAINを実行
          CALL    MAIN
          CALL    WSCORE        ; ハイスコア表示デモへ
          JP      TITLE         ; タイトルループの最初に戻る
          ;
          ; --- ゲーム開始処理 ---
NEXTGO:   CALL    ITEMGT        ; スタートサウンドコール
          CALL    FADE          ; 画面切り替えのフェード
          LD      A,16          ; 16フレームMAINを実行
          CALL    MAIN
          JP      SELECT        ; ゲームモードセレクトデモへ
;
; 3D文字の登録ルーチン
;
DSSS:     POP     HL          ; スタックから戻り先アドレスを取得
                              ; (CALL直後のデータのアドレスがHLに入る)
          ; --- 引数1: アドレス(DE相当)の読み込み ---
          LD      E,(HL)      ; データ1バイト目
          INC     HL
          LD      D,(HL)      ; データ2バイト目
          INC     HL
          ; --- 引数2: パラメータ(BC相当)の読み込み ---
          LD      C,(HL)      ; データ3バイト目
          INC     HL
          LD      B,(HL)      ; データ4バイト目
          INC     HL
          ; --- 取得したデータを実行用ワーク(DSSD)へ転送 ---
          LD      (DSSD+0),DE ; 取得したDEをDSSDの先頭(DEFW 0の部分)に上書き
          LD      (DSSD+4),BC ; 取得したBCをDSSDのオフセット4に上書き
          ; --- オブジェクトの登録実行 ---
          CALL    DSET        ; 自己書き換えされたDSSDを元にタスク登録
DSSD:     DEFW    0,PATER1,0  ; ※実行時に先頭の0が引数DEで書き換わる
          DEFB    250,0,0,16,3,0 ; 固定パラメータ（座標や速度など）
          DEFB    001010B     ; 属性
          ; --- 呼び出し元への復帰処理 ---
          PUSH    HL          ; データを読み飛ばした後のアドレスをスタックに戻す
                              ; (これで正しく次の命令へRETできる)
          LD      A,1         ; 1フレーム分
          CALL    MAIN        ; メインループを実行
          RET                 ; 呼び出し元（PUSHしたHLの指す先）へ戻る
          ;
; 形式: 文字, 相対X座標, 相対Y座標 ... 0(終端)
STMESG:   DEFB    'P',15,30
          DEFB    'U',30,30
          DEFB    'S',45,30
          DEFB    'H',60,30
          DEFB    'S',90,30  ; 'H'と'S'の間を少し空けている(15→30)
          DEFB    'P',105,30
          DEFB    'A',120,30
          DEFB    'C',135,30
          DEFB    'E',150,30
          DEFB    0          ; データの終端
          ;
;
; PUSH SPACE 移動ルーチン
;
MJIPAT:   LD      A,(IX+1)      ; ワークエリアからカウンタ（時間）を取得
          AND     3             ; 下位2ビットのみ抽出 (0, 1, 2, 3 の繰り返し)
          ; --- ビットを左に3回シフトして文字の拡大ビットへ移動 ---
          RLCA                  ; (x2)
          RLCA                  ; (x4)
          RLCA                  ; (x8)
          ; --- 基本属性と合成 ---
          OR      00100101B     ; 基本の表示属性と、計算した文字拡大ビットを結合
          LD      (IX+15),A     ; 属性/色設定をワークエリアに書き戻す
          JP      MHYOUJ        ; 文字表示共通ルーチン(MHYOUJ)へジャンプ
          ;
;
; タイトルデモの文字移動ルーチン
;
PATER1:   LD      A,(IX+1)      ; ワークエリアから経過時間（カウンタ）を取得
          INC     (IX+1)        ; カウンタを更新
          ;
          ; --- フェーズ1: 登場時の急接近演出 (0-7フレーム) ---
          CP      8             ; カウンタが8未満か？
          JR      NC,$+12       ; 8以上なら次の処理(11バイト先)へジャンプ
          CALL    MOVE          ; Z軸（奥から手前）へ高速移動
          DEFB    0,0,-26       ; Z速度:-26
          DEFB    0,-4,2        ; 加速度設定
          RET
          ;
          ; --- フェーズ2: 画面の震え/バイブレーション演出 (8-29フレーム) ---
          CP      30            ; カウンタが30未満か？
          JR      NC,TDPJ1      ; 30以上なら回転処理(TDPJ1)へ
          AND     2             ; ビット1をチェック（2フレームおきに真）
          JR      Z,$+12        ; 0ならジャンプ（結果的に2フレームごとに上下移動）
          CALL    MOVE          ; 下へ移動
          DEFB    0,4,0
          DEFB    0,0,0
          RET
          ;
          CALL    MOVE          ; 上へ戻る（直後の呼び出しで相殺し、震えを表現）
          DEFB    0,-4,0
          DEFB    0,0,0
          RET
          ;
          ; --- フェーズ3: 回転(RTURN)と複雑な移動 (30-65フレーム) ---
TDPJ1:    CP      66            ; カウンタが66未満か？
          JR      NC,$+21       ; 66以上ならこの演出を終了（20バイト先へ）
          ;
          CALL    RTURN         ; 回転ルーチン呼び出し
          DEFB    128,128,128   ; 回転の基準座標(中心)
          DEFB    0,2,0         ; 回転速度/軸設定          
          CALL    MOVE          ; 座標の微調整
          DEFB    0,0,0
          DEFB    0,2,0
          RET
          ;          
          CALL    MOVE          ; Z軸への引き（遠ざかる動作）
          DEFB    0,0,16        ; Z速度:16
          DEFB    1,2,2         ; 加速度/カーブ設定
          RET
;
; タイトルデモの自機オブジェクト移動ルーチン
;
PATER2:   LD      A,(IX+1)      ; 経過時間（カウンタ）を取得
          INC     (IX+1)        ; カウンタを更新
          ;
          ; --- フェーズ1: 回転しながらズーム（0-15フレーム） ---
          CP      16            
          JR      NC,$+12       ; 16以上なら次へ
          CALL    MOVE          ; 前方に回転移動しながら登場
          DEFB    0,0,-10       ; Z速度:-10
          DEFB    2,0,0         
          RET
          ;
          JR      NZ,TDPJ2      ; 16フレーム目に達した瞬間のみ以下の処理を実行
          SET     1,(IX+15)     ; 属性のビット1をセット
          LD      A,200         
          LD      (IX+9),A      ; ワークエリア(IX+9)に初期値を投入
          LD      A,16          ; カウンタ調整用
          ;
          ; --- フェーズ2: 回転しながらズームその2（16-33フレーム） ---
TDPJ2:    CP      34            
          JR      NC,$+12       ; 34以上なら次へ
          CALL    MOVE          
          DEFB    0,0,-8        ; Z速度:-8（少し減速）
          DEFB    2,0,0         
          RET
          ;
          ; --- フェーズ3: 2軸回転演出 (34-69フレーム) ---
          CP      70            
          JR      NC,$+12       ; 70以上なら次へ
          CALL    MOVE          
          DEFB    0,0,0         ; 座標移動なし
          DEFB    0,-1,-1       ; 2軸回転
          RET
          ;
          ; --- フェーズ4: 特殊移動 A (70-119フレーム) ---
          CP      120           
          JR      NC,$+12       ; 120以上なら次へ
          CALL    MOVE          
          DEFB    0,0,0         
          DEFB    0,0,-1        
          RET
          ;
          ; --- フェーズ5: 特殊移動 B (120-189フレーム) ---
          CP      190           
          JR      NC,$+12       ; 190以上なら次へ
          CALL    MOVE          
          DEFB    0,0,0         
          DEFB    -1,0,0        
          RET
          ;
          ; --- ループ処理: フェーズ2へ戻る ---
          ; カウンタを34（フェーズ3の開始直前）に強制リセット
          LD      A,34          
          LD      (IX+1),A      ; カウンタを書き換え
          JR      PATER2        ; ルーチンの先頭へ戻り、永遠にループさせる
          ;
;------------------------------------------------
;
; GAME SELECT　1996年バージョンで追加した部分
;
;------------------------------------------------
;
; SELECT: ゲームモード選択処理 (GAME か PRACTICE か)
;
SELECT:   CALL    CLSPRI        ; オブジェクトワークエリア全消去
          LD      A,00001001B   ; 画面制御用フラグ（ビット操作）
          LD      (SWITCH),A    ; 表示切り替えスイッチを保存
          LD      A,13          ; 文字色（カラーコード13）を設定
          LD      (SCOLOR),A    ; カラー変数に保存
          ;
          ; --- 「GAME」の文字オブジェクト表示設定 ---
          CALL    DSET
          DEFW    GAMEM,MOJIMV  ; データ定義のアドレスと移動ルーチンの指定
          DEFB    9,200,0,0,0,66 ; 初期位置やパラメータ
          DEFB    100,0,00010001B
          ;
          ; --- 「PRACTICE」の文字オブジェクト表示設定 ---
          CALL    DSET
          DEFW    PRACTM,MOJIMV
          DEFB    11,200,0,0,0,60
          DEFB    150,0,00010101B
          ;
          ; --- 選択枠（上側：GAME用）の設定 ---
          CALL    DSET
          DEFW    WALLPT,WALLMV
          DEFB    135,75,60,0,0,0
          DEFB    9,0,00001000B
          ;
          ; --- 選択枠（下側：PRACTICE用）の設定 ---
          CALL    DSET
          DEFW    WALLPT,WALLMV
          DEFB    135,170,60,0,0,0
          DEFB    11,0,00001001B
          ;
          CALL    UNFADE        ; フェードイン（画面表示開始）
          LD      A,8           ; 初期化パラメータ
          CALL    MAIN          ; メイン描画更新          
          LD      C,0           ; Cレジスタを選択状態の管理に使用 (0:GAME, 1:PRACTICE)
          ;
; --- 選択ループ（入力待ち） ---
LPSLCT:   LD      A,2
          CALL    MAIN          ; 画面更新
          CALL    STRIG         ; トリガーボタン（決定キー）のチェック
          OR      A             ; Aが0でなければ（ボタン押下）
          JR      Z,JUMPSL      ; 決定されたら JUMPSL へジャンプ
          ;
          CALL    STICK         ; ジョイスティック（方向キー）のチェック
          OR      A             ; Aが0なら入力なし
          JR      Z,LPSLCT      ; 入力なければループ継続
          ; --- 選択項目の切り替え処理 ---
          LD      A,C           ; 現在の選択状態(C)を取得
          XOR     1             ; 0と1を反転させる
          LD      C,A           ; 反転した状態をCに戻す
          ; 表示の明暗や座標などを入れ替えて、選択中を強調する処理
          LD      A,(PORIDAT+63)
          LD      B,A
          LD      A,(PORIDAT+47)
          LD      (PORIDAT+63),A
          LD      A,B
          LD      (PORIDAT+47),A
          JP      LPSLCT        ; ループに戻る
          ;
; --- 決定後の遷移処理 ---
JUMPSL:   CALL    FADE          ; フェードアウト
          LD      A,10
          CALL    ITEMGT        ; セレクトサウンドコール
          CALL    MAIN
          ;          
          LD      HL,0
          LD      (SCORE),HL    ; スコアを0にリセット
          LD      A,DSTOCK
          LD      (STOCK),A     ; 残機（ストック）をセット
          ;
          LD      A,C           ; 選択していたモード(C)を確認
          OR      A             ; 0（GAME）か 1（PRACTICE）か
          JP      NZ,PRATCE     ; 1ならプラクティスモードへ
          ;
; --- 本編ゲーム開始 ---
GAME:     LD      HL,GMOUT      ; ゲームオーバー時の戻り先を設定
          LD      (JPDEAD),HL   ; ゲームオーバー時ジャンプ先アドレス保存
          CALL    STAGE1        ; 各ステージを順次呼び出し
          CALL    STAGE2
          CALL    STAGE3
          CALL    STAGE4
          CALL    ENDING        ; エンディング処理
          CALL    WSCORE        ; スコア保存/表示
          JP      TITLE         ; タイトルへ戻る
          ;
; --- ゲームオーバー処理 ---
GMOUT:    CALL    GMOVER        ; ゲームオーバー演出
          CALL    WSCORE        ; スコア保存
          JP      TITLE         ; タイトルへ戻る

;
; データ定義セクション
;
JPDEAD    DEFW    0             ; 死亡時のジャンプ先ポインタ

; 表示用テキストデータ（文字, X相対座標, 0）
GAMEM:    DEFB    'G',20,0,'A',50,0,'M',80,0,'E',110,0,0
PRACTM:   DEFB    'P',20,0,'R',35,0,'A',50,0,'C',65,0,'T',80,0
          DEFB    'I',95,0,'C',110,0,'E',125,0,0

; 選択枠の頂点データ（ワイヤーフレームの座標定義）
WALLPT:   DEFB    8,0           ; 頂点数
          DEFB    -120,  30, 5  ; 頂点データ
          DEFB    -120, -30, 5
          DEFB     120, -30, 5
          DEFB     120,  30, 5
          DEFB    -120,  30,-5
          DEFB    -120, -30,-5
          DEFB     120, -30,-5
          DEFB     120,  30,-5
          DEFB    1,2,3,4,1,0   ; 面の繋がり情報
          DEFB    5,6,7,8,5,0,0

; 移動制御
WALLMV:   CALL    MOVE          ; 移動サブルーチン呼び出し
          DEFB    0,0,0,0,1,0
          RET

; 文字の動き制御
MOJIMV:   INC     (IX+1)        ; インデックスレジスタを使って文字を動かす
          JP      MHYOUJ        ; 文字表示サブルーチンへジャンプ
          ;
;------------------------------------------------
;
; PRACTICE SELECT 1996年バージョンで追加した部分
;
;------------------------------------------------


PRATCE:   CALL    CLSPRI        ; オブジェクトワークエリア全消去
          LD      A,00001001B   ; 画面表示モードの設定フラグ
          LD      (SWITCH),A    ; 表示切り替えフラグを保存
          LD      A,1           ; 地平線の速度を設定
          LD      (SCOLOR+1),A  ; 地平線の速度をセット
          ;
          ; --- 「ZONE」ロゴ表示の設定 ---
          CALL    DSET          ; 表示オブジェクト登録
          DEFW    PRATM,PRAMJV  ; 文字データ 'ZONE' とその移動処理アドレス
          DEFB    9,200,0,0,0,76 
          DEFB    100,0,00010001B
          ;
          ; --- 選択肢 M1 (ZONE 1) の設定 ---
          CALL    DSET
          DEFW    M1,SJIMV      ; '1' のデータと数字用移動処理
          DEFB    0,0,0,0,0,0
          DEFB    10,0,00001010B
          ;
          ; --- 選択肢 M4 (ZONE 4) の設定 ---
          CALL    DSET
          DEFW    M4,SJIMV      ; '4' のデータ
          DEFB    0,0,0,0,0,0
          DEFB    8,8,00001010B
          ;
          ; --- 選択肢 M3 (ZONE 3) の設定 ---
          CALL    DSET
          DEFW    M3,SJIMV      ; '3' のデータ
          DEFB    0,0,0,0,0,0
          DEFB    5,16,00001010B
          ;
          ; --- 選択肢 M2 (ZONE 2) の設定 ---
          CALL    DSET
          DEFW    M2,SJIMV      ; '2' のデータ
          DEFB    0,0,0,0,0,0
          DEFB    3,24,00001010B
          ;
          CALL    UNFADE        ; 画面をフェードイン
          LD      C,0           ; Cレジスタ：現在の回転角度/選択位置（0-31）
          ;
; --- メイン・入力監視ループ ---
PRLOOP:   LD      A,1           ; メインルーチンの処理モード1
          CALL    MAIN          ; 1フレーム描画とシステム更新
          CALL    STRIG         ; トリガ（決定ボタン）の状態取得
          JP      Z,JPPRCT      ; ボタンが押されたら(Z=0)ステージ開始へ
          ; --- Bボタンでゲームモードセレクトへ戻る ---
          CALL    STRIGB
          JP      NZ,PRJP0
          CALL    ITEMGT        ; セレクトサウンドコール
          JP      SELECT        ; ゲームセレクトモードへ
          ; --- 右入力判定 ---
PRJP0:    CALL    STICK         ; ジョイスティック（方向）の状態取得
          CP      3             ; 「右」が押されているか？
          JR      NZ,PRJP2      ; 右でなければ左の判定(PRJP2)へ
          ;
          ; --- 右入力：時計回りに8ステップ分回転させる ---
          LD      B,8           ; 8フレーム分回すカウンタ
PRJP1:    INC     C             ; 角度(C)をインクリメント
          LD      A,1           ; 描画更新
          CALL    MAIN
          DJNZ    PRJP1         ; Bが0になるまで繰り返し（滑らかな動き）
          JR      PRLOOP        ; ループに戻る
          ;
		  ; --- 左入力判定 ---
PRJP2:    CP      7             ; 「左」が押されているか？
          JR      NZ,PRLOOP     ; 何も押されていなければループの先頭へ
          
          ; --- 左入力：反時計回りに8ステップ分回転させる ---
          LD      B,8           ; 8フレーム分回すカウンタ
PRJP3:    DEC     C             ; 角度(C)をデクリメント
          LD      A,1           ; 描画更新
          CALL    MAIN
          DJNZ    PRJP3         ; Bが0になるまで繰り返し
          JP      PRLOOP        ; ループに戻る
; --- ステージ確定後の遷移 ---
JPPRCT:   LD      B,10          ; 待ち時間（10フレーム）
          CALL    FADE          ; 画面暗転開始
          CALL    ITEMGT        ; セレクトサウンドコール
JPPRJ1:   LD      A,1           ; 描画更新しながら待機
          CALL    MAIN
          DJNZ    JPPRJ1        
          ;
          LD      HL,PRART      ; 練習モード用ゲームオーバー時のジャンプ先を設定
          LD      (JPDEAD),HL   ; ポインタを保存
          LD      A,DSTOCK      ; 残機(STOCK)を設定
          LD      (STOCK),A
          LD      HL,0          ; スコアを0にクリア
          LD      (SCORE),HL
          ;
          ; --- 選択位置(C)からステージ番号を算出 ---
          LD      A,C           ; Cは0-31の値
          SRL     A             ; A = A / 2
          SRL     A             ; A = A / 4
          SRL     A             ; A = A / 8 (結果は0-3)
          AND     3             ; 念のため下位2ビットでマスク
          ;          
          JR      NZ,JPCT1      ; 0以外ならZONE2以降の判定へ
          CALL    STAGE1        ; --- ZONE 1 実行 ---
          JP      PRATCE        ; 終了後、ステージ選択に戻る
          ;
JPCT1:    CP      1             ; ZONE 2 か？
          JR      NZ,JPCT2
          CALL    STAGE2        ; --- ZONE 2 実行 ---
          JP      PRATCE
          ;
JPCT2:    CP      2             ; ZONE 3 か？
          JR      NZ,JPCT3
          CALL    STAGE3        ; --- ZONE 3 実行 ---
          JP      PRATCE
          ;
JPCT3:    CALL    STAGE4        ; --- ZONE 4 実行 ---
          CALL    ENDING        ; エンディングへ
          JP      TITLE         ; タイトルへ戻る
          ;
; --- 練習モードゲームオーバー時にここへ飛ぶ ---
PRART:    POP     HL            ; コールスタックを1つ破棄（調整）
          JP      TITLE         ; タイトル画面へ強制送還
;
; サポートルーチンとデータ定義
;
; SJIMV: ステージ番号（M1-M4）の移動処理
SJIMV:    LD      (IX+7),128    ; 基準X座標設定
          LD      (IX+8),160    ; 基準Y座標設定
          LD      (IX+9),10     ; 基準Z座標設定
          LD      A,C           ; 共通角度Cを取得
          ADD     A,(IX+14)     ; 各数字ごとの位相オフセット(0, 8, 16, 24)を加算
          AND     31            ; 0-31の範囲に固定
          LD      (TDSJI1+2),A  ; RTURN用のパラメータ書き換え
          LD      (IX+12),A     ; 自身の角度変数に保存
          CALL    RTURN         ; 相対回転計算
          DEFB    128,100,128   ; 相対回転のパラメータ
TDSJI1:   DEFB    0,0,0         ; ワークエリア（実行時に書き換えられる）
          CALL    MOVE          ; 文字の回転
          DEFB    0,0,0
          DEFB    1,0,0
          RET

; PRATM: タイトル文字 'ZONE' の定義
PRATM:    DEFB    'Z',20,0,'O',40,5,'N',60,2,'E',85,0,0

; PRAMJV: 'ZONE'ロゴの移動処理
PRAMJV:   INC     (IX+1)        ; 移動カウンタを更新
          LD      A,C           ; 現在の選択角度Cを元に
          AND     31
          SRL     A             ; 3回右シフトして 0-3 のインデックス作成
          SRL     A
          SRL     A
          LD      H,0           ; HL = 色テーブルへのインデックス
          LD      L,A
          LD      DE,TBLCOR
          ADD     HL,DE         ; テーブルのアドレスを算出
          LD      A,(HL)        ; テーブルからカラーコードを読み出す
          LD      (SCOLOR),A    ; 地平線の色をセット
          LD      (IX+7),A      ; 自身の色も更新
          JP      MHYOUJ        ; 文字表示ルーチンへ

; TBLCOR: 選択ゾーンに対応したカラーテーブル
TBLCOR:   DEFB    11,2,4,6      ; 水色、赤、青、緑（などのパレット番号）
;--------------------------------------------------
;
; ENDING DEMO
;
;--------------------------------------------------

ENDING:   CALL    CLSPRI        ; オブジェクトワークエリア全消去
          LD      A,8
          CALL    MAIN          ; 8フレームMAINを実行
          LD      A,00001001B
          LD      (SWITCH),A    ; 表示フラグ設定
          LD      HL,0203H      ; 地平線の色と速度
          LD      (SCOLOR),HL   ; 地平線一括設定
          LD      HL,0
          LD      (GAGE),HL     ; ゲージ表示などをリセット
          ;          
          ; --- 自機オブジェクト作成 ---
          CALL    DSET
          DEFW    MSDATA,EMSPT1
          DEFB    128,160,16,0,1,0
          DEFB    3,0,00001000B
          CALL    UNFADE        ; フェードインして表示開始
          LD      A,24
          CALL    MAIN          ; 24フレームMAINを実行
          ;
          ; --- "PRODUCED BY" の表示 ---
          CALL    DSET
          DEFW    PRODUM,MHYOUJ ; MHYOUJは標準的な文字表示ルーチン
          DEFB    2,34,0,0,0,75
          DEFB    80,0,00000101B
          LD      A,36
          CALL    MAIN          ; 36フレームMAIN実行（文字を読ませる間隔）
          ;
          ; --- 作者名"MSX2ROCKCITY"の表示 ---
          CALL    DSET
          DEFW    MSX2ROC,MHYOUJ
          DEFB    2,34,0,0,0,73
          DEFB    80,0,00000101B
          LD      A,36
          CALL    MAIN
          ;
          ; --- ゲームタイトル"ROCK CITY"の表示 ---
          CALL    DSET
          DEFW    ROCKM ,MHYOUJ
          DEFB    2,34,0,0,0,73
          DEFB    80,0,00000101B
          LD      A,36
          CALL    MAIN
          ;
          ; --- "THE END" の表示 ---
          CALL    DSET
          DEFW    THEENM,MHYOUJ
          DEFB    2,34,0,0,0,82
          DEFB    80,0,00000101B
          LD      A,36
          CALL    MAIN
          ;
          ; --- 自機の振り向き演出処理 ---
          XOR     A
          LD      (PORIDAT+1),A ; ワークエリアのカウンタをリセット
          LD      HL,EMSPT2     ; 移動ルーチンを EMSPT1 から EMSPT2 へ変更
          LD      (PORIDAT+5),HL; オブジェクトの挙動を動的に書き換え
          ;          
          LD      A,32
          CALL    MAIN          ; 32フレーム新しい動き(EMSPT2)を見せる
          CALL    FADE          ; 一旦フェードアウト
          ;
          LD      A,16
          CALL    MAIN
          LD      A,00001000B   ; 表示設定を変更
          LD      (SWITCH),A
          ;
          ; --- 最後の一言 "MSX" "FOREVER" ---
;          CALL    DSET
;          DEFW    MSXM,MHYOUJ
;          DEFB    15,230,0,0,0,98
;          DEFB    110,0,00010001B
          CALL    DSET
          DEFW    LOGODATA,MSXMV
          DEFB    128,110,20,0,0,0
          DEFB    15,0,00000000B
          
          CALL    DSET
          DEFW    FOREVM,MHYOUJ
          DEFB    15,230,0,0,0,83
          DEFB    160,0,00010101B
          ;
          CALL    UNFADE        ; 再度フェードイン
          LD      A,150         ; 長めの余韻（150フレーム ＝ 約2.5秒）
          CALL    MAIN
          CALL    FADE          ; 最後のフェードアウト
          LD      A,8
          CALL    MAIN
          RET                   ; 呼び出し元（GAMEループ）へ戻る

; --- EMSPT1: 自機が左右移動する移動ルーチン ---
EMSPT1:   LD      A,(IX+1)      ; 経過フレーム数を確認
          INC     (IX+1)
          CP      6
          JR      NC,$+12       ; 6フレーム未満なら移動
          CALL    MOVE
          DEFB    -16,0,0,1,0,0 ; 左方向へ
          RET
          ;
          CP      18
          JR      NC,$+12       ; 18フレーム未満なら移動
          CALL    MOVE
          DEFB    16,0,0,-1,0,0 ; 右方向へ
          RET
          ;
          CP      24
          JR      NC,$+12       ; 24フレーム未満なら移動
          CALL    MOVE
          DEFB    -16,0,0,1,0,0 ; 再度左へ
          RET
          ;
          XOR     A             ; カウンタが24に達したらリセットしてループ
          LD      (IX+1),A
          JR      EMSPT1

; --- EMSPT2: 自機が振り返って去っていく移動制御 ---
EMSPT2:   LD      A,(IX+1)
          INC     (IX+1)
          CP      12
          JR      NC,$+12
          CALL    MOVE
          DEFB    -5,-2,16,0,0,0 ; 斜め前方へ
          RET
          ;
          CP      16
          JR      NC,$+12
          CALL    MOVE
          DEFB    0,0,0,0,-1,-3 ; 振り返り処理
          RET
          ;
          CALL    MOVE          ; 斜め後方へ移動
          DEFB    8,-6,-24,0,0,0
          RET

MSXMV:
          RET
;
; テキストデータ定義（文字, X, Y）
; 
PRODUM:   DEFB    'P',0,0,'R',15,0,'O',30,0,'D',45,0,'U',60,0,'C',75,0
          DEFB    'E',90,0,'D',105,0,'B',45,50,'Y',60,50,0
MSX2ROC:  DEFB    'M',-30,0,'S',-15,3,'X',0,6,'2',15,9,'R',30,12,'O',45,15
          DEFB    'C',60,18,'K',75,21,'C',90,24,'I',105,27,'T',120,30,'Y',135,33,0
ROCKM:    DEFB    'R',0,0,'O',15,0,'C',30,0,'K',45,0,'C',65,0,'I',80,0
          DEFB    'T',95,0,'Y',110,0,0
THEENM:   DEFB    'T',0,0,'H',15,0,'E',30,0,'E',55,0,'N',70,0,'D',85,0,0
MSXM:     DEFB    'M',0,0,'S',30,0,'X',60,0,0
FOREVM:   DEFB    'F',0,0,'O',15,0,'R',30,0,'E',45,0,'V',60,0,'E',75,0
          DEFB    'R',90,0,0
;------------------------------------------
;
; SCORE DEMO
;
;------------------------------------------
WSCORE:   CALL    CLSPRI          ; オブジェクトワークエリア全消去
          LD      HL,(SCORE)      ; 現在のスコアをロード
          LD      IX,NSCORM       ; スコアの先頭アドレスをセット
          CALL    CHTEN           ; 数値を10進数テキスト（IXのアドレスに）に変換
          CALL    DSET            ; スコア表示オブジェクト生成
          DEFW    NSCORM,MHYOUJ   ; 表示データのアドレスと表示ルーチン
          DEFB    15,80,0,0,0,140 ; 座標や色などのパラメータ（スコア用）
          DEFB    140,0,00010001B

          ; --- ハイスコア判定処理 ---
          LD      HL,(HSCORE)     ; 現在のハイスコアをロード
          LD      DE,(SCORE)      ; 今回のスコアをロード
          OR      A               ; キャリーフラグをクリア
          SBC     HL,DE           ; HSCORE - SCORE を計算
          PUSH    AF              ; 計算結果（フラグ）を保存
          ADD     HL,DE           ; HLを元のHSCOREに戻す
          POP     AF              ; フラグを復帰
          LD      C,15            ; 通常時の色（または属性）をセット
          JR      NC,$+4          ; HSCORE >= SCORE ならジャンプ（更新なし）
          ;
          ; --- ハイスコア更新時の処理 ---
          EX      DE,HL           ; 更新されたので SCORE(DE) を HL に入れる
          LD      C,8             ; 更新時の色（または属性）に変更
          LD      A,C             
          LD      (HSCORD+4),A    ; 表示命令(HSCORD)のパラメータを自己書き換え
          LD      (HSCORE),HL     ; 新しいハイスコアを保存
          ;          
          LD      IX,HSCORM       ; ハイスコア表示用バッファをセット
          CALL    CHTEN           ; 数値を10進数に変換（IXで始まるアドレスにセット）
          CALL    DSET            ; ハイスコア表示オブジェクト生成
HSCORD:   DEFW    HSCORM,MHYOUJ   
          DEFB    15,80,0,0,0,140 ; ※+4バイト目が先ほどのLD (HSCORD+4),Aで書き換わる
          DEFB    100,0,00010001B
          ;
          ; --- ラベル表示（"HI-SCORE" / "SCORE" 文字列） ---
          CALL    DSET
          DEFW    HSCOR2,MHYOUJ   ; "HI-SCORE" 文字列の表示オブジェクト生成
          DEFB    14,80,0,0,0,20
          DEFB    100,0,00010101B
          ;          
          CALL    DSET
          DEFW    SCORE2,MHYOUJ   ; "SCORE" 文字列の表示オブジェクト生成
          DEFB    14,80,0,0,0,20
          DEFB    140,0,00010101B
          ;
          ; --- 演出・画面遷移 ---
          CALL    UNFADE          ; フェードイン（表示開始）
          LD      A,00001000B     ; スイッチ切り替え用ビット
          LD      (SWITCH),A
          CALL    UNFADE          ; 再度フェード（または画面更新）
          ;          
          LD      A,50            ;
          CALL    MAIN            ; MAINを50フレーム実行（表示維持）
          
          CALL    FADE            ; フェードアウト
          LD      A,8             ; フェードの間MAINを8フレーム実行して待ち
          CALL    MAIN
          JP      TITLE           ; タイトル画面へ戻る

; --- データ定義エリア ---
; 数値テキスト変換用のバッファ（'0'と座標オフセットの並び）
NSCORM:   DEFB    '0',0,0,'0',20,0,'0',40,0,'0',60,0,'0',80,0,0
HSCORM:   DEFB    '0',0,0,'0',20,0,'0',40,0,'0',60,0,'0',80,0,0

; 固定文字列データ（文字, Xオフセット, Yオフセット）
HSCOR2:   DEFB    'H',0,0,'I',12,0,'S',30,0,'C',45,0,'O',60,0
          DEFB    'R',75,0,'E',90,0,0
SCORE2:   DEFB    'S',0,0,'C',15,0,'O',30,0,'R',45,0,'E',60,0,0
;
;------------------------------------------------
;
; GAME OVER DEMO
;
;------------------------------------------------
GMOVER:   CALL    CLSPRI          ; オブジェクトワークエリア全消去
          CALL    SDOFF
          LD      A,14            ; 
          CALL    MAIN            ; 14フレームMAINを実行(待ち）
          CALL    DSET            ; GAMEOVER文字列表示オブジェクト生成
          DEFW    GMOVEM,MHYOUJ   ; 表示データ(GMOVEM)と表示ルーチンを指定
          DEFB    8,40,0,0,0,80   ; パラメータ（色、X座標初期値、オフセット等）
          DEFB    90,0,00000001B  ; 表示制御フラグ
          ;
          CALL    UNFADE          ; 暗転状態からじわっと表示（フェードイン）
          LD      A,00001000B     
          LD      (SWITCH),A                
          LD      A,32            ; 32フレームMAINを実行
          CALL    MAIN            ; "GAME OVER" を読ませるためのウェイト
          ;          
          CALL    FADE            ; 次のスコア画面へ向けてフェードアウト
          LD      A,20            ; 20フレームMAINを実行
          CALL    MAIN            
          ;
          JP      WSCORE          ; スコア表示（WSCORE）へジャンプ

; --- "GAME OVER" 文字列データ定義 ---
; 形式: '文字', Xオフセット, Yオフセット
GMOVEM:   ; 1行目: "GAME"
          DEFB    'G',0,0,  'A',30,0, 'M',60,0, 'E',90,0
          ; 2行目: "OVER" (Y座標を80ドット下げて表示)
          DEFB    'O',0,80, 'V',30,80,'E',60,80,'R',90,80, 0
          
;-----------------------------------------------------------
;
; STAGE 1
;
;-----------------------------------------------------------

STAGE1:   CALL    CLSPRI          ; オブジェクトワークエリア全消去
          LD      (STACK),SP      ; 現在のスタックポインタを保存
          LD      A,00001000B     ; 表示スイッチセット
          LD      (SWITCH),A      ; 
          CALL    DSET            ; 画面に「ZONE 1」を表示するオブジェクト生成
          DEFW    S1STAGM1,MHYOUJ ; 表示データのアドレスと表示ルーチン
          DEFB    11,40,0,0,0,44  ; 
          DEFB    0,0,00010101B   ; 
          CALL    DSET            ; 画面に「PLANE」を表示するオブジェクト生成
          DEFW    S1STAGM2,MHYOUJ ; 
          DEFB    11,40,0,0,0,40  ; 
          DEFB    50,0,00010001B  ; 
          CALL    UNFADE          ; 画面を徐々に明るくする（フェードイン）
          ;
          LD      A,32            ; 
          CALL    MAIN            ; 32フレームMAINを実行
          CALL    FADE            ; 画面を徐々に暗くする（文字を消す演出）
          LD      A,8             ; 短いウェイトを設定
          CALL    MAIN            ; 8フレームMAINを実行
          CALL    MSSTR           ; 自機の表示開始         
          ;

;--- 地平線有りの前半セクション ---
S1CONT:   CALL    MOVESD          ; 移動サウンド開始
          LD      HL,S1STAGD1     ; ステージ制御データの転送元アドレス
          LD      DE,GAMEWORK     ; GAMEWORKから始まるワークエリアを転送先に設定
          LD      BC,9            ; 転送バイト数（9バイト）
          LDIR                    ; データを一括転送
          LD      HL,S1JPDAT1     ; STAGE1固有の当たり判定用ジャンプテーブル（転送元）
          LD      DE,JPTUCH       ; 当たり判定用ワーク（転送先）
          LD      BC,32           ; 転送バイト数（32バイト）
          LDIR                    ; 転送
;          
;          CALL    DSET
;          DEFW    S1CRASHM,MHYOUJ ; "CRASH THE CRYSTAL"
;          DEFB    10,24,1,1,0      ; 座標
;          DEFB    96,80,0,00110101B ; 属性
;          LD      A,128
;         
          LD      A,24            ; 24フレームMAIN実行
          CALL    MAIN            ; 
          LD      B,192           ; 道中の敵出現ループ回数を192回に設定
S1LOOP:   LD      HL,S1RETLOP     ; 戻り先アドレスをHLにロード
          PUSH    HL              ; スタックに積む（敵出現JP先からの共通戻り先にする）
          CALL    RND             ; Aレジスタに乱数を取得
          CP      90              ; 90未満なら
          JP      C,S1CHARA1      ; 敵1（タイプA）を生成
          CP      150             ; 150未満なら
          JP      C,S1CHARA2      ; 敵2（タイプB）を生成
          CP      200             ; 200未満なら
          JP      C,S1CHARA3      ; 敵3（タイプC）を生成
          CP      240             ; 240未満なら
          JP      C,TECHNO        ; テクノイトを作成
          JP      PARTY           ; 240以上なら人間かキャンプを作成
S1RETLOP: CALL    TURBO           ; ターボアイテム作成ルーチンを呼び出す
          CALL    CURE            ; 回復アイテム作成ルーチンを呼び出す
          CALL    GOD_ITEM        ; 無敵アイテム作成ルーチンを呼び出す
          CALL    ALL_BOMB        ; 全オブジェクト破壊ルーチンを呼び出す
          LD      A,B             ; 現在のループカウンタをAへ
          RLCA                    ; ビットを左に回転（ウェイトの計算）
          RLCA                    ; 4倍速的な計算
          AND     3               ; 下位2ビットを抽出
          INC     A               ; +1
          INC     A               ; +2（最低ウェイトを2に固定）
          CALL    MAIN            ; 計算されたウェイト分だけMAIN実行
          DJNZ    S1LOOP          ; Bを1減らし、0でなければループ継続

          LD      A,(SWITCH)      ; 表示フラグを取得
          AND     11111110B       ; 地平線を消す
          LD      (SWITCH),A      ; 設定を反映
          LD      HL,S1CONT2      ; 次の再開アドレスをセット
          LD      (CONTRT),HL     ; コンティニュー用ワークに保存

;--- 地平線を消した後半戦セクション ---
S1CONT2:  CALL    MOVESD          ; 移動サウンドコール（コンティニュー用）
          LD      A,28            ; 28フレームMAIN実行
          CALL    MAIN            ;
          ;
          ; 直方体のラッシュ
          LD      B,40            ; 敵3を40体出すループ
S1LOOP2:  CALL    S1CHARA3        ; 敵3を呼ぶ
          CALL    S1CHARA3        ; もう一体呼ぶ
          LD      A,2             ; 2フレームMAIN実行
          CALL    MAIN            ; 
          DJNZ    S1LOOP2         ; ループ
          ;
          ; 三角錐のラッシュ
          LD      B,50            ; 敵1を50体出すループ
S1LOOP3:  CALL    S1CHARA1        ; 敵1を呼ぶ
          CALL    S1CHARA1        ; もう一体呼ぶ
          CALL    CURE            ; 自機状態の更新
          CALL    TURBO           ; 高速化ルーチン
          CALL    GOD_ITEM        ; 無敵化ルーチン
          CALL    ALL_BOMB        ; 全破壊ルーチン
          LD      A,2             ; 2フレーム待機
          CALL    MAIN            ; 画面更新
          DJNZ    S1LOOP3         ; ループ
          ;
          LD      A,16            ; 最後の静寂（16フレーム）
          CALL    MAIN            ; 画面更新
          JP      S1BOSS          ; ボス戦ルーチンへジャンプ

;--- ステージ1 各種データ定義 ---
S1STAGD1: DEFB    32,5,11,2       ; スクロール速度や背景制御のパラメータ
          DEFB    01011011B       ; ステージ属性フラグ
          DEFW    S1CONT,DEAD     ; 正常復帰アドレスと死亡時復帰アドレス

S1JPDAT1: DEFW    TUCH0,TUCH1     ; 当たり判定の処理分岐テーブル（16個分）
          DEFW    TUCH2,TUCH3     ; アイテムやダメージなどの
          DEFW    TUCH4,TUCH5     ; ジャンプ先が
          DEFW    TUCH6,TUCH7     ; ステージごとに
          DEFW    TUCH18,TUCH19   ; ここで定義される
          DEFW    TUCHNONE,TUCHNONE
          DEFW    TUCHNONE,TUCHNONE
          DEFW    TUCHNONE,TUCHNONE

S1STAGM1: DEFB    'Z',60,80       ; キャラクター 'Z', X座標60, Y座標80
          DEFB    'O',75,80       ; キャラクター 'O', X座標75, Y座標80
          DEFB    'N',90,80       ; キャラクター 'N', X座標90, Y座標80
          DEFB    'E',105,80      ; キャラクター 'E', X座標105, Y座標80
          DEFB    '1',120,80,0    ; キャラクター '1', X座標120, Y座標80, 終端0
S1STAGM2: DEFB    'P',30,80       ; "PLANET" の各文字座標定義
          DEFB    'L',60,80
          DEFB    'A',90,80
          DEFB    'N',120,80
          DEFB    'E',150,80,0
;-----------------------------------------------------------
; 敵1生成ルーチン
;-----------------------------------------------------------
S1CHARA1: CALL    RND             ; 乱数取得
          CP      186             ; 186以上なら
          JR      NC,$-5          ; 範囲内に収まるまでやり直し
          ADD     A,38            ; オフセットを足して出現位置を調整
          LD      (S1CHARD1+4),A  ; 出現データにX座標を書き込み
          CALL    RND             ; 乱数取得
          CP      196             ; 196以上なら
          JR      NC,$-5          ; やり直し
          ADD     A,44            ; オフセットを足して調整
          LD      (S1CHARD1+5),A  ; Y座標を書き込み
          CALL    DSET            ; オブジェクトをワークエリアに登録
S1CHARD1: DEFW    S1CHAPT1,S1CHAMV1 ; スプライト形状アドレス, 移動ルーチンアドレス
          DEFB    0,0,250,0,0,0   ; 
          DEFB    10,1,00000000B  ; 
          RET                     ; 

S1CHAMV1: CALL    MOVE            ; 敵1の移動ルーチン
          DEFB    0,0,-32,0,0,-2  ; 
          RET                     ; 

S1CHAPT1: DEFB    4,0             ; 敵1のモデリングデータ
          DEFB    -32, 18, 18     ; 頂点1の相対座標(X,Y,Z)
          DEFB     32, 18, 18     ; 頂点2
          DEFB      0,-36, 18     ; 頂点3
          DEFB      0,  0,-36     ; 頂点4
          DEFB    1,2,3,1,4,2,0   ; 線を引く順序の定義（スプライト接続）
          DEFB    4,3,0,0         ; 終端

;-----------------------------------------------------------
; 敵2生成ルーチン
;-----------------------------------------------------------
S1CHARA2: CALL    RND             ; 乱数取得
          AND     127             ; 0-127の範囲に制限
          ADD     A,64            ; 64を足す
          LD      (S1CHARD2+4),A  ; X座標を書き込み
          CALL    RND             ; 乱数取得
          AND     127             ; 制限
          ADD     A,64            ; 足す
          LD      (S1CHARD2+5),A  ; Y座標を書き込み
          CALL    DSET            ; オブジェクト登録
S1CHARD2: DEFW    S1CHAPT2,S1CHAMV2 ; 形状, 移動ルーチン
          DEFB    0,0,255,0,0,0   ; 初期座標(Z=255)
          DEFB    2,2,00000000B   ; パラメータ
          RET

S1CHAPT2: DEFB    11,3            ; 頂点数11、属性3
          DEFB    -12,-48,-12     ; 立体的な形状（立方体など）の頂点定義
          DEFB    -12,-48, 12     ; 以下、各頂点の相対座標が続く
          DEFB     12,-48, 12
          DEFB     12,-48,-12
          DEFB    -12, 48,-12
          DEFB    -12, 48, 12
          DEFB     12, 48, 12
          DEFB     12, 48,-12
          DEFB      0, 24,  0     ; 当たり判定用ダミー頂点
          DEFB      0,-24,  0          
          DEFB      0,  0,  0
          DEFB    1,2,3,4,1,5,6   ; ワイヤーフレームの結線データ
          DEFB    7,8,5,0,4,8,0
          DEFB    3,7,0,2,6,0,0

S1CHAMV2: CALL    MOVE            ; 敵2の移動ルーチン
          DEFB    0,0,-16,2,0,0   ; 
          RET                     ; 
;-----------------------------------------------------------
; 敵3生成ルーチン
;-----------------------------------------------------------
S1CHARA3: CALL    RND             ; 乱数取得
          LD      (S1CHARD3+4),A  ; X座標にそのままセット
          CALL    RND             ; 乱数取得
          AND     127             ; 範囲制限
          ADD     A,64            ; オフセット
          LD      (S1CHARD3+5),A  ; Y座標セット
          CALL    DSET            ; オブジェクト登録
S1CHARD3: DEFW    S1CHAPT2,S1CHAMV3 ; 形状は敵2と同じ、移動ルーチンは別
          DEFB    128,128,255     ; 画面中央・奥から出現
          DEFB    0,0,0,2,2,00000000B ; 設定
          RET

S1CHAMV3: LD      A,(IX+9)        ; 現在のZ座標(IX+9)を取得
          SUB     32              ; 32引く（猛スピードで迫る）
          LD      (IX+9),A        ; 書き戻し
          RET                     ; 単純な減算なのでMOVEは使わずRET

;-----------------------------------------------------------
; ボス戦(S1BOSS) メインルーチン
;-----------------------------------------------------------
S1BOSSPT: DEFB    10,0            ; ボスのパーツ構成
          DEFB      0,-48, 17     ; パーツ相対座標
          DEFB      0,-61,  0
          DEFB    -13,-48,  0
          DEFB      0,-35,  0
          DEFB     13,-48,  0
          DEFB      0, 48, 17
          DEFB      0, 61,  0
          DEFB    -13, 48,  0
          DEFB      0, 35,  0
          DEFB     13, 48,  0
          DEFB    2,3,4,5,2,0,2,1,4,0 ; パーツ接続定義
          DEFB    3,1,5,0,7,8,9,10,7,0
          DEFB    7,6,9,0,8,6,10,0,0

S1BOSMV1: LD      A,(PORIDAT)     ; ボス本体のHP/生存フラグをチェック
          OR      A               ; Aが0かどうか判定
          JR      Z,S1ENDMV1      ; 0（死亡）なら消去へ
          LD      A,(IX+1)        ; ボスの行動タイマー(IX+1)を取得
          INC     (IX+1)          ; タイマーを進める
          CP      16              ; 16未満のとき
          JR      NC,$+12         ; 条件不一致なら次の判定へスキップ
          CALL    MOVE            ; 移動実行
          DEFB    0,0,-8,2,0,0    ; 前進しながら回転
          RET                     ; 復帰
          ;
          CP      32              ; 32未満
          JR      NC,$+12         ; スキップ
          CALL    MOVE            ; 移動
          DEFB    -4,0,0,0,0,0    ; 左へスライド
          RET
          ;
          CP      64              ; 64未満
          JR      NC,$+12         ; スキップ
          CALL    MOVE            ; 移動
          DEFB    4,0,0,0,2,0     ; 右へスライドしつつ回転
          RET
          ;
          CP      80              ; 80未満
          JR      NC,$+12         ; スキップ
          CALL    MOVE            ; 移動
          DEFB    0,0,-4,0,0,0    ; 少し前進
          RET
          ;
          CP      112             ; 112未満
          JR      NC,$+12         ; スキップ
          CALL    MOVE            ; 移動
          DEFB    -4,0,0,0,-2,0   ; 左へ戻りながら逆回転
          RET
          ;
          CP      144             ; 144未満
          JR      NC,$+12         ; スキップ
          CALL    MOVE            ; 移動
          DEFB    2,0,6,1,-2,0    ; 複雑な揺れ
          RET
          ;
          XOR     A               ; A=0
          LD      (IX+1),A        ; タイマーをリセットして行動を繰り返す
          JR      S1BOSMV1        ; ループ先頭へ

S1ENDMV1: LD      A,(IX+15)
          CALL    BOMBOBJ         ; 破壊オブジェクト生成
          XOR     A               ; A=0
          LD      (IX+0),A        ; オブジェクト生存フラグを0にして消去
          RET

S1BOSMV2: LD      A,(PORIDAT)     ; アーム・コア用移動ルーチン
          OR      A               ; ボス死亡判定
          JR      Z,S1ENDMV2      ; 消去へ
          LD      A,(IX+1)        ; タイマー取得
          INC     (IX+1)          ; タイマー進める
          CP      16              ; 行動分岐1
          JR      NC,$+12
          CALL    MOVE
          DEFB    0,0,-8,0,0,2
          RET
          ;
          CP      32              ; 行動分岐2
          JR      NC,$+12
          CALL    MOVE
          DEFB    -4,0,0,0,0,3
          RET
          ;
          CP      64              ; 行動分岐3
          JR      NC,$+12
          CALL    MOVE
          DEFB    4,0,0,0,0,0
          RET
          ;
          CP      80              ; 行動分岐4
          JR      NC,$+12
          CALL    MOVE
          DEFB    0,0,-4,0,0,-3
          RET
          ;
          CP      112             ; 行動分岐5
          JR      NC,$+12
          CALL    MOVE
          DEFB    -4,0,0,0,0,1
          RET
          ;
          CP      144             ; 行動分岐6
          JR      NC,$+12
          CALL    MOVE
          DEFB    2,0,6,-1,0,2
          RET
          ;
          XOR     A               ; タイマーリセット
          LD      (IX+1),A
          JR      S1BOSMV2

S1ENDMV2: CALL    BOMBOBJ         ; 爆発オブジェクト作成
          XOR     A               ; 消去         
          LD      (IX+0),A
          RET

;--- ボス用当たり判定処理 ---
TUCH18:   CALL    TUCH2           ; 基本のダメージ/接触処理を呼ぶ
          ; 自機を弾き飛ばす処理
          LD      A,(MASTER+9)    ; 自機のZ座標取得
          XOR     127             ; ビット反転
          ADD     A,17            ; 補正
          LD      (MASTER+9),A    ; 書き戻し
          RET                     ; 終了

;--- ボス敵（クリスタル）の当たり判定処理 ---
TUCH19:   CALL    DAMAGESD          ; 被弾音
          LD      A,32            ; ダメージパラメータ
          LD      (MASTER+8),A    
          LD      A,(IX+13)       ; 敵のカラーロード
          CP      9               ; カラー9か？（ライフ2）
          JR      NZ,$+8          ; 
          LD      A,8             ; カラー8にランクダウン
          LD      (IX+13),A       
          RET
          CP      8               ; カラー8か？（ライフ1）
          JR      NZ,$+8          
          LD      A,6             ; カラー6にランクダウン
          LD      (IX+13),A       
          RET
          XOR     A               ; それ以外なら（3回目で）
          LD      (IX+0),A        ; オブジェクト消滅
          CALL    BOMBOBJ         ; 破壊オブジェクト生成
          RET

;--- ボスコア 形状データ ---
S1COREPT: DEFB    6,0             ; 頂点数6
          DEFB      0,-24,  0     ; 頂点相対座標（コア）
          DEFB      0, 24,  0
          DEFB      0,  0,-13
          DEFB    -14,  0,  0
          DEFB      0,  0, 13
          DEFB     13,  0,  0
          DEFB    1,4,2,6,1,0,5,4,3,6,5,0 ; 線引き定義
          DEFB    1,3,2,5,1,0,0
          
;--- ボス戦セクション ---
S1BOSS:   
;          CALL    DSET
;          DEFW    S1CRASHM,MHYOUJ ; "CRASH THE CRYSTAL"
;          DEFB    10,128,1,3,0      ; 座標
;          DEFB    96,80,0,00110101B ; 属性
;          LD      A,128
          CALL    DSET            ; ボス警告表示
          DEFW    S1ATACKM,MHYOUJ ; "ATTACK"
          DEFB    9,16,1,1,0      ; 座標
          DEFB    68,80,0,00100101B ; 属性
          LD      A,17            ; 17フレーム待機
          CALL    MAIN            ; 
          CALL    CLSPRI          ; オブジェクトワークエリア全消去
          ;
          ; ボス本体・パーツの組み立て
          CALL    DSET            ; コアオブジェクト生成
          DEFW    S1COREPT,S1BOSMV2 ; コア形状と移動ルーチン
          DEFB    128,128,230     ; X, Y, Z初期位置
          DEFB    0,0,0,9,9,00000000B ; 各種フラグ
          CALL    DSET            ; アーム1オブジェクト生成
          DEFW    S1BOSSPT,S1BOSMV1 ; アーム形状と移動ルーチン1
          DEFB    128,128,230     ; X, Y, Z初期位置
          DEFB    0,0,0,5,8,00000000B ; フラグ
          CALL    DSET            ; アーム2オブジェクト生成
          DEFW    S1BOSSPT,S1BOSMV2 ; アーム形状と移動ルーチン2
          DEFB    128,128,230     ; X, Y, Z
          DEFB    8,0,0,5,8,00000000B ; フラグ
          ;
S1LOOP8:  LD      A,1             ; ボス戦中のメインループ
          CALL    MAIN            ; 更新
          LD      A,(PORIDAT)     ; ボスの生存フラグを取得
          OR      A               ; 0（撃破）かチェック
          JR      NZ,S1LOOP8      ; まだ生きていればループ継続
          ;   
          ; ボス撃破後の自機HOME帰還処理
          LD      HL,HOME         ; 帰還ルーチンのアドレス
          LD      (MASTER+5),HL   ; プレイヤー移動ルーチンをHOMEに書き換え
S1LOOP9:  LD      A,1             ; 帰還演出ループ
          CALL    MAIN            ; 画面更新
          LD      A,(MASTER+1)    ; 自機状態フラグ取得
          OR      A               ; 帰還完了かチェック
          JR      NZ,S1LOOP9      ; 完了まで待機
          
          ;--- ステージクリア リザルト演出 ---
          CALL    DSET            ; 「ZONE 1」再表示
          DEFW    S1STAGM1,MHYOUJ
          DEFB    10,24,0,0,0,38,8
          DEFB    0,00000101B
          CALL    DSET            ; 「CLEAR」表示
          DEFW    S1CLEARM,MHYOUJ
          DEFB    10,24,0,0,0,38,134
          DEFB    0,00000101B
          LD      A,28            ; 28フレーム表示維持
          CALL    MAIN
          CALL    DSET            ; 「BONUS」表示
          DEFW    S1BONUSM,MHYOUJ
          DEFB    10,24,0,0,0,0,55
          DEFB    0,00000101B
          CALL    DSET            ; 「1000」などのスコア表示
          DEFW    S1SCOREM,MHYOUJ
          DEFB    10,24,0,0,0,8,80
          DEFB    0,00010101B
          
          LD      DE,1000         ; 1000点加算
          CALL    SCOREUP
          
          LD      A,1             ; 
          CALL    STOCKUP         ; 残機アップ（1機）
          
          LD      A,30            ; 30フレーム待機
          CALL    MAIN
          CALL    FADE            ; 画面フェードアウト
          LD      A,24            ; 24フレーム待機
          CALL    MAIN
          CALL    SDOFF           ; サウンド全停止
          RET                     ; 呼び出し元へ戻り、次のステージへ


;--- テキストメッセージ用キャラクタデータ ---
S1ATACKM: DEFB    'A',20,0,'T',40,0,'A',60,0,'C',80,0,'K',100,0,0 ; "ATTACK"
S1CRASHM: DEFB    'C',0,0,'L',16,0,'A',32,0,'S',48,0,'H',64,0,'T',16,30,'H',32,30,'E',48,30,'C',-16,60,'R',0,60,'Y',16,60,'S',32,60,'T',48,60,'A',64,60,'L',82,60,0 ; "CLASH THE CRYSTAL"
S1CLEARM: DEFB    'C',60,30,'L',75,30,'E',90,30,'A',105,30,'R',120,30,0 ; "CLEAR"
S1BONUSM: DEFB    'B',88,30,'O',108,30,'N',128,30,'U',148,30,'S',168,30,0 ; "BONUS"
S1SCOREM: DEFB    '1',98,60,'0',113,60,'0',128,60,'0',142,60 ; "1000"
          DEFB    '1',98,90,'U',113,90,'P',128,90,0 ; "1UP"

;-----------------------------------------------------------
;
; STAGE 2
;
;-----------------------------------------------------------
;--- ステージ2 開始初期化ルーチン ---
STAGE2:   CALL    CLSPRI          ; オブジェクトワークエリア全消去
          LD      (STACK),SP      ; 現在のスタックポインタを退避
          LD      A,00001000B     ; 画面制御用ビットパターン
          LD      (SWITCH),A      ; 設定をワークエリアに書き込み
          ;
          CALL    DSET            ; 「ZONE 2」文字表示オブジェクト生成
          DEFW    S2STAGM1,MHYOUJ ; 文字データと表示ルーチンを指定
          DEFB    12,40,0,0,0,44  ;
          DEFB    0,0,00010101B   ; 
          ;
          CALL    DSET            ; 「FOREST」文字表示オブジェクト生成
          DEFW    S2STAGM2,MHYOUJ ; 文字データと表示ルーチンを指定
          DEFB    12,40,0,0,0,26  ;
          DEFB    50,0,00000101B  ;
          ;
          CALL    UNFADE          ; 画面を徐々に明るくする（フェードイン）
          LD      A,32            ; 32フレームMAINを実行
          CALL    MAIN            ; 
          CALL    FADE            ; 画面を徐々に暗くする（フェードアウト）
          LD      A,8             ; 8フレームMAINを実行
          CALL    MAIN            ; 
          CALL    MSSTR           ; 自機オブジェクト出現ルーチン
          ;
;--- ステージ進行メインスクロール設定 ---
S2CONT:   CALL    MOVESD          ; 移動サウンドコール
          LD      HL,S2STAGD1     ; ステージ2の基本データのアドレス
          LD      DE,GAMEWORK     ; ワークエリアのアドレス
          LD      BC,9            ; データ長9バイト
          LDIR                    ; データを一気に転送
          LD      HL,S2JPDAT1     ; ステージ2用の当たり判定ジャンプテーブル
          LD      DE,JPTUCH       ; 当たり判定ワークエリア
          LD      BC,32           ; テーブル長32バイト
          LDIR                    ; テーブルを転送して判定を切り替え
          LD      A,24            ; 24フレームMAINを実行
          CALL    MAIN            ; 
          ;
          LD      B,128           ; 前半戦の敵出現ループ回数を128に設定
S2LOOP:   LD      HL,S2RETLOP     ; ループの戻り先アドレスをHLにロード
          PUSH    HL              ; スタックに積む（RET命令でここに戻るようにする技法）
          CALL    TURBO           ; ターボアイテム作成ルーチンコール
          CALL    CURE            ; 回復アイテム作成ルーチンコール
          CALL    GOD_ITEM        ; 無敵化ルーチン
          CALL    ALL_BOMB        ; 全破壊ルーチン
          LD      A,B             ; 現在のループカウンタをAにロード
          CP      64              ; カウンタが64か？（ステージ中間地点）
          JP      Z,S2CHARA2      ; 64なら敵2（十字架）を強制的に出す
          JR      C,S2J1          ; 64未満（後半）ならS2J1の出現分岐へ
          CALL    RND             ; 乱数を取得
          CP      100             ; 乱数が100未満（約40%）なら
          JP      C,S2CHARA3      ; 敵3（木）を出す
          CP      150             ; 150未満なら
          JP      C,S2CHARA6      ; 敵6（直進する鳥）を出す
          CP      170             ; 170未満なら
          JP      C,S2CHARA7      ; 敵7（安地攻撃）を出す
          CP      180             ; 180未満なら
          JP      C,TECHNO        ; テクノイト作成
          CP      215             ; 215未満なら
          JP      C,PARTY         ; 人間かキャンプを作成
          RET                     ; 乱数が高ければ何も出さずに戻る
          ;
;--- 前半ループ内の細かい条件分岐 ---
S2J1:     CP      48              ; 残りカウンタが48以上か？
          RET     NC              ; 48以上なら何もせず戻る
          CP      40              ; 40以上なら
          JP      NC,S2CHARA4     ; 敵4（旋回する鳥）を出す
          CP      32              ; 32以上なら
          JP      NC,S2CHARA5     ; 敵5（上下動する鳥）を出す
          CP      28              ; 28以上なら
          RET     NC              ; 何もせず戻る
          CP      20              ; 20ちょうどか？
          JP      Z,S2CHARA2      ; 20なら敵2（十字架）を出す
          AND     2
          JP      Z,S2CHARA7      ; 0-19なら敵7（鳥型）を出す
          POP     HL              ; 全条件から漏れたらPUSHしたアドレスを破棄
          ;
;--- ループ内の待機・更新処理 ---
S2RETLOP: CALL    RND             ; 乱数を取得
          AND     3               ; 下位2ビットのみ残す（0?3）
          ADD     A,2             ; 2を足して、2?5フレームのウェイトを作る
          CALL    MAIN            ; 指定フレーム分、画面を更新
          DJNZ    S2LOOP          ; Bレジスタを減らして0でなければS2LOOPへ
          ;
          LD      A,(SWITCH)      ; 表示フラグ読み込み
          AND     11111110B       ; 地平線をオフにする
          LD      (SWITCH),A      ; 更新
          LD      HL,S2CONT2      ;「後半」のアドレスを
          LD      (CONTRT),HL     ; コンティニュー先として保存
          ;
;--- ステージ後半：ラッシュ演出 ---
S2CONT2:  CALL    MOVESD          ; 移動サウンドコール（コンティニュー用）
          LD      A,24            ; 24フレームMAINを実行
          CALL    MAIN            ; 
          LD      B,192           ; 後半ループは長めの192回
S2LOOP2:  CALL    TURBO           ; ターボアイテム作成ルーチンコール
          CALL    CURE            ; 回復アイテム作成ルーチンコール
          CALL    GOD_ITEM        ; 無敵化ルーチン
          CALL    ALL_BOMB        ; 全破壊ルーチン
          LD      HL,S2RETLP3     ; 共通戻り先アドレスをセット
          PUSH    HL              ; スタックに積む
          CALL    RND             ; 乱数発生
          CP      80              ; 80未満
          JP      C,S2CHARA3      ; 敵3
          CP      110             ; 110未満
          JP      C,S2CHARA6      ; 敵6
          CP      135             ; 135未満
          JP      C,S2CHARA4      ; 敵4
          CP      145             ; 145未満
          JP      C,S2CHARA5      ; 敵5
          CP      155             ; 155未満
          JP      C,S2CHARA1      ; 敵1
          CP      180             ; 180未満
          JP      C,S2CHARA7      ; 敵7
          CP      190             ; 190未満
          JP      C,TECHNO        ; テクノイト
          CP      220             ; 220未満
          JP      C,PARTY         ; 人間かキャンプ
          POP     HL              ; 該当なしならスタックからアドレスを捨てる
S2RETLP3: LD      A,B             ; Bレジスタ（残りループ数）をAに
          RLCA                    ; 2倍
          RLCA                    ; 4倍（カウンタに応じてウェイトを変化させる演出）
          AND     3               ; 0?3に制限
          ADD     A,2             ; 2を足してウェイト
          CALL    MAIN            ; Aの回数MAIN実行
          DJNZ    S2LOOP2         ; ループ継続
          ;
          LD      A,32            ; 32フレームMAIN実行（ボス直前の待ち）
          CALL    MAIN            ; 
          JP      S2BOSS          ; ボス戦ルーチンへ

;--- ステージ2 固定データセクション ---
S2STAGD1: DEFB    32,5,12,2       ; スクロールスピードや色等の設定
          DEFB    01011011B       ; 各種制御フラグ
          DEFW    S2CONT,DEAD     ; 復帰用アドレスと死亡時アドレス

S2JPDAT1: DEFW    TUCH0,TUCH1     ; 当たり判定時のジャンプ先リスト
          DEFW    TUCH2,TUCH3     ; ジャンプテーブル本体
          DEFW    TUCH4,TUCH5
          DEFW    TUCH6,TUCH7
          DEFW    TUCH28,TUCH29   ; ステージ2特有の当たり判定（ボス用）
          DEFW    TUCHNONE,TUCHNONE
          DEFW    TUCHNONE,TUCHNONE
          DEFW    TUCHNONE,TUCHNONE

S2STAGM1: DEFB    'Z',60,80       ; 「ZONE 2」の各文字と表示座標(X, Y)
          DEFB    'O',75,80
          DEFB    'N',90,80
          DEFB    'E',105,80
          DEFB    '2',120,80,0    ; 終端の0
S2STAGM2: DEFB    'F',30,80       ; 「FOREST」の文字と表示座標
          DEFB    'O',60,80
          DEFB    'R',90,80
          DEFB    'E',120,80
          DEFB    'S',150,80
          DEFB    'T',180,80,0    ; 終端の0

;-----------------------------------------------------------
; 敵1：鳥型機 (S2CHARA1) の生成
;-----------------------------------------------------------
S2CHARA1: CALL    RND             ; 乱数発生
          AND     127             ; 127までに制限
          ADD     A,90            ; 90を足して出現X座標を決定
          LD      (S2CHARD1+4),A  ; 出現データにX座標を直接書き込む
          CALL    DSET            ; 敵オブジェクトを生成
S2CHARD1: DEFW    S2CHPD11,S2CHARP1 ; 形状データアドレス, 移動ルーチンアドレス
          DEFB    0,225,245,0,0,0 ; 座標、回転値
          DEFB    13,1,00000000B  ; 色・属性フラグ
          RET

;--- 形状データ：羽ばたき（通常） ---
S2CHPD11: DEFB    6,0             ; 頂点数6
          DEFB      0,  0,-20     ; 頂点1の座標
          DEFB    -30,-10,-10     ; 頂点2
          DEFB     30,-10,-10     ; 頂点3
          DEFB      0,  0, 40     ; 頂点4
          DEFB    -10,-16,-20     ; 頂点5
          DEFB     10,-16,-20     ; 頂点6
          DEFB    1,2,4,3,1,4,0,5,1,6,0,0 ; 結線データ

;--- 形状データ：羽ばたき（翼が上がった状態） ---
S2CHPD12: DEFB    6,0             ; 頂点数6
          DEFB      0,  0,-20     
          DEFB    -20, 20,-10     ; 翼の頂点がY方向に移動している
          DEFB     20, 20,-10     
          DEFB      0,  0, 40     
          DEFB    -10,-16,-20     
          DEFB     10,-16,-20     
          DEFB    1,2,4,3,1,4,0,5,1,6,0,0 ; 結線データ

;--- アニメーション：羽ばたき処理ルーチン ---
S2HABATA: LD      A,(IX+1)        ; ワークエリアからアニメーションタイマー取得
          INC     (IX+1)          ; タイマーを加算
          LD      C,A             ; 値を退避
          LD      HL,S2CHPD11     ; 通常の形状をHLに
          AND     2               ; タイマーのビット2をチェック（パタパタさせる）
          JR      Z,$+5           ; ビットが立っていなければそのまま
          LD      HL,S2CHPD12     ; ビットが立っていれば形状2（羽上げ）にする
          LD      (IX+3),L        ; 実行中のオブジェクトの形状ポインタLを上書き
          LD      (IX+4),H        ; 形状ポインタHを上書き（これで見た目が変わる）
          LD      A,C             ; タイマー値を戻す
          RET

;--- 敵1：移動アルゴリズム ---
S2CHARP1: CALL    S2HABATA        ; まず羽ばたかせる
          CP      8               ; 生成から8フレーム経過したか？
          JR      NC,$+11         ; 8フレーム以上なら次のフェーズへ
          LD      A,(IX+9)        ; Z座標（奥行き）をロード
          SUB     16              ; 16減算（高速で手前に接近）
          LD      (IX+9),A        ; 書き戻し
          RET
          CP      40              ; 40フレーム経過したか？
          JR      NC,$+21         ; 40フレーム以上なら直線移動フェーズへ
          CALL    RTURN           ; 旋回処理呼び出し
          DEFB    128,128,128,0,2,0 ; 旋回パラメータ
          CALL    MOVE            ; 移動処理呼び出し
          DEFB    -2,0,0,0,2,0    ; 横にスライドする動き
          RET
          ;
          LD      A,(IX+9)        ; 40フレーム以降の動き
          SUB     16              ; 手前に接近
          LD      (IX+9),A        ; 更新
          RET
;-----------------------------------------------------------
; 敵2：十字架の生成
;-----------------------------------------------------------

S2CHARA2: CALL    RND             ; 乱数
          AND     31              ; 0?31
          ADD     A,112           ; 画面中央寄りに
          LD      (S2CHARD2+4),A  ; X座標セット
          CALL    DSET            ; 登録
S2CHARD2: DEFW    S2CHAPD2,S2CHARP2 ; 巨大形状データ, 移動2
          DEFB    128,128,245,0,0,0 ; 位置初期値
          DEFB    12,2,00000010B  ; 色・属性
          RET

;--- 敵2：巨大形状データ（頂点と結線の塊） ---
S2CHAPD2: DEFB    32,3            ; 頂点数32
          DEFB     -8,-50,  8     ; 以下、各頂点の3D座標が並ぶ
          DEFB      8,-50,  8
          DEFB      8, -8,  8
          DEFB     50, -8,  8
          DEFB     50,  8,  8
          DEFB      8,  8,  8
          DEFB      8, 50,  8
          DEFB     -8, 50,  8
          DEFB     -8,  8,  8
          DEFB    -50,  8,  8
          DEFB    -50, -8,  8
          DEFB     -8, -8,  8
          DEFB     -8,-50, -8
          DEFB      8,-50, -8
          DEFB      8, -8, -8
          DEFB     50, -8, -8
          DEFB     50,  8, -8
          DEFB      8,  8, -8
          DEFB      8, 50, -8
          DEFB     -8, 50, -8
          DEFB     -8,  8, -8
          DEFB    -50,  8, -8
          DEFB    -50, -8, -8
          DEFB     -8, -8, -8
          DEFB    -25,  0, -8     ; 追加パーツの頂点
          DEFB    -25,  0,  8
          DEFB    -25,  0, -8
          DEFB    -25,  0,  8
          DEFB      0, 25, -8
          DEFB      0, 25,  8
          DEFB      0,-25, -8
          DEFB      0,-25,  8
          DEFB    1,2,3,4,5,6,7,8,9,10,11,12,1,0 ; 輪郭1の結線順
          DEFB    13,14,15,16,17,18,19,20,21,22,23,24,13,0 ; 輪郭2の結線順
          DEFB    1,13,0,2,14,0,3,15,0,4,16,0,5,17,0 ; 奥行き方向の結線
          DEFB    6,18,0,7,19,0,8,20,0,9,21,0,10,22,0
          DEFB    11,23,0,12,24,0,0 ; 結線終わり

;--- 敵2：十字架移動アルゴリズム（サイケデリック回転）---
S2CHARP2: LD      A,(IX+13)       ; カラー属性ロード
          XOR     15              ; カラー値を反転させて激しく点滅させる
          LD      (IX+13),A       ; 書き戻し
          LD      A,(IX+1)        ; タイマー
          INC     (IX+1)          ; 加算
          CP      8               ; 8フレームまで
          JR      NC,$+12         ; 
          CALL    MOVE            ; 移動
          DEFB    0,0,-24,2,0,0   ; 猛スピードで画面手前へ
          RET
          ;
          CP      40              ; 40フレームまで
          JR      NC,$+17         ; 
          CALL    MOVE            ; 
          DEFB    0,0,0,1,-2,-1   ; 特殊な回転角の増分で捻るような動き
          AND     15
          CALL    Z,S2CHARA7
          RET
          ;
          CP      72              ; 72フレームまで
          JR      NC,$+17         ; 
          CALL    MOVE            ; 
          DEFB    0,0,0,2,1,2     ; 回転軸を変えてさらに複雑に回る
          AND     15
          CALL    Z,S2CHARA7
          RET
          ;
          CALL    MOVE            ; それ以降
          DEFB    0,0,-8,2,0,0    ; ゆっくり前進しながら回転維持
          RET
;-----------------------------------------------------------
; 敵3：木の生成
;-----------------------------------------------------------
S2CHARA3: CALL    RND             ; 乱数
          CP      200             ; 200以上なら
          JR      NC,$-5          ; やり直し（出現率調整）
          ADD     A,25            ; X座標オフセット
          LD      (S2CHARD3+4),A  ; 書き込み
          LD      HL,S2CHRP31     ; デフォルトで倒れるルーチン
          CALL    RND             ; 再び乱数
          AND     00010100B       ; 特殊ビットチェック
          JR      Z,$+5           ; 通常ならそのまま
          LD      HL,S2CHRP32     ; 当たりなら倒れないルーチン（急接近）
          LD      (S2CHARD3+2),HL ; ポインタ書き換え
          CALL    DSET            ; 木オブジェクト生成
S2CHARD3: DEFW    S2CHAPD3,S2CHRP31 ; 形状, 移動ルーチン
          DEFB    128,225,255     ; 初期位置
          DEFB    0,0,0,12,2,00000000B ; パラメータ
          RET

;--- 敵3：通常前方移動 ---
S2CHRP32: LD      A,(IX+9)        ; Z座標
          SUB     24              ; 大幅に減算して急接近
          LD      (IX+9),A        ; 更新
          RET

;--- 敵3：木が倒れる移動 ---
S2CHRP31: LD      A,(IX+1)        ; フェーズ確認（カウンタを利用）
          CP      1               ; フェーズ1（倒れるモード）か？
          JR      Z,S2CJ5         ; ならば倒れる処理へ
          LD      A,(IX+9)        ; フェーズ0：接近中
          SUB     24              ; 高速接近
          LD      (IX+9),A        ; 更新
          LD      C,A             ; Z座標を退避
          LD      A,(MASTER+9)    ; 自機のZ座標取得
          NEG                     ; 反転
          ADD     A,C             ; 自機との距離計算
          CP      60              ; 十分に近づいたか？
          RET     NC              ; まだなら戻る
          ;
          LD      A,1             ; フェーズ1へ
          LD      (IX+1),1        ; フラグセット
          RET
S2CJ5:    LD      A,(IX+9)        ; 木が倒れるモード
          SUB     16              ; 少し速度を落とす
          LD      (IX+9),A        ; 更新
          LD      A,(IX+7)        ; X座標取得
          CP      128             ; 画面右半分にいるか？
          LD      A,(IX+10)       ; 回転角をロード
          JR      NC,S2CJ52       ; 右側なら別の回転処理へ
          CP      8               ; 角度上限（90度）
          RET     NC              
          ADD     A,2             ; 回転角を加算
          LD      (IX+10),A       ; 更新
          RET
S2CJ52:   SUB     2               ; 回転角を減算（反対に倒す）
          AND     31              ; 0?31に丸める
          CP      24              ; 下限チェック
          RET     C               
          LD      (IX+10),A       ; 更新
          RET

;--- 敵3：木の形状データ ---
S2CHAPD3: DEFB    10,0            ; 頂点10
          DEFB      0,-127, 0     ; 巨大なスケールの頂点（拡大縮小で使う？）
          DEFB    -17,  0, 17
          DEFB     -7,  0,-23
          DEFB     23,  0,  7
          DEFB    -11,-43,  0     ; ここから6個は当たり判定用ダミー頂点
          DEFB     -5,-43,  0
          DEFB     16,-43,  0
          DEFB     -8,-86,  0
          DEFB     -2,-86,  0
          DEFB      8,-86,  0
          DEFB    1,2,3,1,4,2,0,4,3,0,0 ; 結線
;-----------------------------------------------------------
; 敵4：旋回敵生成処理
;-----------------------------------------------------------
S2CHARA4: CALL    RND             
          AND     127             
          ADD     A,64            
          LD      (S2CHARD4+4),A  
          CALL    RND             
          AND     31              
          ADD     A,180           
          LD      (S2CHARD4+5),A  
          CALL    DSET            
S2CHARD4: DEFW    S2CHPD11,S2CHARP4 ; 生成データ
          DEFB    0,0,240,0,0,0   
          DEFB    11,1,00000000B  
          RET
          
;--- 敵4：旋回敵 移動ルーチン ---
S2CHARP4: CALL    S2HABATA        ; 羽ばたき
          CALL    RTURN           ; ぐるぐる回る
          DEFB    128,128,128,2,0,0 
          CALL    MOVE            ; 前進
          DEFB    0,0,-8,2,0,0    
          RET
;-----------------------------------------------------------
; 敵5：トリッキーな上下移動敵の生成
;-----------------------------------------------------------
S2CHARA5: CALL    RND             ; 乱数
          LD      (S2CHARD5+4),A  ; X座標セット
          CALL    DSET            ; 登録
S2CHARD5: DEFW    S2CHPD11,S2CHARP5 ; 形状は敵1と同じ（鳥）、ルーチンは専用
          DEFB    0,215,245,0,0,0 
          DEFB    5,1,00000000B   ; 低めの耐久力
          RET

;--- 敵5：移動ルーチン ---
S2CHARP5: CALL    S2HABATA        ; 羽ばたき
          CP      4               ; 行動フェーズ1
          JR      NC,$+12         
          CALL    MOVE            
          DEFB    0,-22,-8,0,2,0  ; 上へ移動
          RET
          ;
          CP      8               ; フェーズ2
          JR      NC,$+12         
          CALL    MOVE            
          DEFB    0,-22,-8,0,-2,0 ; 上移動・回転は逆回転
          RET
          ;
          CP      12              ; フェーズ3
          JR      NC,$+12         
          CALL    MOVE            
          DEFB    0,22,-8,0,-2,0  ; 下移動・逆回転
          RET
          ;
          CP      16              ; フェーズ4
          JR      NC,$+12         
          CALL    MOVE            
          DEFB    0,22,-8,0,2,0   ; 下移動・回転は戻すように
          RET
          ;
          XOR     A               ; タイマーリセット
          LD      (IX+1),A        ; 最初に戻る
          JR      S2CHARP5
;-----------------------------------------------------------
; 敵6：直進敵の生成
;-----------------------------------------------------------
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

;--- 敵6：移動ルーチン（ひたすら真っ直ぐ！） ---
S2CHARP6: CALL    S2HABATA        
          LD      A,(IX+9)        ; Z座標
          SUB     24              ; 最高速度で接近
          LD      (IX+9),A        
          RET
          
;-----------------------------------------------------------
; 敵7：安全地帯を襲ってくる直進敵の生成
;-----------------------------------------------------------
S2CHARA7: CALL    RND       
          AND     3
          CP      1             
          JR      NZ,S2E7J1
          CALL    DSET
          DEFW    S2CHPD11,S2CHARP7 
          DEFB    30,30,255,0,0,0   
          DEFB    10,1,00000000B  
          RET
S2E7J1:   CP      2
          JR      NZ,S2E7J2
          CALL    DSET
          DEFW    S2CHPD11,S2CHARP7 
          DEFB    225,30,255,0,0,0   
          DEFB    10,1,00000000B  
          RET
S2E7J2:   CP      3
          JR      NZ,S2E7J3
          CALL    DSET
          DEFW    S2CHPD11,S2CHARP7 
          DEFB    30,225,255,0,0,0   
          DEFB    10,1,00000000B  
          RET
S2E7J3:   CALL    DSET
          DEFW    S2CHPD11,S2CHARP7 
          DEFB    225,225,255,0,0,0   
          DEFB    10,1,00000000B  
          RET

;--- 敵7：移動ルーチン（ひたすら真っ直ぐ！） ---
S2CHARP7: CALL    S2HABATA        
          LD      A,(IX+9)        ; Z座標
          SUB     24              ; 最高速度で接近
          LD      (IX+9),A        
          RET
;-----------------------------------------------------------
; ボス戦開始処理
;-----------------------------------------------------------
S2BOSS:   CALL    DSET            ; 警告メッセージ「ATTACK」表示オブジェクト生成
          DEFW    S2ATACKM,MHYOUJ 
          DEFB    9,16,1,1,0
          DEFB    72,80,0,00100101B
          LD      A,17            ; 表示待ちに17フレームMAINを実行
          CALL    MAIN
          CALL    CLSPRI          ; オブジェクトワークエリア全消去
          CALL    DSET            ; ボスの核を生成
          DEFW    S2COREPT,S2BOSMV2 ; コア形状, コア移動
          DEFB    128,56,64       ; 出現位置
          DEFB    0,0,0,9,9,00000000B
          CALL    DSET            ; ボスの鳥（核をもっている）を生成
          DEFW    S2CHPD11,S2BOSMV3 ; 形状, オプション移動
          DEFB    128,32,64       
          DEFB    0,0,0,9,8,00000010B
          LD      HL,4005H        ; 座標パラメータ1をHLにセット
          CALL    S2BOSS2         ; ボスの周りを回る鳥の生成1
          LD      A,8             ; 待機
          CALL    MAIN
          LD      HL,0C00DH       ; 
          CALL    S2BOSS2         ; ボスの周りを回る鳥の生成2
          LD      A,8             ; 
          CALL    MAIN
          LD      HL,800BH        ; 
          CALL    S2BOSS2         ; ボスの周りを回る鳥の生成3
          ;
;--- ボス戦ループ（決着待ち） ---
S2LOOP8:  LD      A,1             ; 1フレーム更新
          CALL    MAIN
          LD      A,(PORIDAT)     ; ボスの生存フラグ（コアのHP等）を確認
          OR      A               ; 0になったか？
          JR      NZ,S2LOOP8      ; 生きていれば継続
          ;
;--- ボス撃破後の自機帰還演出 ---
          LD      HL,HOME         ; 自動帰還のアドレス
          LD      (MASTER+5),HL   ; 自機オブジェクトの挙動を帰還ルーチンに書き換える
S2LOOP9:  LD      A,1             ; 更新
          CALL    MAIN
          LD      A,(MASTER+1)    ; 帰還完了フラグチェック
          OR      A
          JR      NZ,S2LOOP9      ; 完了まで待機
          ;          
;--- ステージクリア表示とボーナス計算 ---
          CALL    DSET            ; 「ZONE 2」表示オブジェクト生成
          DEFW    S2STAGM1,MHYOUJ
          DEFB    2,24,0,0,0,38,8
          DEFB    0,00000101B
          CALL    DSET            ; 「CLEAR」表示オブジェクト生成
          DEFW    S2CLEARM,MHYOUJ
          DEFB    2,24,0,0,0,38,134
          DEFB    0,00000101B
          LD      A,28            ;  28フレーム表示
          CALL    MAIN
          CALL    DSET            ; 「BONUS」表示オブジェクト生成
          DEFW    S2BONUSM,MHYOUJ
          DEFB    2,24,0,0,0,0,55
          DEFB    0,00000101B
          CALL    DSET            ; 「SCORE」表示オブジェクト生成
          DEFW    S2SCOREM,MHYOUJ
          DEFB    2,24,0,0,0,8,80
          DEFB    0,00010101B
          ;
          LD      DE,2000         ; ステージクリアボーナス 2000点
          CALL    SCOREUP         ; スコア加算
          ;
          LD      A,1             ; ステージクリアボーナス 1機
          CALL    STOCKUP         ; 自機加算
          ;
          LD      A,30            ; 終了ウェイト
          CALL    MAIN
          CALL    FADE            ; 暗転
          LD      A,24            ; 
          CALL    SDOFF           ; サウンド停止
          CALL    MAIN            ; 
          RET                     ; ステージ2 全行程終了

;-----------------------------------------------------------
; サブボス敵生成ルーチン
;-----------------------------------------------------------

S2BOSS2:  LD      A,H             ; 引数の座標HをAに
          LD      (S2BOSRD2+5),A  ; 生成データ(Y座標)を直接書き換え
          LD      A,L             ; 引数の座標LをAに
          LD      (S2BOSRD2+10),A ; 生成データ(属性)を直接書き換え
          CALL    DSET            ; 部位を生成
S2BOSRD2: DEFW    S2CHPD11,S2BOSMV ; 鳥の姿をしたボスのパーツ
          DEFB    192,128,102,0,0,0 
          DEFB    7,8,00000000B   
          RET

;--- サブボス鳥：移動と攻撃 ---
S2BOSMV:  LD      A,(PORIDAT)     ; ボスの核が生きているか確認
          OR      A               
          JR      NZ,$+9          ; コア死亡なら
          LD      (IX+0),A        ; 自分も道連れで消滅
          CALL    BOMBOBJ         ; 破壊オブジェクト生成
          RET                     
          CALL    RND             ; 乱数で攻撃判定
          AND     31              ; 1/32の確率で
          CALL    Z,S2FUN         ; 糞を発射
          CALL    S2HABATA        ; アニメーション
          CP      4               ; パーツごとの周期移動
          JR      NC,$+12         
          CALL    MOVE            
          DEFB    0,0,-18,0,0,-2  
          RET                     
          ;
          CP      12              
          JR      NC,$+12         
          CALL    MOVE            
          DEFB    -18,0,0,0,0,-1  
          RET                     
          ;
          CP      16              
          JR      NC,$+12         
          CALL    MOVE            
          DEFB    0,0,18,0,0,-2   
          RET                     
          ;
          CP      24              
          JR      NC,$+12         
          CALL    MOVE            
          DEFB    18,0,0,0,0,-1   
          RET                     
          ;
          XOR     A               ; 移動タイマーリセット
          LD      (IX+1),A        
          JR      S2BOSMV         

;--- ボスコア（クリスタル）：独自の上下移動ルーチン ---
S2BOSMV2: LD      A,(IX+1)        ; タイマー
          INC     (IX+1)          
          CP      16              ; フェーズ1
          JR      NC,$+12         
          CALL    MOVE            
          DEFB    0,8,0,0,0,1     ; 上へ
          RET                     
          ;
          CP      32              ; フェーズ2
          JR      NC,$+12         
          CALL    MOVE            
          DEFB    0,-8,0,0,0,1    ; 下へ
          RET                     
          ;
          XOR     A               
          LD      (IX+1),A        
          JR      S2BOSMV2        

;--- ボス鳥：前後スライド移動 ---
S2BOSMV3: LD      A,(PORIDAT)     
          OR      A               
          JR      NZ,$+9
          LD      (IX+0),A        
          CALL    BOMBOBJ         ; 破壊オブジェクト生成
          RET                     
          CALL    S2HABATA        
          CP      16              ; 手前へスライド
          JR      NC,$+11         
          LD      A,(IX+8)        
          ADD     A,8             
          LD      (IX+8),A        
          RET                     
          CP      32              ; 奥へスライド
          JR      NC,$+11         
          LD      A,(IX+8)        
          SUB     8               
          LD      (IX+8),A        
          RET                     
          XOR     A               
          LD      (IX+1),A     
          JR      S2BOSMV3        

;--- ボス攻撃：糞の生成 ---
S2FUN:    LD      A,(IX+7)        ; 親機（部位）のX座標
          LD      (S2FUNRD+4),A   ; 弾の初期Xにセット
          LD      A,(IX+8)        ; Y座標
          LD      (S2FUNRD+5),A   ; 弾の初期Yにセット
          LD      A,(IX+9)        ; Z座標
          LD      (S2FUNRD+6),A   ; 弾の初期Zにセット
          CALL    DSET            ; 弾オブジェクト生成
S2FUNRD:  DEFW    S2FUNPD,S2FUNMV ; 弾の形状, 弾の移動
          DEFB    0,0,0,0,0,0     
          DEFB    8,1,00000000B   
          RET                     

;--- ボス攻撃：糞の移動ルーチン（直進接近） ---
S2FUNMV:  LD      A,(IX+8)        ; Y座標ロード
          ADD     A,16            ; 迫りくる速度で加算
          LD      (IX+8),A        
          RET                     

;--- ボス攻撃：糞の形状データ（扇形） ---
S2FUNPD:  DEFB    4,0             ; 頂点4
          DEFB     -8,  5, -5     
          DEFB      8,  5, -5     
          DEFB      0,  5,  9     
          DEFB      0, -9,  0     
          DEFB    1,2,3,1,4,2,0   ; 結線1
          DEFB    4,3,0,0         ; 結線2
          

;--- ボス敵（鳥）の当たり処理 ---
TUCH28:   CALL    TUCH2           ; 基本のダメージ判定
          ; 自機を弾き飛ばす処理
          LD      A,(MASTER+9)    ; 自機のZ座標
          XOR     127             ; ビット反転（手前と奥を入れ替えるような演出）
          ADD     A,17            ; 位置微調整
          LD      (MASTER+9),A    ; 強制書き換え
          RET

;--- ボス敵（クリスタル）の当たり判定処理 ---
TUCH29:   CALL    DAMAGESD          ; 被弾音
          LD      A,32            ; ダメージパラメータ
          LD      (MASTER+8),A    
          LD      A,(IX+13)       ; 敵のカラーロード
          CP      9               ; カラー9か？（ライフ2）
          JR      NZ,$+8          ; 
          LD      A,8             ; カラー8にランクダウン
          LD      (IX+13),A       
          RET
          CP      8               ; カラー8か？（ライフ1）
          JR      NZ,$+8          
          LD      A,6             ; カラー6にランクダウン
          LD      (IX+13),A       
          RET
          XOR     A               ; それ以外なら（3回目で）
          LD      (IX+0),A        ; オブジェクト消滅
          CALL    BOMBOBJ         ; 破壊オブジェクト生成
          RET

;--- ボスコア：形状データ（多面体コア） ---
S2COREPT: DEFB    6,0             
          DEFB      0,-24,  0     
          DEFB      0, 24,  0     
          DEFB      0,  0,-13     
          DEFB    -13,  0,  0     
          DEFB      0,  0, 13     
          DEFB     13,  0,  0     
          DEFB    1,4,2,6,1,0,5,4,3,6,5,0 ; 表側の結線
          DEFB    1,3,2,5,1,0,0           ; 裏側の結線

;--- テキストメッセージ定義 ---
S2ATACKM: DEFB    'A',9,0,'T',32,0,'A',55,0,'C',79,0,'K',106,0,0
S2CLEARM: DEFB    'C',60,30,'L',75,30,'E',90,30,'A',105,30,'R',120,30,0
S2BONUSM: DEFB    'B',88,30,'O',108,30,'N',128,30,'U',148,30,'S',168,30,0
S2SCOREM: DEFB    '2',98,60,'0',113,60,'0',128,60,'0',142,60
          DEFB    '1',98,90,'U',113,90,'P',128,90,0

;-----------------------------------------------------------
;
; STAGE 3
;
;-----------------------------------------------------------

STAGE3:   CALL    CLSPRI        ; 全オブジェクトワークエリア全消去
          LD      (STACK),SP    ; 現在のスタックポインタを保存
          LD      A,00001000B   ; 特定のフラグ（ビット3）を立てる
          LD      (SWITCH),A    ; ワークエリア(SWITCH)に設定値を保存
          CALL    DSET          ; 表示セットアップルーチン呼び出し
          DEFW    S3STAGM1,MHYOUJ ; 「ZONE 3」の表示データとルーチンを指定
          DEFB    7,40,0,0,0,44 ; 色(7)、座標(40,44)などのパラメータ
          DEFB    0,0,00010101B ; 表示属性フラグ
          CALL    DSET          ; 続いてステージ名のセットアップ
          DEFW    S3STAGM2,MHYOUJ ; 「ICE LAND」の表示データ
          DEFB    7,40,0,0,0,46 ; 表示座標（ZONE3の少し下）
          DEFB    55,0,00000101B; 表示属性フラグ
          CALL    UNFADE        ; 徐々に画面を明るくする
          LD      A,32          ; タイトル表示用の待ち時間をセット
          CALL    MAIN          ; 32フレームMAINを回して待ち
          CALL    FADE          ; 画面を徐々に暗くしてゲーム本編へ
          LD      A,8           ; 短い待ち時間をセット
          CALL    MAIN          ; 8フレームMAINを回す
          CALL    MSSTR         ; 自機の表示開始
          ;
          ; 前半戦セクション
S3CONT:   CALL    MOVESD        ; エンジンサウンドコール
          LD      HL,S3STAGD1   ; ステージの設定データの先頭を指定
          LD      DE,GAMEWORK   ; システムのワークエリア
          LD      BC,9          ; 9バイト分
          LDIR                  ; 設定データを一括転送
          LD      HL,S3JPDAT1   ; 当たり判定用データの先頭を指定
          LD      DE,JPTUCH     ; システムの当たり判定ポインタワークエリア
          LD      BC,32         ; 32バイト分
          LDIR                  ; 判定データを一括転送
          LD      A,24          ; 24フレームMAINを実行して待ち
          CALL    MAIN          ; 
          LD      B,192         ; ステージ進捗カウンタ（192回ループ）をセット
S3LOOP:   LD      HL,S3RETLOP   ; ループの戻り先アドレスをHLに格納
          PUSH    HL            ; スタックに積んでRETでS3RETLOPに戻れるようにする
          CALL    CURE          ; 回復アイテム作成ルーチンコール
          CALL    TURBO         ; ターボアイテム作成ルーチンコール
          CALL    GOD_ITEM      ; 無敵化ルーチン
          CALL    ALL_BOMB      ; 全破壊ルーチン
          CALL    RND           ; 乱数を取得
          CP      40            ; 40未満なら
          CALL    C,TECHNO      ; テクノイト作成ルーチンコール
          CALL    RND           ; 乱数を取得
          CP      30            ; 30未満なら
          CALL    C,PARTY       ; キャンプか人の作成ルーチンコール
          LD      A,B           ; 現在の進捗カウンタをAへ
          CP      160           ; 160以上（ステージ序盤）か判定
          JR      C,S3SJ1       ; 160未満なら中盤処理へ分岐
          CALL    S3CHARA1      ; 序盤の敵キャラ1を生成
          JP      S3CHARA6      ; 序盤の敵キャラ6を生成してループへ
          ;
S3SJ1:    CP      90            ; ステージ中盤（90?159）か判定
          JR      C,S3SJ2       ; 90未満なら終盤処理へ分岐
          CALL    RND           ; 乱数取得
          CP      120           ; 120未満なら
          CALL    C,S3CHARA1    ; 敵キャラ1を生成
          CALL    RND           ; 乱数取得
          CP      100           ; 100未満なら
          JP      C,S3CHARA6    ; 敵キャラ6を生成
          CP      180           ; 180未満なら
          JP      C,S3CHARA3    ; 敵キャラ3を生成
          JP      S3CHARA4      ; それ以外は敵キャラ4を生成
          ;
S3SJ2:    CP      15            ; ステージ終盤（15?89）か判定
          JR      C,S3SJ3       ; 15未満ならボス直前へ
          AND     15            ; Aの下位4ビット（16回に1回の周期）
          CALL    Z,S3CHARA5    ; 周期的に敵キャラ5を生成
          CALL    RND           ; 乱数取得
          CP      100           ; 
          CALL    C,S3CHARA1    ; 100未満なら敵キャラ1を作成
          CALL    RND           ; 乱数取得
          CP      60            ; 
          JP      C,S3CHARA6    ; 60未満なら敵キャラ6を作成
          CP      120           ; 
          JP      C,S3CHARA3    ; 120未満なら敵キャラ3を作成
          CP      180           ; 
          JP      C,S3CHARA4    ; 180未満なら敵キャラ4を作成
          CP      190           ; 
          JP      C,S3CHARA2    ; 190未満なら敵キャラ2を作成
          RET                   ; 戻り先(S3RETLOP)へ戻る
          ;
S3SJ3:    CP      14            ; カウントが残り14ちょうどか判定
          CALL    Z,S3CHARA8    ; 14の瞬間だけ特定の敵（バキュラ系）を出す
          RET                   ; 戻り先(S3RETLOP)へ戻る
          ;
S3RETLOP: LD      A,4           ; 4フレーム待機してウェイトをかける
          CALL    MAIN          ; メインループ実行
          DJNZ    S3LOOP        ; Bをデクリメントし、0でなければS3LOOPへ
          ;
          ; 後半戦開始前処理
          LD      A,(SWITCH)    ; スイッチの状態を取得
          AND     11111110B     ; 地平線を消す
          LD      (SWITCH),A    ; 更新
          LD      HL,S3CONT2    ; 次の復活ポイントアドレスをセット
          LD      (CONTRT),HL   ; 
          ;
          ; 後半戦セクション
S3CONT2:  CALL    MOVESD        ; エンジンサウンドコール
          LD      A,32          ; 32フレームMAINを回して待ち
          CALL    MAIN          ; 
          LD      B,192         ; 第2フェーズのループカウンタをリセット
S3LOOP2:  CALL    TURBO         ; ターボアイテム作成ルーチンコール
          CALL    CURE          ; 回復アイテム作成ルーチンコール
          CALL    GOD_ITEM      ; 無敵化ルーチン
          CALL    ALL_BOMB      ; 全破壊ルーチン
          LD      HL,S3RETLP2   ; 戻り先アドレスをセット
          PUSH    HL            ; スタックへ積む
          LD      A,B           ; 現在のカウントをAへ
          AND     31            ; 32回周期のタイミングかチェック
          JP      Z,S3CHARA8    ; 周期的に敵キャラ8を出現させる
          CALL    RND           ; 以下、怒涛の敵生成ラッシュ
          CP      80            ; 各キャラの出現率をCP命令で細かく制御
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
          RET                   ; 戻り先(S3RETLP2)へ
          ;
S3RETLP2: LD      A,B           ; ループ進捗に応じた可変ウェイト処理
          RLCA                  ; Aを左回転（ビット操作で数値を加工）
          RLCA
          AND     3             ; 下位2ビットのみ抽出(0?3)
          ADD     A,3           ; 3を足して3?6フレームの待機にする
          CALL    MAIN          ; 実行（これにより敵キャラが適度にばらけるように）
          DJNZ    S3LOOP2       ; カウント終了までループ
          ;
          LD      A,32          ; ボス突入前のウェイト(32フレーム）
          CALL    MAIN          ; 実行
          JP      S3BOSS        ; ボス戦ルーチンへ突入（実際にはボスはいない）
;-----------------------------------------------------------
; STAGE 3 各種設定データ
;-----------------------------------------------------------
S3STAGD1: DEFB    32,5,5,2      ; 背景や速度の設定値
          DEFB    01011011B     ; ステージ属性のフラグ群（SWITCH)
          DEFW    S3CONT,DEAD   ; コンティニューアドレスとゲームオーバー処理アドレス
          ;
S3JPDAT1: DEFW    TUCH0,TUCH1   ; STAGE3専用当たり判定処理のポインタ
          DEFW    TUCH2,TUCH3
          DEFW    TUCH4,TUCH5
          DEFW    TUCH6,TUCH7
          DEFW    TUCHNONE,TUCHNONE
          DEFW    TUCHNONE,TUCHNONE
          DEFW    TUCHNONE,TUCHNONE
          DEFW    TUCHNONE,TUCHNONE
          ;
S3STAGM1: DEFB    'Z',60,80      ; 文字'Z'、座標X=60, Y=80
          DEFB    'O',75,80      ; 文字'O'
          DEFB    'N',90,80      ; 文字'N'
          DEFB    'E',105,80     ; 文字'E'
          DEFB    '3',120,80,0   ; 文字'3'、終端
          ;
S3STAGM2: DEFB    'I',30,80      ; ステージ名 "ICE ISLAND" の各文字定義
          DEFB    'C',45,80
          DEFB    'E',60,80
          DEFB    'L',90,80
          DEFB    'A',105,80
          DEFB    'N',120,80
          DEFB    'D',135,80,0
;-----------------------------------------------------------
; 敵キャラ1 つらら、（分岐しているが、もう一方は画面外で消えているよう）
;-----------------------------------------------------------
S3CHARA1: CALL    RND           ; 乱数を発生
          LD      (S3CHARD1+4),A ; X座標をランダムに決定
          CALL    RND           ; 再び乱数
          AND     31            ; 0?31の範囲に限定
          LD      (S3CHARD1+5),A ; Y座標をランダムに決定
          LD      HL,S3CHARP1   ; 基本移動パターンを指定
          AND     1             ; 乱数の結果で分岐
          JR      Z,$+5         ; 偶数ならそのまま
          LD      HL,S3CHRP12   ; 奇数なら別の移動パターンを指定
          LD      (S3CHARD1+2),HL ; 決定したアドレスをデータ枠へ上書き
          CALL    DSET          ; 敵キャラを表示リストに登録
S3CHARD1: DEFW    S3CHAPD1,S3CHARP1 ; 形状データと移動処理のアドレス
          DEFB    0,20,255,0,0,0 ; 初期パラメータ
          DEFB    7,1,00000000B ; 色と表示属性
          RET
          ;
          ; つららモデリングデータ
S3CHAPD1: DEFB    6,2           ; 頂点数6、描画形式2
          DEFB    -10,  0, 10   ; 3D頂点データ(X, Y, Z)
          DEFB     10,  0, 10
          DEFB      0,  0,-10
          DEFB      0, 80,  0
          DEFB      0, 25, -6
          DEFB      0, 50, -3
          DEFB    1,2,3,1,4,3,0,2,4,0,0 ; 線を結ぶインデックスリスト
          ;
          ; 地面から生えている氷柱モデリングデータ
S3CHPD12: DEFB    6,2           ; 形状パターンのバリエーション
          DEFB    -10,  0, 10
          DEFB     10,  0, 10
          DEFB      0,  0,-10
          DEFB      0,-80,  0
          DEFB      0,-25, -6
          DEFB      0,-50, -3
          DEFB    1,4,3,0,4,2,0,0,4,0,0
          ;
          ; つららの移動ルーチン
S3CHARP1: LD      A,(IX+1)      ; 汎用ワークを取得
          CP      1             ; 1かチェック
          JR      Z,S3CHRP1J    ; 1なら落下
          LD      A,(IX+9)      ; Z座標（奥行き）を取得
          SUB     24            ; 手前に移動させる
          LD      (IX+9),A      ; 更新
          LD      A,(MASTER+9)  ; 自機のZ座標を取得
          XOR     (IX+9)        ; ★(謎のXOR）
          CP      40            ; 一定範囲に入ったか
          RET     NC            ; まだなら何もしない
          LD      A,1           ; 十分近づいたので
          LD      (IX+1),A      ; 落下に移行
          RET
          ; 落下移動
S3CHRP1J: LD      A,(IX+8)      ; Y座標（上下）を取得
          ADD     A,32          ; 急激に下方向へ移動
          LD      (IX+8),A      ; 
          RET
          ;
          ; 氷柱の移動ルーチン
S3CHRP12: LD      A,(IX+9)      ; パターン2：ひたすら手前に迫るのみ
          SUB     24            ;
          LD      (IX+9),A
          RET
;-----------------------------------------------------------
; 敵キャラ2　シャッター敵
;-----------------------------------------------------------
S3CHARA2: CALL    RND           ; 乱数で出現位置を計算
          AND     63
          ADD     A,64
          LD      (S3CHARD2+4),A ; 1体目のX座標
          ADD     A,32
          LD      (S3CHAR22+4),A ; 2体目のX座標（少し横にずらす）
          CALL    RND           ; 乱数
          AND     127
          ADD     A,64
          LD      (S3CHARD2+5),A ; 1体目のY座標
          LD      (S3CHAR22+5),A ; 2体目も同じ高さに配置
          CALL    DSET          ; 1体目を画面に配置
S3CHARD2: DEFW    S3CHAPD2,S3CHARP2
          DEFB    128,128,245,0,0,0
          DEFB    7,2,00000010B
          CALL    DSET          ; 2体目を画面に配置
S3CHAR22: DEFW    S3CHAPD2,S3CHRP22
          DEFB    128,128,245,0,0,0
          DEFB    7,2,00000010B
          RET
          ;
S3CHAPD2: DEFB    10,2          ; 頂点数10の複雑なモデル
          DEFB     -6,-28, -6   ; 形状データリスト
          DEFB     -6,-28,  6
          DEFB      6,-28,  6
          DEFB      6,-28, -6
          DEFB     -6, 28, -6
          DEFB     -6, 28,  6
          DEFB      6, 28,  6
          DEFB      6, 28, -6
          DEFB      0,  0,  0
          DEFB      0, -9,  0
          DEFB    1,2,3,4,1,5,6 ; 描画ライン接続指示
          DEFB    7,8,5,0,4,8,0
          DEFB    3,7,0,2,6,0,0
          ;
S3CHARP2: LD      A,(IX+1)      ; 1体目の動き制御（左右の揺れ）
          INC     (IX+1)        ; カウンタ増加
          CP      3             ; 位相判定
          JR      NC,$+12       ; 分岐
          CALL    MOVE          ; 左・手前に移動
          DEFB    -16,0,-10,0,0,0
          RET
          ;
          CP      6
          JR      NC,$+12
          CALL    MOVE          ; 右・手前に移動
          DEFB    16,0,-10,0,0,0
          RET
          ;
          XOR     A             ; カウンタリセット
          LD      (IX+1),A
          JR      S3CHARP2      ; ループしてジグザグ移動
          ;
S3CHRP22: LD      A,(IX+1)      ; 2体目の動き制御（1体目と逆の揺れ）
          INC     (IX+1)
          CP      3
          JR      NC,$+12
          CALL    MOVE          ; 右・手前に移動（交差する動き）
          DEFB    16,0,-10,0,0,0
          RET
          ;
          CP      6
          JR      NC,$+12
          CALL    MOVE          ; 左・手前に移動
          DEFB    -16,0,-10,0,0,0
          RET
          ;
          XOR     A
          LD      (IX+1),A
          JR      S3CHRP22
;-----------------------------------------------------------
; 敵キャラ3（ランダム浮遊型）ルーチン
;-----------------------------------------------------------
S3CHARA3: CALL    RND           ; 乱数で出現座標を吟味
          CP      210
          JR      NC,$-5        ; 端すぎたらやり直し
          ADD     A,20
          LD      (S3CHARD3+4),A ; X座標決定
          CALL    RND           ; 乱数
          CP      210
          JR      NC,$-5        ; 範囲チェック
          ADD     A,20
          LD      (S3CHARD3+5),A ; Y座標決定
          CALL    DSET          ; キャラクタを登録
S3CHARD3: DEFW    S3CHAPD3,S3CHARP3 ; 形状データ、移動ルーチン指定
          DEFB    0,0,245,0,0,0 ; 初期属性
          DEFB    7,1,00000000B ; 色とサイズ
          RET
          ;
S3CHARP3: LD      A,(IX+9)      ; Z座標（奥行き）を取得
          SUB     33            ; かなりの速度で迫ってくる
          LD      (IX+9),A
          LD      A,(IX+8)      ; Y座標を取得
          XOR     16            ; ビット反転で小刻みに上下させる
          LD      (IX+8),A
          LD      A,(IX+13)     ; 点滅演出
          XOR     2             ; 
          LD      (IX+13),A
          RET
          ;
S3CHAPD3: DEFB    9,1           ; 頂点数9、描画形式1
          DEFB    -16,-16,-16   ; 立方体の形状データ
          DEFB     16,-16,-16
          DEFB    -16, 16,-16
          DEFB     16, 16,-16
          DEFB    -16,-16, 16
          DEFB     16,-16, 16
          DEFB    -16, 16, 16
          DEFB     16, 16, 16
          DEFB      0,  0,  0
          DEFB    1,2,4,3,7,5,1,3,0 ; 接続情報1
          DEFB    5,6,8,7,0,6,2,0,8,4,0,0 ; 接続情報2

;-----------------------------------------------------------
; 敵キャラ4　バキュラ状の敵（2軸回転、1軸回転の2種類)
;-----------------------------------------------------------
S3CHAPD4: DEFB    5,1         ; 頂点数5、形式1
          DEFB    -25,-25,  0   ; 正方形の板のような形状
          DEFB     25,-25,  0
          DEFB     25, 25,  0
          DEFB    -25, 25,  0
          DEFB      0,  0,  0
          DEFB    1,2,3,4,1,0,0 ; 形状接続
          ;
S3CHARP4: LD      A,(IX+13)     ; 点滅演出
          XOR     2
          LD      (IX+13),A
          CALL    MOVE          ; 猛スピードで迫る移動(Z=-32)
          DEFB    0,0,-32,2,0,3
          RET
          ;
S3CHRP42: LD      A,(IX+13)     ; パターン2：同様に高速移動
          XOR     2
          LD      (IX+13),A     ; 点滅演出
          CALL    MOVE
          DEFB    0,0,-32,0,-3,0
          RET
          ;
S3CHARA4: CALL    RND           ; キャラ4生成メイン
          LD      (S3CHARD4+4),A ; 乱数X座標
          CALL    RND
          LD      (S3CHARD4+5),A ; 乱数Y座標
          LD      HL,S3CHARP4   ; 移動ルーチン1
          AND     1             ; 乱数で分岐
          JR      Z,$+5
          LD      HL,S3CHRP42   ; 移動ルーチン2
          LD      (S3CHARD4+2),HL
          CALL    DSET
S3CHARD4: DEFW    S3CHAPD4,S3CHRP42
          DEFB    0,0,255,0,0,0
          DEFB    7,1,00000000B
          RET
;-----------------------------------------------------------
; 敵キャラ5　吸い込み換気扇型の敵
;-----------------------------------------------------------
S3CHARA5: CALL    DSET          ; 敵キャラ5を画面に生成
          DEFW    S3CHAPD5,S3CHARP5 ; 形状と移動ルーチン
          DEFB    128,128,255,0,0,0
          DEFB    7,2,00000010B
          RET
          ;
S3CHAPD5: DEFB    10,4          ; 頂点数10、描画形式4
          DEFB      0,-30,-10   ; 複雑なトゲ状の形状
          DEFB     26,-15,  0
          DEFB     26, 15,-10
          DEFB      0, 30,  0
          DEFB    -26, 15,-10
          DEFB    -26,-15,  0
          DEFB      0,  0,  0
          DEFB    -16,  0, -5
          DEFB      8,-15, -5
          DEFB      8, 15, -5
          DEFB    1,2,5,6,3,4,1,0,0 ; 形状接続情報
          ;
S3CHARP5: LD      A,(LIFE)      ; プレイヤーが生きているか
          OR      A
          JR      Z,S3RP5END    ; 死んでいたら追尾しない
          LD      A,(IX+1)      ; 内部カウンタ
          INC     (IX+1)
          AND     3             ; 4フレームに1回判定
          LD      HL,HOME       ; プレイヤーを追いかけるように
          JR      Z,$+5         ; ターゲット変更
          LD      HL,KEY        ; キー入力に反応させる
          LD      (MASTER+5),HL ; ターゲットをセット
S3RP5END: LD      A,(IX+13)     ; 回転演出
          XOR     2
          LD      (IX+13),A
          CALL    MOVE          ; 前進させる
          DEFB    0,0,-8,3,0,0
          RET

;-----------------------------------------------------------
; 敵キャラ6　下から生えている氷柱ルーチン
;-----------------------------------------------------------
S3CHARA6: CALL    RND           ; 乱数でX座標を決定
          LD      (S3CHARD6+4),A
          CALL    DSET          ; 画面下部(Y=235)に出現させる
S3CHARD6: DEFW    S3CHPD12,S3CHARP6
          DEFB    0,235,255,0,0,0
          DEFB    7,1,00000000B
          RET
          ;
S3CHARP6: LD      A,(IX+9)      ; 画面奥からではなく
          SUB     24            ; 急速に手前に迫る動き
          LD      (IX+9),A
          RET
;-----------------------------------------------------------
; 敵キャラ7　大きく回転しながら､最後に手前にくる直方体ルーチン
;-----------------------------------------------------------
S3CHARA7: CALL    RND           ; 乱数座標
          AND     127
          ADD     A,64
          LD      (S3CHARD7+5),A ; Y座標決定
          CALL    DSET
S3CHARD7: DEFW    S3CHAPD2,S3CHARP7
          DEFB    30,128,255,0,0,0
          DEFB    7,2,00000010B
          RET
          ;
S3CHARP7: LD      A,(IX+11)   ; 特殊な回転角などのパラメータを更新
          ADD     A,3
          LD      (IX+11),A
          LD      A,(IX+1)
          INC     (IX+1)
          CP      5             ; 位相チェック
          JR      NC,$+5
          JP      S3CHARP6      ; 初期はキャラ6と同じ動き
          CP      29            ; 中期
          JR      NC,S3CHARP6
          CALL    RTURN         ; 回転しながら接近する特殊挙動
          DEFB    128,128,144,0,0,2
          INC     (IX+12)
          INC     (IX+12)
          RET
;-----------------------------------------------------------
; 敵キャラ8　バキュラ状の物体を発射しながら去って行く敵
;-----------------------------------------------------------
S3CHARA8: CALL    DSET          ; バキュラ状の物体の射出機
          DEFW    S3CHAPD8,S3CHRP81
          DEFB    128,20,40,0,0,0
          DEFB    11,2,00000000B
          CALL    DSET          ; プロペラ
          DEFW    S3CHAPD5,S3CHRP82
          DEFB    128,20,40,0,8,0
          DEFB    11,2,00000000B
          RET
          ;
S3CHARP8: LD      A,(IX+1)      ; 移動共通ルーチン
          INC     (IX+1)
          CP      46
          JR      NC,$+11       ; 一定時間経過で挙動変更
          LD      A,(IX+8)      ; Y軸（高さ）をずらしていく
          ADD     A,4
          LD      (IX+8),A
          RET
          CALL    RTURN         ; 回転処理
          DEFB    128,128,128,2,0,0
          LD      A,(IX+9)      ; 遠ざかるように移動
          ADD     A,8
          LD      (IX+9),A
          RET
          ;
S3CHRP81: CALL    S3CHARP8      ; 共通移動ルーチンで移動
          LD      A,(IX+1)
          CP      46
          RET     C
          JP      S3BACURA      ; バキュラ射出
          ;
S3CHRP82: CALL    S3CHARP8      ; プロペラの回転
          LD      A,(IX+10)
          ADD     A,3
          LD      (IX+10),A
          RET
          ;
S3CHAPD8: DEFB    7,0           ; 射出機の形状データ
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
;-----------------------------------------------------------
; BACURA: 特殊移動（回転しながら去る）
;-----------------------------------------------------------
S3BACURA: LD      A,(IX+7)      ; 現在の位置情報を転送
          LD      (S3BACURD+4),A
          LD      A,(IX+8)
          LD      (S3BACURD+5),A
          LD      A,(IX+9)
          LD      (S3BACURD+6),A
          CALL    DSET          ; 最終的なバキュラ・オブジェクトを生成
S3BACURD: DEFW    S3CHAPD4,S3BACURP
          DEFB    0,0,0,0,0,0
          DEFB    10,1,00000100B
          RET
          ;
S3BACURP: LD      A,(IX+10)     ; 回転速度の制御
          SUB     3
          LD      (IX+10),A
          LD      A,(IX+9)      ; 画面外へ
          SUB     24
          JP      C,MULEND      ; 画面外(CARRY発生)なら消去ルーチンへ
          LD      (IX+9),A
          RET
          ;
;-----------------------------------------------------------
; STAGE 3 ボス戦・クリア処理
;-----------------------------------------------------------
S3BOSS:   LD      A,(SWITCH)    ; スイッチ状態取得
          OR      00000001B     ; 地平線を表示
          LD      (SWITCH),A    ; 保存
          LD      A,24          ; 演出用ウェイト
          CALL    MAIN          ; 24フレームMAIN実行
          CALL    CLSPRI        ; オブジェクトワークエリア全消去
          ;
          LD      A,1           ; 
          LD      (SCOLOR+1),A  ; 地平線の移動速度を落とす
          ;
          LD      A,(SWITCH)    ; 
          RES     2,A           ; スピードアップ状態解除
          LD      (SWITCH),A    ; 
          ;
          LD      HL,HOME       ; 自機を定位置へ
          LD      (MASTER+5),HL ; 自機の移動ルーチンを書き換え
          LD      A,1
          CALL    MAIN          ; 1フレームMAIN実行
          LD      A,(MASTER+1)  ; 状態チェック
          OR      A
          JR      NZ,$-9        ; 定位置にくるまでループ
          ;
          CALL    DSET          ; 大型キャンプを作成
          DEFW    PARPD1,S3CLPTR2
          DEFB    128,255,240,0,0,0
          DEFB    11,0,00001010B
          ;
          LD      A,20          ; ウェイト
          CALL    MAIN
          LD      HL,S3CLPTR    ; 自機の移動ルーチンを書き換え
          LD      (MASTER+5),HL
          XOR     A             ;
          LD      (SCOLOR+1),A  ; 地平線を完全に停止する
          LD      A,14
          CALL    MAIN
          CALL    SDOFF         ; エンジン音を消す
          LD      A,18          ; ウェイト
          CALL    MAIN          ; 32フレームMAINを実行
          ;
          ; --- クリアメッセージとスコア計算 ---
          CALL    DSET          ; ステージ数表示
          DEFW    S3STAGM1,MHYOUJ
          DEFB    7,24,0,0,0,38,8
          DEFB    0,00000101B
          CALL    DSET          ; "CLEAR"メッセージ
          DEFW    S3CLEARM,MHYOUJ
          DEFB    7,24,0,0,0,38,134
          DEFB    0,00000101B
          LD      A,28          ; メッセージ表示時間
          CALL    MAIN
          CALL    DSET          ; "BONUS"メッセージ
          DEFW    S3BONUSM,MHYOUJ
          DEFB    7,24,0,0,0,0,55
          DEFB    0,00000101B
          CALL    DSET          ; スコア詳細表示
          DEFW    S3SCOREM,MHYOUJ
          DEFB    7,24,0,0,0,8,80
          DEFB    0,00010101B
          ;
          LD      DE,3000       ; クリアボーナス 3000点
          CALL    SCOREUP       ; スコア加算
          ;
          LD      A,2           ; クリアボーナス 自機アップ
          CALL    STOCKUP       ; 自機を2機アップ
          ;
          LD      A,30          ; 終了間際のウェイト
          CALL    MAIN
          CALL    FADE          ; 画面をフェードアウト
          LD      A,24
          CALL    SDOFF         ; サウンドを停止
          CALL    MAIN
          RET                   ; ステージ3終了、呼び出し元へ
          ;
;-----------------------------------------------------------
; キャンプに自機が到着する移動ルーチン
;-----------------------------------------------------------
S3CLPTR:  LD      A,(IX+1)      ; クリア後の自機上昇演出
          INC     (IX+1)
          CP      8
          JR      NC,$+11
          LD      A,(IX+9)      ; 遠ざかるようにZ座標を加算
          ADD     A,6
          LD      (IX+9),A
          RET
          CP      16
          RET     NC
          LD      A,(IX+8)      ; Y座標を加算して上昇
          ADD     A,12
          LD      (IX+8),A
          INC     (IX+12)       ; 特殊属性
          RET
          
;-----------------------------------------------------------
; キャンプの移動ルーチン
;-----------------------------------------------------------
S3CLPTR2: LD      A,(IX+1)      ; サブオブジェクトのクリア後演出
          INC     (IX+1)
          CP      16
          RET     NC
          LD      A,(IX+9)      ; 少しずつ遠ざける
          SUB     6
          LD      (IX+9),A
          RET
          ;
;-----------------------------------------------------------
; 文字列・メッセージ用データ
;-----------------------------------------------------------
S3ATACKM: DEFB  'A',9,0,'T',32,0,'A',55,0,'C',79,0,'K',106,0,0 ; "ATACK"
S3CLEARM: DEFB  'C',60,30,'L',75,30,'E',90,30,'A',105,30,'R',120,30,0 ; "CLEAR"
S3BONUSM: DEFB  'B',88,30,'O',108,30,'N',128,30,'U',148,30,'S',168,30,0 ; "BONUS"
S3SCOREM: DEFB  '3',98,60,'0',113,60,'0',128,60,'0',142,60 ; "3000" (ボーナス点)
          DEFB  '2',98,90,'U',113,90,'P',128,90,0 ; "2UP" (残機アップ)
          
;-----------------------------------------------------------
;
; STAGE 4
;
;-----------------------------------------------------------

STAGE4:   CALL    CLSPRI        ; オブジェクトワークエリア全消去
          LD      (STACK),SP    ; スタックポインタを保存
          LD      A,00001000B   ; スイッチ設定（ビット3オン）
          LD      (SWITCH),A    ; システムフラグへ格納
          
          ; "ZONE 4" の文字表示
          CALL    DSET          ; 文字表示オブジェクト作成
          DEFW    S4STAGM1,MHYOUJ ; データアドレス, 表示ルーチン
          DEFB    8,40,0,0,0,44 ; 
          DEFB    0,0,00010101B ; 
          
          ; "VOLCANO" の文字表示
          CALL    DSET
          DEFW    S4STAGM2,MHYOUJ
          DEFB    8,40,0,0,0,10 
          DEFB    60,0,00000101B
          
          CALL    UNFADE        ; 画面を徐々に明るくする
          LD      A,32          ; 
          CALL    MAIN          ; MAINを32フレーム動かして待ち
          CALL    FADE          ; 画面を暗くする
          LD      A,8           ; 短い待ち
          CALL    MAIN
          CALL    MSSTR         ; 自機出現演出スタート
          
; STAGE 4 前半戦セクション
S4CONT:   CALL    MOVESD        ; エンジン音コール
          LD      HL,S4STAGD1   ; ステージ設定データ
          LD      DE,GAMEWORK   ; ワークエリアへ転送
          LD      BC,9          ; 9バイト転送
          LDIR
          LD      HL,S4JPDAT1   ; 当たり判定処理テーブルを
          LD      DE,JPTUCH     ; 当たり判定ジャンプワークへ転送
          LD      BC,32         ; 32バイト転送
          LDIR
          LD      A,13          ; マスターウェイト設定
          LD      (MASTER+13),A ; 自機の色設定？
          LD      A,24          ; 24フレームMAIN実行
          CALL    MAIN
          
          ; 敵キャラ出現ループ1
          LD      B,32          ; 32回繰り返す
S4LOOP0:  CALL    S4CHARA1      ; 敵タイプ1出現ルーチンコール
          CALL    CURE          ; 回復アイテム作成
          LD      A,3           ; 3フレームウェイト
          CALL    MAIN
          DJNZ    S4LOOP0       ; Bが0になるまでループ
          CALL    S4CHARA6      ; 敵タイプ6出現
          
          ; 敵キャラ出現ループ2（ランダム分岐含む）
          LD      B,128         ; 128回繰り返す
S4LOOP:   LD      HL,S4RETLOP   ; ループの戻り先アドレス
          PUSH    HL            ; スタックに積んで戻れるようにする
          CALL    CURE          ; 回復アイテム作成ルーチンコール
          CALL    TURBO         ; ターボアイテム作成ルーチンコール
          CALL    GOD_ITEM      ; 無敵化ルーチン
          CALL    ALL_BOMB      ; 全破壊ルーチン
          LD      A,B           ; カウンタBを確認
          CP      92            ; 92以下なら分岐
          JR      C,S4SJ1
          CALL    S4CHARA1      ; 敵1出現
          CALL    RND           ; 乱数取得
          CP      50            ; 確率分岐
          JP      C,S4CHARA3    ; 敵3ルーチンコール
          CP      90
          JP      C,S4CHAR51    ; 敵5作成ルーチンコール
          CP      150
          JP      C,TECHNO      ; テクノイト作成ルーチンコール
          CP      200
          JP      C,PARTY       ; 人、キャンプ作成ルーチンコール
          RET                   ; 戻る
          
S4SJ1:    CP      70            ; 70以下なら分岐
          JR      C,S4SJ2
          CALL    S4CHARA1      ; 敵1出現
          JP      S4CHARA4      ; 敵4出現へジャンプ
          
S4SJ2:    CP      48            ; 48以下なら分岐
          JR      C,S4SJ3
          CALL    S4CHARA1      ; 敵1出現
          JP      S4CHAR51      ; 敵5出現へジャンプ
          
S4SJ3:    AND     15            ; カウンタBの下位4ビットが0なら
          JP      Z,S4CHARA6    ; 敵6出現
          CALL    S4CHARA1      ; 敵1
          JP      C,PARTY       ; キャリーがあればPARTYへ
          CALL    RND           ; 乱数でさらに細かく出現分岐
          CP      40
          JP      C,S4CHARA3    ; 敵3
          CP      80
          JP      C,S4CHARA4    ; 敵4
          CP      120
          JP      C,S4CHAR51    ; 敵5
          CP      140
          JP      C,S4CHARA7    ; 敵7
          CP      185
          JP      C,TECHNO      ; テクノイト
          CP      225
          JP      C,PARTY       ; 人、キャンプ
          RET
          
; --- ループの最後 ---
S4RETLOP: LD      A,6           ; 6フレームウェイト
          CALL    MAIN
          DJNZ    S4LOOP        ; メインループ継続
          
          ; ボス戦前準備
          LD      A,(SWITCH)
          AND     11111110B     ; 地平線を消す
          LD      (SWITCH),A
          LD      HL,S4CONT2    ; コンティニューアドレスセット
          LD      (CONTRT),HL

; STAGE 4　後半戦セクション
S4CONT2:  CALL    MOVESD        ; エンジン音コール
          LD      A,13
          LD      (MASTER+13),A ; 自機の色設定？
          LD      A,32          ; 32フレームMAIN実行
          CALL    MAIN
          CALL    S4CHARA5      ; 敵5軍団出現
          LD      A,24          ; 24フレームMAIN実行
          CALL    MAIN
          
          LD      B,128         ; ボス直前ループ
S4LOOP2:  CALL    TURBO         ; ターボアイテム作成
          CALL    CURE          ; 回復アイテム作成
          CALL    CURE          ; 回復アイテム作成
          CALL    GOD_ITEM      ; 無敵化ルーチン
          CALL    ALL_BOMB      ; 全破壊ルーチン
          LD      HL,S4RETLP2   ; RETの戻り先に設定
          PUSH    HL
          LD      A,B           ; Bのタイミングで敵出現
          AND     31
          CALL    Z,S4CHARA6    ; 32フレームおきに敵6出現
          LD      A,B
          AND     28            ; 謎AND
          RET     Z             ; 一定間隔で戻る？
          CALL    RND           ; さらに乱数で敵をバラまく
          AND     1
          CALL    Z,S4CHARA1    ; 敵1
          CALL    RND
          CP      35
          JP      C,S4CHARA3    ; 敵3
          CP      80
          JP      C,S4CHARA4    ; 敵4
          CP      125
          JP      C,S4CHAR51    ; 敵5
          CP      145
          JP      C,S4CHARA7    ; 敵7
          CP      185
          JP      C,S4CHRA72    ; 敵7変種
          CP      230
          JP      C,TECHNO      ; テクノイト
          JP      PARTY         ; 人かキャンプ作成
          
S4RETLP2: LD      A,B           ; ループウェイトの計算
          RLCA
          RLCA
          AND     3
          ADD     A,3
          CALL    MAIN
          DJNZ    S4LOOP2
          
          LD      A,32          ; ボス前の静寂
          CALL    MAIN
          JP      S4BOSS        ; ボス戦へ！

;-----------------------------------------------------------
; STAGE4 各種データ
;-----------------------------------------------------------
S4STAGD1: DEFB    32,5,6,2      ; ステージ設定パラメータ
          DEFB    01011011B     ; ステージ属性フラグ
          DEFW    S4CONT,DEAD   ; 初期コンティニューアドレスと死亡時自機移動アドレス

S4JPDAT1: DEFW    TUCH0,TUCH1   ; 当たり判定用ポインタ群
          DEFW    TUCH2,TUCH3
          DEFW    TUCH4,TUCH5
          DEFW    TUCH6,TUCH7
          DEFW    TUCH48,TUCH49 ; ステージ4固有の判定
          DEFW    TUCHNONE,TUCHNONE
          DEFW    TUCHNONE,TUCHNONE
          DEFW    TUCHNONE,TUCHNONE

; メッセージデータ (ASCII, X, Y)
S4STAGM1: DEFB    'Z',60,80, 'O',75,80, 'N',90,80, 'E',105,80, '4',120,80,0
S4STAGM2: DEFB    'V',69,80, 'O',86,80, 'L',103,80, 'C',120,80, 'A',137,80, 'N',154,80, 'O',171,80,0

;-----------------------------------------------------------
;  敵キャラ1 （火山）
;-----------------------------------------------------------
S4CHARA1: CALL    RND
          AND     127
          ADD     A,90          ; Y座標をランダムに
          LD      (S4CHARD1+4),A
          CALL    RND
          AND     00000010B     
          LD      (S4CHARD1+12),A   ; 拡大フラグをランダムでセットして大きい火山を作る
          CALL    DSET              ; 敵生成
S4CHARD1: DEFW    S4CHAPD1,S4CHARP1 ; 形状, 思考ルーチン
          DEFB    0,235,180,0,0,0   ; 初期状態
          DEFB    8,2,00000000B     ; 属性
          RET

S4CHAPD1: DEFB    14,5          ; 頂点数14, スケール5
          DEFB      0,-60, -6   ; 3Dモデルデータ（X, Y, Z）
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
          DEFB    1,2,3,0,4,5,6,0   ; 線を繋ぐ順番
          DEFB    7,8,9,0,1,4,7,1,0,0

S4CHARP1: LD      A,(IX+9)      ; Z座標取得
          SUB     16            ; 手前に移動（奥から迫る）
          LD      (IX+9),A
          LD      A,(IX+15)     ; フラグ確認
          AND     00000010B
          RET     Z
          CALL    RND           ; 噴火
          AND     15
          CALL    Z,S4CHARA2    ; 敵2（弾）出現
          RET
;-----------------------------------------------------------
; 敵キャラ2 (火山弾) 
;-----------------------------------------------------------
S4CHARA2: LD      A,(IX+7)      ; 親のX座標継承
          LD      (S4CHARD2+4),A
          LD      (S4CHAR22+4),A
          LD      (S4CHAR23+4),A
          LD      A,(IX+9)      ; 親のZ座標継承
          LD      (S4CHARD2+6),A
          LD      (S4CHAR22+6),A
          LD      (S4CHAR23+6),A
          CALL    DSET          ; 3方向に放出
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

S4CHAPD2: DEFB    4,0           ; 弾のモデル
          DEFB    -12,  8, -8
          DEFB     12,  8, -8
          DEFB      0,  8, 12
          DEFB      0,-13,  0
          DEFB    1,2,3,1,4,2,0
          DEFB    4,3,0,0

S4CHRP21: CALL    S4CHARP2      ; 共通移動
          CALL    MOVE          ; 個別ベクトル移動
          DEFB    4,0,2,0,0,0   ; 右方向へ
          RET

S4CHRP22: CALL    S4CHARP2
          CALL    MOVE
          DEFB    -4,0,2,0,0,0  ; 左方向へ
          RET

S4CHRP23: CALL    S4CHARP2
          CALL    MOVE
          DEFB    0,0,-6,0,0,0  ; 手前へ
          RET

S4CHARP2: LD      A,(IX+1)      ; 経過フレーム
          INC     (IX+1)
          OR      A
          RET     Z
          CP      8             ; 一定時間で消滅チェック
          JR      NC,S4CJ2
          LD      B,A
          LD      A,-64         ; 加速度的な動き
          SRA     A
          DJNZ    $-2
          ADD     A,(IX+8)      ; Y座標更新
          JP      NC,MULEND     ; 画面外なら消滅
          LD      (IX+8),A
          RET
S4CJ2:    SUB     7
          LD      B,A
          LD      A,2
          RLCA
          DJNZ    $-1
          ADD     A,(IX+8)
          JP      C,MULEND
          LD      (IX+8),A
          RET
;-----------------------------------------------------------
; 敵キャラ3 (雷) 
;-----------------------------------------------------------
S4CHARA3: CALL    RND           ; X座標ランダム
          LD      (S4CHARD3+4),A
          CALL    RND
          AND     127
          ADD     A,127         ; Z座標（奥）
          LD      (S4CHARD3+6),A
          CALL    DSET
S4CHARD3: DEFW    S4CHAPD3,S4CHARP3
          DEFB    0,127,0,0,0,0
          DEFB    8,2,00000010B
          RET

S4CHARP3: LD      A,(IX+7)      ; X座標
          XOR     15            ; 左右に細かく揺れる
          LD      (IX+7),A
          LD      A,(IX+13)     ; 色をチカチカさせる
          XOR     1
          LD      (IX+13),A
          LD      A,(IX+9)      ; Z座標（接近）
          SUB     12
          JP      C,MULEND      ; 通過したら消滅
          LD      (IX+9),A
          LD      A,(IX+1)      ; アニメーションカウンタ
          INC     (IX+1)
          AND     8             ; 周期的に表示フラグ反転（消えたり点いたり）
          RET     NZ
          LD      A,(IX+15)
          XOR     1
          LD      (IX+15),A
          RET

S4CHAPD3: DEFB    9,0           ; 縦長の敵モデル
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
;-----------------------------------------------------------
; 敵キャラ4 (突然出現する火の玉敵) 
;-----------------------------------------------------------
S4CHARA4: CALL    RND
          AND     127
          ADD     A,64
          LD      (S4CHARD4+4),A ; X座標
          CALL    RND
          AND     127
          ADD     A,64
          LD      (S4CHARD4+5),A ; Y座標
          CALL    RND
          AND     63
          ADD     A,32
          LD      (S4CHARD4+6),A ; Z座標
          CALL    RND
          AND     7
          ADD     A,A           ; 8種類の移動パターンから選択
          LD      HL,S4RNDPT4
          ADD     A,L
          JR      NC,$+3
          INC     H
          LD      L,A
          LD      E,(HL)
          INC     HL
          LD      D,(HL)
          EX      DE,HL
          LD      (S4CHARD4+2),HL ; 移動ルーチン決定
          CALL    DSET
S4CHARD4: DEFW    S4CHAPD4,S4CHARP4
          DEFB    0,0,0,0,0,0
          DEFB    8,1,00011000B
          RET

S4CHAPD4: DEFB    6,0           ; 火の玉（立方体的な）モデル
          DEFB      0,-18,  0
          DEFB      0, 18,  0
          DEFB      0,  0,-18
          DEFB    -18,  0,  0
          DEFB      0,  0, 18
          DEFB     18,  0,  0
          DEFB    1,4,2,6,1,0,5,4,3,6,5,0
          DEFB    1,3,2,5,1,0,0

S4RNDPT4: DEFW    S4CHRP41,S4CHRP42,S4CHRP43,S4CHRP44
          DEFW    S4CHRP45,S4CHRP46,S4CHRP47,S4CHRP48

; このルーチン呼ばれてない？？
S4CHARP4: LD      A,(IX+13)     ; 点滅
          XOR     1
          LD      (IX+13),A
          LD      A,(IX+1)      ; 寿命
          INC     (IX+1)
          CP      2
          RET     NC
          POP     HL            ; スタック破棄して終了
          CP      1
          RET     C
          XOR     A
          LD      (IX+15),A     ; 消滅
          RET

; 各方向への移動ルーチン
S4CHRP41: CALL    S4CHARP4
          CALL    MOVE
          DEFB    18,2,-8,0,0,0
          RET
S4CHRP42: CALL    S4CHARP4
          CALL    MOVE
          DEFB    -10,3,-15,0,0,0
          RET
S4CHRP43: CALL    S4CHARP4
          CALL    MOVE
          DEFB    11,-12,-8,0,0,0
          RET
S4CHRP44: CALL    S4CHARP4
          CALL    MOVE
          DEFB    12,21,-8,0,0,0
          RET
S4CHRP45: CALL    S4CHARP4
          CALL    MOVE
          DEFB    -8,13,-12,0,0,0
          RET
S4CHRP46: CALL    S4CHARP4
          CALL    MOVE
          DEFB    -18,-12,1,0,0,0
          RET
S4CHRP47: CALL    S4CHARP4
          CALL    MOVE
          DEFB    6,-18,-7,0,0,0
          RET
S4CHRP48: CALL    S4CHARP4
          CALL    MOVE
          DEFB    -10,-18,-16,0,0,0
          RET
;-----------------------------------------------------------
; 敵キャラ5 (上下に移動する柱)
;-----------------------------------------------------------
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

S4CHARP5: LD      A,(IX+9)      ; 前進
          SUB     16
          LD      (IX+9),A
          LD      A,(IX+13)     ; 点滅
          XOR     1
          LD      (IX+13),A
          LD      A,(IX+1)      ; 移動方向フラグ
          OR      A
          JR      NZ,S4UP
          LD      A,(IX+8)      ; 下降
          ADD     A,32
          CP      200
          JR      NC,$+6
          LD      (IX+8),A
          RET
          LD      A,1           ; 端まで行ったら反転
          LD      (IX+1),A
          RET
S4UP:     LD      A,(IX+8)      ; 上昇
          SUB     32
          CP      50
          JR      C,$+6
          LD      (IX+8),A
          RET
          XOR     A
          LD      (IX+1),A      ; 反転
          RET

S4CHAR52: LD      (S4CHARD5+4),A ; 敵5生成コア
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

S4CHARA5: PUSH    BC            ; 敵5を1列にまとめて出す
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

S4CHAR51: CALL    RND
          CALL    S4CHAR52      ; 乱数位置に1体出す
          RET
;-----------------------------------------------------------
; 敵キャラ6 (歩く岩) 
;-----------------------------------------------------------
S4CHAPD6: DEFB    10,4          ; 頂点10のモデル
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

S4CHARP6: LD      A,(IX+1)      ; 複雑なサインカーブ的な動き
          INC     (IX+1)
          CP      3
          JR      NC,$+12
          CALL    MOVE
          DEFB    0,5,-10,0,-1,0
          RET
          CP      6
          JR      NC,$+12
          CALL    MOVE
          DEFB    0,-5,-10,0,1,0
          RET
          CP      9
          JR      NC,$+12
          CALL    MOVE
          DEFB    0,5,-10,0,1,0
          RET
          CP      12
          JR      NC,$+12
          CALL    MOVE
          DEFB    0,-5,-10,0,-1,0
          RET
          XOR     A
          LD      (IX+1),A
          JR      S4CHARP6      ; ループ

S4CHARA6: CALL    RND           ; 敵6出現
          AND     127
          ADD     A,64
          LD      (S4CHARD6+4),A
          ADD     A,30
          LD      (S4CHRD62+4),A
          CALL    DSET          ; 2体セットで出現
S4CHARD6: DEFW    S4CHAPD6,S4CHARP6
          DEFB    50,130,225,0,0,0
          DEFB    8,2,00000000B
          CALL    DSET
S4CHRD62: DEFW    S4CHAPD6,S4CHARP6
          DEFB    80,130,225,0,0,16
          DEFB    8,2,00000000B
          RET
;-----------------------------------------------------------
; 敵キャラ7 (回転する敵) 
;-----------------------------------------------------------
S4CHARA7: CALL    RND
          AND     7
          LD      (S4CHARD7+8),A ; 初期回転角
          CALL    DSET
S4CHARD7: DEFW    S4CHAPD5,S4CHARP7
          DEFB    55,128,240,0,0,0
          DEFB    8,2,00000000B
          RET

S4CHARP7: CALL    RTURN         ; 回転処理
          DEFB    128,128,128,3,0,0
          CALL    MOVE          ; 前進
          DEFB    0,0,-12,-3,0,0
          RET

S4CHRA72: CALL    RND           ; 敵7変種（高速接近）
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

S4CHRP72: LD      A,(IX+9)      ; 超高速で接近
          SUB     42
          LD      (IX+9),A
          LD      A,(IX+13)     ; 点滅
          XOR     1
          LD      (IX+13),A
          RET

;-----------------------------------------------------------
; ボス戦 (S4BOSS)
;-----------------------------------------------------------
S4BOSS:   CALL    DSET          ; "ATTACK" メッセージ
          DEFW    S4ATACKM,MHYOUJ
          DEFB    9,16,1,1,0
          DEFB    72,80,0,00100101B
          LD      A,17          ; ウェイト
          CALL    MAIN
          CALL    CLSPRI        ; 全オブジェクトワーク消去
          
          ; ボスのコアを生成
          CALL    DSET
          DEFW    S4COREPT,S4CORERP
          DEFB    128,128,64,0,0,0
          DEFB    9,9,00000000B
          
          ; 魔方陣セット
          CALL    S4MAHOU
          
          ; ボスのガードクリスタル3つ生成
          CALL    DSET
          DEFW    S4BOSPD2,S4BOSSRP
          DEFB    128,128,64,0,0,0 ; パーツ1
          DEFB    8,8,00000000B
          CALL    DSET
          DEFW    S4BOSPD2,S4BOSSRP
          DEFB    128,128,64,0,11,0 ; パーツ2（回転オフセット）
          DEFB    8,8,00000000B
          CALL    DSET
          DEFW    S4BOSPD2,S4BOSSRP
          DEFB    128,128,64,0,22,0 ; パーツ3
          DEFB    8,8,00000000B

S4BOSLOP: CALL    RND           ; ボス戦中の雑魚出現
          AND     15
          CALL    Z,S4CHARA4    ; 敵4をたまに出現（突然出現する岩）
          LD      A,1
          CALL    MAIN
          LD      A,(PORIDAT+1) ; ボスのHPや状態をチェック？
          OR      A
          JR      Z,S4BOSLOP    ; まだ生きていればループ
          
          ; ボス撃破後の演出
          LD      HL,HOME        ; 自機を定位置へ
          LD      (MASTER+5),HL
S4LOOP8:  LD      A,1
          CALL    MAIN
          LD      A,(MASTER+1)
          OR      A
          JR      NZ,S4LOOP8    ; 帰還完了まで待ち
          
          LD      HL,S4CORRP2   ; コア消滅ルーチンへ差し替え
          LD      (PORIDAT+5),HL
          LD      A,80          ; 爆破待ち
          CALL    MAIN
          
          ; クリアメッセージ "STAGE CLEAR"
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
          
          ; ミッションエンド表示
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
          
          CALL    FADE          ; ステージ終了フェードアウト
          LD      A,24
          CALL    MAIN
          CALL    SDOFF         ; サウンド停止
          RET                   ; ステージ4完了！

;-----------------------------------------------------------
; ボス用当たり判定ルーチン
;-----------------------------------------------------------
; ガードクリスタル当たり判定
TUCH48:   CALL    TUCH2         ; 通常判定
          LD      A,(MASTER+9)  ; 自機を弾き飛ばす処理
          XOR     127
          ADD     A,17
          LD      (MASTER+9),A
          RET
          
; クリスタル当たり判定
TUCH49:   CALL    DAMAGESD        ; ピストル音を鳴らす
          LD      A,32
          LD      (MASTER+8),A
          LD      A,(IX+13)     ; 状態によって分岐（耐久度削り？）
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
          XOR     A             ; 破壊
          LD      (IX+2),A
          INC     A
          LD      (IX+1),A
          LD      A,00001000B
          LD      (IX+15),A 
          RET

; --- ボスのコアモデル ---
S4COREPT: DEFB    6,0
          DEFB      0,-24,  0
          DEFB      0, 24,  0
          DEFB      0,  0,-13
          DEFB    -13,  0,  0
          DEFB      0,  0, 13
          DEFB     13,  0,  0
          DEFB    1,4,2,6,1,0,5,4,3,6,5,0
          DEFB    1,3,2,5,1,0,0

; --- 文字列データ群 ---
S4ATACKM: DEFB    'A',9,0,'T',32,0,'A',55,0,'C',79,0,'K',106,0,0
S4CLEARM: DEFB    'C',60,30,'L',75,30,'E',90,30,'A',105,30,'R',120,30,0
S4MISSIM: DEFB    'M',20,30,'I',31,30,'S',42,30,'S',57,30,'I',68,30
          DEFB    'O',79,30,'N',94,30,0
S4ENDM:   DEFB    'E',98,90,'N',113,90,'D',128,90,0

; --- ボス用思考ルーチン (パーツ・コア) ---
S4BOSSRP: LD      A,(IX+13)     ; 共通点滅
          XOR     1
          LD      (IX+13),A
          LD      A,(PORIDAT+1) ; ボスの生命反応
          OR      A
          JR      Z,$+15
          XOR     A             ; 撃破時
          LD      (IX+0),A
          LD      A,00011000B
          LD      (IX+15),A
          CALL    BOMBOBJ       ; 爆発オブジェクト生成
          RET
S4BOSRJ:  LD      A,(IX+1)      ; 複雑な巡回移動
          INC     (IX+1)
          CP      8
          JR      NC,$+12
          CALL    MOVE
          DEFB    0,0,0H,3,0,0
          RET
          CP      40
          JR      NC,$+12
          CALL    MOVE
          DEFB    0,0,0,0,3,0
          RET
          CP      72
          JR      NC,$+12
          CALL    MOVE
          DEFB    0,0,0,0,0,3
          RET
          CP      88
          JR      NC,$+12
          CALL    MOVE
          DEFB    0,0,0,2,2,2
          RET
          XOR     A
          LD      (IX+1),A
          JR      S4BOSRJ

S4BOSPD2: DEFB    8,0           ; ボスのパーツモデル
          DEFB    -40,0F6H,40   ; 8つの頂点
          DEFB    -40,0F6H,60
          DEFB    -40,0AH,40
          DEFB    -40,0AH,60
          DEFB    40,0F6H,40
          DEFB    40,0F6H,60
          DEFB    40,0AH,40
          DEFB    40,0AH,60
          DEFB    1,2,4,3,7,5,1,3,0 ; 接続
          DEFB    5,6,8,7,0,2,6,0,4,8,0,0

S4CORERP: INC     (IX+12)       ; コアの回転（バンク）
          RET

S4CORRP2: INC     (IX+12)       ; コア破壊演出（回転しながら上昇）
          INC     (IX+8)
          LD      A,(IX+13)
          XOR     15            ; 激しく点滅
          LD      (IX+13),A
          LD      A,(IX+1)
          INC     (IX+1)
          CP      40            ; 一定時間で完全消滅
          JR      NC,S4COJ1
          AND     3
          LD      A,00011000B
          JR      Z,$+4
          LD      A,00001000B
          LD      (IX+15),A
          RET
S4COJ1:   XOR     A
          LD      (IX+0),A      ; オブジェクト消去
          LD      A,00011000B
          LD      (IX+15),A
          RET
;-----------------------------------------------------------
; ボスキャラ下の魔法陣
;-----------------------------------------------------------
S4MAHOU:  CALL    DSET          ; 巨大な魔法陣を背景に出す
          DEFW    S4MAHOPD,S4DEMO21
          DEFB    128,255,128,0,0,0
          DEFB    5,0,00101000B
          RET

S4MAHOPD: DEFB    7,0           ; 魔法陣モデル
          DEFB      0,  0,  0
          DEFB   -104,  0,-60
          DEFB   -104,  0, 60
          DEFB      0,  0,120
          DEFB    104,  0, 60
          DEFB    104,  0,-60
          DEFB      0,  0,-120
          DEFB    2,3,4,5,6,7,2,0 ; 外枠
          DEFB    2,4,6,2,0,3,5,7,3,0,0 ; 内側の星型

S4DEMO21: LD      A,(PORIDAT+1) ; ボスの生命チェック
          OR      A
          RET     Z             ; まだ健在ならそのまま
          LD      HL,S4DEMO22   ; 撃破されたら消滅演出へ
          LD      (IX+5),L
          LD      (IX+6),H
          RET

S4DEMO22: LD      A,(PORIDAT+0) ; 演出用カウンタ
          OR      A
          JR      Z,S4DEMJ
          INC     (IX+12)       ; 高速回転
          LD      A,(IX+13)     ; 点滅
          XOR     15
          LD      (IX+13),A
          RET
S4DEMJ:   LD      A,(IX+1)      ; 段階的にパレット変更
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
          JP      NC,MULEND     ; 演出終了、消滅
          LD      A,4
          LD      (IX+13),A
          RET
;-----------------------------------------------------------
; 点滅メッセージ表示用共通移動ルーチン
;-----------------------------------------------------------
S4MJIPTR: LD      A,(IX+7)      ; 色点滅
          XOR     15
          LD      (IX+7),A
          JP      MHYOUJ        ; 文字表示ルーチンへ

ROCKEND:  EQU     $