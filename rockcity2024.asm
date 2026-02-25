;*********************************************************
;
;  ROCK CITY
;
;  MSXPen LAST VERSION VER 2.1.1
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
MJVER:    EQU     '2'
MIVER:    EQU     '1'
PTVER:    EQU     '1'
          ORG     09000H
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
          LD      A,5           ; SCREEN 5（256x212ドット、16色）を指定
          LD      IX,005FH      ; BIOSのCHGMOD（画面モード変更）のアドレス
          LD      IY,(EXPTBL-1) ; BIOSが載っているスロット情報を取得
          CALL    CALSLT        ; インタースロットコールで画面をSCREEN 5に切り替え
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
          JP      LOGODEMO      ; ロゴデモ（メイン処理）へ
;
;---- MAIN ROUTINE ----
;
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
          LD      A,(SWHICH)    ; システムスイッチの状態をロード
          BIT     0,A           ; bit0: スケーリング（拡大縮小）処理が必要か
          CALL    NZ,SCALE      ; 必要なら拡大縮小計算を実行
          ;
          BIT     1,A           ; bit1: マスターオブジェクトの描画フラグ
          JR      Z,M1MA0       ; 0ならスキップ
          LD      IX,MASTER     ; 自機などのマスターオブジェクトをセット
          CALL    MALTI         ; AI実行 ＆ 3D描画！
          BIT     2,A           ; bit2: セカンドマスター（敵ボスなど）のフラグ
          CALL    NZ,MALTI      ; 必要ならさらに描画
          ;
M1MA0:    BIT     3,A           ; bit3: ポリス（ザコ敵や弾）の群れを描画するか
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
          CALL    MALTI         ; AI実行 ＆ 3D描画！
          ADD     HL,DE         ; 次のオブジェクトワークへ進む
          DJNZ    M1MA1         ; 全スロット分繰り返す
          POP     AF            ; フラグ復帰
          ;
M1MA2:    BIT     6,A           ; bit6: ライフゲージなどのUI表示フラグ
          CALL    NZ,WRLIFE     ; 必要ならライフを描画
          ;
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
          CALL    SDOFF         ; サウンドなどを停止
          JP      START         ; タイトル画面や最初へ戻る
;
;---- PORY WRITE ----
;
MALTI:    PUSH    AF            ; レジスタをすべて保存
          PUSH    BC            ; 
          PUSH    DE            ; 
          PUSH    HL            ; 
          LD      (MALRET+1),SP ; 現在のスタックポインタを保存（強制復帰用）
          LD      HL,PARET      ; 戻り先をPARETに設定して
          PUSH    HL            ; スタックに積む
          LD      H,(IX+6)      ; オブジェクト固有のAIルーチン
          LD      L,(IX+5)      ; アドレッシングをロード
          JP      (HL)          ; 固有ルーチン（移動計算など）を実行

PARET:    BIT     0,(IX+15)     ; 描画禁止フラグをチェック
          JP      NZ,MALRET     ; フラグが立っていれば描画せずに終了へ
          ; --- 3D頂点変換開始 ---
          XOR     A             ; A=0
          LD      (IX+2),A      ; 画面外フラグなどをクリア
          LD      L,(IX+3)      ; 3Dモデルデータの開始アドレス
          LD      H,(IX+4)      ; 
          LD      B,(HL)        ; 頂点数をBにロード
          INC     HL            ; 
          LD      C,(HL)        ; 面（または線）の定義数をCにロード
          INC     HL            ; 
          LD      DE,HYOUJI     ; 座標変換後の格納先アドレス
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

MALEND:   XOR     A             ; オブジェクト消去処理
          LD      (IX+0),A      ; ワークの先頭を0にして「空き」にする
