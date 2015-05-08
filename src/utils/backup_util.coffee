_ = require 'underscore'
debuglog = require("debug")("redis-backups::backup_util")
fs = require "fs"
path = require "path"
os = require "os"
child_process = require "child_process"
assert = require "assert"
dateFormat = require('dateformat')
mkdirp = require "mkdirp"
uploadUtil = require './upload_util'

REDIS_RDB_PATH = null
REDIS_RDB_NAME = null
BACKUP_RDB_PATH = null


init = (config) ->
  REDIS_RDB_PATH = config.redisRdbPath
  REDIS_RDB_NAME = config.redisRdbName
  assert REDIS_RDB_PATH, "missing REDIS_RDB_PATH"
  assert(fs.existsSync("#{REDIS_RDB_PATH}/#{REDIS_RDB_NAME}"), "bad file path to redis rdb")
  #BACKUP_RDB_PATH = path.join os.tmpdir(), "#{config.backupDirName||'development'}"
  BACKUP_RDB_PATH = config.backupPath
  mkdirp.sync BACKUP_RDB_PATH

start = (callback) ->
  date = dateFormat(new Date(), "yyyymmddHHMMss")
  #envObj = cwd : BACKUP_RDB_PATH
  sourceFile = "#{BACKUP_RDB_PATH}/redisBuck_#{date}.tar.gz"
  cmd = "cd #{REDIS_RDB_PATH} && tar -czf #{sourceFile} #{REDIS_RDB_NAME}"
  debuglog "cmd: #{cmd}"
  envObj = cwd: REDIS_RDB_PATH
  child_process.exec cmd, (err, stdout, stderr)  ->
    return callback err if err?
    uploadUtil.upload sourceFile, callback
    return
  return

module.exports =
  init: init
  start:start

