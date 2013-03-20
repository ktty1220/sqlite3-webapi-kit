# sqlite3-webapi-kit - SQLite3をデータベースサーバー化するNode.js用APIキット

SQLite3はMySQLやPostgreSQLと違い、DBファイルに直接アクセスすることによってデータを取り扱うタイプのデータベースです。

手軽に利用できる反面、外部PCからアクセスできないので(マウントやフォルダの共有をすれば可能)、1PC内で1アプリケーションが占有するような使い方が主流となっていると思います。

sqlite3-webapi-kitは、SQLite3のDBファイルをロードしてhttp通信でデータの操作や受け渡しを行うWebAPIサーバー機能を提供するモジュールです。基本機能としてCRUDやスキーマ情報他、直接SQLをパラメータに与えてデータを取得・操作するようなWebAPIを実装していますが、それらをすべて破棄してオリジナルのWebAPIを実装する事も可能です。

## 基本サンプル

sqlite3-webapi-kitをロードして、SQLite3形式のDBファイルを開き、ポート4983で待ち受けを行います。

    var sqlited = require('sqlite3-webapi-kit');
    sqlited.open('/path/to/hoge.db3', function (err) {
      sqlite3.listen(4983, function () {
        console.log('server start');
      });
    });

localhost:4983にアクセスし、userテーブルのレコードを取得します(デフォルト実装WebAPI:`/select`にアクセス)。

    $ curl http://localhost:4983/select?table=user

取得したレコードは以下のようなJSON形式で返ります。

    {
      "result": [
        { "id": 1, "name": "taro", "sex": "male", "age": 30 },
        { "id": 2, "name": "jiro", "sex": "male", "age": 25 },
        { "id": 3, "name": "saburo", "sex": "male", "age": 20 }
      ]
    }

## インストール

    npm install sqlite3-webapi-kit

## 使用方法

requireでsqlite3-webapi-kitをロードします。ロードした変数を使用してDBファイルを読み込んだり、WebAPIメソッドを追加・削除したりして準備を行った後、サーバーを稼動させます。

    sqlited = require('sqlite3-webapi-kit');

### メソッド

#### open(dbfile,[ initSQL,] callback)

DBファイルを開きます。

* dbfile

    DBファイルのパスを指定します。`undefined`もしくは`null`を指定するとメモリ上にデータベースを作成します(:memory:)。

* initSQL (省略可能)

    DBファイルを開いた時に自動的に実行されるSQLを指定します。配列で複数指定すると配列の順番にSQLを実行します。

* callback

    DBファイルを開いた後(initSQLが指定されている場合はinitSQLの内容を実行した後)に呼び出されるcallbackを指定します。

    open処理の過程でエラーが発生した場合は第一引数にエラー情報が入ります。

sqlite3-webapi-kitでは1DBファイルしか開けません。複数のDBファイルを開いてサーバー管理したい場合は`initSQL`で他のDBファイルをattachする等の方法を使用すれば実現できます。

    sqlited.open('/path/to/hoge.db3', [
      "attach '/path/to/fuga.db3' as fuga",
      "attach '/path/to/henyo.db3' as henyo"
    ], callback (err) {
      ...
    });

#### close(callback)

openメソッドで開いたDBファイルを閉じます。メモリ上にデータベースを開いていた場合はその内容を破棄します。

* callback

    DBファイルを閉じた後に呼び出されるcallbackを指定します。

    close処理の過程でエラーが発生した場合は第一引数にエラー情報が入ります。

#### dbname()

現在開いているDBファイルパスを返します。

#### get(sql[, bind], callback)

読み取り系SQL(SELECT)を実行して、取得したレコードを返します。SELECT文以外のSQLを指定した場合はエラーとなります。

* sql

    実行するSELECT文

* bind (動的SQLでない場合は省略可能)

    プレースホルダを使用した動的SQLを実行する場合は、バインドする変数を指定してください。配列で指定する方法と連想配列で指定する方法があります。

    配列を使用する例

        sqlited.get('SELECT * FROM user WHERE age > ? AND sex = ?', [ 20, 'male' ], function (err, result) {
          ...
        });

    連想配列を使用する例

        sqlited.get('SELECT * FROM user WHERE age > $age AND sex = $sex', { $age: 20, $sex: 'male' }, function (err, result) {
          ...
        });

* callback

    第一引数にエラー情報、第二引数に{ 項目名: 値 }の連想配列で構成されたレコードが配列で返ります。

#### post(sql[, bind], callback)

更新系SQL(INSERT/UPDATE/CREATE/DELETE/DROP)を実行して、処理結果ステータスを返します。SELECT文を指定した場合はエラーとなります。

