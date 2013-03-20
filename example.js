#!/usr/bin/env node
/*jshint node:true*/

'use strict';

var util = require('util');
var http = require('http');
var querystring = require('querystring');
var async = require('async');
var sqlited = require('./lib/sqlite3-webapi-kit');


// カスタムHTTPメソッドを追加
sqlited.addMethod('/hoge', function (param, callback) {
  // 性別と年齢(n歳以上)を指定して抽出するhogeというメソッド
  sqlited.get('SELECT * FROM user where sex = ? AND age > ?', [ param.sex, param.age ], callback);
});

// httpリクエスト時のフック関数を登録
sqlited.setHook(function (remoteAddress, request) {
  // クライアントのIPアドレスを表示する
  console.log('@ access from', remoteAddress);
  return true;
});

// DBを開いた時に実行されるSQL
var initSql = [
  'CREATE TABLE user (id INTEGER PRIMARY KEY, name VARCHAR(100), sex VARCHAR(6), age INTEGER)',
  'CREATE INDEX idx_user_sex_age ON user (sex, age)'
];

// メモリDBを開く
sqlited.open(':memory:', initSql, function (err) {

  // DBのスキーマ情報を表示
  sqlited.schema(function (err, schema) {
    console.log('\n##### schema =>');
    console.log(util.inspect(schema, false, null));

    // 初期データ
    var users = [
      { $name: 'taro', $sex: 'male', $age: 30 },
      { $name: 'jiro', $sex: 'male', $age: 25 },
      { $name: 'saburo', $sex: 'male', $age: 20 },
      { $name: 'hanako', $sex: 'female', $age: 15 }
    ];

    // 初期データをインポート
    console.log('\n##### import data');
    async.eachSeries(users, function (item, next) {
      sqlited.post('INSERT INTO user (name, sex, age) VALUES ($name, $sex, $age)', item, next);
    }, function (err) {

      // HTTP待ちうけ開始
      sqlited.listen(4983, function () {
        console.log('\n##### server listening start');

        // HTTPリクエスト情報
        var requests = [{
          info: '現在のuserテーブルを確認',
          method: 'query',
          param: { sql: 'select * from user' }
        }, {
          info: 'userテーブルにjack(50歳)を挿入',
          method: 'insert',
          param: { table: 'user', fields: 'name, age', values: "'jack', 50" }
        }, {
          info: 'jackの性別を入れ忘れたので性別に男性をセット',
          method: 'update',
          param: { table: 'user', set: "sex = 'male'", conditions: "name = 'jack'" }
        }, {
          info: 'userテーブルから男性を年齢が高い順に3人表示',
          method: 'select',
          param: { table: 'user', conditions: "sex = 'male'", sort: 'age desc', limit: 3 }
        }, {
          info: '追加したカスタムHTTPメソッド"/hoge"を実行',
          method: 'hoge',
          param: { sex: 'male', age: 30 }
        }, {
          info: 'jackさようなら',
          method: 'delete',
          param: { table: 'user', conditions: "name = 'jack'" }
        }, {
          info: 'idsテーブルを作成',
          method: 'create',
          param: { table: 'ids', fields: 'id INTEGER' }
        }, {
          info: 'idsテーブルにuserテーブル内の男性のidを挿入',
          method: 'insert',
          param: { table: 'ids', values: "SELECT id FROM user WHERE sex = 'male'" }
        }, {
          info: 'idsテーブルを確認(男性のidが入っている)',
          method: 'select',
          param: { table: 'ids' }
        }, {
          info: 'userテーブルからidsテーブルのidに該当するデータ(要するに男性)を削除',
          method: 'delete',
          param: { table: 'user', conditions: "id IN (SELECT id FROM ids)" }
        }, {
          info: 'userテーブルを確認(hanakoだけになっている)',
          method: 'select',
          param: { table: 'user' }
        }, {
          info: 'userテーブルを削除',
          method: 'drop',
          param: { table: 'user' }
        }, {
          info: 'スキーマを確認(userテーブルが削除されているのを確認)',
          method: 'schema'
        }, {
          info: 'userテーブルを確認(もうないのでエラー)',
          method: 'select',
          param: { table: 'user' }
        }];

        // HTTPリクエストを順番に実行
        async.eachSeries(requests, function (item, next) {
          console.log('\n$ ' + item.info);
          var url = util.format('http://localhost:4983/%s?%s', item.method, querystring.stringify(item.param));
          http.get(url, function (res) {
            console.log('% request %s => [%d]', url, res.statusCode);
            var body = '';
            res.on('data', function (chunk) {
              body += chunk;
            });
            res.on('end', function (chunk) {
              console.log(util.inspect(JSON.parse(body.toString('utf8')), false, null));
              next();
            });
          }).on('error', function (e) {
            next(e);
          });
        }, function (err) {
          if (err) {
            console.log('! error: ' + err.message);
          }
          // サーバーを終了
          sqlited.shutdown(function (err) {
            console.log(err || 'done');
          });
        });
      });
    });
  });
});
