
## config.rb の説明

* config ファイルは、次の優先度で読み込まれます。

  * 環境変数 RASPIREC_CONF で指定したファイル(拡張子は .rb)
  * $HOME/.config/raspirec/config.rb


* 配列の定義で、`%w( 1 2 3 )` は `[ "1", "2", "3" ]` と等価です。

## 各パラメータの意味は次の通りです。

#### httpd

| 定数名             | 説明 |
|--------------------|------|
|Http_port|httpd のポート番号を指定する。<BR>WEBインターフェースには http://XXX.YYY.ZZZ:${Http_port}/ でアクセスする。|

#### ディレクトリ、ファイル関係

| 定数名             | 説明 |
|--------------------|------|
|Recpt1_cmd|recpt1 コマンドの path を指定する。|
|Recpt1_opt|recpt1 コマンドのオプションを指定する。b25 デコードをする場合は --b25 を指定する。|
|Epgdump|epgdump コマンドの path を指定する。|
|BaseDir|raspirec がインストールされているディレクトリを設定する。( raspirec.rb があるディレクトリ )|
|DataDir|データベースや録画したファイルの置き場所を指定する。|

#### 録画タイミング関係

| 定数名             | 説明 |
|--------------------|------|
|Start_margin|番組開始前の録画マージンを指定(秒)。録画は PC の時計を基準に、開始します。|
|After_margin|番組終了後の録画マージンを指定(秒)。録画は PC の時計を基準に、終了します。|
|Gap_time|録画が連続し、前番組が時短になった場合の、前番組録画終了から次番組開始間隔を指定(秒)。<br>前番組は Start_margin +  Gap_time の秒数だけ録画時間が削られます。<br>TVチューナー依存ですが、あまり短いと動作が不安定になります。|

#### チューナー関係

| 定数名             | 説明 |
|--------------------|------|
|GR_tuner_num|地デジチュナー数|
|BSCS_tuner_num|BSCSチュナー数|
|GBC_tuner_num|地デジ/BS/CS チューナー数|
|Total_tuner_limit|トータルチュナー数制限を掛ける場合に指定する。使用しない場合は false|

#### EPG関係

| 定数名             | 説明 |
|--------------------|------|
|GR_EPG_channel|地デジ EPG 受信局を設定する。<br>東京スカイツリーならば%w( 27 26 25 24 22 23 21 16 ) になります。<a href="https://www.maspro.co.jp/contact/channel.pdf#page=4"> 参考 </a>|
|BS_EPG_channel|BS EPG 受信局を設定する。BSを受信しない場合は空にする。<br>通常の番組情報は、どれか 1局だけ受信すれば十分だが、詳細情報を取得するには、その情報を取りたい局を指定する必要がある。|
|CS_EPG_channel|CS EPG 受信局を設定する。CSを受信しない場合は空にする。|
|GR_EpgRsvTime|地デジ EPG受信時間 (秒)|
|BS_EpgRsvTime|BS EPG受信時間 (秒)|
|CS_EpgRsvTime|CS EPG受信時間 (秒)|
|EPGperiod|EPG 取得周期 (H)|
|EpgBanTime|EPG の取得禁止時間帯の指定。(24H制 時間単位) 1時から5時までを禁止したい場合は、[ 1,2,3,4,5 ] と指定する。使用しない場合は nil|
|EPG_tuner_limit|EPG取得時の使用チュナー数に制限を掛ける場合に指定する。使用しない場合は false|


#### 自動録画延長機能
| 定数名             | 説明 |
|--------------------|------|
|AutoRecExt          | 自動録画延長機能  true で有効。 詳細は <a href="https://kaikoma-soft.github.io/raspirec-RecExt.html"> こちら </a> を参照 |
|ARE_sampling_time   | 番組終了の n 秒前に EPG 採取 |
|ARE_epgdump_opt     | 最後尾切り出しの epgdump のオプション |


#### ダイアログのオプション初期値

| 定数名             | 説明 |
|--------------------|------|
|D_FreeOnly|無料放送のみ|
|D_dedupe|重複予約は無効化する|
|D_jitan|チューナー不足の場合に時短を許可|

#### TSファイル転送

