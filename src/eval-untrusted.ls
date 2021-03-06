'use strict'

require! 'prelude-ls': { map, join, each }
require! 'uuid/v4': uuid-v4
require! 'worker!./worker.ls': EvalWorker
require! 'raw!gloria-utils': gloria-utils

function get-origin url
  (new URL url).origin

export function inflated-request-headers details
  if window.session-storage["request.id.#{details.request-id}"]
    cookie-index = false
    origin-index = false
    referer-index = false

    for i, header of details.request-headers
      switch header.name.to-lower-case!
      | 'cookie'  => cookie-index = i
      | 'origin'  => origin-index = i
      | 'referer' => referer-index = i

    data = JSON.parse window.session-storage["request.id.#{details.request-id}"]
    details.request-headers.push name: 'Cookie', value: data.cookie ? '' unless cookie-index
    details.request-headers.push name: 'Referer', value: data.referer ? details.url unless referer-index
    if origin-index
      if details.request-headers[origin-index].value is 'null'
        details.request-headers[origin-index].value = data.origin ? get-origin details.url
    else
      details.request-headers.push name: 'Origin', value: data.origin ? get-origin details.url unless origin-index

  else if window.session-storage["request.inflate.#{details.url}"]
    try
      window.session-storage["request.id.#{details.request-id}"] = window.session-storage["request.inflate.#{details.url}"]
    catch e
      if e.name is 'QuotaExceededError'
        each ((key) ->
          if key isnt "request.id.#{details.request-id}" and key isnt "request.inflate.#{details.url}"
            window.session-storage.remove-item key
        ), Object.keys window.session-storage
        window.session-storage["request.id.#{details.request-id}"] = window.session-storage["request.inflate.#{details.url}"]
      else
        console.error e

    is-send-by-gloria = false
    cookie-index = false
    origin-index = false
    referer-index = false

    for i, header of details.request-headers
      switch header.name.to-lower-case!
      | 'send-by' => is-send-by-gloria = true if header.value is 'Gloria'
      | 'cookie'  => cookie-index = i
      | 'origin'  => origin-index = i
      | 'referer' => referer-index = i

    if is-send-by-gloria
      data = JSON.parse window.session-storage["request.inflate.#{details.url}"]
      details.request-headers.push name: 'Cookie', value: data.cookie ? '' unless cookie-index
      details.request-headers.push name: 'Referer', value: data.referer ? details.url unless referer-index
      if origin-index
        if details.request-headers[origin-index].value is 'null'
          details.request-headers[origin-index].value = data.origin ? get-origin details.url
      else
        details.request-headers.push name: 'Origin', value: data.origin ? get-origin details.url unless origin-index

  request-headers: details.request-headers

export function bind-call-remote worker
  (function-name, ...function-arguments) ->
    new Promise (resolve, reject) !->
      message =
        id: uuid-v4!
        type: 'call'
        function-name: function-name
        function-arguments: function-arguments

      listener = ({ data: { id, type, function-result, error }}) ->
        if id is message.id
          switch type
          | 'return' => resolve function-result
          | 'error' => reject error
          worker.remove-event-listener 'message', listener

      worker.add-event-listener 'message', listener
      worker.post-message message

export function eval-untrusted code
  callable =
    get-cookies: (url) ->
      new Promise (resolve, reject) !->
        cookies <-! chrome.cookies.get-all { url }
        if chrome.runtime.last-error
          console.error chrome.runtime.last-error
        resolve join '; ' map (cookie) -> "#{cookie.name}=#{cookie.value}", cookies || []

    set-session-storage: (name, data) ->
      try
        window.session-storage[name] = JSON.stringify data
      catch e
        if e.name is 'QuotaExceededError'
          window.session-storage.clear!
          window.session-storage[name] = JSON.stringify data
        else
          console.error e

      Promise.resolve window.session-storage[name]

    import-scripts: (url) ->
      if url is 'gloria-utils'
        Promise.resolve gloria-utils
      else
        name = "import-scripts.cache.#{url}"
        cache = window.session-storage[name]

        if cache
          Promise.resolve cache
        else
          new Promise (resolve, reject) !->
            fetch url
            .then (res) ->
              if 200 <= res.status < 300
                res
              else
                throw new Error res.status-text
            .then (.text!)
            .then (x) ->
              try
                window.session-storage[name] = x
              catch e
                if e.name is 'QuotaExceededError'
                  window.session-storage.clear!
                  window.session-storage[name] = x
                else
                  console.error e
              x
            .then resolve
            .catch ({ message, stack }) ->
              reject error: { message, stack }

  eval-worker = new EvalWorker!
  call-remote = bind-call-remote eval-worker

  eval-worker.add-event-listener 'message', ({ data: { id, type, function-name, function-arguments } }) ->
    if type is 'call'
      callable[function-name](...function-arguments)
      .then (result) ->
        eval-worker.post-message id: id, type: 'return', function-result: result
      .catch (error) ->
        eval-worker.post-message id: id, type: 'error', error: error

  eval-worker.add-event-listener 'error', (error) ->
    console.error error

  call-remote 'eval', code
