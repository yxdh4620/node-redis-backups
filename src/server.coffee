###
# redis-info 项目主程序
# author:YuanXiangDong
# date: 2015-05-09
# 读取和分析多个redis-cli info 信息，并对可能的问题进行报警
###

###
  需要的配置信息：
    server_name: 当前所在的服务器(报警时可使用)
    redis:
      host: -h
      port: -p
    interval_time:执行检查的时间间隔(毫秒)

    slowlog:（慢查询报警得阀值）
      len:数量
      max_exec_time: 最大时长（如果有时长超过最大时长报警）

    email:
      to_users: 发送报警邮件的对象

  项目使用setTimeout 循环, 即在本次检查完成后确定下次的检查时间？
###

###
  需要做的检查：
    slowlog: 慢查询的检查（redis返回的查询时长单位是微秒， 默认超过10毫秒的就会记入慢查询）
      1. 当前慢查询的数量（默认最大128）redis-cli -h xxx -p xxx -r 1 slowlog len
      2. 将得到的慢查询写入日志文件中  redis-cli -h xxx -p xxx -r 1 slowlog get
      3. 检查完后清除掉slowlog（方便下次检查）

    info:
      1.内存的使用情况：（used_memory 和 used_memory_peak ）
      2.持久化：（rdb_last_save_time 进行监控，了解你最近一次 dump 数据操作的时间，还可以通过对 rdb_changes_since_last_save 进行监控来知道如果这时候出现故障，你会丢失多少数据。）
      3.fork性能：(通过对 info 输出的 latest_fork_usec 进行监控来了解最近一次 fork 操作导致了多少时间的卡顿。)

  将得到的查询写入日志文件并记录时间
  如果出现异常发送邮件通知
###

fs = require "fs"
path = require "path"
p = require 'commander'
_ = require 'underscore'
debuglog = require("debug")("redis-backups::server")
os = require "os"

pkg = JSON.parse(fs.readFileSync(path.join(__dirname, "../package.json")))

## 更新外部配置
p.version(pkg.version)
  .option('-e, --environment [type]', 'runtime environment of [development, production, testing]', 'development')
  .option('-l, --loger [value]', 'runtime log file dir', "#{os.tmpdir()}/redis_info")
  .parse(process.argv)


###
# bootstrap config
###

env = p.environment || 'development'
config = require('./config/config')[env]
config.version = pkg.version
config.root = path.resolve __dirname, "../"
config.log_path = p.loger || path.join(os.tmpdir(), "redis_info")
config.server_name = config.server_name || 'development'


start=(config)->
  require('./redis_info').init(config)
  require('./utils/mailer').init(config)

  mailer = require "./utils/mailer"
  unless env is 'development'
    process.on 'uncaughtException', (error) -> mailer.deliverServerException(error)


  redisInfo = require "./redis_info"
  redisInfo.start()


start(config)



