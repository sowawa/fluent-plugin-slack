# Fluent event to slack plugin.

# Installation

```
$ fluent-gem install fluent-plugin-slack
```

# Usage (Incoming Webhook)

```apache
<match slack>
  type slack
  webhook_url https://hooks.slack.com/services/XXX/XXX/XXX
  channel general
  username sowasowa
  color good
  icon_emoji :ghost:
  flush_interval 60s
</match>
```

```ruby
fluent_logger.post('slack', {
  :message  => 'Hello<br>World!'
})
```

# Usage (Slack API)

```apache
<match slack>
  type slack
  token xoxb-XXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXX
  channel general
  username sowasowa
  color good
  icon_emoji :ghost:
  flush_interval 60s
</match>
```

```ruby
fluent_logger.post('slack', {
  :message  => 'Hello<br>World!'
})
```

### Parameter

|parameter|description|default|
|---|---|---|
|webhook_uri|Incoming Webhook URI (Required for Incoming Webhook mode)||
|token|Token for Slack API (Required for Slack API mode)||
|username|name of bot|fluentd|
|color|color to use|good|
|icon_emoji|emoji to use as the icon|`:question:`|
|channel|channel to send messages (without first '#')||
|channel_keys|keys used to format channel. %s will be replaced with value specified by channel_keys if this option is used|nil|
|title|title format. %s will be replaced with value specified by title_keys. title is created from the first appeared record on each tag|nil|
|title_keys|keys used to format the title|nil|
|message|message format. %s will be replaced with value specified by message_keys|%s|
|message_keys|keys used to format messages|message|

`fluent-plugin-slack` uses `SetTimeKeyMixin` and `SetTagKeyMixin`, so you can also use:

|parameter|description|default|
|---|---|---|
|timezone|timezone such as `Asia/Tokyo`||
|localtime|use localtime as timezone|true|
|utc|use utc as timezone||
|time_key|key name for time used in xxx_keys|time|
|time_format|time format. This will be formatted with Time#strftime.|%H:%M:%S|
|tag_key|key name for tag used in xxx_keys|tag|

`fluent-plugin-slack` is a kind of BufferedOutput plugin, so you can also use [Buffer Parameters](http://docs.fluentd.org/articles/out_exec#buffer-parameters).

# Copyright

* Copyright:: Copyright (c) 2014- Keisuke SOGAWA
* License::   Apache License, Version 2.0

