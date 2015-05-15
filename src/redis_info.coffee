###
# 读取和分析多个redis-cli info 信息，并对可能的问题进行报警
###

###
  需要的配置信息：
    server_name: 当前所在的服务器(报警时可使用)
    redis:(一个服务只检查一个redis， 如果一台服务器上有多个redis, 可以部署多个服务)
      host: -h
      port: -p

    slowlog:（慢查询报警得阀值）
      len:数量
      max_exec_time: 最大时长（如果有时长超过最大时长报警）

    info:
      used_memory
      used_memory_peak
      latest_fork_usec
      max_save_interval

  项目使用setTimeout 循环, 即在本次检查完成后确定下次的检查时间？
###

###
  需要做的检查：
    slowlog: 慢查询的检查（redis返回的查询时长单位是微秒， 默认超过10毫秒的就会记入慢查询）
      1. 当前慢查询的数量（默认最大128）redis-cli -h xxx -p xxx -r 1 slowlog len
      2. 将得到的慢查询写入日志文件中  redis-cli -h xxx -p xxx -r 1 slowlog get
      3. 检查完后清除掉slowlog（方便下次检查）

    info:
      1.内存的使用情况：（used_memory(使用内存) 和 used_memory_peak(峰值内存) ）
      2.持久化：（rdb_last_save_time 进行监控，了解你最近一次 dump 数据操作的时间(秒)。）
      3.fork性能：(通过对 info 输出的 latest_fork_usec 进行监控来了解最近一次 fork 操作导致了多少时间(毫秒)的卡顿。)

  将得到的查询写入日志文件并记录时间
  如果出现异常发送邮件通知
###

fs = require "fs"
async = require "async"
child_process = require 'child_process'
_ = require 'underscore'
debuglog = require("debug")("redis_info")
mkdirp = require "mkdirp"
dateFormat = require('dateformat')
mailer = require "./utils/mailer"

regExp = new RegExp(/.+/g)

REDIS =
  host: '127.0.0.1'
  port: '6379'

SLOWLOG =
  len:32
  max_exec_time:10

INFO =
  used_memory : 734003200 #700mb
  used_memory_peak: 1073741824 #1gb
  latest_fork_usec: 10000 #10秒（1gb数据持久化可能得延时会达到5~8秒）
  max_save_interval: 1000 #1000秒

LOG_PATH = null
INTERVAL_TIME = 300000
INTERVAL_MULTIPLE = 1 #间隔时间的倍率， 在出错时适当延长其倍率（防止报警邮件发送过于频繁），
CMDS = {}
CMD_KEYS = null

_validateInfo = (info, errs) ->
  if _.isEmpty(info)
    errs.push "redis info is empty"
    return
  used_memory = parseInt(info.used_memory||0)
  used_memory_peak = parseInt(info.used_memory_peak||0)
  rdb_last_save_time = info.rdb_last_save_time
  latest_fork_usec = parseInt(info.latest_fork_usec||0)
  console.log "memory:#{used_memory} memory_peak:#{used_memory_peak} rdb_last_save_time:#{rdb_last_save_time} latest_fork_usec:#{latest_fork_usec}"
  if used_memory > INFO.used_memory
    errs.push "redis info used_memory: #{used_memory}"
  if used_memory_peak > INFO.used_memory_peak
    errs.push "redis info used_memory_peak: #{used_memory_peak}"
  if latest_fork_usec > INFO.latest_fork_usec
    errs.push "redis info latest_fork_usec: #{latest_fork_usec}"
  if new Date(rdb_last_save_time).getTime() < Date.now() - (INFO.max_save_interval*1000)
    errs.push "redis info rdb_last_save_time: #{rdb_last_save_time}"
  return

init = (config) ->
  REDIS = config.REDIS || REDIS
  SLOWLOG = config.SLOWLOG || SLOWLOG
  INFO = config.INFO || INFO
  LOG_PATH = config.log_path
  INTERVAL_TIME = config.interval_time || INTERVAL_TIME
  cmd_slowlog_len = "redis-cli -h #{REDIS.host} -p #{REDIS.port} -r 1 slowlog len"
  cmd_slowlog_get = "redis-cli -h #{REDIS.host} -p #{REDIS.port} -r 1 slowlog get"
  cmd_slowlog_reset = "redis-cli -h #{REDIS.host} -p #{REDIS.port} -r 1 slowlog reset"
  cmd_info = "redis-cli -h #{REDIS.host} -p #{REDIS.port} info"
  CMDS =
    slowlogLen: cmd_slowlog_len
    slowlogGet: cmd_slowlog_get
    info: cmd_info
  CMD_KEYS = _.keys(CMDS)
  mkdirp.sync LOG_PATH
  return

timeout = null
start = () ->
  clearTimeout(timeout)
  infos = {}
  errs = []
  async.eachSeries CMD_KEYS, (key, next) =>
    child_process.exec CMDS[key], (err, stdout, stderr)=>
      #执行错误停止并立即报警
      return next(err) if err?
      unless key == "info"
        infos[key] = stdout
      else
        arr = stdout.match(regExp) || []
        test = {}
        arr.map (str) =>
          star = str.split(":")
          test[star[0]] = star[1] if _.isArray(star) and star.length==2
        infos[key] = test
      next()
  , (err) ->
    if err?
      debuglog err
      errs.push err
      #报警（）
    else
      slowlogLen = parseInt(infos.slowlogLen||0)
      if slowlogLen >= SLOWLOG.len
        errs.push "slowlog len: #{slowlogLen}"
      info = infos.info
      _validateInfo(infos.info, errs)
      console.log "log_path: #{LOG_PATH}"
      fs.writeFileSync "#{LOG_PATH}/info_#{dateFormat(new Date(), "yyyymmddHHMMss")}.log", JSON.stringify(infos, null, 4)
    unless _.isEmpty(errs)
      #发送报警邮件
      console.dir errs
      mailer.sendErrors errs
      INTERVAL_MULTIPLE += INTERVAL_MULTIPLE
    else
      INTERVAL_MULTIPLE = 1
    console.log "#{INTERVAL_MULTIPLE}"
    timeout = setTimeout start, INTERVAL_TIME*INTERVAL_MULTIPLE
    return
  return

    #TODO 发邮件
  #TODO 记录info
  #TODO 确认下次开始时间

module.exports =
  init:init
  start:start

