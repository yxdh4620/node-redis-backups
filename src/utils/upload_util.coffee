_ = require 'underscore'
debuglog = require("debug")("redis-backups::upload_util")
OssEasy = require "oss-easy"
fs = require "fs"
path = require "path"
assert = require "assert"

OSS_CLIENT = null
BUCKUP_DIR = null

init = (config) ->
  if OSS_CLIENT?
    console.error "[oss_depositer::init] OSS_CLIENT is already inited"
    return
  OSS_CLIENT = new OssEasy(config.oss)
  BUCKUP_DIR = config.backupDirName||'development'

upload = (sourceFile, callback) ->
  unless fs.existsSync(sourceFile)
    console.error "missing sourceFile: #{sourceFile}"
    return
  OSS_CLIENT.uploadFile sourceFile, "#{BUCKUP_DIR}/#{path.basename(sourceFile)}", (err)->
    console.error "upload_util: upload is error: #{err}" if err?
    return callback err
  return

module.exports =
  init:init
  upload: upload
