

## 目的

本プログラム(raspirec) は Linux 系OS上で、
recpt1,epgdump を使って TV番組を録画する録画サーバーを構築するための
プログラムです。

特に、ラズパイのようなシングルボードコンピュータ(SBC)で動作させる事に最適化しています。

なお動作には recpt1 に対応しているドライバーがあるTVチューナー
( アースソフト社製 PT1〜3, PLEX社製 PX-W3U4、PX-W3PE4、PX-Q3U4、PX-Q3PE4 等)
が必要です。


## 特徴

* Raspberry Pi のようなシングルボードコンピュータ(SBC)でも実行できるように、
  機能はシンプルで小型、軽量。
* 処理能力の低いPCでも動作するように最適化。
* 同時録画本数を多くする為に録画中は負荷を掛けない。
  (raspberyy Pi 3B+ で 6本までは確認)
* インストールが容易
* WEBインターフェースで、EPG番組表から録画予約が可能。
* 条件検索を設定することで、自動予約登録が可能。
* 録画したTSファイルを、親機にコピーする機能
* チューナーの数とは別に、同時録画の本数で制限を掛ける事が可能。
  (SBCの場合、能力不足により本数制限が必要になる。)

## スクリーンショット

|![](https://github.com/kaikoma-soft/raspirec/wiki/images/top.png)|![](https://github.com/kaikoma-soft/raspirec/wiki/images/prg_tbl.png)|![](https://github.com/kaikoma-soft/raspirec/wiki/images/rsv_tbl.png)|![](https://github.com/kaikoma-soft/raspirec/wiki/images/search.png)|
|---|---|---|---|

## ステータス

* 現在運用試験中。
* とりあえず録画で出来る所まで出来たので、β版で公開開始


## 実行に必要な環境

* Linux系 OSが稼働するPC と OS
* ruby  2.5 以上
* sqlite3
* TVチューナー ( recpt1 のドライバーが存在するもの )
* recpt1 ( https://github.com/stz2012/recpt1 を推奨 )
* epgdump ( https://github.com/Piro77/epgdump を推奨 )
* もし b25 デコードするなら b25 ライブラリ + カードリーダー


## 制限事項

* jquery,Materialize を参照しているので、インターネットにアクセス出来る環境
  で動作させる事が必要。
  だたし、あらかじめ参照ファイルをダウンロードして置けばオフラインでも動作
  させる事ができる。( doc/jquery_local.md を参照 )

* セキュリティにはあまり考慮していないので、インターネット側から
  アクセス出来る状態にしないで下さい。

* android版(Fire HD10)のブラウザでは、一部機能が動作しない。
  ( firefox と opera では、動作しない箇所が違う。)

## インストール方法 ( Raspbian buster lite の場合 )

* インストールに必要な下記のパッケージを apt install で インストールする。

    * git
    * autoconf
    * raspberrypi-kernel-headers
    * dkms
    * cmake
    * sqlite3
    * ruby
    * ruby-sqlite3
    * ruby-sys-filesystem
    * ruby-net-ssh
    * ruby-sinatra
    * ruby-slim
    * ruby-sass


* recpt1

  ハードに合わせたドライバーをインストールし、
  コマンドラインから実行して録画出来る事を確認しておく。

* epgdump

   epgdump は、同じ名前で仕様の違うものがあるので、
   必ず https://github.com/Piro77/epgdump を使う。

* 本体

    1. インストールするディレクトリに移動して

       `% git clone https://github.com/kaikoma-soft/raspirec.git`

    1. 環境に合わせてカスタマイズ

       * 雛形の config.rb.sample を $HOME/raspirec/config.rb にコピー
       * コピーした config.rb をテキストエディタを使って、
         自分の環境に合わせるように修正する。
         とりあえず最低限必須なのは次のもの。詳細は doc/config.md を参照
         
         ```
         Recpt1_cmd        : recpt1 コマンドの path を指定する。
         Epgdump           : epgdump コマンドの path を指定する。
         BaseDir           : raspirec がインストールされているディレクトリを設定する。 ( raspirec.rb があるディレクトリ )
         DataDir           : データベースや録画したファイルの置き場所を指定する。
         GR_EPG_channel    : 地デジ EPG 受信局を設定する。
         GR_tuner_num      : 地デジチュナー数
         BSCS_tuner_num    : BSCSチュナー数
         ```

* 実行方法

  `% ruby ${BaseDir}/raspirec.rb`

  でデーモンモードで起動する。(BaseDirはインストールしたディレクトリ)
  <br>
  すぐに終了するが、バックグラウンドでサービスは走っているので、
  WEBブラウザ で http://ホスト名:4567/ でアクセスする。
  ( ポート番号の 4567はデフォルトの値で、config で変更可)

  なお、PC の boot時に、自動で起動させたい場合は crontab に

  `@reboot /usr/bin/ruby ${BaseDir}/raspirec.rb`

  を記述する。

* 停止方法

  `% ruby ${BaseDir}/raspirec.rb --kill`

  で、デーモンが停止する。

## アンインストール方法

  * ディレクトリ BaseDir, DataDir 以下のファイルを削除
  * インストールしたパッケージを apt remove で削除

## 動作確認環境

 |              |  その１             | その２                      |
 |--------------|---------------------|-----------------------------|
 | 機種         |  raspberry pi 3B+   | AMD Ryzen 7 2700 + MEM 16G  |
 | OS           |  Raspbian Stretch   | Ubuntu 18.04.3 LTS          |
 | TVチューナー |  PX-Q3U4            | PT2                         |
 | ドライバー   |  px4_drv            | pt1_drv                     |


## リンク

+ [gitHub raspirec](https://github.com/kaikoma-soft/raspirec )
+ [gitHub recpt1]( https://github.com/stz2012/recpt1 )
+ [gitHub epgdump]( https://github.com/Piro77/epgdump )
+ [gitHub px4_drv]( https://github.com/nns779/px4_drv )
+ [PLEX社 Linux用ドライバー]( http://www.plex-net.co.jp/download/ )




## ライセンス
このソフトウェアは、Apache License Version 2.0 ライセンスのも
とで公開します。詳しくは LICENSE を見て下さい。
