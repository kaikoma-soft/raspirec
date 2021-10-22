
## 名前

  tool/reserve_SL.rb  予約データの save & load

## 書式

   reserve_SL.rb [Options1]  [Options2...]  file

## 説明

   データベース中の予約関係データを保存、読み込みを行う。

## オプション

### Options1

-s,--save  &emsp; 
データセーブモード : DBの中の予約関係データ を yaml 形式でダンプする。

-l,--load  &emsp; 
データロードモード : ダンプしたファイルを DBに読み込む。

### Options2

-f, --filter &emsp;
フィルターデータ

-a, --auto  &emsp;
自動予約データ

-r, --reserv  &emsp;
未録画   予約データ

-o, --old  &emsp;
録画済み 予約データ

-A, --ALL   &emsp;
全部(-f,-a,-r,-o)

-d, --db  db_file &emsp;
DBファイルの指定(デフォルトは config.rb 中の DbFname )

-C, --clearTable  &emsp;
読み込む前にデータ削除

file &emsp;  yaml 入力(-l時),出力(-s時) ファイル名

## 例

```
% ruby tool/reserve_SL.rb --save -A backup.yaml        # バックアップ
% ruby tool/reserve_SL.rb --load -f -a  backup.yaml    # restore
```



## 注意
* 事前に config.rb の設定がされている事が必要です。
