vows = require 'vows'
assert = require 'assert'
fs = require 'fs'
async = require 'async'
request = require 'request'
try
  coverage = require 'coverage'
catch e
  coverage = { require: require }
try
  sqlited = coverage.require "#{__dirname}/../lib/sqlite3-webapi-kit"
catch e
  sqlited = coverage.require "../lib/sqlite3-webapi-kit"

dbname = 'test.db3'

GET = (path, param, callback) =>
  if param instanceof Function
    callback = param
    param = undefined

  request { uri: "http://localhost:4983#{path}", qs: param }, (err, res, body) =>
    ret = JSON.parse body
    callback err,
      statusCode: res.statusCode,
      result: ret.result
      error: ret.error
  return

HEAD = (path, param, callback) =>
  if param instanceof Function
    callback = param
    param = undefined

  request { method: 'HEAD', uri: "http://localhost:4983#{path}", qs: param }, (err, res, body) =>
    callback undefined, err
  return

vows.describe('http server test')
.addBatch
  'カスタムhttpメソッド追加':
    topic: ->
      sqlited.addMethod '/hoge', (param, callback) =>
        return callback 'error: < 0' if param.age < 0
        return callback new Error 'error: > 100' if param.age > 100
        # 性別と年齢(n歳以上)を指定して抽出するhogeというメソッド
        sqlited.get 'SELECT * FROM user where sex = ? AND age > ? ORDER by id', [ param.sex, param.age ], callback
      sqlited.methods()
    'メソッドが追加されている': (topic) =>
      assert.include topic, '/hoge'

.addBatch
  'カスタムhttpメソッド追加(関数以外を登録)':
    topic: -> sqlited.addMethod '/fuga', 999
    '登録失敗': (topic) =>
      assert.isFalse topic

.addBatch
  'httpリクエスト時のフック関数を登録(関数以外を登録)':
    topic: -> sqlited.setHook 'function'
    '登録失敗': (topic) =>
      assert.isFalse topic

.addBatch
  'httpリクエスト時のフック関数を登録(アクセス禁止)':
    topic: -> sqlited.setHook (remoteAddress, request) => false
    '正常に登録されている': (topic) =>
      assert.isTrue topic

.addBatch
  'DBを開いてサーバーを公開':
    topic: ->
      initSql = [
        'CREATE TABLE user (id INTEGER PRIMARY KEY, name VARCHAR(100), sex VARCHAR(6), age INTEGER)'
        'CREATE INDEX idx_user_sex_age ON user (sex, age)'
      ]
      sqlited.close () =>
        sqlited.open ':memory:', initSql, (err) =>
          users = [
            { $name: 'taro', $sex: 'male', $age: 30 }
            { $name: 'jiro', $sex: 'male', $age: 25 }
            { $name: 'saburo', $sex: 'male', $age: 20 }
            { $name: 'hanako', $sex: 'female', $age: 15 }
          ]
          async.eachSeries users, (item, next) ->
            sqlited.post 'INSERT INTO user (name, sex, age) VALUES ($name, $sex, $age)', item, (err) -> next err
          , (err) => sqlited.listen () => GET '/', @callback
      return
    'localhost:4983にアクセスできる(403)': (topic) =>
      assert.equal topic.statusCode, 403
    '1002エラーが発生する': (topic) =>
      assert.equal topic.error.errno, 1002

.addBatch
  'httpリクエスト時のフック関数を登録(アクセス許可)':
    topic: -> sqlited.setHook (remoteAddress, request) => true
    '正常に登録されている': (topic) =>
      assert.isTrue topic

.addBatch
  'httpリクエスト時のフック関数の登録を解除':
    topic: -> sqlited.setHook undefined
    '登録解除に成功': (topic) =>
      assert.isTrue topic

.addBatch
  '存在しないhttpメソッドにアクセス':
    topic: -> GET '/', @callback
    'httpレスポンスステータスコード: 404': (topic) =>
      assert.equal topic.statusCode, 404
    '1001エラーが発生する': (topic) =>
      assert.equal topic.error.errno, 1001

