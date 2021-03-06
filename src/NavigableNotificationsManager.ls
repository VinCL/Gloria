require! 'prelude-ls': { fold, first, map, filter }
require! 'parse-favicon': parse-favicon
require! 'enhanced-notification': { BasicNotification, ImageNotification }

const DEFAULT_ICON_URL = 'assets/images/icon-128.png'

class NavigableNotificationsManager
  add: (options) ->
    notification = do ->
      options.default-icon-url = DEFAULT_ICON_URL

      if options.url and options.icon-url is DEFAULT_ICON_URL and not options.detect-icon
        options.detect-icon = true

      if options.type === 'basic'
        new BasicNotification options
      else if options.type === 'image'
        notification = new ImageNotification options
        notification.experimental = true
        notification
      else
        null

    if notification
      notification.create!

module.exports = NavigableNotificationsManager