MALRET:   LD      SP,0          ; スタックポインタを保存した値で復帰（自己書き換え）
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
          CALL    NZ,KAITEN     ; 角度があれば回転演算を実行
          ; --- 座標を入れ替えて第2平面の回転 ---
          LD      D,B           ; 計算結果のBをDへ退避
          LD      B,(HL)        ; 頂点データの第3成分(Z)をBにロード
          LD      A,(IX+11)     ; 回転角(2軸目)を取得
          AND     00011111B     ; 
          CALL    NZ,KAITEN     ; 2軸目の回転を実行
          ; --- 座標を並べ替えて第3平面の回転 ---
          LD      E,C           ; 
          LD      C,B           ; 
          LD      B,D           ; 各成分を各軸の役割に振り直す
          LD      A,(IX+12)     ; 回転角(3軸目)を取得
          AND     00011111B     ; 
          CALL    NZ,KAITEN     ; 3軸目の回転を実行
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
KAITEN:   PUSH    DE            ; レジスタDEを保護
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
          CALL    NZ,TIMES      ; 座標1 * sinθ を計算
          LD      L,A           ; 結果をLへ
          LD      A,E           ; cosθをAへ
          LD      H,C           ; 座標2をHへ
          OR      A             ; 
          CALL    NZ,TIMES      ; 座標2 * cosθ を計算
          LD      H,A           ; 結果をHへ
          PUSH    HL            ; (成分1, 成分2)の中間結果を保存
          ; --- 積和計算：第2成分 ---
          LD      A,D           ; sinθ
          LD      H,C           ; 座標2
          OR      A             ; 
          CALL    NZ,TIMES      ; 座標2 * sinθ
          LD      L,A           ; 
          LD      A,E           ; cosθ
          LD      H,B           ; 座標1
          OR      A             ; 
          CALL    NZ,TIMES      ; 座標1 * cosθ
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
TIMES:    INC     H             ; 座標値Hが0かどうかをチェック
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
          ; --- ビットシフト加算ループ ---
          LD      HL,0          ; 
          LD      B,8           ; 8ビット分ループ
M1LP2:    RRA                   ; 倍率Aを右シフトして1ビットずつ確認
          JR      NC,$+3        ; ビットが立っていなければ加算スキップ
          ADD     HL,DE         ; ビットが立っていれば加算
          SLA     E             ; 次のビットのために2倍にする
          RL      D             ; 
          DJNZ    M1LP2         ; 8回繰り返す
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
          JP      Z,MALEND      ; フラグがなければ終了処理へ
          JP      MALRET        ; フラグがあれば復帰ルーチンへ
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
          AND     15            ; 下位4ビット（0?15の範囲）に限定する
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
          CALL    WARIZU        ; 【割り算実行】 A = B(X成分) / DE(Z距離)
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
          CALL    WARIZU        ; 【割り算実行】 A = B(Y成分) / DE(Z距離)
          POP     DE            ; アドレス復帰
          LD      (DE),A        ; 算出した2Dの「y座標」をメモリに書き込む
          RET                   ; 頂点1つ分の投影完了！
          ;
WARIZU:   PUSH    HL            ; HLレジスタを保護
          LD      H,0           ; Hを0にする
          LD      L,B           ; Lに分子をセット（HL = 被除数）
          LD      B,8           ; 8ビット分繰り返すカウンタをセット
WALOOP:   RL      C             ; キャリーをCに拾う（拡張用）
          RL      L             ; HLを左に1ビットシフト（2倍にする）
          RL      H             ; 
          OR      A             ; キャリーフラグをクリア
          SBC     HL,DE         ; 被除数(HL)から除数(DE)を引いてみる
          JR      NC,$+4        ; 結果が正（引けた）なら次へジャンプ
          ADD     HL,DE         ; 結果が負（引けなかった）なら元の値に戻す
          SCF                   ; キャリーフラグを1にする（引けなかった印）
          CCF                   ; それを反転させて0にする
          RLA                   ; 商のビット（0か1）をAレジスタに流し込む
          DJNZ    WALOOP        ; 8回繰り返すまでループ
          POP     HL            ; HLを元に戻す
          RET                   ; 割り算終了（Aに商が入っている）
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
          DEC     A             ; 0?7の範囲に調整
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
          DEC     (IX+10)       ; ワークエリアのパラメータ（回転角など？）を減らす
          JR      M1DOWN        ; Y軸計算へ
M1LEFT:   SUB     16            ; 【左移動】16ドット左へ
          CP      32            ; 左端（32）より小さくならないかチェック
          JR      C,M1DOWN      ; 
          LD      D,A           ; X座標を更新
          INC     (IX+10)       ; パラメータを増やす          
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
          CALL    SETGAG        ; ゲージ表示か何かのサブルーチンを呼ぶ
          RET                   ; 終了！
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
          RET                   ; 更新完了、戻る
