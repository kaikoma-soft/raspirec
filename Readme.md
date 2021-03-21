
## 目的

本プログラム(raspirec) は Linux 系OS上で、
recpt1/recdvb,epgdump を使って TV番組を録画する録画サーバーを構築するための
録画予約システムです。
<br>
特に、ラズパイのようなシングルボードコンピュータ(SBC)で動作させる事に最適化しています。

なお動作には recpt1/recdvb に対応しているドライバーがあるTVチューナー
( アースソフト社製 PT1〜3, PLEX社製 PX-W3U4、PX-W3PE4、PX-Q3U4、PX-Q3PE4 等)
が必要です。

## 特徴

* Raspberry Pi のようなシングルボードコンピュータ(SBC)でも実行できるように、
  機能はシンプルで小型、軽量。
* 処理能力の低いPCでも動作するように最適化。
* 同時録画本数を多くする為に録画中はなるべく負荷を掛けない。
  (raspbery Pi 3B+ で 6本までは確認)
* インストールが容易
* WEBインターフェースで、EPG番組表から録画予約が可能。
* 条件検索を設定することで、自動予約登録が可能。
* 録画したTSファイルを、親機にコピーする機能
* チューナーの数とは別に、同時録画の本数で制限を掛ける事が可能。
  (SBCの場合、能力不足により本数制限が必要になる。)


## 詳細
インストール方法等の詳細は、
[GitHub Pages](https://kaikoma-soft.github.io/src/raspirec.html)
を参照して下さい。


## docker
[dockerによる動作テスト環境](https://github.com/kaikoma-soft/docker-raspirec)
を用意したので、簡単に動作テストを行う事が出来ます。



## ライセンス
このソフトウェアは、Apache License Version 2.0 ライセンスのも
とで公開します。詳しくは LICENSE を見て下さい。