.addBatch
  'デフォルトhttpメソッド: /query':
    topic: -> GET '/query', { sql: 'select * from user' }, @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    '現在のuserテーブルの内容を取得': (topic) =>
      assert.deepEqual topic.result, [
        { id: 1, name: 'taro', sex: 'male', age: 30 }
        { id: 2, name: 'jiro', sex: 'male', age: 25 }
        { id: 3, name: 'saburo', sex: 'male', age: 20 }
        { id: 4, name: 'hanako', sex: 'female', age: 15 }
      ]

.addBatch
  'デフォルトhttpメソッド: /query (エラー)':
    topic: -> GET '/query', { sql: 123 }, @callback
    'httpレスポンスステータスコード: 500': (topic) =>
      assert.equal topic.statusCode, 500
    'エラー情報に実行したSQLが入っている': (topic) =>
      assert.equal topic.error.sql, 123
    '1エラーが発生する': (topic) =>
      assert.equal topic.error.errno, 1

.addBatch
  'デフォルトhttpメソッド: /insert':
    topic: -> GET '/insert', { table: 'user', fields: 'name,age', values: "'jack',50" }, @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    '実行SQLの検証': (topic) =>
      assert.equal topic.result.sql, "INSERT INTO user (name,age) VALUES ('jack',50)"
    '挿入された行は1行': (topic) =>
      assert.equal topic.result.changes, 1
    '挿入された行のIDは5': (topic) =>
      assert.equal topic.result.lastID, 5

.addBatch
  'デフォルトhttpメソッド: /insert (エラー)':
    topic: -> GET '/insert', { table: 'user', fields: 'name,age' }, @callback
    'httpレスポンスステータスコード: 500': (topic) =>
      assert.equal topic.statusCode, 500
    '1004エラーが発生する': (topic) =>
      assert.equal topic.error.errno, 1004

.addBatch
  'デフォルトhttpメソッド: /update':
    topic: -> GET '/update', { table: 'user', set: "sex = 'male'", conditions: "name = 'jack'" }, @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    '実行SQLの検証': (topic) =>
      assert.equal topic.result.sql, "UPDATE user SET sex = 'male' WHERE name = 'jack'"
    '更新された行は1行': (topic) =>
      assert.equal topic.result.changes, 1

.addBatch
  'デフォルトhttpメソッド: /update (エラー)':
    topic: -> GET '/update', { table: 'user', conditions: "name = 'jack'" }, @callback
    'httpレスポンスステータスコード: 500': (topic) =>
      assert.equal topic.statusCode, 500
    '1004エラーが発生する': (topic) =>
      assert.equal topic.error.errno, 1004

.addBatch
  'デフォルトhttpメソッド: /select':
    topic: -> GET '/select', { table: 'user', conditions: "sex = 'male'", sort: 'age desc', limit: 3 }, @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    'insertやupdateが反映されたuserテーブルの内容を取得': (topic) =>
      assert.deepEqual topic.result, [
        { id: 5, name: 'jack', sex: 'male', age: 50 }
        { id: 1, name: 'taro', sex: 'male', age: 30 }
        { id: 2, name: 'jiro', sex: 'male', age: 25 }
      ]

.addBatch
  'デフォルトhttpメソッド: /select (エラー)':
    topic: -> GET '/select', { conditions: "sex = 'male'", sort: 'age desc', limit: 3 }, @callback
    'httpレスポンスステータスコード: 500': (topic) =>
      assert.equal topic.statusCode, 500
    '1004エラーが発生する': (topic) =>
      assert.equal topic.error.errno, 1004

.addBatch
  'カスタムhttpメソッドにアクセス':
    topic: -> GET '/hoge', { sex: 'male', age: 20 }, @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    '結果の配列を取得': (topic) =>
      assert.deepEqual topic.result, [
        { id: 1, name: 'taro', sex: 'male', age: 30 }
        { id: 2, name: 'jiro', sex: 'male', age: 25 }
        { id: 5, name: 'jack', sex: 'male', age: 50 }
      ]

