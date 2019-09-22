

## 目的

本プログラムは、PX-Q3U4,PT2等のチューナー使ってTV番組を録画する為の
管理ソフトです。


## 特徴

* Raspberry Pi のようなシングルボードコンピュータ(SBC)でも実行できるように、
  機能はシンプルで小型、軽量。
* 同時録画本数を多くする為に低負荷を目指す。
  (raspberyy Pi 3B+ で 6本までは確認)
* WEBインターフェースで、EPG番組表から録画予約が可能。
* 条件検索を設定することで、自動予約登録が可能。
* 録画したTSファイルを、親機にコピーする機能
* チューナーの数とは別に、同時録画の本数で制限を掛ける事が可能。
  (SBCの場合、能力不足により本数制限が必要になる。)

## ステータス

* 現在運用試験中。
* とりあえず録画で出来る所まで出来たので、βリリースで公開開始


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
  だたし、あらかじめダウンロードして置けばオフラインでも動作させる事ができる。

* セキュリティにはあまり考慮していないので、インターネット側から
  アクセス出来る状態にしないで下さい。


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

  インストールするディレクトリに移動して
  
  % git clone https://github.com/kaikoma-soft/raspirec.git

* 環境に合わせてカスタマイズ

  * 雛形の config.rb を $HOME/raspirec/config.rb にコピー
  * コピーした config.rb をテキストエディタを使って、自分の環境に合わせるように     修正する。 必須なのは

      * Recpt1_cmd
      * Epgdump
      * BaseDir
      * DataDir
      * GR_EPG_channel

* 実行

  % ruby ${BaseDir}/raspirec.rb

  でデーモンモードで起動する。
  すぐに終了するが、バックグラウンドでサービスは走っているので、
  WEBブラウザ で http://ホスト名:4567/ でアクセスする。
  ( ポート番号の 4567はデフォルトの値で、config で変更可)

  なお、PC の boot時に、自動で起動させたい場合は crontab に

  @reboot /usr/bin/ruby ${BaseDir}/raspirec.rb

  を記述する。


## アンインストール方法

  * ディレクトリ BaseDir, DataDir 以下のファイルを削除
  * インストールしたパッケージを apt remove で削除

  

## ライセンス
このソフトウェアは、Apache License Version 2.0 ライセンスのも
とで公開します。詳しくは LICENSE を見て下さい。
