# Description:
#   Give or take away points. Keeps track and even prints out graphs.
#
# Dependencies:
#   "underscore": ">= 1.0.0"
#   "clark": "0.0.6"
#
# Configuration:
#
# Commands:
#   <name>++
#   <name>--
#   hubot score <name>
#   hubot top <amount>
#   hubot bottom <amount>
#   GET http://<url>/hubot/scores[?name=<name>][&direction=<top|botton>][&limit=<10>]
#
# Author:
#   ajacksified


_ = require("underscore")
clark = require("clark")
querystring = require('querystring')

class ScoreKeeper
  constructor: (@robot) ->
    @robot.brain.data.scores ||= {}
    @robot.brain.data.scoreLog ||= {}
    @robot.brain.data.scoreReasons || = {}
    @robot.brain.data.mostRecentlyUpdated ||= {}

    @cache =
      scores: @robot.brain.data.scores
      scoreLog: @robot.brain.data.scoreLog
      scoreReasons: @robot.brain.data.scoreReasons
      mostRecentlyUpdated: @robot.brain.data.mostRecentlyUpdated

    @robot.brain.on 'connected', =>
      @robot.brain.data.scores ||= {}
      @robot.brain.data.scoreLog ||= {}
      @robot.brain.data.scoreReasons ||= {}

      @cache.scores = @robot.brain.data.scores || {}
      @cache.scoreLog = @robot.brain.data.scoreLog || {}
      @cache.scoreReasons = @robot.brain.data.scoreReasons || {}
      @cache.mostRecentlyUpdated = @robot.brain.data.mostRecentlyUpdated || {}

      if typeof @robot.brain.data.mostRecentlyUpdated == "string"
        @robot.brain.data.mostRecentlyUpdated = {}
        @cache.mostRecentlyUpdated = @robot.brain.data.mostRecentlyUpdated


  getUser: (user) ->
    @cache.scores[user] ||= 0
    user

  saveUser: (user, from, room, reason) ->
    @saveScoreLog(user, from, room, reason)
    @robot.brain.data.scores[user] = @cache.scores[user]
    @robot.brain.data.scoreLog[user] = @cache.scoreLog[user]
    @robot.brain.data.scoreReasons[user] = @cache.scoreReasons[user]
    @robot.brain.emit('save', @robot.brain.data)
    @robot.brain.data.mostRecentlyUpdated[room] = @cache.mostRecentlyUpdated[room]

    [@cache.scores[user], @cache.scoreReasons[user][reason] || ""]

  add: (user, from, room, reason) ->
    if @validate(user, from)
      user = @getUser(user)
      @cache.scores[user]++
      @cache.scoreReasons[user] ||= {}

      if reason
        @cache.scoreReasons[user][reason] ||= 0
        @cache.scoreReasons[user][reason]++

      @saveUser(user, from, room, reason)
    else
      [null, null]

  subtract: (user, from, room, reason) ->
    if @validate(user, from)
      user = @getUser(user)
      @cache.scores[user]--
      @cache.scoreReasons[user] ||= {}

      if reason
        @cache.scoreReasons[user][reason] ||= 0
        @cache.scoreReasons[user][reason]--

      @saveUser(user, from, room, reason)
    else
      [null, null]

  scoreForUser: (user) ->
    user = @getUser(user)
    @cache.scores[user]

  reasonsForUser: (user) ->
    user = @getUser(user)
    @cache.scoreReasons[user]

  saveScoreLog: (user, from, room, reason) ->
    unless typeof @cache.scoreLog[from] == "object"
      @cache.scoreLog[from] = {}

    @cache.scoreLog[from][user] = new Date()
    @cache.mostRecentlyUpdated[room] = {user: user, reason: reason}

  mostRecentlyUpdated: (room) ->
    recent = @cache.mostRecentlyUpdated[room]
    if typeof recent == 'string'
      [recent, '']
    else
      [recent.user, recent.reason]

  isSpam: (user, from) ->
    # leaving this forever to display Horace's shame in cheating the system
    #return false

    @cache.scoreLog[from] ||= {}

    if !@cache.scoreLog[from][user]
      return false

    dateSubmitted = @cache.scoreLog[from][user]

    date = new Date(dateSubmitted)
    messageIsSpam = date.setSeconds(date.getSeconds() + 30) > new Date()

    if !messageIsSpam
      delete @cache.scoreLog[from][user] #clean it up

    messageIsSpam

  validate: (user, from) ->
    user != from && user != "" && !@isSpam(user, from)

  length: () ->
    @cache.scoreLog.length

  top: (amount) ->
    tops = []

    for name, score of @cache.scores
      tops.push(name: name, score: score)

    tops.sort((a,b) -> b.score - a.score).slice(0,amount)

  bottom: (amount) ->
    all = @top(@cache.scores.length)
    all.sort((a,b) -> b.score - a.score).reverse().slice(0,amount)

  normalize: (fn) ->
    scores = {}

    _.each(@cache.scores, (score, name) ->
      scores[name] = fn(score)
      delete scores[name] if scores[name] == 0
    )

    @cache.scores = scores
    @robot.brain.data.scores = scores
    @robot.brain.emit 'save'

