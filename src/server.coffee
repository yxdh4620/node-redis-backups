###
# redis-backups 项目主程序
# author:YuanXiangDong
# date: 2015-04-28
###


fs = require "fs"
path = require "path"
p = require 'commander'
_ = require 'underscore'
debuglog = require("debug")("redis-backup::server")
os = require "os"

pkg = JSON.parse(fs.readFileSync(path.join(__dirname, "../package.json")))

## 更新外部配置
p.version(pkg.version)
  .option('-e, --environment [type]', 'runtime environment of [development, production, testing]', 'development')
  .parse(process.argv)


###
# bootstrap config
###
env = p.environment || 'development'
c = require('./config/config')
config = require('./config/config')[env]
config.version = pkg.version
config.root = path.resolve __dirname, "../"
config.backupPath = path.join os.tmpdir(), "#{config.backupDirName||'development'}"
config.server_name = config.server_name || env

start=(config)->
  require("./redis_backup").init(config)
  require('./utils/mailer').init(config)

  mailer = require "./utils/mailer"
  unless env is 'development'
    process.on 'uncaughtException', (error) -> mailer.deliverServerException(error)

  redisBackup = require("./redis_backup")
  redisBackup.start()
  return

start(config)



