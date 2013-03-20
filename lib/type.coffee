#jshint bitwise:false
###*
* 変数の型をビットマスクの形で取得
*
* @class Type
* @see http://javascripter.hatenablog.com/entry/20081002/1222962329
###
class Type
  @OBJECT: 0x01
  @ARRAY: 0x02
  @STRING: 0x04
  @FUNCTION: 0x08
  @NUMBER: 0x10
  @BOOLEAN: 0x20
  @UNDEFINED: 0x40
  @NULL: 0x80

  ###*
  * 型判定
  *
  * @method get
  * @param data {mixed} 判定する変数
  * @return {Number} ビットマスクで表現された型
  ###
  @get: (data) ->
    ret = 0x00
    ret |= 0x01 if data instanceof Object
    ret |= 0x02 if data instanceof Array
    ret |= 0x04 if data instanceof String or typeof data is 'string'
    ret |= 0x08 if data instanceof Function
    ret |= 0x10 if data instanceof Number or typeof data is 'number'
    ret |= 0x20 if data instanceof Boolean or typeof data is 'boolean'
    ret |= 0x40 if data is undefined
    ret |= 0x80 if data is null
    ret

  ###*
  * 文字列判定
  *
  * @method string
  * @param data {mixed} 判定する変数
  * @return {Boolean} 文字列 | 数値ならtrue
  ###
  @string: (data) -> (@get data) & @STRING

  ###*
  * 数値判定
  *
  * @method number
  * @param data {mixed} 判定する変数
  * @return {Boolean} 数値ならtrue
  ###
  @number: (data) -> (@get data) & @NUMBER

  ###*
  * 配列判定
  *
  * @method array
  * @param data {mixed} 判定する変数
  * @return {Boolean} 配列ならtrue
  ###
  @array: (data) -> (@get data) & @ARRAY

  ###*
  * 文字列or数値判定
  *
  * @method strnum
  * @param data {mixed} 判定する変数
  * @return {Boolean} 文字列 | 数値ならtrue
  ###
  @strnum: (data) -> (@get data) & (@STRING | @NUMBER)

module.exports = Type