module.exports = (robot) ->
  scoreKeeper = new ScoreKeeper(robot)

  # sweet regex bro
  robot.hear /^([\w\S'.\s]+)?(?:[\W\s]*)?(\+\+|\-\-)(?: (?:for|because|cause|cuz) (.+))?$/i, (msg) ->
    # let's get our local vars in place
    [__, name, operator, reason] = msg.match
    from = msg.message.user.name.toLowerCase()
    room = msg.message.room

    # do some sanitizing
    reason = reason?.trim().toLowerCase()
    name = name?.trim().toLowerCase()

    # check whether a name was specified. use MRU if not
    unless name?
      [name, lastReason] = scoreKeeper.mostRecentlyUpdated(room)
      reason = lastReason if !reason? && lastReason?

    # do the {up, down}vote, and figure out what the new score is
    [score, reasonScore] = if operator == "++"
              scoreKeeper.add(name, from, room, reason)
            else
              scoreKeeper.subtract(name, from, room, reason)

    # if we got a score, then display all the things and fire off events!
    if score?
      message = if reason?
                  "#{name} has #{score} points, #{reasonScore} of which are for #{reason}."
                else
                  "#{name} has #{score} points"

      msg.send message

      robot.emit "plus-one", {
        name: name
        direction: operator
        room: room
        reason: reason
      }

  robot.respond /score (?:for )?((?:[\w\s'".,-][^\|])+)(?: [\|] grep (.+))?/i, (msg) ->
    name = msg.match[1].trim().toLowerCase()
    grepString = msg.match[2]?.trim().toLowerCase()
    grep = new RegExp(grepString) if grepString

    score = scoreKeeper.scoreForUser(name)
    reasons = scoreKeeper.reasonsForUser(name)

    reduceReasons = (memo, val, key) ->
      if !grep || grep.test(key)
        memo += "\n#{key}: #{val} points"
      memo

    reasonBlock = _.reduce(reasons, reduceReasons, "")

    reasonString = if typeof reasons == 'object' && Object.keys(reasons).length > 0 && reasonBlock
                     "#{name} has #{score} points. here are some reasons: #{reasonBlock}"
                   else
                     "#{name} has #{score} points."

    msg.send reasonString

  robot.respond /(top|bottom) (\d+)/i, (msg) ->
    amount = parseInt(msg.match[2])
    message = []

    tops = scoreKeeper[msg.match[1]](amount)

    for i in [0..tops.length-1]
      message.push("#{i+1}. #{tops[i].name} : #{tops[i].score}")

    if(msg.match[1] == "top")
      graphSize = Math.min(tops.length, Math.min(amount, 20))
      message.splice(0, 0, clark(_.first(_.pluck(tops, "score"), graphSize)))

    msg.send message.join("\n")

  robot.router.get "/hubot/normalize-points", (req, res) ->
    scoreKeeper.normalize((score) ->
      if score > 0
        score = score - Math.ceil(score / 10)
      else if score < 0
        score = score - Math.floor(score / 10)

      score
    )

    res.end JSON.stringify('done')

  robot.router.get "/hubot/scores", (req, res) ->
    query = querystring.parse(req._parsedUrl.query)

    if query.name
      obj = {}
      obj[query.name] = scoreKeeper.scoreForUser(query.name)
      res.end JSON.stringify(obj)
    else
      direction = query.direction || "top"
      amount = query.limit || 10

      tops = scoreKeeper[direction](amount)

      res.end JSON.stringify(tops)

