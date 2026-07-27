# DexieCable

Read the [blog post introducing DexieCable](https://dev.to/buhrmi/real-time-rails-without-turbo-modern-reactive-uis-with-inertia-and-dexiecable-4lge)

DexieCable augments ActionCable channels with a query DSL that mirrors the Dexie.js API, letting you push database mutations from the server to the client in real time. It also gives you a [`syncs_to_dexie`](#syncs_to_dexie--automatic-model-syncing) ActiveRecord macro for automatic change syncing.

You can run any Dexie table update directly inside a channel:

```ruby
class UserChannel < ApplicationCable::Channel
  include DexieCable

  def subscribed
    stream_for current_user
    recent_notifications = current_user.notifications.last(10)
    table("notifications").bulkAdd(recent_notifications)
  end
end
```

Or from inside a controller:

```ruby
class NotificationsController < ApplicationController
  def create
    notification = current_user.notifications.create!(notification_params)
    UserChannel[current_user].table("notifications").add(notification)
  end
end
```

An even more convenient way is to use the `syncs_to_dexie` macro (more info [below](#syncs_to_dexie--automatic-model-syncing))

```ruby
class Notification < ApplicationRecord
  syncs_to_dexie via: UserChannel, to: :user
end
```

## Installation

### Ruby gem

Add to your `Gemfile`:

```ruby
gem "dexiecable"
```

Then `bundle install`. The Railtie automatically extends `ActiveRecord::Base` with `syncs_to_dexie`.

### npm package

```bash
npm install dexiecable
# or
yarn add dexiecable
```

Assign your Dexie database to `DexieCable.db` and subscribe to a channel:

```js
import DexieCable from "dexiecable";
import { db } from "./db";

DexieCable.db = db;
DexieCable.subscribe("UserChannel");
```

DexieCable automatically creates a consumer and assigns it to `DexieCable.consumer`. If you need to access the consumer earlier in your app, you can create one yourself:

```js
// DexieCable ships with its own version of ActionCable (see below).
import { createConsumer } from "dexiecable";

DexieCable.consumer = createConsumer();
```

## Usage

### `include DexieCable` in a channel

```ruby
class UserChannel < ApplicationCable::Channel
  include DexieCable

  def subscribed
    stream_for current_user
  end
end
```

This gives you:

| Method | Description |
|---|---|
| `self.[](to)` | Returns a `ScopedChannel` bound to a recipient. `UserChannel[current_user]` |
| `table(name)` | Starts a query chain. `table("messages")` |

### Chaining Dexie operations

Any Dexie.js write operation triggers an immediate broadcast:

```ruby
# Single insert
UserChannel[current_user].table("messages").add(id: 1, text: "hello")

# Bulk insert
UserChannel[current_user].table("messages").bulkAdd(messages)

# Update (using modify)
UserChannel[current_user]
  .table("messages")
  .where(:id).equals(msg.id)
  .modify(read: true)

# Update (using update)
UserChannel[current_user]
  .table("messages")
  .update(msg.id, text: "updated text")

# Delete
UserChannel[current_user]
  .table("messages")
  .where(:room_id).equals(room.id)
  .delete()
```

The full query chain is serialized as JSON and sent over ActionCable. The JS client replays every method call against the local Dexie database in order.

### `syncs_to_dexie` — automatic model syncing

Add to any ActiveRecord model. Just provide the channel class and the broadcast target.

```ruby
class Message < ApplicationRecord
  # Calls send(:receiver), then broadcasts: UserChannel.broadcast_to(receiver, ...)
  syncs_to_dexie via: UserChannel, to: :receiver

  # String used directly: UserChannel.broadcast_to("global_feed", ...)
  syncs_to_dexie via: UserChannel, to: "global_feed"

  # Procs are also supported. If an array is returned, multiple broadcasts are made
  # conversation.users.each { |u| UserChannel.broadcast_to(u, ...) }
  syncs_to_dexie via: UserChannel, to: -> { conversation.users }
end
```

Internally, `syncs_to_dexie` sets up the following ActiveRecord callbacks:

| Event | Action |
|---|---|
| `after_commit on: :create` | `channel.table(table).add(record.as_json_for_dexie)` |
| `after_commit on: :update` | `channel.table(table).put(record.as_json_for_dexie)` |
| `after_commit on: :destroy` | `channel.table(table).delete(record.id)` |

#### Options

| Option | Default | Description |
|---|---|---|
| `via:` | *(required)* | A DexieCable channel class |
| `to:` | *(none)* | The stream target passed to `broadcast_to`. Symbol → calls `send`. String → used as-is. Proc → evaluated in record context. Returns a single recipient or collection. |
| `table:` | model's `table_name` | Override the Dexie table name. A Proc is evaluated in the record's context. |
| `only:` | `[:create, :update, :destroy]` | Limit which events trigger a sync |
| `if:` | *(none)* | Symbol (method name) or Proc — only sync when it returns truthy |
| `unless:` | *(none)* | Symbol (method name) or Proc — skip sync when it returns truthy |

You can combine multiple `syncs_to_dexie` declarations, each with different conditions:

```ruby
class Message < ApplicationRecord
  syncs_to_dexie via: UserChannel, to: -> { sender },
                 if: :published?

  syncs_to_dexie via: AdminChannel,
                 unless: -> { draft? }
end
```

#### Customizing the synced payload

Override `as_json_for_dexie` in your model:

```ruby
class Message < ApplicationRecord
  syncs_to_dexie via: UserChannel, to: :sender

  def as_json_for_dexie
    super.merge(room_name: room.name)
  end
end
```

## How it works

```mermaid
sequenceDiagram
    participant Model as ActiveRecord Model
    participant Channel as DexieCable Channel
    participant WS as ActionCable WebSocket
    participant JS as dexiecable.js
    participant DB as Dexie.js (IndexedDB)

    Model->>Channel: after_commit
    Channel->>Channel: build Query DSL
    Channel->>WS: broadcast JSON { table, ops }
    WS->>JS: received(data)
    JS->>DB: replay ops chain
    DB-->>JS: result
```

The Ruby side builds a JSON payload like:

```json
{
  "table": "messages",
  "ops": [
    { "method": "where", "params": ["room_id"] },
    { "method": "equals", "params": [5] },
    { "method": "add", "params": [{ "id": 1, "text": "hello" }] }
  ]
}
```

The JS side replays it as:

```js
dexie.messages.where("room_id").equals(5).add({ id: 1, text: "hello" })
```

## Syncing missed records on reconnection

A common pattern to avoid data loss during transient disconnections is using sequence IDs to bridge the offline gap. When a connection drops, updates continue on the server. Sending the client’s latest known sequence ID upon reconnect allows the backend to query and stream only the records missed while offline.

To enable this, DexieCable ships its own version of the ActionCable client with one key
extension: **channel params can be functions**. When a param value is a
function, it is called and awaited at subscribe time — use this to submit the latest known sequence ID on connection:

```js
import { createConsumer } from "dexiecable";
import { getLastMessageId } from './database';

const consumer = createConsumer();

consumer.subscriptions.create(
  {
    channel: "ChatChannel",
    room_id: 123,
    seq_id: getLastMessageId // evaluated fresh on each reconnect
  }
);
```

Send missed messages on reconnection:

```ruby
class ChatChannel < ApplicationChannel:Base
  def subscribed
    stream_from "chat:#{params[:room_id]}"
    missed_messages = room.messages.where("seq_id > ?", params[:seq_id])
    table("messages").bulkAdd(missed_messages)
  end
end
```

## License

MIT