| 定数名             | 説明 |
|--------------------|------|
|TSFT|true=転送機能有効 true以外=無効<br>この機能を使うには、送り先のホストに対して,パスワードなしでssh,scpアクセス可能なように設定されていることが必要です。|
|TSFT_host|送り先 ホスト名|
|TSFT_user|送り先 login名|
|TSFT_toDir|送り先Dir|
|TSFT_rate|想定転送速度 ( Mbyte/秒 )<br> この数字を使って、空き時間に転送する／しないを判断します。|

#### HLS モニタ機能

| 定数名             | 説明 |
|--------------------|------|
|MonitorFunc|true=モニタ機能を有効, false=無効。 無効の場合は、下記のパラメータは無視される。設定方法は <a href="https://kaikoma-soft.github.io/raspirec-option.html"> こちら </a> を参照して下さい。|
|StreamDir|ストリーム出力先ディレクトリ|
|MonitorWidth|モニタ画面の横幅|
|HlsConvCmd|HLS変換コマンド|

#### mpv モニタ機能

| 定数名             | 説明 |
|--------------------|------|
|MPMonitor|true = mpv モニタ機能を有効、false = 無効 <br>無効の場合は、下記のパラメータは無視される。設定方法は <a href="https://kaikoma-soft.github.io/raspirec-option.html"> こちら </a> を参照して下さい。|
|DevAutoDetection| DeviceList_GR, DeviceList_BSCS, DeviceList_GBC を自動設定する。true = 有効。|
|DeviceList_GR|地デジのデバイスファイルを指定する。|
|DeviceList_BSCS|BS,CS のデバイスファイルを指定する。|
|DeviceList_GBC | 地デジ,BS,CS のデバイスファイルを指定する。|
|Mpv_cmd|mpv の実行ファイル名(絶対パス)|
|Mpv_opt|mpv の引数を指定する。
|RemoteMonitor|表示するマシンが別の場合 ture, 同一の場合に false|
|UDPbasePort|使用する UDP のポート番号、デバイスの数だけプラスされる。|
|XServerName|RemoteMonitor が true の場合に、mpvを実行、表示するマシンのマシン名を設定する。|
|RecHostName|RemoteMonitor が true の場合に、チューナー(raspirecが実行されている)のマシン名を設定する。|
|Lsof_cmd|lsof コマンドへのパス。Ubuntu では /usr/bin/lsof |
|Browser_cmd| 番組表を表示するブラウザの実行ファイル名(絶対パス) |
|RaspirecTV_font|フォント指定|
|RaspirecTV_GEO|座標指定 ( WxH+X+Y or X+Y )|
|RaspirecTV_SOCAT|socat の実行ファイル名(絶対パス)(RemoteMonitor == true の時のみ)|

#### その他

| 定数名             | 説明 |
|--------------------|------|
|TSnameFormat|TSファイル名の生成ルール。詳細は 「コントロールパネル／補足説明」を参照して下さい。|
|LogSaveDay|ログの保持期間(日)|
|RsvHisSaveDay|録画済み記録の保持期間(日)|
|DiskKeepPercent|録画したTSファイルを古い順に削除して指定したDisk容量(%)を確保する。(指定するのは空き容量)<br>機能を無効にする場合は false を指定する。|
|Local_jquery|オフライン環境で動作させる為に jquery, materialize のライブラリをローカルにコピーした場合に、true にする。<br>詳細は doc/jquery_local.md を参照の事。 通常は false|
|StationPage|番組表で、1ページ当たりの放送局数 (個) の初期値|
|Debug|ture で Debug モード。ログファイルを出力するようになる。オプションで、 -d を指定するのと同じ。|
|Debug_mem|ture で メモリの消費量をモニタするようになる。|
|TitleRegex|「自動予約」ボタンを押して番組検索に遷移した時に、番組タイトルから「題名」を生成する為の、余計な文字を削除する正規表現の配列|
|SearchStringRegex|「自動予約」ボタンを押して番組検索に遷移した時に、番組タイトルから「検索文字列」を生成する為の、余計な文字を削除する正規表現の配列|
|EpgPatchEnable|EPGPatch機能を有効にする。 false = 無効。デフォルトは有効|