* sql

    実行するSQL文

* bind (動的SQLでない場合は省略可能)

    プレースホルダを使用した動的SQLを実行する場合は、バインドする変数を指定してください。指定の仕方は`get()`と同様です。

* callback

    第一引数にエラー情報、第二引数に処理結果ステータスが返ります。

    処理結果ステータスは以下の内容です。

    * sql

        実行したSQL

    * changes

        更新・削除などの影響があったレコード数

    * lastID

        処理したテーブルの現在の最終ID(INSERT文を実行すると更新されます)

#### postMulti(sql[, transaction], callback)

配列で指定した複数の更新系SQLを順番に実行します。`post()`と異なり、動的SQLは使用できません。

* sql

    実行するSQLの配列を指定します。`post()`と同様、SELECT文を指定するとエラーとなります。

* transaction

    指定したSQL配列をトランザクション内で実行するかどうかの指定です。true/falseで指定します。省略した場合はfalse扱いとなります。trueを指定した場合、配列で指定したSQLのどこかでエラーが発生した場合にそれまでの更新が自動でロールバックされます。

* callback

    第一引数にエラー情報、第二引数に処理結果ステータスがsqlと同じ順番で返ります。 処理結果ステータスの内容は`post()`と同様です。

#### schema(callback)

現在開いているDBファイルのスキーマ情報(各テーブルの項目やインデックス情報など)を返します。

* callback

    第一引数にエラー情報、第二引数にスキーマ情報が返ります。

#### addMethod(path, function)

サーバーで提供するオリジナルなWebAPIを登録します。

* path

    WebAPIで提供するリクエストパスを指定します。`'/hoge'`と指定すると、外部から`http://サーバー名:ポート/hoge`というアクセスに対してfunctionの処理を実行し、その結果を返します。

* function

    pathで指定したリクエストパスにへのアクセスに対してデータを返す関数を指定します。

    functionの形式は、GETパラメータと処理結果を返すコールバックを引数に受け取る関数です。

    __何かしらの処理を行った後に必ず`callback(エラー情報、処理結果)`を呼び出さなければいけません。__

        function (param, callback) {
          ・
          ・
          ・
          return callback(err, result);
        });

    エラー情報は、エラーメッセージ文字列でもnew Errorで作成したエラーオブジェクトでも構いません。エラーがなければ`undefined`を指定します。

    具体的な例はexample.jsを参照してください。

メソッドの登録が成功した場合はtrue、失敗した場合はfalseが返ります。すでに指定したリクエストパスに対する処理が登録されている場合はエラーとはならず、上書きされます。

#### removeMethod(path)

`addMethod()`で登録したWebAPIを削除します。削除されたWebAPIは外部からアクセスできなくなります。

* path

    削除するWebAPIのリクエストパスを指定します(`'/hoge'`など)。

メソッドの削除が成功した場合はtrue、失敗した場合はfalseが返ります。

#### clearMethod()

デフォルトで登録されているWebAPIも含めてすべてのWebAPIを消去します。デフォルトで用意されているWebAPIは更新ができたり直接SQLを実行できたりとセキュリティ面で問題があるので、それらをすべて消して必要最低限の情報を返すオリジナルWebAPIのみを提供したい場合などに使用します。

#### methods()

現在登録されているWebAPIのリクエストパス一覧を配列で返します。

#### setHook(function)

サーバーにアクセスがあった時にリクエストパスの処理を行う前に実行されるフック関数を登録します。

フック関数を指定しない場合はすべてのアクセスを許可します。

* function

    フック関数を指定します。第一引数にクライアントのIPアドレス、第二引数にリクエストオブジェクトが入ります。

    この関数でfalseを返すとリクエストパスに対する処理は行わず、アクセス元に対して403エラーを返します。

    __リクエストを許可する場合は必ずtrueを指定してください。__

        sqlited.setHook(function (remoteAddress, request) {
          // ローカルネットワークのみ許可
          return /^(192\.168\.|127\.0\.0\.1)/.test(remoteAddress);
        });

#### listen([port, ]callback)

外部からの待ち受けを開始します。`listen()`を実行するまでは外部からのアクセスは受け付けません。

* port

    公開ポートを指定します。デフォルトは4983です。

* callback

    待ちうけ開始後に実行されるcallbackです。引数はありません。

#### shutdown(callback)

外部からの待ち受けを停止します。一時的に外部からのアクセスをすべて遮断したい場合に使用します。

