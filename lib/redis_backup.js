// Generated by CoffeeScript 1.8.0

/*
 * 向oss 备份 redis rdb 的本地备份文件
 */


/*
  需要的配置信息：
    redis_back_path redis 备份的地址(找到所有没有上传得备份, 地址规则：server_name/redis_port)

    redis_dbs: （因为存在多个redis, 所以以数组得方式）
      server_name: -h
      port: -p
 */


/*
 *ls -t /var/folders/k0/cx_xzqln76n6cn35why_42j00000gn/T//redis_info | head -n 5
  工作任务：
    1.检查redis最后备份文件， 进行时间对比， 如果长时间没有新的备份信息则报警
    2.将没有上传的redis文件上传并转移到对应的时间目录（以年月日命名）， 如果出错则报警
    3.定期清理超过时效的redis文件（默认30天以上? 还是使用linux得crontab?）
 */

(function() {
  var INTERVAL_TIME, MAX_BACKUP_INTERVAL, OSS_CLIENT, OssEasy, REDIS_BACK_PATH, REDIS_INFOS, assert, async, child_process, dateFormat, debuglog, init, mailer, mkdirp, path, size, start, timeout, _, _readFiles, _uploadFiles;

  debuglog = require("debug")("redis-backups::redis_backup");

  _ = require('underscore');

  child_process = require("child_process");

  async = require("async");

  assert = require('assert');

  path = require("path");

  OssEasy = require("oss-easy");

  mkdirp = require("mkdirp");

  mailer = require('./utils/mailer');

  dateFormat = require('dateformat');

  INTERVAL_TIME = 30000;

  MAX_BACKUP_INTERVAL = 15 * 60 * 1000;

  REDIS_BACK_PATH = "/Users/user/temp/redis-backup";

  REDIS_INFOS = null;

  OSS_CLIENT = null;

  size = 1;

  init = function(config) {
    REDIS_BACK_PATH = config.redis_back_path;
    REDIS_INFOS = config.redis_dbs;
    OSS_CLIENT = new OssEasy(config.oss);
    INTERVAL_TIME = config.interval_time || INTERVAL_TIME;
    assert(REDIS_BACK_PATH, "missing REDIS_BACK_PATH");
    assert(_.isArray(REDIS_INFOS), "missing REDIS_INFOS");
  };

  _readFiles = function(redisInfo, backupPath, callback) {
    var cmd;
    cmd = "ls -t " + backupPath + "/*.tar.gz | head -n " + size;
    child_process.exec(cmd, function(err, stdout, stderr) {
      var basename, date, file, fileTime, files;
      if (err != null) {
        console.error("command ls(" + cmd + ") is error:" + err);
        return callback(err);
      }
      console.log(stdout);
      files = stdout.split('\n');
      if (!((files != null) && _.isArray(files) && files.length > 1)) {
        return callback("" + redisInfo.server_name + "_" + redisInfo.port + " not find redis_backup file");
      }
      file = files[0];
      basename = path.basename(file || '', '.tar.gz');
      if (!((basename != null) && basename.length > 0)) {
        return callback("" + redisInfo.server_name + "_" + redisInfo.port + " not find redis_backup file");
      }
      fileTime = basename.split("_")[1];
      date = new Date(Date.now() - MAX_BACKUP_INTERVAL);
      console.log("" + (dateFormat(date, "yyyymmddHHMMss")) + "  " + fileTime);
      if (dateFormat(date, "yyyymmddHHss") > fileTime) {
        return callback("" + redisInfo.server_name + "_" + redisInfo.port + " Long time no backup");
      }
      callback(null, file);
    });
  };

  _uploadFiles = function(redisInfo, file, backupPath, callback) {
    var basename, fileTime, ossPath;
    basename = path.basename(file, '.tar.gz');
    fileTime = basename.split("_")[1];
    ossPath = "" + redisInfo.server_name + "/" + redisInfo.port + "/" + (fileTime.substr(0, 8));
    OSS_CLIENT.uploadFile(file, "" + ossPath + "/" + (path.basename(file)), (function(_this) {
      return function(err) {
        return callback(err);
      };
    })(this));
  };

  timeout = null;

  start = function() {
    var errors;
    console.log("time: " + (Date.now()));
    errors = [];
    clearTimeout(timeout);
    async.eachSeries(REDIS_INFOS, (function(_this) {
      return function(redisInfo, next) {
        var backupPath;
        backupPath = "" + REDIS_BACK_PATH + "/" + redisInfo.server_name + "/" + redisInfo.port;
        _readFiles(redisInfo, backupPath, function(err, file) {
          if (err != null) {
            errors.push("" + err);
            return next();
          }
          console.dir(file);
          _uploadFiles(redisInfo, file, backupPath, function(err) {
            if (err != null) {
              errors.push("" + err);
            }
            return next();
          });
        });
      };
    })(this), (function(_this) {
      return function(err) {
        if (_.isEmpty(errors)) {
          timeout = setTimeout(start, INTERVAL_TIME);
        } else {
          console.dir(errors);
          mailer.sendErrors(errors);
          timeout = setTimeout(start, INTERVAL_TIME);
        }
        console.log("end");
      };
    })(this));
  };

  module.exports = {
    init: init,
    start: start
  };

}).call(this);