.addBatch
  'カスタムhttpメソッドにアクセス (0件)':
    topic: -> GET '/hoge', { sex: 'female', age: 20 }, @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    '結果の空配列を取得': (topic) =>
      assert.isEmpty topic.result

.addBatch
  'カスタムhttpメソッドにアクセス (エラー文字列)':
    topic: -> GET '/hoge', { sex: 'male', age: -1 }, @callback
    'httpレスポンスステータスコード: 500': (topic) =>
      assert.equal topic.statusCode, 500
    '1000エラーが発生する': (topic) =>
      assert.equal topic.error.errno, 1000
    'エラーメッセージ: "error: < 0"': (topic) =>
      assert.equal topic.error.message, 'error: < 0'

.addBatch
  'カスタムhttpメソッドにアクセス (エラーオブジェクト)':
    topic: -> GET '/hoge', { sex: 'male', age: 101 }, @callback
    'httpレスポンスステータスコード: 500': (topic) =>
      assert.equal topic.statusCode, 500
    '1000エラーが発生する': (topic) =>
      assert.equal topic.error.errno, 1000
    'エラーメッセージ: "error: > 100"': (topic) =>
      assert.equal topic.error.message, 'error: > 100'

.addBatch
  'デフォルトhttpメソッド: /delete':
    topic: -> GET '/delete', { table: 'user', conditions: "name = 'jack'" }, @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    '実行SQLの検証': (topic) =>
      assert.equal topic.result.sql, "DELETE FROM user WHERE name = 'jack'"
    '削除された行は1行': (topic) =>
      assert.equal topic.result.changes, 1

.addBatch
  'デフォルトhttpメソッド: /delete (同じ条件で再度)':
    topic: -> GET '/delete', { table: 'user', conditions: "name = 'jack'" }, @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    '削除された行はない': (topic) =>
      assert.equal topic.result.changes, 0

.addBatch
  'デフォルトhttpメソッド: /delete (エラー)':
    topic: -> GET '/delete', { conditions: "name = 'jack'" }, @callback
    'httpレスポンスステータスコード: 500': (topic) =>
      assert.equal topic.statusCode, 500
    '1004エラーが発生する': (topic) =>
      assert.equal topic.error.errno, 1004

.addBatch
  'デフォルトhttpメソッド: /create (エラー)':
    topic: -> GET '/create', { table: 'ids' }, @callback
    'httpレスポンスステータスコード: 500': (topic) =>
      assert.equal topic.statusCode, 500
    '1004エラーが発生する': (topic) =>
      assert.equal topic.error.errno, 1004

.addBatch
  'デフォルトhttpメソッド: /create':
    topic: -> GET '/create', { table: 'ids', fields: "id INTEGER" }, @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    '実行SQLの検証': (topic) =>
      assert.equal topic.result.sql, "CREATE TABLE ids (id INTEGER)"

.addBatch
  'デフォルトhttpメソッド: /insert (valuesにSELECT文)':
    topic: -> GET '/insert', { table: 'ids', values: "SELECT id FROM user WHERE sex = 'male'" }, @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    '実行SQLの検証': (topic) =>
      assert.equal topic.result.sql, "INSERT INTO ids SELECT id FROM user WHERE sex = 'male'"
    '挿入された行は3行': (topic) =>
      assert.equal topic.result.changes, 3
    '最後に挿入された行のIDは3': (topic) =>
      assert.equal topic.result.lastID, 3

.addBatch
  'デフォルトhttpメソッド: /delete (conditionsにin句)':
    topic: -> GET '/delete', { table: 'user', conditions: "id IN (SELECT id FROM ids)" }, @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    '削除された行は3行': (topic) =>
      assert.equal topic.result.changes, 3

.addBatch
  'デフォルトhttpメソッド: /select (count(*))':
    topic: -> GET '/select', { table: 'user', fields: 'count(*) as count' }, @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    'userテーブルの内容は1件': (topic) =>
      assert.deepEqual topic.result, [ count: 1 ]

