###
# redis-backups 项目主程序
# author:YuanXiangDong
# date: 2015-04-28
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

start=(config)->
  require('./utils/upload_util').init(config)
  require('./utils/delete_buckup').init(config)
  backupUtil = require('./utils/backup_util')
  backupUtil.init(config)
  backupUtil.start (err) ->
    return console.dir err if err?
    deleteBackup = require "./utils/delete_buckup"
    deleteBackup.deleteBackup (err,stdout) ->
      return console.error err if err?
      console.log stdout
      return
    return
  return

start(config)



