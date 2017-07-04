// Generated by CoffeeScript 1.12.6
var GET, HEAD, assert, async, coverage, dbname, e, fs, request, sqlited, vows;

vows = require('vows');

assert = require('assert');

fs = require('fs');

async = require('async');

request = require('request');

try {
  coverage = require('coverage');
} catch (error) {
  e = error;
  coverage = {
    require: require
  };
}

try {
  sqlited = coverage.require(__dirname + "/../lib/sqlite3-webapi-kit");
} catch (error) {
  e = error;
  sqlited = coverage.require("../lib/sqlite3-webapi-kit");
}

dbname = 'test.db3';

GET = (function(_this) {
  return function(path, param, callback) {
    if (param instanceof Function) {
      callback = param;
      param = void 0;
    }
    request({
      uri: "http://localhost:4983" + path,
      qs: param
    }, function(err, res, body) {
      var ret;
      ret = JSON.parse(body);
      return callback(err, {
        statusCode: res.statusCode,
        result: ret.result,
        error: ret.error
      });
    });
  };
})(this);

HEAD = (function(_this) {
  return function(path, param, callback) {
    if (param instanceof Function) {
      callback = param;
      param = void 0;
    }
    request({
      method: 'HEAD',
      uri: "http://localhost:4983" + path,
      qs: param
    }, function(err, res, body) {
      return callback(void 0, err);
    });
  };
})(this);

