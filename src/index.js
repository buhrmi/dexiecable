import { createConsumer } from "@rails/actioncable";
export { createConsumer }

// The channel the client subscribes to. Defaults to "DexieChannel", which
// you define in your app by including DexieCable.
const DEFAULT_CHANNEL = "DexieChannel";

// ---------------------------------------------------------------------------
// Module state
// ---------------------------------------------------------------------------

/** @type {import("@rails/actioncable").Consumer | null} */
let consumer = null;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Get the current ActionCable consumer (lazily creates one if needed).
 * @returns {import("@rails/actioncable").Consumer}
 */
export function getConsumer() {
  consumer ||= createConsumer();
  return consumer;
}

/**
 * Set a custom ActionCable consumer.
 * @param {import("@rails/actioncable").Consumer} c
 */
export function setConsumer(c) {
  consumer = c;
}

/**
 * Subscribe to the DexieChannel.
 *
 * Streams are added and removed dynamically after the subscription is
 * established. `addStream()` accepts a signed token (the value returned by
 * `DexieChannel.stream_token_for(target)` on the server) or a plain string,
 * which becomes a public stream. It also accepts extra params that are
 * forwarded to the server's `subscribed_to` hook, and returns a function
 * that removes the stream. `removeAllStreams()` stops every current stream
 * (e.g. on logout).
 *
 * @param {import("dexie").Dexie} db - Your Dexie database instance.
 * @param {string|object} [channelOrMixin="DexieChannel"] - Channel class
 *   name, or an ActionCable lifecycle mixin.
 * @param {object} [mixin={}] - ActionCable lifecycle callbacks.
 * @returns {import("@rails/actioncable").Subscription & {
 *   addStream: (stream: string, params?: Record<string, any>) => () => void,
 *   removeStream: (stream: string) => void,
 *   removeAllStreams: () => void
 * }}
 *
 * @example
 *   import { subscribe } from "dexiecable";
 *   import { db } from "./db";
 *
 *   const subscription = subscribe(db); // subscribes to "DexieChannel"
 *   const removeStream = subscription.addStream(streamToken, { last_seq_id: 100 });
 *   const removeFeed = subscription.addStream("feed"); // plain strings are public
 *   removeStream(); // stop listening
 */
export function subscribe(db, channelOrMixin, mixin) {
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
    },
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

// ---------------------------------------------------------------------------
// Internal
// ---------------------------------------------------------------------------

/**
 * Replay a Dexie query payload against the given database.
 * @param {import("dexie").Dexie} db
 * @param {{ table: string, ops: Array<{ method: string, params: any[] }> }} data
 */
function replay(db, data) {
  let table = db[data.table];
  if (!table) {
    console.warn(`[dexiecable] Table "${data.table}" not found in db.`);
    return;
  }

  // This is the entire replay magic 🤷
  for (const op of data.ops) {
    table = table[op.method](...op.params);
  }
}
