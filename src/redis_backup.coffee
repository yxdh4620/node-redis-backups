###
# 向oss 备份 redis rdb 的本地备份文件
###

###
  需要的配置信息：
    redis_back_path redis 备份的地址(找到所有没有上传得备份, 地址规则：server_name/redis_port)

    redis_dbs: （因为存在多个redis, 所以以数组得方式）
      server_name: -h
      port: -p
###
###
#ls -t /var/folders/k0/cx_xzqln76n6cn35why_42j00000gn/T//redis_info | head -n 5
  工作任务：
    1.检查redis最后备份文件， 进行时间对比， 如果长时间没有新的备份信息则报警
    2.将没有上传的redis文件上传并转移到对应的时间目录（以年月日命名）， 如果出错则报警
    3.定期清理超过时效的redis文件（默认30天以上? 还是使用linux得crontab?）
###


debuglog = require("debug")("redis-backups::redis_backup")
_ = require 'underscore'
child_process = require "child_process"
async = require "async"
assert = require 'assert'
path = require "path"
OssEasy = require "oss-easy"
mkdirp = require "mkdirp"
mailer = require './utils/mailer'
dateFormat = require('dateformat')
#require "shelljs/global"
#files = ls("-t /var/folders/k0/cx_xzqln76n6cn35why_42j00000gn/T/redis_info/*.log")
#console.dir files

INTERVAL_TIME = 30000
MAX_BACKUP_INTERVAL = 15*60*1000

#redis备份文件得路径地址?
REDIS_BACK_PATH = "/Users/user/temp/redis-backup"
#要上传得redis信息集合
REDIS_INFOS = null
OSS_CLIENT = null

#一个节点时间， 每次上传完后更新, KEY为redisInfo 中得serverName_port
#LAST_TIMES = {}
#最后一个上传的文件
#LAST_FILES = {}

size = 1

init = (config) ->
  REDIS_BACK_PATH = config.redis_back_path
  REDIS_INFOS = config.redis_dbs
  OSS_CLIENT = new OssEasy(config.oss)
  INTERVAL_TIME = config.interval_time || INTERVAL_TIME
  assert REDIS_BACK_PATH, "missing REDIS_BACK_PATH"
  assert _.isArray(REDIS_INFOS), "missing REDIS_INFOS"
  return

#_readFiles = (backupPath, callback) ->
#  require "shelljs/global"
#  files = ls("#{backupPath}/*.tar.gz")
#  callback null, files
#  return
#  child_process.exec cmd, (err, stdout, stderr) ->
#    if err?
#      console.error "command ls(#{cmd}) is error:#{err}"
#      return callback(err)
#    console.log stdout
#    files = stdout.split('\n')
#    unless files? and _.isArray(files) and files.length>1
#      return callback("#{redisInfo.server_name}_#{redisInfo.port} not find redis_backup file")
#    files.pop()
#    errors.push "#{redisInfo.server_name}_#{redisInfo.port} Long time no backup"
#    callback null, files
#    return

#_uploadFiles = (redisInfo, files, backupPath, errors, callback) ->
#  async.eachSeries files, (file, next) =>
#    basename = path.basename file, '.tar.gz'
#    fileTime = basename.split("_")[1]
#    ossPath = "#{redisInfo.server_name}/#{redisInfo.port}/#{fileTime.substr(0,8)}"
#    OSS_CLIENT.uploadFile file, "#{ossPath}/#{path.basename(file)}", (err)=>
#      if err?
#        errors.push "#{err}"
#        return next()
#      #dir = "#{backupPath}/#{fileTime.substr(0,8)}"
#      #mkdirp.sync dir
#      #cmd = "mv #{file} #{dir}/#{path.basename(file)}"
#      #child_process.exec cmd, (err, stdout, stderr) =>
#      #  errors.push "#{err}" if err?
#      #  return next()
#      next()
#      return
#    return
#  , (err) =>
#    callback(err)
#    return
#  return

_readFiles = (redisInfo, backupPath, callback) ->
  cmd = "ls -t #{backupPath}/*.tar.gz | head -n #{size}"
  child_process.exec cmd, (err, stdout, stderr) ->
    if err?
      console.error "command ls(#{cmd}) is error:#{err}"
      return callback(err)
    console.log stdout
    files = stdout.split('\n')
    unless files? and _.isArray(files) and files.length>1
      return callback("#{redisInfo.server_name}_#{redisInfo.port} not find redis_backup file")
    file = files[0]
    basename = path.basename(file||'', '.tar.gz')
    unless basename? and basename.length> 0
      return callback("#{redisInfo.server_name}_#{redisInfo.port} not find redis_backup file")
    fileTime = basename.split("_")[1]
    date = new Date(Date.now() - MAX_BACKUP_INTERVAL)
    console.log "#{dateFormat(date, "yyyymmddHHMMss")}  #{fileTime}"
    if dateFormat(date, "yyyymmddHHss") >  fileTime
      return callback "#{redisInfo.server_name}_#{redisInfo.port} Long time no backup"
    callback null, file
    return
  return

_uploadFiles = (redisInfo, file, backupPath, callback) ->
  basename = path.basename file, '.tar.gz'
  fileTime = basename.split("_")[1]
  ossPath = "#{redisInfo.server_name}/#{redisInfo.port}/#{fileTime.substr(0,8)}"
  OSS_CLIENT.uploadFile file, "#{ossPath}/#{path.basename(file)}", (err)=>
    return callback err
  return


timeout = null
start = () ->
  console.log "time: #{Date.now()}"
  errors = []
  clearTimeout(timeout)
  #cmd = "ls -t #{redis_back_path} | head -n #{size}"
  async.eachSeries REDIS_INFOS, (redisInfo, next) =>
    backupPath = "#{REDIS_BACK_PATH}/#{redisInfo.server_name}/#{redisInfo.port}"
    _readFiles redisInfo, backupPath, (err, file) =>
      if err?
        errors.push "#{err}"
        return next()
      console.dir file
      _uploadFiles redisInfo, file, backupPath, (err) =>
        errors.push "#{err}" if err?
        return next()
      return
    return
  ,(err) =>
    if _.isEmpty(errors)
      timeout = setTimeout start, INTERVAL_TIME
    else
      #发送报警邮件
      console.dir errors
      mailer.sendErrors errors
      timeout = setTimeout start, INTERVAL_TIME
    console.log "end"
    return
  return


module.exports =
  init: init
  start: start





