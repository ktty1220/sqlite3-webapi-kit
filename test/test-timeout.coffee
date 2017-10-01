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
randtime = [90,30,70,10,20,100,80,60,40,50]

vows.describe('core test')
.addBatch
  'メモリ上のDBをオープン (200ミリ秒後にクローズ)':
    topic: ->
      sqlited.open (err) =>
        setTimeout () ->
          sqlited.close()
          return
        , 200
        @callback err, sqlited.dbname()
      return
    'DBオブジェクトのfilenameが「:memory:」になっている': (topic) =>
      assert.equal topic, ':memory:'

.addBatch
  '2重オープン (待機指定なし)':
    topic: ->
      start = Date.now()
      sqlited.open dbname, (err) =>
        @callback null, { err: err, elapsed: Date.now() - start }
      return
    '1007エラーが発生する': (topic) =>
      assert.equal topic.err.errno, 1007
    '即座にコールバックされている': (topic) =>
      assert.isTrue topic.elapsed <= 10

.addBatch
  '2重オープン (0ミリ秒待機)':
    topic: ->
      start = Date.now()
      sqlited.open dbname, null, 0, (err) =>
        @callback null, { err: err, elapsed: Date.now() - start }
      return
    '1007エラーが発生する': (topic) =>
      assert.equal topic.err.errno, 1007
    '即座にコールバックされている': (topic) =>
      assert.isTrue topic.elapsed <= 10

.addBatch
  '2重オープン (100ミリ秒待機)':
    topic: ->
      start = Date.now()
      sqlited.open dbname, null, 100, (err) =>
        @callback null, { err: err, elapsed: Date.now() - start }
      return
    '1007エラーが発生する': (topic) =>
      assert.equal topic.err.errno, 1007
    '100ミリ秒後にコールバックされている': (topic) =>
      assert.isTrue 100 <= topic.elapsed and topic.elapsed <= 110

.addBatch
  '2重オープン (+100ミリ秒待機)':
    topic: ->
      sqlited.open dbname, null, 100, (err) => @callback null, err
      return
    'エラーが発生しない': (topic) =>
      assert.isUndefined topic

.addBatch
  'クローズ直後にオープン':
    topic: ->
      sqlited.close () =>
        sqlited.open dbname, (err) => @callback null, err
        return
      return
    'エラーが発生しない': (topic) =>
      assert.isUndefined topic

.addBatch
  '複数オープン (すべてタイムアウトする場合)':
    topic: ->
      # (DBはオープンされたままの状態)
      timeouted = []  # タイムアウトの順番
      quelen1 = []    # 待ち行列の遷移 (オープン呼び出し後)
      quelen2 = []    # 待ち行列の遷移 (オープンコールバック後)
      # 指定の待機時間でオープンする関数
      open = (timeout) =>
        sqlited.open dbname, null, timeout, (err) =>
          timeouted.push(timeout) if err.errno is 1007
          quelen2.push(sqlited.variables._openQueue.length)
          if timeout is Math.max.apply(null, randtime)
            @callback null, { timeouted: timeouted, quelen1: quelen1, quelen2: quelen2 }
        quelen1.push(sqlited.variables._openQueue.length)
        return
      # 10回オープン
      open timeout for timeout in randtime
      return
    '待機時間が短い順に1007エラーが発生する': (topic) =>
      sorted = randtime.sort((a, b) => a - b)
      for i in [0..sorted.length]
        assert.equal topic.timeouted[i], sorted[i]
    '待ち行列に追加されていく': (topic) =>
      for i in [0..9]
        assert.equal topic.quelen1[i], i + 1
    '待ち行列から除去されていく': (topic) =>
      for i in [0..9]
        assert.equal topic.quelen2[i], 9 - i

.addBatch
  'クローズ':
    topic: ->
      sqlited.close (err) =>
        @callback err, { db: sqlited.variables._db, que: sqlited.variables._openQueue }
      return
    '_dbがnullになっている': (topic) =>
      assert.isNull topic.db
    '待ち行列が空になっている': (topic) =>
      assert.lengthOf topic.que, 0

.addBatch
  '複数オープン (すべてタイムアウトしない場合)':
    topic: ->
      opened = []     # オープン成功の順番
      quelen1 = []    # 待ち行列の遷移 (オープン呼び出し後)
      quelen2 = []    # 待ち行列の遷移 (オープンコールバック後)
      # 待機時間1000ミリ秒でオープンする関数
      open = (index) =>
        sqlited.open dbname, null, 1000, (err) =>
          unless err?
            opened.push(index)
            # オープンしたら10ミリ秒後にクローズ
            setTimeout =>
              sqlited.close()
              quelen2.push(sqlited.variables._openQueue.length)
              if index is 9
                @callback null, { opened: opened, quelen1: quelen1, quelen2: quelen2 }
            , 10
            return
        quelen1.push(sqlited.variables._openQueue.length)
        return
      # 10回オープン
      open i for i in [0..9]
      return
    '呼び出された順にオープンに成功する': (topic) =>
      for i in [0..9]
        assert.equal topic.opened[i], i
    '待ち行列に追加されていく': (topic) =>
      for i in [0..9]
        assert.equal topic.quelen1[i], i
    '待ち行列から除去されていく': (topic) =>
      for i in [0..9]
        assert.equal topic.quelen2[i], 9 - i

.export module
