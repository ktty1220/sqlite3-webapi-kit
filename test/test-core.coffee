vows = require 'vows'
assert = require 'assert'
fs = require 'fs'
try
  coverage = require 'coverage'
catch e
  coverage = { require: require }
try
  sqlited = coverage.require "#{__dirname}/../lib/sqlite3-webapi-kit"
catch e
  sqlited = coverage.require "../lib/sqlite3-webapi-kit"

dbname = 'test.db3'

vows.describe('core test')
.addBatch
  'DB指定なし: メモリ上のDBを開く':
    topic: ->
      sqlited.open (err) => @callback err, sqlited.dbname()
      return
    'DBオブジェクトのfilenameが「:memory:」になっている': (topic) =>
      assert.equal topic, ':memory:'

.addBatch
  '2重オープン':
    topic: ->
      sqlited.open (err) => @callback null, err.errno
      return
    '1007エラーが発生する': (topic) =>
      assert.equal topic, 1007

.addBatch
  'DBクローズ':
    topic: ->
      sqlited.close (err) => @callback err, sqlited._db
      return
    '_dbがnullになっている': (topic) =>
      assert.equal topic, null

.addBatch
  '2重クローズ(何もしない)':
    topic: ->
      sqlited.close (err) => @callback err, sqlited._db
      return
    '_dbがnullになっている': (topic) =>
      assert.equal topic, null

.addBatch
  'DBを開いていない状態でスキーマ取得':
    topic: ->
      sqlited.schema (err, result) => @callback null, err.errno
      return
    '1008エラーが発生する': (topic) =>
      assert.equal topic, 1008

.addBatch
  'DB指定(:memory:) & オープン時実行SQLなし: メモリ上のDBを開く':
    topic: ->
      sqlited.close => sqlited.open ':memory:', (err) => @callback err, sqlited.dbname()
      return
    'DBオブジェクトのfilenameが「:memory:」になっている': (topic) =>
      assert.equal topic, ':memory:'

.addBatch
  'DB指定(:memory:) & オープン時実行SQL指定(文字列): メモリ上のDBを開いてSQLを実行':
    topic: ->
      sqlited.close =>
        initSql = 'create table test (c integer)'
        sqlited.open ':memory:', initSql, (err) =>
          return @callback err if err?
          chkSql = "select * from sqlite_master where type = 'table'"
          sqlited.get chkSql, (err, result) =>
            @callback err,
              sql: initSql
              dbname: sqlited.dbname()
              result: result
      return
    'DBオブジェクトのfilenameが「:memory:」になっている': (topic) =>
      assert.equal topic.dbname, ':memory:'
    'testテーブルが作成されている': (topic) =>
      assert.equal topic.result.length, 1
    '登録されたtestテーブルのSQLと作成時SQLが同一': (topic) =>
      assert.equal topic.result[0].sql.toUpperCase(), topic.sql.toUpperCase()

.addBatch
  'DB指定(:memory:) & オープン時実行SQL指定(配列): メモリ上のDBを開いてSQLを実行':
    topic: ->
      sqlited.close =>
        initSql = [
          'create table test (c varchar(100))'
          "insert into test (c) values ('テスト')"
        ]
        sqlited.open ':memory:', initSql, (err) =>
          return @callback err if err?
          chkSql = 'select * from test'
          sqlited.get chkSql, (err, result) =>
            @callback err,
              dbname: sqlited.dbname()
              result: result
      return
    'DBオブジェクトのfilenameが「:memory:」になっている': (topic) =>
      assert.equal topic.dbname, ':memory:'
    'testテーブルにデータが1件作成されている': (topic) =>
      assert.equal topic.result.length, 1
    'testテーブルの内容の検証': (topic) =>
      assert.equal topic.result[0].c, 'テスト'

.addBatch
  'DBを開いていない状態でget':
    topic: ->
      sqlited.close => sqlited.get 'select * from test', (err, result) => @callback null, err.errno
      return
    '1008エラーが発生する': (topic) =>
      assert.equal topic, 1008

.addBatch
  'DBを開いていない状態でpost':
    topic: ->
      sqlited.post 'delete from test', (err, result) => @callback null, err.errno
      return
    '1008エラーが発生する': (topic) =>
      assert.equal topic, 1008

.addBatch
  'DBを開いていない状態でpostMulti':
    topic: ->
      sql = [
        'update test set c = null'
        "update test set c = 'test'"
      ]
      sqlited.postMulti sql, (err, result) => @callback null, err.errno
      return
    '1008エラーが発生する': (topic) =>
      assert.equal topic, 1008

