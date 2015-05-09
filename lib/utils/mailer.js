// Generated by CoffeeScript 1.8.0
(function() {
  var DEFAULT_FROM, POSTMARK_APP_KEY, REQUEST_HEADERS, REQUEST_METHOD, REQUEST_URL, SERVER_NAME, TO, assert, debuglog, fs, path, request, _;

  _ = require('underscore');

  path = require('path');

  fs = require('fs');

  assert = require('assert');

  request = require('request');

  debuglog = require("debug")("redis-info::utils::mailer");

  assert = require("assert");

  REQUEST_URL = "https://api.postmarkapp.com/email";

  REQUEST_METHOD = "POST";

  REQUEST_HEADERS = {
    "Accept": "application/json",
    "Content-Type": "application/json",
    "X-Postmark-Server-Token": null
  };

  DEFAULT_FROM = "donotreply@gamagama.cn";

  TO = 'yi2004@gmail.com';

  POSTMARK_APP_KEY = null;

  SERVER_NAME = null;

  exports.init = function(config) {
    debuglog("[init] postmarkKey:" + config.postmarkKey + ", to:" + config.postmarkTo);
    assert(config.postmarkKey, "missing postmark key");
    POSTMARK_APP_KEY = config.postmarkKey;
    REQUEST_HEADERS["X-Postmark-Server-Token"] = POSTMARK_APP_KEY;
    TO = config.postmarkTo || TO;
    return SERVER_NAME = config.server_name;
  };

  exports.deliverServerException = function(error) {
    error = error || {};
    console.log("[deliverServerException] error:" + error + ", stack:" + error.stack);
    assert(POSTMARK_APP_KEY, "postmark is not inited");
    request({
      url: "https://api.postmarkapp.com/email",
      method: "POST",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-Postmark-Server-Token": POSTMARK_APP_KEY
      },
      json: {
        "From": "donotreply@gamagama.cn",
        "To": TO,
        "Subject": "redis-info::" + SERVER_NAME + "::uncaughtException " + ((new Date).toLocaleString()) + ", " + error,
        "TextBody": JSON.stringify({
          error: error.toString(),
          stack: error.stack
        }, null, 4)
      }
    });
  };

  exports.sendErrors = function(errors) {
    errors = errors || {};
    assert(POSTMARK_APP_KEY, "postmark is not inited");
    request({
      url: "https://api.postmarkapp.com/email",
      method: "POST",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-Postmark-Server-Token": POSTMARK_APP_KEY
      },
      json: {
        "From": "donotreply@gamagama.cn",
        "To": TO,
        "Subject": "redis-info::" + SERVER_NAME + "::uncaughtException " + ((new Date).toLocaleString()),
        "TextBody": JSON.stringify(errors, null, 4)
      }
    });
  };

}).call(this);