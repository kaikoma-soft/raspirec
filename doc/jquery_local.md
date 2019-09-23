

## jquery と materializ をローカルに配置して使う方法

- 下記のファイルを public の下にダウンロードする。

  BaseDir はインストールしたディレクトリ
  
```
  % cd $BaseDir/src/public
  % wget https://code.jquery.com/jquery-3.3.1.min.js
  % wget https://code.jquery.com/ui/1.12.0/jquery-ui.min.js
  % wget http://code.jquery.com/ui/1.12.1/themes/pepper-grinder/jquery-ui.css
  % wget https://cdnjs.cloudflare.com/ajax/libs/materialize/1.0.0/css/materialize.min.css
  % wget https://cdnjs.cloudflare.com/ajax/libs/materialize/1.0.0/js/materialize.min.js
```

- $HOME/.config/raspirec/config.rb の下記のパラメータを変更する。

 `Local_jquery = false -> true`

- プログラムを再起動する。


