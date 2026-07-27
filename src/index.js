import { createConsumer } from "./actioncable.js";
export { createConsumer }

let unloading = false;

if (typeof window !== "undefined") {
  window.addEventListener("beforeunload", () => {
    unloading = true;
  });
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

const DexieCable = {
  /** @type {import("@rails/actioncable").Consumer} */
  consumer: null,

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
   *   import DexieCable from "dexiecable";
   *   import { db } from "./db";
   *
   *   DexieCable.subscribe(db, "UserChannel", { last_update: Date.now() });
   */
  subscribe(db, channel, params = {}, callbacks = {}) {
    if (!db) {
      throw new Error("[dexiecable] Pass a Dexie database as the first argument to subscribe().");
    }

    params = { channel, ...params };
    callbacks = {
      connected() {
        console.log(`[dexiecable] Connected to ${channel}`);
      },
      disconnected({ willAttemptReconnect }) {
        console.log(`[dexiecable] Disconnected from ${channel}`);
        if (!willAttemptReconnect || unloading) return;
        this.reconnecting?.();
      },
      received(data) {
        replay(db, data);
      },
      ...callbacks,
    };

    DexieCable.consumer ||= createConsumer();
    return DexieCable.consumer.subscriptions.create(params, callbacks);
  },
};

export const { subscribe } = DexieCable;
export default DexieCable;

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

  for (const op of data.ops) {
    table = table[op.method](...op.params);
  }
}
