// Generated by CoffeeScript 1.8.0

/*
 * redis-backups 项目主程序
 * author:YuanXiangDong
 * date: 2015-04-28
 */

(function() {
  var c, config, debuglog, env, fs, os, p, path, pkg, start, _;

  fs = require("fs");

  path = require("path");

  p = require('commander');

  _ = require('underscore');

  debuglog = require("debug")("redis-backup::server");

  os = require("os");

  pkg = JSON.parse(fs.readFileSync(path.join(__dirname, "../package.json")));

  p.version(pkg.version).option('-e, --environment [type]', 'runtime environment of [development, production, testing]', 'development').parse(process.argv);


  /*
   * bootstrap config
   */

  env = p.environment || 'development';

  c = require('./config/config');

  config = require('./config/config')[env];

  config.version = pkg.version;

  config.root = path.resolve(__dirname, "../");

  config.backupPath = path.join(os.tmpdir(), "" + (config.backupDirName || 'development'));

  config.server_name = config.server_name || env;

  start = function(config) {
    var mailer, redisBackup;
    require("./redis_backup").init(config);
    require('./utils/mailer').init(config);
    mailer = require("./utils/mailer");
    if (env !== 'development') {
      process.on('uncaughtException', function(error) {
        return mailer.deliverServerException(error);
      });
    }
    redisBackup = require("./redis_backup");
    redisBackup.start();
  };

  start(config);

}).call(this);
