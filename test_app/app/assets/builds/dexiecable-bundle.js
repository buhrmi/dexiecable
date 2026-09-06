// ../src/index.js
import { createConsumer } from "@rails/actioncable";
var CHANNEL = "DexieCable::DexieChannel";
var consumer = null;
function getConsumer() {
  consumer ||= createConsumer();
  return consumer;
}
function setConsumer(c) {
  consumer = c;
}
function subscribe(db, mixin) {
  if (!db) {
    throw new Error("[dexiecable] Pass a Dexie database as the first argument to subscribe().");
  }
  const userMixin = mixin || {};
  const pending = [];
  let connected = false;
  const subscription = getConsumer().subscriptions.create(CHANNEL, {
    received(data) {
      replay(db, data);
    },
    ...userMixin,
    connected() {
      connected = true;
      for (const [action, data] of pending) {
        this.perform(action, data);
      }
      pending.length = 0;
      if (typeof userMixin.connected === "function") userMixin.connected.apply(this, arguments);
    },
    disconnected() {
      connected = false;
      if (typeof userMixin.disconnected === "function") userMixin.disconnected.apply(this, arguments);
    }
  });
  const performStream = (action, data) => {
    if (connected) {
      subscription.perform(action, data);
    } else {
      pending.push([action, data]);
    }
  };
  subscription.addStream = (stream) => performStream("add_stream", { stream });
  subscription.removeStream = (stream) => performStream("remove_stream", { stream });
  subscription.addPublicStream = (name) => performStream("add_public_stream", { stream: name });
  subscription.removePublicStream = (name) => performStream("remove_public_stream", { stream: name });
  subscription.removeAllStreams = () => performStream("remove_all_streams", {});
  return subscription;
}
function replay(db, data) {
  let table = db[data.table];
  if (!table) {
    console.warn(`[dexiecable] Table "${data.table}" not found in db.`);
    return;
  }
  for (const op of data.ops) {
    table = table[op.method](...op.params);
  }
}
export {
  createConsumer,
  getConsumer,
  setConsumer,
  subscribe
};
