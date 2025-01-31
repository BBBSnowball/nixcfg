#!/usr/bin/env node

// copied from https://github.com/illuspas/Node-Media-Server/blob/master/bin/app.js

const fs = require("fs");
const path = require("path");
const config = require("./config.json");
//const NodeMediaServer = require("..");
const NodeMediaServer = require("node-media-server");

if (config.rtmps?.key && !fs.existsSync(config.rtmps.key)) {
  config.rtmps.key = path.join(__dirname, config.rtmps.key);

}
if (config.rtmps?.cert && !fs.existsSync(config.rtmps.cert)) {
  config.rtmps.cert = path.join(__dirname, config.rtmps.cert);
}

if (config.https?.key && !fs.existsSync(config.https.key)) {
  config.https.key = path.join(__dirname, config.https.key);

}
if (config.https?.cert && !fs.existsSync(config.https.cert)) {
  config.https.cert = path.join(__dirname, config.https.cert);
}

const nms = new NodeMediaServer(config);
nms.run();