.addBatch
  'DB指定(ファイル名) & オープン時実行SQL指定(配列): ディスク上にDBを作成してSQLを実行':
    topic: ->
      fs.unlinkSync dbname if fs.existsSync dbname
      initSql = [
        'create table test1 (c1 integer, c2 varchar(100))'
        'create index idx_test1_c1 on test1(c1)'
        "insert into test1 (c1, c2) values (1, 'てすと01')"
        "insert into test1 (c1, c2) values (2, 'てすと02')"
        "insert into test1 (c1, c2) values (3, 'てすと03')"
      ]
      sqlited.open dbname, initSql, (err) =>
        return @callback err if err?
        sqlited.close =>
          return @callback err if err?
          sqlited.open dbname, (err) =>
            return @callback err if err?
            chkSql = 'select * from test1'
            sqlited.get chkSql, (err, result) =>
              @callback err,
                dbname: sqlited.dbname()
                result: result
      return
    'DBオブジェクトのfilenameがファイル名になっている': (topic) =>
      assert.equal topic.dbname, dbname
    'test1テーブルにデータが3件作成されている': (topic) =>
      assert.equal topic.result.length, 3
    'test1テーブルの内容の検証': (topic) =>
      for r, i in topic.result
        assert.equal r.c1, i + 1
        assert.equal r.c2, "てすと0#{i + 1}"

.addBatch
  'getメソッド(バインドなし & 0件)':
    topic: ->
      sql = 'select * from test1 where c2 is null'
      sqlited.get sql, (err, result) => @callback err, result.length
      return
    '取得結果が0件': (topic) =>
      assert.equal topic, 0

.addBatch
  'getメソッド(文字列bind)':
    topic: ->
      sql = 'select * from test1 where c2 like ?'
      bind = '%02'
      sqlited.get sql, bind, (err, result) => @callback err, result
      return
    'test1テーブルの内容の検証': (topic) =>
      assert.equal topic.length, 1
      assert.equal topic[0].c1, 2

.addBatch
  'getメソッド(数値bind)':
    topic: ->
      sql = 'select * from test1 where c1 < ?'
      bind = '3'
      sqlited.get sql, bind, (err, result) => @callback err, result
      return
    'test1テーブルの内容の検証': (topic) =>
      assert.equal topic.length, 2
      assert.equal topic[0].c1, 1

.addBatch
  'getメソッド(配列bind)':
    topic: ->
      sql = 'select c1 from test1 where c1 = ? or c2 like ? order by c1 desc'
      bind = [ 1, '%03' ]
      sqlited.get sql, bind, (err, result) => @callback err, result
      return
    'test1テーブルの内容の検証': (topic) =>
      assert.deepEqual topic, [ { c1: 3 }, { c1: 1 } ]

.addBatch
  'getメソッド(連想配列bind)':
    topic: ->
      sql = 'select c2 from test1 where c1 = $c1 or c2 like $c2'
      bind =
        $c1: 2
        $c2: '%01'
      sqlited.get sql, bind, (err, result) => @callback err, result
      return
    'test1テーブルの内容の検証': (topic) =>
      assert.deepEqual topic, [ { c2: 'てすと01' }, { c2: 'てすと02' } ]

.addBatch
  'getメソッド(存在しないテーブル)':
    topic: ->
      sql = 'select * from tttest1'
      sqlited.get sql, (err, result) => @callback null, err.message
      return
    'エラーメッセージの検証': (topic) =>
      assert.match topic, /no such table/

.addBatch
  'getメソッドで配列を指定':
    topic: ->
      sql = [
        'select * from test1'
        'select * from test2'
      ]
      sqlited.get sql, (err, result) => @callback null, err.errno
      return
    '1003エラーが発生する': (topic) =>
      assert.equal topic, 1003

.addBatch
  'getメソッドでselect文以外を実行':
    topic: ->
      sqlited.get "insert into test1 (c2) values ('てすと99')", (err, result) => @callback null, err.errno
      return
    '1006エラーが発生する': (topic) =>
      assert.equal topic, 1006

