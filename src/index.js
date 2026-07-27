import { createConsumer } from "./actioncable.js";
export { createConsumer }

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
 * Subscribe to a DexieCable channel.
 *
 * @param {import("dexie").Dexie} db - Your Dexie database instance.
 * @param {string} channel - Channel class name (e.g. "UserChannel").
 * @param {Record<string, any>} [params={}] - Extra parameters sent on subscription.
 * @param {object} [callbacks={}] - ActionCable lifecycle callbacks.
 * @returns {import("@rails/actioncable").Subscription}
 *
 * @example
 *   import { subscribe } from "dexiecable";
 *   import { db } from "./db";
 *
 *   subscribe(db, "UserChannel", { last_update: Date.now() });
 */
export function subscribe(db, channelName, mixin) {
  if (!db) {
    throw new Error("[dexiecable] Pass a Dexie database as the first argument to subscribe().");
  }

  mixin = {
    received(data) {
      replay(db, data);
    },
    ...mixin,
  };

  return getConsumer().subscriptions.create(channelName, mixin);
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
