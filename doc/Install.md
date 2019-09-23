
### インストール例

#### 条件
```
     PC           :  raspberrypi zero w
     TVチューナー    :  PLEX PX-Q3U4 
     OS           :  raspbian-buster-lite
     ドライバー      :  px4_drv
```

#### インストール

-  インストールに必要なパッケージを apt install で インストール

```
    git
    autoconf
    raspberrypi-kernel-headers
    dkms
    cmake
    sqlite3
    ruby
    ruby-sqlite3
    ruby-sys-filesystem
    ruby-net-ssh
    ruby-sinatra
    ruby-slim
    ruby-sass
```

- recpt1

```
   git clone https://github.com/stz2012/recpt1.git
   cd recpt1/recpt1
   sh autogen.sh
   ./configure
   PX-Q3U4 用に デバイス名を変更する。
   make
   sudo make install
```

- px4_drv

   `git clone https://github.com/nns779/px4_drv.git`

   ドキュメントに従ってインストール


- epgdump

```
   git clone https://github.com/Piro77/epgdump
   cd epgdump
   cmake .
   make
   sudo make install
```


-  raspirec 本体

  インストールするディレクトリに移動して

```
   git clone https://github.com/kaikoma-soft/raspirec.git
   cd raspirec
   mkdir -p ~/.config/raspirec
   cp config.rb.sample ~/.config/raspirec/config.rb
   エディタで、~/.config/raspirec/config.rb を適宜修正
```

- 動作確認

  `% ruby raspirec.rb`

  でプログラムを起動する。
  すぐに終了するがバックグランドでサービスが走っているので、

   `http://localhost:4567/`

  にアクセスし、画面が出れば正常
  なお初回は、番組表取得するまでは多少の時間が掛かる。