.addBatch
  'デフォルトhttpメソッド: /drop':
    topic: -> GET '/drop', { table: 'user' }, @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    '実行SQLの検証': (topic) =>
      assert.equal topic.result.sql, 'DROP TABLE user'

.addBatch
  'デフォルトhttpメソッド: /drop (削除したテーブルを再度削除)':
    topic: -> GET '/drop', { table: 'user' }, @callback
    'httpレスポンスステータスコード: 500': (topic) =>
      assert.equal topic.statusCode, 500
    '1エラーが発生する': (topic) =>
      assert.equal topic.error.errno, 1

.addBatch
  'デフォルトhttpメソッド: /drop (エラー)':
    topic: -> GET '/drop', @callback
    'httpレスポンスステータスコード: 500': (topic) =>
      assert.equal topic.statusCode, 500
    '1004エラーが発生する': (topic) =>
      assert.equal topic.error.errno, 1004

.addBatch
  'デフォルトhttpメソッド: /schema':
    topic: -> GET '/schema', @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    'スキーマの検証': (topic) =>
      assert.deepEqual topic.result.main,
        path: ''
        views: {}
        tables:
          ids:
            indexes: {}
            fields: [
              name: 'id'
              type: 'INTEGER'
            ]
            sql: 'CREATE TABLE ids (id INTEGER)'

.addBatch
  'デフォルトhttpメソッド: /reload':
    topic: ->
      sqlited.close () =>
        sqlited.open dbname, (err) =>
          return @callback err if err?
          GET '/reload', @callback
      return
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200

.addBatch
  'デフォルトhttpメソッド: /select (開き直したDBへのアクセス確認)':
    topic: -> GET '/select', { table: 'test1' }, @callback
    'httpレスポンスステータスコード: 200': (topic) =>
      assert.equal topic.statusCode, 200
    'test1テーブルにデータの件数は3件': (topic) =>
      assert.equal topic.result.length, 3
    'test1テーブルの内容の検証': (topic) =>
      for r, i in topic.result
        assert.equal r.c1, i + 1
        assert.equal r.c2, "てすと0#{i + 1}"

.addBatch
  'カスタムhttpメソッドを削除':
    topic: ->
      sqlited.removeMethod '/hoge'
      sqlited.methods()
    'メソッドが削除されている': (topic) =>
      assert.equal topic.indexOf('/hoge'), -1
    '他のメソッドは残っている': (topic) =>
      assert.isNotZero topic.length

.addBatch
  '削除したカスタムhttpメソッドにアクセス(エラー)':
    topic: -> GET '/hoge', { sex: 'male', age: 20 }, @callback
    'httpレスポンスステータスコード: 404': (topic) =>
      assert.equal topic.statusCode, 404
    '1001エラーが発生する': (topic) =>
      assert.equal topic.error.errno, 1001

.addBatch
  '削除したカスタムhttpメソッドを再度削除':
    topic: -> sqlited.removeMethod '/hoge'
    '削除失敗': (topic) =>
      assert.isFalse topic

.addBatch
  'httpサーバー終了':
    topic: ->
      sqlited.shutdown () =>
        HEAD '/select', { table: 'test1' }, @callback
      return
    '接続できない': (topic) =>
      assert.equal topic.errno, 'ECONNREFUSED'

.addBatch
  'httpサーバー再公開':
    topic: ->
      sqlited.listen () =>
        GET '/select', { table: 'test1' }, @callback
      return
    '接続できる': (topic) =>
      assert.equal topic.statusCode, 200
    'test1テーブルにデータの件数は3件': (topic) =>
      assert.equal topic.result.length, 3
    'test1テーブルの内容の検証': (topic) =>
      for r, i in topic.result
        assert.equal r.c1, i + 1
        assert.equal r.c2, "てすと0#{i + 1}"

.addBatch
  'カスタムhttpメソッドをクリア':
    topic: ->
      sqlited.clearMethod()
      sqlited.methods()
    'メソッドが空になっている': (topic) =>
      assert.isEmpty topic

.afterSuite () ->
  sqlited.shutdown () => this.done()

.export module
