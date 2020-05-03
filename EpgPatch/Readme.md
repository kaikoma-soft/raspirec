
## 目的

このディレクトリは、EPG データに修正を加える必要がある場合に、
パッチデータを設定するものです。

## 設定ルール

* ファイル名の拡張子は .dat とする。  
   例   2020-04-01.dat

* ファイルに記述する書式は、
    + \# の後ろはコメント
    + チャンネルID は ```[]``` で囲む  
       例   [BS_101]
    + 書き換え対象を ```キーワード + 空白文字 + 値``` で指定する    
      例   "stinfo_slot    1"
    + キーワード は以下のもの
    ```
      tsid                transport_stream_id
      onid                original_network_id
      svid                service_id
      name                放送局名
      stinfo_tp           トランスポート番号
      stinfo_slot         スロット番号
    ```

* 内容を変更した場合は、プログラムの再起動が必要。


* 記述例
    ```
    [BS_231]                # 放送大学ex
    stinfo_slot    1

    [BS_232]                # 放送大学on
    stinfo_slot    1

    [BS_241]                # ＢＳスカパー！
    stinfo_slot    0
    ```
      
      
    