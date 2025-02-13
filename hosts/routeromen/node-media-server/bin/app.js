#!/usr/bin/env node

// copied from https://github.com/illuspas/Node-Media-Server/blob/master/bin/app.js

const fs = require("fs");
const path = require("path");
const { spawn } = require('node:child_process');
const config = require("./config.json");
//const NodeMediaServer = require("..");
const NodeMediaServer = require("node-media-server");
const BroadcastServer = require("node-media-server/src/server/broadcast_server.js");
const logger = require( "node-media-server/src/core/logger.js");

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

class MyBroadcastServer extends BroadcastServer {
  constructor() {
    super();

    this.postPlaySuper = this.postPlay;
    this.postPlay = this.postPlay2;
    this.donePlaySuper = this.donePlay;
    this.donePlay = this.donePlay2;

    this.streamActive = false;
  }

  // must be an arrow method to override
  // https://stackoverflow.com/questions/45881670/should-i-write-methods-as-arrow-functions-in-angulars-class/45882417#45882417
  // -> We cannot use super in an arrow method, so we use a different name and save the previous one before replacing it (see above).
  postPlay2 = (session) => {
    logger.info(`postPlay in MyBroadcastServer, protocol ${session.protocol}, before ${this.subscribers.size} subscribers`);
    this.postPlaySuper(session);

    if (!this.streamActive) {
      logger.info("Starting stream service");
      this.streamActive = true;
      spawn("/run/wrappers/bin/sudo systemctl start stream-printer1.service", { stdio: "inherit", shell: true });
    }
  }
  donePlay2 = (session) => {
    this.donePlaySuper(session);
    logger.info(`donePlay in MyBroadcastServer, protocol ${session.protocol}, after ${this.subscribers.size} subscribers`);
    if (this.subscribers.size == 0 && this.streamActive) {
      logger.info("Stopping stream service");
      spawn("/run/wrappers/bin/sudo systemctl stop stream-printer1.service", { stdio: "inherit", shell: true });
      this.streamActive = false;
    }
  }
}

const nms = new NodeMediaServer(config);

const ctx = nms.ctx;

const streamPath = "/live/test";
nms.ctx.broadcasts.set(streamPath, new MyBroadcastServer());
logger.info(`We have added MyBroadcastServer for ${streamPath}`);

// Get the HTTP App object - *very* ugly hack!
const app = nms.httpServer.httpServer._events.request;
function reply(req, res, process) {
  process.on('exit', (code) => {
    if (code == 0) {
      res.send('ok');
    } else {
      console.log(`child process exited with code ${code}`);
      res.status(503);
      res.send("error: couldn't run command");
    }
  });
  process.on('error', (err) => {
    console.log(`child process had an error: ${err}`);
    res.status(503);
    res.send("error: couldn't run command");
  });
}
app.post("/restart", (req, res) => {
  const p = spawn("/run/wrappers/bin/sudo systemctl restart stream-printer1.service", { stdio: "inherit", shell: true });
  reply(req, res, p);
});
app.post("/stop", (req, res) => {
  const p = spawn("/run/wrappers/bin/sudo systemctl stop stream-printer1.service", { stdio: "inherit", shell: true });
  reply(req, res, p);
});

nms.run();