;
; TURN SUB 
;
; ３軸回転サブルーチン
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
          CALL    NZ,KAITEN     ; 0でなければ回転サブルーチン実行！
          ; 軸の入れ替え（レジスタの役割をスライドさせる）
          LD      E,B           ; Bを退避
          LD      B,D           ; 
          INC     HL            ; 次のデータ（Y軸回転角）へ
          LD      A,(HL)        ; 
          OR      A             ; 
          CALL    NZ,KAITEN     ; 2軸目の回転実行！
          ; 再び軸の入れ替え
          LD      D,C           ; 
          LD      C,B           ; 
          LD      B,E           ; 
          INC     HL            ; 次のデータ（Z軸回転角）へ
          LD      A,(HL)        ; 
          OR      A             ; 
          CALL    NZ,KAITEN     ; 3軸目の回転実行！
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
          LD      (HL),0        ; 状態管理用？（例えば生存時間や初期状態）をリセット
          INC     HL            ; 
          LD      (HL),0        ; 
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
          JP      Z,MALEND      ; 最大なら、このフェードインタスクを自身で消去して終了
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
          JP      Z,MALEND      ; 完了したら、このオブジェクトを消去（MALEND）して終了
          ; --- パレットの減算値をセット ---
          LD      (PLDAT),A     ; カウント値Aをそのまま減算値として書き込む
                                ; (0=通常, 1=少し暗い ... 7=真っ暗)
          CALL    PALETE        ; パレット更新ルーチンを呼び出し、実際に画面を暗くする
          RET                   ; 次のフレームまで待機
;
;---- WORK AREA ----
;
RDVDP:    DEFS    2             ; VDPのポートアドレス（ベース）格納用
                                ; (MAINルーチンで BC,(RDVDP+1) として使用)
WORK:     DEFS    3             ; 3D回転演算（TURN）時の一時的な座標置き場
                                ; (X, Y, Z の3バイト分)
HYOUJI:   DEFS    120           ; 変換後の2D座標を格納するテーブル
                                ; (最大で60頂点分、または複数の物体用)
VIJUAL:   DEFB    0             ; 現在表示中のVRAMページ番号（0 または 1）
                                ; (ダブルバッファリングの切り替えに使用)
STACK:    DEFW    0             ; ゲーム内スタックの退避用
SSTACK:   DEFW    0             ; システム（BIOS）スタックの退避用
                                ; (エラー時や中断時の復帰ポイント)
; --- ゲーム・コントロール ---
SCROLL:   DEFB    0,0           ; 背景スクロール値（X, Y）
SCOLOR:   DEFB    3,1           ; 描画色（ペン色と背景色など）
SWHICH:   DEFB    00001001B     ; ★システム制御フラグ
                                ; (bit0:スケーリング, bit3:ザコ敵描画 ...等のスイッチ)
CONTRT:   DEFW    00            ; コントロールルーチンのアドレス
DEADRT:   DEFW    00            ; プレイヤー死亡（LIFE=0）時のジャンプ先
LIFE:     DEFB    16            ; プレイヤーの耐久力（16段階）
STOCK:    DEFB    3             ; 残機
SCORE:    DEFW    00            ; 現在のスコア
HSCORE:   DEFW    00            ; ハイスコア
GAGE:     DEFB    0,0,0,0,0,0   ; 当たり判定ボックス
MASTER:   DEFS    16            ; 自機（マスターオブジェクト）専用のワーク
                                ; (座標、AIポインタ、フラグ、回転角など)
PORIDAT:  DEFS    256           ; ★エネミー・タスク・エリア
                                ; (16バイトのワーク × 最大16個分)
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
; MINING PARTY ROUTINE
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
PARTY:    CALL    RND
          CP      224
          JR      NC,$-5
          ADD     A,12
          LD      (PARRD+4),A
          CALL    RND
          AND     7
          LD      HL,PARPD1
          LD      DE,PARMV
          LD      C,7
          JR      Z,PARJP1
          LD      HL,PARPD2
          LD      DE,PARMV2
          LD      C,6
PARJP1:   LD      (PARRD+0),HL
          LD      (PARRD+2),DE
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
PARMV2:   LD      A,(IX+1)
          INC     (IX+1)
          LD      HL,PARPD2
          AND     2
          JR      Z,PARJP2
          LD      HL,PARPD3
PARJP2    LD      (IX+4),H
          LD      (IX+3),L
          LD      A,(IX+9)
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
; LOGO DEMO とりあえず設置
;
;------------------------------------------------
;
LOGODEMO: LD      IX,SCOLOR
          LD      A,15
          LD      (IX+0),A
          LD      A,1
          LD      (IX+1),A
          LD      A,00001000B
          LD      (IX+2),A
          
          CALL    CLSPRI
          CALL    UNFADE
          LD      A,8
          CALL    MAIN
          ;
          CALL    DSET
          DEFW    LOGODATA,LOGOMV2
          DEFB    128,128,160,-30,0,0
          DEFB    15,0,00101000B
          ;
          LD      A,24
          CALL    MAIN
          CALL    FADE
          LD      A,10
          CALL    MAIN
          JP      TITLE
          ;          
