## 0.6.7 (2017/05/23)

Enhancements:

* Allow channel @username (DM)

## 0.6.6 (2017/05/23)

Enhancements:

* Make channel config optional on webhook because webhook has its defaul channel setting (thanks to @hirakiuc)

## 0.6.5 (2017/05/20)

Enhancements:

* Avoid Encoding::UndefinedConversionError from ASCII-8BIT to UTF-8 on to_json by doing String#scrub! (thanks @yoheimuta)

## 0.6.4 (2016/07/07)

Enhancements:

* Add `as_user` option (thanks @yacchin1205)

## 0.6.3 (2016/05/11)

Enhancements:

* Add `verbose_fallback` option to show fallback (popup) verbosely (thanks @eisuke)

## 0.6.2 (2015/12/17)

Fixes:

* escape special characters in message (thanks @fujiwara)

## 0.6.1 (2015/05/17)

Fixes:

* Support ruby 1.9.3

## 0.6.0 (2015/04/02)

This version has impcompatibility with previous versions in default option values

Enhancements:

* Support `link_names` and `parse` option. `link_names` option is `true` as default

Changes:

* the default payload of Incoming Webhook was changed
* `color` is `nil` as default
* `icon_emoji` is `nil` as default
* `username` is `nil` as default
* `mrkdwn` is `true` as default

## 0.5.5 (2015/04/01)

Enhancements:

* Support Slackbot Remote Control API

## 0.5.4 (2015/03/31)

Enhancements:

* Support `mrkdwn` option

## 0.5.3 (2015/03/29)

Enhancements:

* Support `https_proxy` option

## 0.5.2 (2015/03/29)

Enhancements:

* Support `icon_url` option (thanks to @jwyjoy)

## 0.5.1 (2015/03/27)

Enhancements:

* Support `auto_channels_create` option to automatically create channels.

## 0.5.0 (2015/03/22)

Enhancements:

* Support `message` and `message_keys` options
* Support `title` and `title_keys` options
* Support `channel_keys` options to dynamically change channels
