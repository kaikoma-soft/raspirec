
## config.rb の説明

* config ファイルは、次の優先度で読み込まれます。

  * 環境変数 RASPIREC_CONF で指定したファイル(拡張子は .rb)
  * $HOME/.config/raspirec/config.rb


* 配列の定義で、`%w( 1 2 3 )` は `[ "1", "2", "3" ]` と等価です。

## 各パラメータの意味は次の通りです。

#### httpd

| 定数名             | 説明 |
|--------------------|------|
| Http_port          | httpd のポート番号を指定する。WEBインターフェースには http://XXX.YYY.ZZZ:4567/ でアクセスする。 |

#### ディレクトリ、ファイル関係

| 定数名             | 説明 |
|--------------------|------|
| Recpt1_cmd         | recpt1 コマンドの path を指定する。 |
| Recpt1_opt         | recpt1 コマンドのオプションを指定する。 b25 デコードをする場合は --b25 を指定する。|
| Epgdump            | epgdump コマンドの path を指定する。
| BaseDir            | raspirec がインストールされているディレクトリを設定する。 ( raspirec.rb があるディレクトリ )
| DataDir            | データベースや録画したファイルの置き場所を指定する。|
| Start_margin       | 番組開始前の録画マージンを指定(秒)。録画は PC の時計を基準に、開始します。|
| After_margin       | 番組終了後の録画マージンを指定(秒)。録画は PC の時計を基準に、終了します。|
| Gap_time           | 録画が連続し、前番組が時短になった場合の、前番組録画終了から次番組開始間隔を指定(秒)。<br>前番組は Start_margin + Gap_time の秒数だけ録画時間が削られます。TVチューナー依存ですが、あまり短いと動作が不安定になります。|


#### EPG関係

| 定数名             | 説明 |
|--------------------|------|
| GR_tuner_num       | 地デジチュナー数 |
| BSCS_tuner_num     | BSCSチュナー数  |
| Total_tuner_limit  | トータルチュナー数制限を掛ける場合に指定する。 通常は GR_tuner_num + BSCS_tuner_num = Total_tuner_limit |
| GR_EPG_channel     | 地デジ EPG 受信局を設定する。 東京スカイツリーならば `%w( 27 26 25 24 22 23 21 16 )` になります。|
| BS_EPG_channel     | BS EPG 受信局を設定する。BSを受信しない場合は空にする。通常の番組情報は、どれか 1局だけ受信すれば十分だが、詳細情報を取得するには、その情報を取りたい局を指定する必要がある。|
| CS_EPG_channel     | CS EPG 受信局を設定する。CSを受信しない場合は空にする。|
| GR_EpgRsvTime      | 地デジ EPG受信時間 (秒) |
| BS_EpgRsvTime      | BS EPG受信時間 (秒) |
| CS_EpgRsvTime      | CS EPG受信時間 (秒) |
| EPGperiod          | EPG 取得周期 (H)    |

#### ダイアログのオプション初期値

| 定数名             | 説明 |
|--------------------|------|
| D_FreeOnly         | true の場合「無料放送のみ」にチェックを付ける  |
| D_dedupe           | true の場合「重複予約は無効化する」にチェックを付ける |
| D_jitan            | true の場合「チューナー不足の場合に時短を許可」にチェックを付ける |

#### TSファイル転送

| 定数名             | 説明 |
|--------------------|------|
| TSFT               | true=転送機能有効 true以外=無効 <br> この機能を使うには、送り先のホストに対して,パスワードなしで ssh,scpアクセス可能なように設定されていることが必要です。|
| TSFT_host          | 送り先 ホスト名 |
| TSFT_user	         | 送り先 login名 |
| TSFT_toDir         | 送り先Dir |
| TSFT_rate          | 想定転送速度 ( Mbyte/秒 ) <br>この数字を使って、空き時間に転送する／しないを判断します。|

#### その他

| 定数名             | 説明 |
|--------------------|------|
| LogSaveDay         | ログの保持期間(日) |
| RsvHisSaveDay      | 録画済み記録の保持期間(日) |
| DiskKeepPercent    | 録画したTSファイルを古い順に削除して指定したDisk容量(%)を確保する。<br>(指定するのは空き容量)機能を無効にする場合は false を指定する。
| Local_jquery       | オフライン環境で動作させる為に jquery, materialize のライブラリをローカルにコピーした場合に、true にする。<br> 詳細は doc/jquery_local.md を参照の事。通常は false |
| StationPage        | 番組表で、1ページ当たりの放送局数 (個) |
| Debug              | ture で Debug モード。ログファイルを出力するようになる。オプションで、 -d を指定するのと同じ。|
| Debug_mem	         | ture で メモリの消費量をモニタするようになる。|
