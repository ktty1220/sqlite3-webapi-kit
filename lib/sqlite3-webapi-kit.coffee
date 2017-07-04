#jshint forin:false
http = require 'http'
async = require 'async'
url = require 'url'
os = require 'os'
sqlite3 = require('sqlite3').verbose()
Type = require './type'

###*
* モジュール本体
*
* - クラスではなく単一のオブジェクトとしてロードすることを想定したモジュール
* - モジュールロード時に自動的にオブジェクトが作成される
*
* @class Sqlite3WebApiKit
* @see http://blog.asial.co.jp/1101
###
Sqlite3WebApiKit = (->
  _apiMethods = require './api-method'
  _db = null
  _onopen = null
  _requestHook = -> true
  _server = null

  ###*
  * 開いているDB名(ファイルパス)を取得
  *
  * @public
  * @method dbname
  * @return {String} DB名
  ###
  _dbname = -> _db.filename

  ###*
  * DBを開く
  *
  * @public
  * @method open
  * @param dbname {String} DBファイルのパス(未指定はメモリデータベースの指定と同じ)
  * @param init {mixed} DBを開いた時に実行するSQL(文字列 or 配列)
  * @param callback {Function} 引数無し
  ###
  _open = (dbname, init, callback) ->
    if init instanceof Function
      callback = init
      init = undefined
    if dbname instanceof Function
      callback = dbname
      dbname = undefined
      init = undefined
    dbname ?= ':memory:'

    return callback _error(1007) if _db?
    _db = new sqlite3.Database dbname
    if init
      _onopen = init
      _postMulti _onopen, callback
    else
      callback()

  ###*
  * DBを閉じる
  *
  * @public
  * @method close
  * @param callback {Function} 引数無し
  ###
  _close = (callback) ->
    return callback?() unless _db?
    _db.close (err) ->
      return callback? err if err?
      _db = null
      _onopen = null
      callback?()

  # webapiで発生したエラー番号とエラーメッセージの組み合わせ
  _errMessage =
    1001: 'unknown method'
    1002: 'forbidden'
    1003: 'invalid SQL type'
    1004: 'required param is not defined'
    1005: 'this SQL should be run on get()'
    1006: 'this SQL should be run on post()'
    1007: 'db is already opened'
    1008: 'db is not open'

  ###*
  * エラーオブジェクト作成
  *
  * - JSON化して送信するのでnew Error()で作成したエラーオブジェクトだと都合が悪い
  *
  * @private
  * @method _error
  * @param err sqlite3モジュールで発生したエラーオブジェクト、もしくはwebapiで発生したエラー番号
  * @param info {Object} エラーオブジェクトに付加する追加情報
  * @return {Object} エラーオブジェクト
  ###
  _error = (err, info = {}) ->
    return undefined unless err?

    # errにエラー番号がセットされた場合はwebapiエラー
    if Type.number err
      errObj =
        message: _errMessage[err]
        errno: err
        code: 'WEBAPI_ERROR'
    else if Type.string err
      errObj =
        message: err
        errno: 1000
        code: 'WEBAPI_ERROR'
    else
      errObj =
        message: err.message.replace /^SQLITE_ERROR:\s+/, ''
        errno: err.errno ? 1000
        code: err.code ? 'WEBAPI_ERROR'

    # 追加情報セット
    errObj[k] = v for k, v of info
    errObj

  ###*
  * 読み取り系SQL実行
  *
  * @public
  * @method get
  * @param sql {String} SQL文字列
  * @param bind {mixed} バインドパラメータ(省略可)
  * @param callback {Function} (エラーオブジェクト, 取得データオブジェクト)
  ###
  _get = (sql, bind, callback) ->
    if bind instanceof Function
      callback = bind
      bind = undefined
    bind = [ bind ] if Type.strnum bind

    return callback _error(1008) unless _db?
    return callback _error(1003) unless Type.string sql
    return callback _error(1006) if not /^\s*(select|pragma)/i.test sql

    _db.all sql, bind, (err, rows) ->
      return callback _error(err, { sql: sql, bind: bind }) if err?
      callback undefined, rows

  ###*
  * 書き込み系SQL実行
  *
  * @public
  * @method post
  * @param sql {String} SQL文字列
  * @param bind {mixed} バインドパラメータ(省略可)
  * @param callback {Function} (エラーオブジェクト, 実行結果({sql, lastID, changes}))
  ###
  _post = (sql, bind, callback) ->
    if bind instanceof Function
      callback = bind
      bind = undefined

    return callback _error(1008) unless _db?
    return callback _error(1003) unless Type.string sql
    return callback _error(1005) if /^\s*(select|pragma)/i.test sql

    _db.run sql, bind, (err) ->
      return callback _error(err, { sql: sql, bind: bind }) if err?
      callback undefined, @
    return

  ###*
  * 書き込み系SQL実行(配列内のSQLを順番に実行)
  *
  * - パラメータのバインドは未実装
  *
  * @public
  * @method postMulti
  * @param sql {mixed} SQL文字列、又はそれらの配列
  * @param trans {Boolean} SQL配列をトランザクションの中で実行する
  * @param callback {Function} (エラーオブジェクト)
  ###
  _postMulti = (sql, trans, callback) ->
    if trans instanceof Function
      callback = trans
      trans = false

    unless Type.array sql
      # sqlが配列でも文字列でもなければ型エラー
      return callback _error(1003, sql: sql) unless Type.string sql

      # 配列の形に統一
      sql = [ sql ]

    # トランザクション指定の場合は配列の最初と最後にbeginとcommitを入れる
    if trans
      sql.unshift 'begin'
      sql.push 'commit'

    # SQLを順番に実行
    results = []
    async.eachSeries sql, (item, next) ->
      return next _error(1008) unless _db?
      return next _error(1005) if /^\s*select/i.test item

      _db.run item, (err, info) ->
        return next _error(err, sql: item, results) if err?
        results.push info
        next()
    , (err) ->
      if err? and trans
        _post 'rollback', () -> callback err, results
      else
        callback err, results

  ###*
  * CREATE TABLE文から項目リスト作成
  *
  * @private
  * @method _fieldsFromSql
  * @param sql {String} CREATE TABLE文
  ###
  _fieldsFromSql = (sql) ->
    fields = []

    # SQL文から項目情報作成
    fld = sql
    # 'CREATE TABLE xxx (' 以降を取得して
    .substr(sql.indexOf('(') + 1)
    # 全項目に'collate nocase'が付いているので外して
    .replace(/\s+collate\s+nocase/ig, '')
    # 最後の閉じ括弧を外して
    .replace(/\)$/, '')
    # 1項目定義毎に分割する
    .split ','

    m = 0

    # 分割した項目をスキーマに当てはめていく
    while m < fld.length
      ms = fld[m].trim()
        .replace(/primary\s+key/gi, 'primary_key true')
        .replace(/\s*\(\s*/gi, '(')
        .replace(/\s*\)/gi, ')')
        .split ' '
      f = name: ms[0]
      mt = ms[1].match /^(.+)*\((\d+)\)/
      if mt
        f.type = mt[1]
        f.length = Number mt[2]
      else
        f.type = ms[1]
      mo = 2

      while mo < ms.length
        mv = ms[mo + 1]
        mv = Number mv if /^\d+$/.test mv
        mv = Boolean mv if /^(true|false)$/.test mv
        mv = null if mv is 'null'
        f[ms[mo]] = mv
        mo += 2
      fields.push f
      m++

    fields

  ###*
  * CREATE INDEX文から項目リスト作成
  *
  * @private
  * @method _indexesFromSql
  * @param sql {String} CREATE INDEX文
  ###
  _indexesFromSql = (sql) ->
    # 'CREATE INDEX xxx ON yyy (' 以降を取得して
    sql.substr(sql.indexOf('(') + 1)
    # 全項目に'collate nocase'が付いているので外して
    .replace(/\s+collate nocase/ig, '')
    # 最後の閉じ括弧を外して
    .replace(/\)$/, '')
    # 空白を消して
    .replace(/\s/, '')
    # 1項目定義毎に分割する
    .split ','

  ###*
  * スキーマ情報取得
  *
  * @public
  * @method schema
  * @param callback {Function} (エラーオブジェクト, スキーマ情報)
  ###
  _schema = (callback) ->
    _get 'pragma database_list', (err, dbList) ->
      return callback err if err?
      schema = {}

      async.eachSeries dbList, (dItem, dNext) ->
        dbname = dItem.name
        schema[dbname] =
          path: dItem.file
          tables: {}
          views: {}

        mSql = "select * from #{dbname}.sqlite_master where type = ?"
        _get mSql, 'table', (err, tableList) ->
          return dNext err if err?

          async.eachSeries tableList, (tItem, tNext) ->
            tblname = tItem.name
            schema[dbname].tables[tblname] =
              sql: tItem.sql
              fields: _fieldsFromSql tItem.sql
              indexes: {}
            
            # インデックス情報取得
            iSql = "select * from #{dbname}.sqlite_master where type = ? and tbl_name = ?"
            _get iSql, [ 'index', tblname ], (err, indexList) ->
              return tNext err if err?
              schema[dbname].tables[tblname].indexes[il.name] = _indexesFromSql il.sql for il in indexList
              tNext()

          , (err) ->
            return dNext err if err?
            _get mSql, 'view', (err, viewList) ->
              return dNext err if err?
              schema[dbname].views[v.name] = v.sql for v, i in viewList
              dNext()
      , (err) ->
        return callback err if err?
        callback undefined, schema

  ###*
  * httpメソッドの追加
  *
  * @public
  * @method addMethod
  * @param path {String} リクエストパス('/xxxx')
  * @param func {Function} (param, callback)を受け、callbackで処理結果(エラーオブジェクト、実行結果)を返す関数
  * @return {Boolean} 成功/失敗
  ###
  _addMethod = (path, func) ->
    return false unless func instanceof Function
    _apiMethods[path] = func
    true

  ###*
  * httpメソッドの削除
  *
  * @public
  * @method removeMethod
  * @param path {String} リクエストパス('/xxxx')
  * @return {Boolean} 成功/失敗
  ###
  _removeMethod = (path) ->
    return false unless path of _apiMethods
    delete _apiMethods[path]
    true

  ###*
  * httpメソッドの全消去
  *
  * @public
  * @method clearMethod
  ###
  _clearMethod = ->
    _apiMethods = {}
    return

  ###*
  * httpメソッド一覧取得
  *
  * @public
  * @method methods
  * @return {Array} 登録メソッド一覧
  ###
  _methods = -> (path for path of _apiMethods)

  ###*
  * httpリクエスト時のフック関数登録
  *
  * falseを返すとそのリクエストに対し403エラーを返す
  * 登録する関数は(remoteAddress, request)を受け、true or falseを返す関数
  *
  * @public
  * @method setHook
  * @param func {Function} フック関数(undefinedの場合は解除)
  * @return {Boolean} 成功/失敗
  ###
  _setHook = (func) ->
    if func instanceof Function
      _requestHook = func
      return true
    else if func is undefined
      _requestHook = -> true
      return true
    false

  ###*
  * httpインターフェースを公開
  *
  * @public
  * @method listen
  * @param port {Number} 待ち受けポート(デフォルト: 4983)
  * @param callback {Function} (エラーオブジェクト)
  ###
  _listen = (port, callback) ->
    if port instanceof Function
      callback = port
      port = undefined
    port ?= 4983

    resHeader =
      'Content-Type': 'application/json; charset=utf-8'
      'Connection': 'close'

    _server = http.createServer (req, res) =>
      unless _requestHook req.headers['x-forwarded-for'] or req.client.remoteAddress, req
        res.writeHead 403, resHeader
        return res.end JSON.stringify error: _error(1002)

      urlInfo = url.parse req.url, true
      urlInfo.pathname = urlInfo.pathname.toLowerCase()

      unless _apiMethods[urlInfo.pathname]
        res.writeHead 404, resHeader
        return res.end JSON.stringify error: _error(1001)

      _apiMethods[urlInfo.pathname].call @, urlInfo.query, (err, result) ->
        res.writeHead (if err? then 500 else 200), resHeader
        body = undefined
        unless /head/i.test req.method
          body = JSON.stringify
            error: _error err, urlInfo.query
            result: result

          # Unicodeエスケープ
          # @see http://stackoverflow.com/questions/4901133/json-and-escaping-characters
          body = body.replace /[\u007f-\uffff]/g, (c) ->
            '\\u' + ('0000' + c.charCodeAt(0).toString(16)).slice(-4)
        res.end body
        #req.connection.end()
        #req.connection.destroy()

    _server.listen port
    callback?()

  ###*
  * httpサーバー終了
  *
  * @public
  * @method shutdown
  * @param callback {Function} (エラーオブジェクト)
  ###
  _shutdown = (callback) ->
    _server?.close()
    _server = null
    callback?()

  # 公開メソッドをエクスポート
  dbname: _dbname
  open: _open
  close: _close
  get: _get
  post: _post
  postMulti: _postMulti
  schema: _schema
  addMethod: _addMethod
  removeMethod: _removeMethod
  clearMethod: _clearMethod
  methods: _methods
  setHook: _setHook
  listen: _listen
  shutdown: _shutdown

)()

module.exports = Sqlite3WebApiKit
