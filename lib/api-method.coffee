###*
* デフォルトhttpメソッド
*
* - クラスではないがドキュメントで識別しやすくする為に便宜上クラス扱いとする
*
* @class apiMethods
###
apiMethods =
  ###*
  * SQLを直接指定
  *
  * @public
  * @method /query
  * @param param {Object} リクエストに付加されたパラメータ
  * @param param.sql {String} SQL文字列
  * @param callback {Function} (エラーオブジェクト, 実行結果)
  * @example http://localhost:4983/query?sql=select%20name%20from%20user
  ###
  '/query': (param, callback) ->
    method = (if /^\s*select\s/i.test param.sql then @get else @post)
    method param.sql, callback

  ###*
  * SELECT文を実行
  *
  * @public
  * @method /select
  * @param param {Object} リクエストに付加されたパラメータ
  * @param param.talbe {string} テーブル名(必須)
  * @param param.fields {String} 項目(デフォルト: *)
  * @param param.conditions {String} 抽出条件(WHERE句以降)
  * @param param.sort {String} 並び順(ORDER BY句以降)
  * @param param.limit {Number} 抽出件数上限(LIMIT句以降)
  * @param param.skip {Number} 取得開始レコード位置(SKIP句以降)
  * @param callback {Function} (エラーオブジェクト, 実行結果)
  * @example http://localhost:4983/select?table=user&fields=rowid,name,age&limit=10&sort=age
  ###
  '/select': (param, callback) ->
    return callback 1004 unless param.table
    sql = "SELECT #{param.fields ? '*'} FROM #{param.table}"
    sql += " WHERE #{param.conditions}" if param.conditions
    sql += " ORDER BY #{param.sort}" if param.sort
    sql += " LIMIT #{param.limit}" if param.limit
    @get sql, callback

  ###*
  * UPDATE文を実行
  *
  * @public
  * @method /update
  * @param param {Object} リクエストに付加されたパラメータ
  * @param param.talbe {String} テーブル名(必須)
  * @param param.set {String} 更新内容(必須)
  * @param param.conditions {String} 抽出条件(WHERE句以降)
  * @param callback {Function} (エラーオブジェクト, 実行結果)
  * @example http://localhost:4983/update?table=user&set=name=%27taro%27,age=20&conditions=flag%20is%20null
  ###
  '/update': (param, callback) ->
    return callback 1004 if not param.table or not param.set
    sql = "UPDATE #{param.table} SET #{param.set}"
    sql += " WHERE #{param.conditions}" if param.conditions
    @post sql, callback

  ###*
  * INSERT文を実行
  *
  * @public
  * @method /insert
  * @param param {Object} リクエストに付加されたパラメータ
  * @param param.talbe {String} テーブル名(必須)
  * @param param.fields {String} 項目指定(デフォルト: なし(全項目))
  * @param param.values {String} 挿入項目 or SELECT文
  * @param callback {Function} (エラーオブジェクト, 実行結果)
  * @example http://localhost:4983/insert?table=user&fields=name,age&values=%27hanako%27,30
  ###
  '/insert': (param, callback) ->
    return callback 1004 if not param.table or not param.values
    sql = "INSERT INTO #{param.table} "
    sql += "(#{param.fields}) " if param.fields
    valueIsSQL = /^select\s/i.test param.values
    sql += "VALUES ("  unless valueIsSQL
    sql += param.values
    sql += ")"  unless valueIsSQL
    @post sql, callback

  ###*
  * DELETE文を実行
  *
  * @public
  * @method /delete
  * @param param {Object} リクエストに付加されたパラメータ
  * @param param.talbe {String} テーブル名(必須)
  * @param param.conditions {String} 抽出条件(WHERE句以降)
  * @param callback {Function} (エラーオブジェクト, 実行結果)
  * @example http://localhost:4983/delete?table=user&conditions=age<10
  ###
  '/delete': (param, callback) ->
    return callback 1004 unless param.table
    sql = "DELETE FROM #{param.table}"
    sql += " WHERE #{param.conditions}" if param.conditions
    @post sql, callback

  ###*
  * CREATE TABLE文を実行
  *
  * @public
  * @method /create
  * @param param {Object} リクエストに付加されたパラメータ
  * @param param.talbe {String} テーブル名(必須)
  * @param param.fields {String} 作成する項目
  * @param callback {Function} (エラーオブジェクト, 実行結果)
  * @example http://localhost:4983/create?table=user&fields=id%20integer%20primary%20key,name%20varchar(100)
  ###
  '/create': (param, callback) ->
    return callback 1004 if not param.table or not param.fields
    sql = "CREATE TABLE #{param.table} (#{param.fields})"
    @post sql, callback

  ###*
  * DROP TABLE文を実行
  *
  * @public
  * @method /drop
  * @param param {Object} リクエストに付加されたパラメータ
  * @param param.talbe {String} テーブル名(必須)
  * @param callback {Function} (エラーオブジェクト, 実行結果)
  * @example http://localhost:4983/drop?table=user
  ###
  '/drop': (param, callback) ->
    return callback 1004 unless param.table
    sql = "DROP TABLE #{param.table}"
    @post sql, callback

  ###*
  * スキーマ情報のオブジェクトを取得
  *
  * @public
  * @method /schema
  * @param param {Object} リクエストに付加されたパラメータ
  * @param callback {Function} (エラーオブジェクト, 実行結果)
  ###
  '/schema': (param, callback) -> @schema callback

  ###*
  * データベースの再読み込み
  *
  * @public
  * @method /reload
  * @param param {Object} リクエストに付加されたパラメータ
  * @param callback {Function} (エラーオブジェクト, 実行結果)
  ###
  '/reload': (param, callback) ->
    dbname = @dbname()
    @close (err) =>
      return callback err if err?
      @open dbname, @onopen, (err) =>
        return callback err if err?
        callback undefined, 'OK'

module.exports = apiMethods
