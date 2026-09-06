import { createConsumer } from "@rails/actioncable";
export { createConsumer }

// The single channel the client subscribes to. Broadcasts originate from the
// gem's DexieChannel (see the `syncs_to_dexie` ActiveRecord macro).
const CHANNEL = "DexieCable::DexieChannel";

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
 * established. Private streams use a signed token (the value returned by
 * `DexieChannel.stream_token_for(target)` on the server) with `addStream()`
 * and `removeStream()`. Public streams use `addPublicStream()` and
 * `removePublicStream()` with a plain name. `removeAllStreams()` stops
 * every current stream (e.g. on logout).
 *
 * @param {import("dexie").Dexie} db - Your Dexie database instance.
 * @param {object} [mixin={}] - ActionCable lifecycle callbacks.
 * @returns {import("@rails/actioncable").Subscription & {
 *   addStream: (stream: string) => void,
 *   removeStream: (stream: string) => void,
 *   addPublicStream: (name: string) => void,
 *   removePublicStream: (name: string) => void,
 *   removeAllStreams: () => void
 * }}
 *
 * @example
 *   import { subscribe } from "dexiecable";
 *   import { db } from "./db";
 *
 *   const subscription = subscribe(db);
 *   subscription.addStream(streamToken);
 */
export function subscribe(db, mixin) {
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
    },
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
