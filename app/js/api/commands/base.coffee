do (Cypress, _) ->

  Cypress.addDualCommand

    ## thens can return more "thenables" which are not resolved
    ## until they're 'really' resolved, so naturally this API
    ## supports nesting promises
    then: (subject, fn) ->
      ## if this is the very last command we know its the 'then'
      ## called by mocha.  in this case, we need to defer its
      ## fn callback else we will not properly finish the run
      ## of our commands, which ends up duplicating multiple commands
      ## downstream.  this is because this fn callback forces mocha
      ## to continue synchronously onto tests (if for instance this
      ## 'then' is called from a hook) - by defering it, we finish
      ## resolving our deferred.
      current = @prop("current")

      if not current.next and current.args.length is 2 and (current.args[1].name is "done" or current.args[1].length is 1)
        return @prop("next", fn)

      ## we need to wrap this in a try-catch still (even though we're
      ## using bluebird) because we want to handle the return by
      ## allow the 'then' to change the subject to the return value
      ## if its a non null/undefined value else to return the subject
      try
        ret = fn.call @prop("runnable").ctx, subject

        ## then will resolve with the fn's
        ## return or just pass along the subject
        return ret ? subject
      catch e
        throw e

    and: (subject, fn) -> @sync.then(fn)

  Cypress.addParentCommand

    options: (options = {}) ->
      ## change things like pauses in between commands
      ## the max timeout per command
      ## or anything else here...

    noop: (obj) -> obj

    url: ->
      href = @sync.location("href", {log: false})

      Cypress.command
        message: href

      return href

    hash: ->
      hash = @sync.location("hash", {log: false})

      Cypress.command
        message: hash

      return hash

    location: (key, options) ->
      ## normalize arguments allowing key + options to be undefined
      ## key can represent the options
      if _.isObject(key) and _.isUndefined(options)
        options = key

      options ?= {}

      _.defaults options,
        log: true

      currentUrl = window.location.toString()
      remoteUrl  = @sync.window().location.toString()
      remoteOrigin = @config("remoteOrigin")

      location = Cypress.location(currentUrl, remoteUrl, remoteOrigin)

      ret = if _.isString(key)
        ## use existential here because we only want to throw
        ## on null or undefined values (and not empty strings)
        location[key] ?
          @throwErr("Location object does have not have key: #{key}")
      else
        location

      if options.log
        Cypress.command
          message: key ? null

      return ret

    title: (options = {}) ->
      ## using call here to invoke the 'text' method on the
      ## title's jquery object

      ## we're chaining off the promise so we need to go through
      ## the command method which returns a promise
      @command("get", "title", options).call("text")

    window: ->
      @throwErr "The remote iframe is undefined!" if not @$remoteIframe
      @$remoteIframe.prop("contentWindow")

    document: ->
      win = @sync.window()
      @throwErr "The remote iframe's document is undefined!" if not win.document
      $(win.document)

    doc: -> @sync.document()