LOGOMV11:  
		  CALL    MOVE
          DEFB   -1,0,20
          DEFB    2,3,0
          RET
LOGOMV12:  
		  CALL    MOVE
          DEFB    0,1,20
          DEFB    0,3,2
          RET
LOGOMV13:  
		  CALL    MOVE
          DEFB    1,0,20
          DEFB    3,0,2
          RET
          ;
LOGOMV2:  LD 	  A,(IX+9)
		  CP      10
          JR      Z,MV2JR
		  CALL    MOVE
          DEFB    0,0,-15
          DEFB    3,-0,0
MV2JR:    
          INC     (IX+1)
          LD      A,(IX+1)
          CP      16
          JR      NZ,MV2JR2   
          CALL    DSET
          DEFW    LGMDATA,LOGOMV11
          DEFB    58,128,10,0,0,0
          DEFB    15,0,00101000B
          CALL    DSET
          DEFW    LGSDATA,LOGOMV12
          DEFB    128,128,10,0,0,0
          DEFB    15,0,00101000B
          CALL    DSET
          DEFW    LGXDATA,LOGOMV13
          DEFB    193,128,10,0,0,0
          DEFB    15,0,00101000B
          JP      MALEND
MV2JR2:   
          CALL    DSET
          DEFW    LGDEMOMJ,MHYOUJ
          DEFB    15,0,0,0,0,0
          DEFB    0,0,00010101B 
          RET
          
LGDEMOMJ: DEFB 'M',10+46,175,'S',10+62,175,'X',10+78,175,'2',10+94,175,'G',10+126,175,'A',10+142,175,'M',10+158,175,'E',10+174,175,'S',10+188,175
		  DEFB MJVER,60+158,220,MIVER,60+170,220,PTVER,60+182,220,0
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
;---- LOGO POINT DATA ----
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
          DEFB    +35,+15,0
          DEFB    +20,-10,0
          DEFB    -15,-10,0
          DEFB    -15,-20,0
          DEFB    +40,-20,0
          DEFB    +55,  0,0
          DEFB    +25,+40,0
          DEFB    +45,+40,0
          DEFB	  +65,+15,0
          DEFB    +85,+40,0
          DEFB   +105,+40,0
          DEFB    +75,  0,0
          DEFB   +105,-40,0
          DEFB    +85,-40,0
          DEFB    +65,-15,0
          DEFB    +45,-40,0
          DEFB    -20,-40,0
          DEFB    -35,-15,0
          DEFB    -20,+10,0
          DEFB    +15,+10,0
          DEFB    +15,+20,0          
          DEFB    -35,+20,0
          DEFB    -50,-40,0
          DEFB    -60,-40,0
          DEFB    -70,  0,0
          DEFB    -80,-40,0
          DEFB    1,2,3,4,5,6,7,8,9,10,11,12,13,14
          DEFB    15,16,17,18,19,20,21,22,23,24,25
          DEFB    26,27,28,29,30,31,32,33,34,35,1,0,0

;
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
          
          CALL    VERDISP
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
VERDISP:
          CALL    DSET
          DEFW    DEVVER,MHYOUJ
          DEFB    80,0,0,0,0,80
          DEFB    15,200,00010101B       
          RET
          
DEVVER:   DEFB 'V',16+46,160,'E',16+62,160,'R',16+78,160
		  DEFB	MJVER,16+126,160,MIVER,16+142,160,PTVER,0 
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
          CALL    DSET
S2CHARD2: DEFW    S2CHAPD2,S2CHARP2
          DEFB    128,128,245,0,0,0
          DEFB    12,2,00000010B
          RET
          ;
S2CHAPD2: DEFB    32,3
          DEFB     -8,-50,  8
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
          
          DEFB    -25,  0, -8
          DEFB    -25,  0,  8
          DEFB    -25,  0, -8
          DEFB    -25,  0,  8
          DEFB      0, 25, -8
          DEFB      0, 25,  8
          DEFB      0,-25, -8
          DEFB      0,-25,  8
         
          DEFB    1,2,3,4,5,6,7,8,9,10,11,12,1,0
          DEFB    13,14,15,16,17,18,19,20,21,22,23,24,13,0
          DEFB    1,13,0,2,14,0,3,15,0,4,16,0,5,17,0
          DEFB    6,18,0,7,19,0,8,20,0,9,21,0,10,22,0
          DEFB    11,23,0,12,24,0,0
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