* callback

    待ちうけ停止後に実行されるcallbackです。エラーが発生した場合は第一引数にエラー情報が入ります。

### デフォルトで登録されているWebAPI

GETパラメータはURLエンコードした状態である必要があります。

レスポンスのJSONデータは`error`と`result`から成り立っています。エラーが発生しなかった場合は`error`は存在しません。`result`の中身は`get()`や`post()`で取得できる結果オブジェクトと同様です。

__デフォルトで用意されているWebAPIはテーブルの削除など危険なものも含めて外部からどんな操作も可能なので、そのまま使用するのは止めたほうが良いです。あくまでサンプル的な意味合いで用意されているものと考えてください。実際に組み込む際は`clearMethod()`でこれらのデフォルトWebAPIを消去してオリジナルのWebAPIを登録する方法をお勧めします。__

#### /query

サーバーに対しSQLを直接指定して実行させ、その処理結果もしくはレコードを取得します。読み取り系・更新系に関わらず実行できます。

##### GETパラメータ

* sql (必須)

    SQLを指定します。

##### サンプル

    http://localhost:4983/query?sql=select%20name%20from%20user

#### /select

SELECT文を実行し、条件に該当するレコードを取得します。

##### GETパラメータ

* table (必須)

    対象のテーブル名を指定します。

* fields (省略可能)

    取得する項目名(SELECT句以降)を指定します。省略した場合は`*`とみなされます。

* conditions (省略可能)

    抽出条件(WHERE句以降)を指定します。

* sort (省略可能)

    並び順(ORDER BY句以降)を指定します。

* limit (省略可能)

    抽出件数上限(LIMIT句以降)を指定します。

* skip (省略可能)

    取得開始レコード位置(SKIP句以降)を指定します。

##### サンプル

    http://localhost:4983/select?table=user&fields=rowid,name,age&limit=10&sort=age%20desc

#### /update

UPDATE文を実行し、処理結果を取得します。

##### GETパラメータ

* table (必須)

    対象のテーブル名を指定します。

* set (必須)

    取得内容(SET句以降)を指定します。

* conditions (省略可能)

    抽出条件(WHERE句以降)を指定します。

##### サンプル

    http://localhost:4983/update?table=user&set=name=%27taro%27,age=20&conditions=flag%20is%20null

#### /insert

INSERT文を実行し、処理結果を取得します。

##### GETパラメータ

* table (必須)

    対象のテーブル名を指定します。

* fields (省略可能)

    挿入するレコードの項目(INSERT INTO TABLE句以降)を指定します。省略時は全項目とみなされます。

* values (必須)

    挿入項目(VALUES句以降)もしくはSELECT文を指定します。`fields`と項目数が合っている必要があります。

##### サンプル

    http://localhost:4983/insert?table=user&fields=name,age&values=%27hanako%27,30

#### /delete

DELETE文を実行し、処理結果を取得します。

##### GETパラメータ

* table (必須)

    対象のテーブル名を指定します。

* conditions (省略可能)

    削除対象条件(WHERE句以降)を指定します。省略した場合は全レコードが削除対象となります。

##### サンプル

    http://localhost:4983/delete?table=user&conditions=age<10

#### /create

CREATE TABLE文を実行し、処理結果を取得します。

##### GETパラメータ

* table (必須)

    作成するテーブル名を指定します。

* fields (必須)

    作成する項目内容を指定します(項目名 型 その他情報)。

##### サンプル

    http://localhost:4983/create?table=user&fields=id%20integer%20primary%20key,name%20varchar(100)

#### /drop

DROP TABLE文を実行し、処理結果を取得します。

##### GETパラメータ

* table (必須)

    削除するテーブル名を指定します。

##### サンプル

    http://localhost:4983/drop?table=user

#### /schema

現在開いているDBのスキーマ情報を取得します。

##### サンプル

    http://localhost:4983/schema

#### /reload

DBファイルを開き直します(使う意味はなさそうですが)。

##### サンプル

    http://localhost:4983/reload

### 外部からのアクセスに関しての仕様

* 登録されていないWebAPIにアクセスするとステータスコード404が返ります。
* `setHook()`によってアクセスが拒否された場合はステータスコード403が返ります。
* WebAPIでエラーが発生した(レスポンスのJSONの`error`がある)場合はステータスコード500が返ります。
* エラーが発生しなかった場合のステータスコードは200になります。

## Changelog

### 0.1.0 (2013-03-20)

* 初版リリース

## ライセンス

[MIT license](http://www.opensource.org/licenses/mit-license)で配布します。

&copy; 2013 [ktty1220](mailto:ktty1220@gmail.com)