vows.describe('http server test').addBatch({
  'カスタムhttpメソッド追加': {
    topic: function() {
      sqlited.addMethod('/hoge', (function(_this) {
        return function(param, callback) {
          if (param.age < 0) {
            return callback('error: < 0');
          }
          if (param.age > 100) {
            return callback(new Error('error: > 100'));
          }
          return sqlited.get('SELECT * FROM user where sex = ? AND age > ? ORDER by id', [param.sex, param.age], callback);
        };
      })(this));
      return sqlited.methods();
    },
    'メソッドが追加されている': (function(_this) {
      return function(topic) {
        return assert.include(topic, '/hoge');
      };
    })(this)
  }
}).addBatch({
  'カスタムhttpメソッド追加(関数以外を登録)': {
    topic: function() {
      return sqlited.addMethod('/fuga', 999);
    },
    '登録失敗': (function(_this) {
      return function(topic) {
        return assert.isFalse(topic);
      };
    })(this)
  }
}).addBatch({
  'httpリクエスト時のフック関数を登録(関数以外を登録)': {
    topic: function() {
      return sqlited.setHook('function');
    },
    '登録失敗': (function(_this) {
      return function(topic) {
        return assert.isFalse(topic);
      };
    })(this)
  }
}).addBatch({
  'httpリクエスト時のフック関数を登録(アクセス禁止)': {
    topic: function() {
      return sqlited.setHook((function(_this) {
        return function(remoteAddress, request) {
          return false;
        };
      })(this));
    },
    '正常に登録されている': (function(_this) {
      return function(topic) {
        return assert.isTrue(topic);
      };
    })(this)
  }
}).addBatch({
  'DBを開いてサーバーを公開': {
    topic: function() {
      var initSql;
      initSql = ['CREATE TABLE user (id INTEGER PRIMARY KEY, name VARCHAR(100), sex VARCHAR(6), age INTEGER)', 'CREATE INDEX idx_user_sex_age ON user (sex, age)'];
      sqlited.close((function(_this) {
        return function() {
          return sqlited.open(':memory:', initSql, function(err) {
            var users;
            users = [
              {
                $name: 'taro',
                $sex: 'male',
                $age: 30
              }, {
                $name: 'jiro',
                $sex: 'male',
                $age: 25
              }, {
                $name: 'saburo',
                $sex: 'male',
                $age: 20
              }, {
                $name: 'hanako',
                $sex: 'female',
                $age: 15
              }
            ];
            return async.eachSeries(users, function(item, next) {
              return sqlited.post('INSERT INTO user (name, sex, age) VALUES ($name, $sex, $age)', item, function(err) {
                return next(err);
              });
            }, function(err) {
              return sqlited.listen(function() {
                return GET('/', _this.callback);
              });
            });
          });
        };
      })(this));
    },
    'localhost:4983にアクセスできる(403)': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 403);
      };
    })(this),
    '1002エラーが発生する': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.errno, 1002);
      };
    })(this)
  }
}).addBatch({
  'httpリクエスト時のフック関数を登録(アクセス許可)': {
    topic: function() {
      return sqlited.setHook((function(_this) {
        return function(remoteAddress, request) {
          return true;
        };
      })(this));
    },
    '正常に登録されている': (function(_this) {
      return function(topic) {
        return assert.isTrue(topic);
      };
    })(this)
  }
}).addBatch({
  'httpリクエスト時のフック関数の登録を解除': {
    topic: function() {
      return sqlited.setHook(void 0);
    },
    '登録解除に成功': (function(_this) {
      return function(topic) {
        return assert.isTrue(topic);
      };
    })(this)
  }
}).addBatch({
  '存在しないhttpメソッドにアクセス': {
    topic: function() {
      return GET('/', this.callback);
    },
    'httpレスポンスステータスコード: 404': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 404);
      };
    })(this),
    '1001エラーが発生する': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.errno, 1001);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /query': {
    topic: function() {
      return GET('/query', {
        sql: 'select * from user'
      }, this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    '現在のuserテーブルの内容を取得': (function(_this) {
      return function(topic) {
        return assert.deepEqual(topic.result, [
          {
            id: 1,
            name: 'taro',
            sex: 'male',
            age: 30
          }, {
            id: 2,
            name: 'jiro',
            sex: 'male',
            age: 25
          }, {
            id: 3,
            name: 'saburo',
            sex: 'male',
            age: 20
          }, {
            id: 4,
            name: 'hanako',
            sex: 'female',
            age: 15
          }
        ]);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /query (エラー)': {
    topic: function() {
      return GET('/query', {
        sql: 123
      }, this.callback);
    },
    'httpレスポンスステータスコード: 500': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 500);
      };
    })(this),
    'エラー情報に実行したSQLが入っている': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.sql, 123);
      };
    })(this),
    '1エラーが発生する': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.errno, 1);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /insert': {
    topic: function() {
      return GET('/insert', {
        table: 'user',
        fields: 'name,age',
        values: "'jack',50"
      }, this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    '実行SQLの検証': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.sql, "INSERT INTO user (name,age) VALUES ('jack',50)");
      };
    })(this),
    '挿入された行は1行': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.changes, 1);
      };
    })(this),
    '挿入された行のIDは5': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.lastID, 5);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /insert (エラー)': {
    topic: function() {
      return GET('/insert', {
        table: 'user',
        fields: 'name,age'
      }, this.callback);
    },
    'httpレスポンスステータスコード: 500': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 500);
      };
    })(this),
    '1004エラーが発生する': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.errno, 1004);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /update': {
    topic: function() {
      return GET('/update', {
        table: 'user',
        set: "sex = 'male'",
        conditions: "name = 'jack'"
      }, this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    '実行SQLの検証': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.sql, "UPDATE user SET sex = 'male' WHERE name = 'jack'");
      };
    })(this),
    '更新された行は1行': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.changes, 1);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /update (エラー)': {
    topic: function() {
      return GET('/update', {
        table: 'user',
        conditions: "name = 'jack'"
      }, this.callback);
    },
    'httpレスポンスステータスコード: 500': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 500);
      };
    })(this),
    '1004エラーが発生する': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.errno, 1004);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /select': {
    topic: function() {
      return GET('/select', {
        table: 'user',
        conditions: "sex = 'male'",
        sort: 'age desc',
        limit: 3
      }, this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    'insertやupdateが反映されたuserテーブルの内容を取得': (function(_this) {
      return function(topic) {
        return assert.deepEqual(topic.result, [
          {
            id: 5,
            name: 'jack',
            sex: 'male',
            age: 50
          }, {
            id: 1,
            name: 'taro',
            sex: 'male',
            age: 30
          }, {
            id: 2,
            name: 'jiro',
            sex: 'male',
            age: 25
          }
        ]);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /select (エラー)': {
    topic: function() {
      return GET('/select', {
        conditions: "sex = 'male'",
        sort: 'age desc',
        limit: 3
      }, this.callback);
    },
    'httpレスポンスステータスコード: 500': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 500);
      };
    })(this),
    '1004エラーが発生する': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.errno, 1004);
      };
    })(this)
  }
}).addBatch({
  'カスタムhttpメソッドにアクセス': {
    topic: function() {
      return GET('/hoge', {
        sex: 'male',
        age: 20
      }, this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    '結果の配列を取得': (function(_this) {
      return function(topic) {
        return assert.deepEqual(topic.result, [
          {
            id: 1,
            name: 'taro',
            sex: 'male',
            age: 30
          }, {
            id: 2,
            name: 'jiro',
            sex: 'male',
            age: 25
          }, {
            id: 5,
            name: 'jack',
            sex: 'male',
            age: 50
          }
        ]);
      };
    })(this)
  }
}).addBatch({
  'カスタムhttpメソッドにアクセス (0件)': {
    topic: function() {
      return GET('/hoge', {
        sex: 'female',
        age: 20
      }, this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    '結果の空配列を取得': (function(_this) {
      return function(topic) {
        return assert.isEmpty(topic.result);
      };
    })(this)
  }
}).addBatch({
  'カスタムhttpメソッドにアクセス (エラー文字列)': {
    topic: function() {
      return GET('/hoge', {
        sex: 'male',
        age: -1
      }, this.callback);
    },
    'httpレスポンスステータスコード: 500': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 500);
      };
    })(this),
    '1000エラーが発生する': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.errno, 1000);
      };
    })(this),
    'エラーメッセージ: "error: < 0"': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.message, 'error: < 0');
      };
    })(this)
  }
}).addBatch({
  'カスタムhttpメソッドにアクセス (エラーオブジェクト)': {
    topic: function() {
      return GET('/hoge', {
        sex: 'male',
        age: 101
      }, this.callback);
    },
    'httpレスポンスステータスコード: 500': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 500);
      };
    })(this),
    '1000エラーが発生する': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.errno, 1000);
      };
    })(this),
    'エラーメッセージ: "error: > 100"': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.message, 'error: > 100');
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /delete': {
    topic: function() {
      return GET('/delete', {
        table: 'user',
        conditions: "name = 'jack'"
      }, this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    '実行SQLの検証': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.sql, "DELETE FROM user WHERE name = 'jack'");
      };
    })(this),
    '削除された行は1行': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.changes, 1);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /delete (同じ条件で再度)': {
    topic: function() {
      return GET('/delete', {
        table: 'user',
        conditions: "name = 'jack'"
      }, this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    '削除された行はない': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.changes, 0);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /delete (エラー)': {
    topic: function() {
      return GET('/delete', {
        conditions: "name = 'jack'"
      }, this.callback);
    },
    'httpレスポンスステータスコード: 500': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 500);
      };
    })(this),
    '1004エラーが発生する': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.errno, 1004);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /create (エラー)': {
    topic: function() {
      return GET('/create', {
        table: 'ids'
      }, this.callback);
    },
    'httpレスポンスステータスコード: 500': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 500);
      };
    })(this),
    '1004エラーが発生する': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.errno, 1004);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /create': {
    topic: function() {
      return GET('/create', {
        table: 'ids',
        fields: "id INTEGER"
      }, this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    '実行SQLの検証': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.sql, "CREATE TABLE ids (id INTEGER)");
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /insert (valuesにSELECT文)': {
    topic: function() {
      return GET('/insert', {
        table: 'ids',
        values: "SELECT id FROM user WHERE sex = 'male'"
      }, this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    '実行SQLの検証': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.sql, "INSERT INTO ids SELECT id FROM user WHERE sex = 'male'");
      };
    })(this),
    '挿入された行は3行': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.changes, 3);
      };
    })(this),
    '最後に挿入された行のIDは3': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.lastID, 3);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /delete (conditionsにin句)': {
    topic: function() {
      return GET('/delete', {
        table: 'user',
        conditions: "id IN (SELECT id FROM ids)"
      }, this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    '削除された行は3行': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.changes, 3);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /select (count(*))': {
    topic: function() {
      return GET('/select', {
        table: 'user',
        fields: 'count(*) as count'
      }, this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    'userテーブルの内容は1件': (function(_this) {
      return function(topic) {
        return assert.deepEqual(topic.result, [
          {
            count: 1
          }
        ]);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /drop': {
    topic: function() {
      return GET('/drop', {
        table: 'user'
      }, this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    '実行SQLの検証': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.sql, 'DROP TABLE user');
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /drop (削除したテーブルを再度削除)': {
    topic: function() {
      return GET('/drop', {
        table: 'user'
      }, this.callback);
    },
    'httpレスポンスステータスコード: 500': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 500);
      };
    })(this),
    '1エラーが発生する': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.errno, 1);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /drop (エラー)': {
    topic: function() {
      return GET('/drop', this.callback);
    },
    'httpレスポンスステータスコード: 500': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 500);
      };
    })(this),
    '1004エラーが発生する': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.errno, 1004);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /schema': {
    topic: function() {
      return GET('/schema', this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    'スキーマの検証': (function(_this) {
      return function(topic) {
        return assert.deepEqual(topic.result.main, {
          path: '',
          views: {},
          tables: {
            ids: {
              indexes: {},
              fields: [
                {
                  name: 'id',
                  type: 'INTEGER'
                }
              ],
              sql: 'CREATE TABLE ids (id INTEGER)'
            }
          }
        });
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /reload': {
    topic: function() {
      sqlited.close((function(_this) {
        return function() {
          return sqlited.open(dbname, function(err) {
            if (err != null) {
              return _this.callback(err);
            }
            return GET('/reload', _this.callback);
          });
        };
      })(this));
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this)
  }
}).addBatch({
  'デフォルトhttpメソッド: /select (開き直したDBへのアクセス確認)': {
    topic: function() {
      return GET('/select', {
        table: 'test1'
      }, this.callback);
    },
    'httpレスポンスステータスコード: 200': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    'test1テーブルにデータの件数は3件': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.length, 3);
      };
    })(this),
    'test1テーブルの内容の検証': (function(_this) {
      return function(topic) {
        var i, j, len, r, ref, results;
        ref = topic.result;
        results = [];
        for (i = j = 0, len = ref.length; j < len; i = ++j) {
          r = ref[i];
          assert.equal(r.c1, i + 1);
          results.push(assert.equal(r.c2, "てすと0" + (i + 1)));
        }
        return results;
      };
    })(this)
  }
}).addBatch({
  'カスタムhttpメソッドを削除': {
    topic: function() {
      sqlited.removeMethod('/hoge');
      return sqlited.methods();
    },
    'メソッドが削除されている': (function(_this) {
      return function(topic) {
        return assert.equal(topic.indexOf('/hoge'), -1);
      };
    })(this),
    '他のメソッドは残っている': (function(_this) {
      return function(topic) {
        return assert.isNotZero(topic.length);
      };
    })(this)
  }
}).addBatch({
  '削除したカスタムhttpメソッドにアクセス(エラー)': {
    topic: function() {
      return GET('/hoge', {
        sex: 'male',
        age: 20
      }, this.callback);
    },
    'httpレスポンスステータスコード: 404': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 404);
      };
    })(this),
    '1001エラーが発生する': (function(_this) {
      return function(topic) {
        return assert.equal(topic.error.errno, 1001);
      };
    })(this)
  }
}).addBatch({
  '削除したカスタムhttpメソッドを再度削除': {
    topic: function() {
      return sqlited.removeMethod('/hoge');
    },
    '削除失敗': (function(_this) {
      return function(topic) {
        return assert.isFalse(topic);
      };
    })(this)
  }
}).addBatch({
  'httpサーバー終了': {
    topic: function() {
      sqlited.shutdown((function(_this) {
        return function() {
          return HEAD('/select', {
            table: 'test1'
          }, _this.callback);
        };
      })(this));
    },
    '接続できない': (function(_this) {
      return function(topic) {
        return assert.equal(topic.errno, 'ECONNREFUSED');
      };
    })(this)
  }
}).addBatch({
  'httpサーバー再公開': {
    topic: function() {
      sqlited.listen((function(_this) {
        return function() {
          return GET('/select', {
            table: 'test1'
          }, _this.callback);
        };
      })(this));
    },
    '接続できる': (function(_this) {
      return function(topic) {
        return assert.equal(topic.statusCode, 200);
      };
    })(this),
    'test1テーブルにデータの件数は3件': (function(_this) {
      return function(topic) {
        return assert.equal(topic.result.length, 3);
      };
    })(this),
    'test1テーブルの内容の検証': (function(_this) {
      return function(topic) {
        var i, j, len, r, ref, results;
        ref = topic.result;
        results = [];
        for (i = j = 0, len = ref.length; j < len; i = ++j) {
          r = ref[i];
          assert.equal(r.c1, i + 1);
          results.push(assert.equal(r.c2, "てすと0" + (i + 1)));
        }
        return results;
      };
    })(this)
  }
}).addBatch({
  'カスタムhttpメソッドをクリア': {
    topic: function() {
      sqlited.clearMethod();
      return sqlited.methods();
    },
    'メソッドが空になっている': (function(_this) {
      return function(topic) {
        return assert.isEmpty(topic);
      };
    })(this)
  }
}).afterSuite(function() {
  return sqlited.shutdown((function(_this) {
    return function() {
      return _this.done();
    };
  })(this));
})["export"](module);
