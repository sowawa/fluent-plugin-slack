# fluent-plugin-slack [![Build Status](https://travis-ci.org/sowawa/fluent-plugin-slack.svg)](https://travis-ci.org/sowawa/fluent-plugin-slack)

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
|slackbot_url|Slackbot URI (Required for Slackbot mode). See https://api.slack.com/slackbot. NOTE: most of optional parameters such as `username`, `color`, `icon_emoji`, `icon_url`, and `title` are not available for this mode, but Desktop Notification via Highlight Words works with only this mode||
|token|Token for Web API (Required for Web API mode). See https://api.slack.com/web||
|username|name of bot|nil|
|color|color to use such as `good` or `bad`. See `Color` section of https://api.slack.com/docs/attachments. NOTE: This parameter must **not** be specified to receive Desktop Notification via Mentions in cases of Incoming Webhook and Slack Web API|nil|
|icon_emoji|emoji to use as the icon. either of `icon_emoji` or `icon_url` can be specified|nil|
|icon_url|url to an image to use as the icon. either of `icon_emoji` or `icon_url` can be specified|nil|
|mrkdwn|enable formatting. see https://api.slack.com/docs/formatting|true|
|link_names|find and link channel names and usernames. NOTE: This parameter must be `true` to receive Desktop Notification via Mentions in cases of Incoming Webhook and Slack Web API|true|
|parse|change how messages are treated. `none` or `full` can be specified. See `Parsing mode` section of https://api.slack.com/docs/formatting|nil|
|channel|channel to send messages (without first '#')||
|channel_keys|keys used to format channel. %s will be replaced with value specified by channel_keys if this option is used|nil|
|title|title format. %s will be replaced with value specified by title_keys. title is created from the first appeared record on each tag. NOTE: This parameter must **not** be specified to receive Desktop Notification via Mentions in cases of Incoming Webhook and Slack Web API|nil|
|title_keys|keys used to format the title|nil|
|message|message format. %s will be replaced with value specified by message_keys|%s|
|message_keys|keys used to format messages|message|
|auto_channels_create|Create channels if not exist. Not available for Incoming Webhook mode (since Incoming Webhook is specific to a channel). A web api `token` for Normal User is required (Bot User can not create channels. See https://api.slack.com/bot-users)|false|
|https_proxy|https proxy url such as `https://proxy.foo.bar:443`|nil|

`fluent-plugin-slack` uses `SetTimeKeyMixin` and `SetTagKeyMixin`, so you can also use:

|parameter|description|default|
|---|---|---|
|localtime|use localtime as timezone|true|
|utc|use utc as timezone||
|time_key|key name for time used in xxx_keys|time|
|time_format|time format. This will be formatted with Time#strftime.|%H:%M:%S|
|tag_key|key name for tag used in xxx_keys|tag|

`fluent-plugin-slack` is a kind of BufferedOutput plugin, so you can also use [Buffer Parameters](http://docs.fluentd.org/articles/out_exec#buffer-parameters).

## FAQ

### Desktop Notification seems not working?

Currently, slack.com has following limitations:

1. Desktop Notification via both Highlight Words and Mentions works only with Slackbot Remote Control
2. Desktop Notification via Mentions works for the `text` field if `link_names` parameter is specified in cases of Incoming Webhook and Slack Web API, that is,
  * Desktop Notification does not work for the `attachments` filed (used in `color` and `title`)
  * Desktop Notification via Highlight Words does not work for Incoming Webhook and Slack Web API anyway

## ChangeLog

See [CHANGELOG.md](CHANGELOG.md) for details.

# Contributors

- [@sonots](https://github.com/sonots)
- [@kenjiskywalker](https://github.com/kenjiskywalker)

# Copyright

* Copyright:: Copyright (c) 2014- Keisuke SOGAWA
* License::   Apache License, Version 2.0

