import { createConsumer } from "@rails/actioncable";

let db = null;
let consumer = null;
let unloading = false;

if (typeof window !== "undefined") {
  window.addEventListener("beforeunload", () => {
    unloading = true;
  });
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Configure the DexieCable client.
 * Must be called before {@link subscribe}.
 *
 * @param {{ db: import("dexie").Dexie, consumer: import("@rails/actioncable").Consumer }} options
 *
 * @example
 *   import { configure } from "dexiecable";
 *   import { db } from "./db";
 *   import { createConsumer } from "@rails/actioncable"
 *   configure({ db, consumer: createConsumer() });
 */
export function configure({ db: _db, consumer: _consumer } = {}) {
  db = _db;
  if (_consumer) consumer = _consumer;
}

/**
 * Subscribe to a DexieCable channel.
 *
 * @param {string} channel - Channel class name (e.g. "UserChannel").
 * @param {Record<string, any>} [params={}] - Extra parameters sent on subscription.
 * @param {object} [callbacks={}] - ActionCable lifecycle callbacks.
 * @returns {import("@rails/actioncable").Subscription}
 *
 * @example
 *   import { subscribe } from "dexiecable";
 *   const sub = subscribe("UserChannel", { last_update: Date.now() });
 */
export function subscribe(channel, params = {}, callbacks = {}) {
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
      handle(data);
    },
    ...callbacks,
  };

  if (!consumer) consumer = createConsumer();
  return consumer.subscriptions.create(params, callbacks);
}

// ---------------------------------------------------------------------------
// Internal
// ---------------------------------------------------------------------------

/**
 * Replay a Dexie query payload against the local database.
 * @param {{ table: string, ops: Array<{ method: string, params: any[] }> }} data
 */
function handle(data) {
  if (!db) {
    console.warn("[dexiecable] Received data but db is not configured. Call configure({ db }) first.");
    return;
  }

  let table = db[data.table];
  if (!table) {
    console.warn(`[dexiecable] Table "${data.table}" not found in db.`);
    return;
  }

  for (const op of data.ops) {
    table = table[op.method](...op.params);
  }
}