.addBatch
  'postMultiメソッド':
    topic: ->
      sql = [
        'create table test2 (f1 integer primary key, f2 integer default 0, f3 text, f4 varchar ( 16 ) default null)'
        'create view view_test2_f1_f4 as select f1, f4 from test2'
        'create index idx_test2_f2_f3 on test2(f2, f3)'
        'create index idx_test2_f2_f4 on test2(f2, f4)'
      ]
      sqlited.postMulti sql, (err, result) =>
        return @callback err if err?
        chkSql = "select * from sqlite_master where type = 'table' and name = 'test2'"
        sqlited.get chkSql, (err, result) =>
          @callback err,
            sql: sql[0]
            result: result
      return
    'test2テーブルが作成されている': (topic) =>
      assert.equal topic.result.length, 1
    '登録されたtestテーブルのSQLと作成時SQLが同一': (topic) =>
      assert.equal topic.result[0].sql.toUpperCase(), topic.sql.toUpperCase()

.addBatch
  'postメソッド':
    topic: ->
      sql = 'insert into test2 (f3) values (?)'
      bind = 'testtesttest'
      sqlited.post sql, bind, (err, updateInfo) =>
        return @callback err if err?
        sqlited.get 'select * from test2', (err, result) =>
          @callback err, updateInfo: updateInfo, result: result
      return
    '更新処理結果の検証': (topic) =>
      assert.equal topic.updateInfo.lastID, 1
      assert.equal topic.updateInfo.changes, 1
    '更新後のtest2テーブルの検証': (topic) =>
      expected =
        f1: 1
        f2: 0
        f3: 'testtesttest'
        f4: null
      assert.deepEqual topic.result[0], expected

.addBatch
  'スキーマ取得':
    topic: ->
      sqlited.schema (err, result) => @callback err, result
      return
    'スキーマの検証': (topic) =>
      expected1 =
        fields: [
          { name: 'c1', type: 'integer' }
          { name: 'c2', type: 'varchar', length: 100 }
        ]
        indexes: idx_test1_c1: [ 'c1' ]
        sql: 'CREATE TABLE test1 (c1 integer, c2 varchar(100))'
      assert.deepEqual topic.main.tables.test1, expected1

      expected2 =
        fields: [
          { name: 'f1', type: 'integer', primary_key: true }
          { name: 'f2', type: 'integer', default: 0 }
          { name: 'f3', type: 'text' }
          { name: 'f4', type: 'varchar', length: 16, default: null }
        ]
        indexes:
          idx_test2_f2_f3: [ 'f2', 'f3' ]
          idx_test2_f2_f4: [ 'f2', 'f4' ]
        sql: 'CREATE TABLE test2 (f1 integer primary key, f2 integer default 0, f3 text, f4 varchar ( 16 ) default null)'
      assert.deepEqual topic.main.tables.test2, expected2

      expected3 =
        view_test2_f1_f4: 'CREATE VIEW view_test2_f1_f4 as select f1, f4 from test2'
      assert.deepEqual topic.main.views, expected3

.addBatch
  '不正なSQLでpostメソッド':
    topic: ->
      sqlited.post 'update test1 set c999 = ?', 'xxx', (err, result) => @callback null, err.message
      return
    'エラーメッセージの検証': (topic) =>
      assert.match topic, /no such column/

.addBatch
  'postメソッドでSELECT文を実行':
    topic: ->
      sqlited.post 'select * from test1', (err, result) => @callback null, err.errno
      return
    '1005エラーが発生する': (topic) =>
      assert.equal topic, 1005

.addBatch
  'postメソッドで配列を指定':
    topic: ->
      sql = [
        'delete from test1'
        'delete from test2'
      ]
      sqlited.post sql, (err, result) => @callback null, err.errno
      return
    '1003エラーが発生する': (topic) =>
      assert.equal topic, 1003

.addBatch
  '不正なSQLでpostMultiメソッド(実行前)':
    topic: ->
      sqlited.postMulti 999, (err, result) => @callback null, err.errno
      return
    '1003エラーが発生する': (topic) =>
      assert.equal topic, 1003

.addBatch
  '不正なSQLでpostMultiメソッド(実行時)':
    topic: ->
      sqlited.postMulti 'drop table test0', (err, result) => @callback null, err.message
      return
    'エラーメッセージの検証': (topic) =>
      assert.match topic, /no such table/

.addBatch
  'postMultiメソッドでSQL配列の途中でSELECT文を実行(トランザクション指定)':
    topic: ->
      sql = [
        'delete from test1'
        'select count(*) as c from test1'
      ]
      sqlited.postMulti sql, true, (err, result) =>
        return @callback true unless err?
        errno = err.errno
        sqlited.get 'select count(*) as cnt from test1', (err, result) =>
          @callback err,
            errno: errno
            result: result
      return
    '1005エラーが発生する': (topic) =>
      assert.equal topic.errno, 1005
    'ロールバックされている': (topic) =>
      assert.deepEqual topic.result, [{ cnt: 3 }]

.export module
