// ../src/index.js
import { createConsumer } from "@rails/actioncable";
var DEFAULT_CHANNEL = "DexieChannel";
var consumer = null;
function getConsumer() {
  consumer ||= createConsumer();
  return consumer;
}
function setConsumer(c) {
  consumer = c;
}
function subscribe(db, channelOrMixin, mixin) {
  if (!db) {
    throw new Error("[dexiecable] Pass a Dexie database as the first argument to subscribe().");
  }
  let channel = DEFAULT_CHANNEL;
  if (typeof channelOrMixin === "string") {
    channel = channelOrMixin;
  } else {
    mixin = channelOrMixin;
  }
  const userMixin = mixin || {};
  const pending = [];
  let connected = false;
  const subscription = getConsumer().subscriptions.create(channel, {
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
  subscription.addStream = (stream, params = {}) => {
    performStream("add_stream", { ...params, stream });
    return () => performStream("remove_stream", { stream });
  };
  subscription.removeStream = (stream) => performStream("remove_stream", { stream });
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
