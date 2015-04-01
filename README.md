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

# Usage (Slackbot)

```apache
<match slack>
  type slack
  slackbot_url https://xxxx.slack.com/services/hooks/slackbot?token=XXXXXXXXX
  channel general
  flush_interval 60s
</match>
```

```ruby
fluent_logger.post('slack', {
  :message  => 'Hello<br>World!'
})
```

# Usage (Web API)

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
|webhook_url|Incoming Webhook URI (Required for Incoming Webhook mode). See https://api.slack.com/incoming-webhooks||
|slackbot_url|Slackbot URI (Required for Slackbot mode). See https://api.slack.com/slackbot. `username`, `color`, `icon_emoji`, `icon_url` are not available for this mode, but Desktop Notification via Highlight Words works with only this mode (Notification via Mentions works from Incoming Webhook and Web API with link_names=1, but Notification via Highlight Words does not)||
|token|Token for Web API (Required for Web API mode). See https://api.slack.com/web||
|username|name of bot|fluentd|
|color|color to use|good|
|icon_emoji|emoji to use as the icon. either of icon_emoji or icon_url can be specified|`:question:`|
|icon_url|url to an image to use as the icon. either of icon_emoji or icon_url can be specified|nil|
|mrkdwn|enable formatting. see https://api.slack.com/docs/formatting|false|
|channel|channel to send messages (without first '#')||
|channel_keys|keys used to format channel. %s will be replaced with value specified by channel_keys if this option is used|nil|
|title|title format. %s will be replaced with value specified by title_keys. title is created from the first appeared record on each tag|nil|
|title_keys|keys used to format the title|nil|
|message|message format. %s will be replaced with value specified by message_keys|%s|
|message_keys|keys used to format messages|message|
|auto_channels_create|Create channels if not exist. Not available for Incoming Webhook mode (since Incoming Webhook is specific to a channel). A web api `token` for Normal User is required (Bot User can not create channels. See https://api.slack.com/bot-users)|false|
|https_proxy|https proxy url such as `https://proxy.foo.bar:443`|nil|

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

## ChangeLog

See [CHANGELOG.md](CHANGELOG.md) for details.

# Contributors

- [@sonots](https://github.com/sonots)
- [@kenjiskywalker](https://github.com/kenjiskywalker)

# Copyright

* Copyright:: Copyright (c) 2014- Keisuke SOGAWA
* License::   Apache License, Version 2.0

