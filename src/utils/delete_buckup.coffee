
_ = require 'underscore'
debuglog = require("debug")("redis-backups::backup_util")
fs = require "fs"
path = require "path"
child_process = require "child_process"
assert = require "assert"
dateFormat = require('dateformat')
mkdirp = require "mkdirp"
uploadUtil = require './upload_util'

BACKUP_RDB_PATH = null
OVER_TIME_SECOND = 2592000 #30天

init = (config) ->
  BACKUP_RDB_PATH = config.backupPath
  mkdirp.sync BACKUP_RDB_PATH
  OVER_TIME_SECOND = config.overTimeSecond || 2592000


deleteBackup = (callback) ->
  times = Date.now() - (OVER_TIME_SECOND * 1000)
  date = new Date(times)
  cmd = "rm -r #{BACKUP_RDB_PATH}/redisBuck_#{dateFormat(date, "yyyymmddHH")}*.tar.gz"
  debuglog "cmd: #{cmd}"
  child_process.exec cmd, (err, stdout, stderr)  ->
    return callback err, stdout
  return


module.exports =
  init:init
  deleteBackup:deleteBackup
