# DexieCable

DexieCable augments your ActionCable channels with superpowers that allow you to run your Dexie (IndexedDB) database updates directly from your Rails backend.

You can run any Dexie table update directly inside a channel:

```ruby
class UserChannel < ApplicationCable::Channel
  include DexieCable

  def subscribed
    stream_for current_user
    recent_notifications = current_user.notifications.last(10)
    table("notifications").add(recent_notifications)
  end
end
```

Or from inside a controller:

```ruby
class NotificationsChannel < ApplicationController
  def create
    current_user.notifications.create(notification_params)
    UserChannel[current_user].table("notifications").add(notification)
  end
end
```

An even more convenient way is to use the `syncs_to_dexie` macro:

```ruby
class Notification < ApplicationRecord
  syncs_to_dexie via: -> { UserChannel[user] }
end
```

## Installation