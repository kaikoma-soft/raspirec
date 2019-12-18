

## TS ファイル名の生成ルール

- 出力する TS ファイル名の生成ルールは、config.rb 中の TSnameFormat で指定する。

- デフォルトは、
"%YEAR%-%MONTH%-%DAY%_%HOUR%:%MIN%_%DURATION%_%TITLE%_%CHNAME%"
で、<br>
"2019-12-17_15:00_1800_ショッピング情報_BS11イレブン.ts" に展開される。

- 使用出来るキーワードは下記のもの。

|キーワード   |意味          |
|-------------|--------------|
|%TITLE%      | 番組タイトル |
|%ST%         | 開始日時（ YYYYMMDDHHMM ) |
|%ET%         | 終了日時（同上） |
|%BAND%       | GR,BS,CS |
|%CHNAME%     | 放送局名 |
|%YEAR%       | 開始年 |
|%MONTH%      | 開始月 |
|%DAY%        | 開始日 |
|%HOUR%       | 開始時 |
|%MIN%        | 開始分 |
|%SEC%        | 開始秒 |
|%WDAY%       | 曜日 0(日曜日)から6(土曜日) |
|%DURATION%   | 録画時間（秒） |




