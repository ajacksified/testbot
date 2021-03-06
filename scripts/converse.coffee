# Allows Hubot to talk back. Passive script.
cleverbot = require('cleverbot-node')
timeSinceLastRandomMessage = null

class Messages
  constructor: (@robot) ->
    @cache = []
    @robot.brain.on 'loaded', =>
      if @robot.brain.data.messages
        @cache = @robot.brain.data.messages

  nextMessageNum: ->
    maxMessageNum = if @cache.length then Math.max.apply(Math,@cache.map (n) -> n.num) else 0
    maxMessageNum++
    maxMessageNum

  add: (messageText) ->
    message = {num: @nextMessageNum(), message: messageText}

    if(@cache.length) > 1000
      @cache = @cache.slice(@cache.length - 1000, @cache.length)

    @cache.push message
    @robot.brain.data.messages = @cache
    messageText

  all: -> @cache

  random: -> @cache[(Math.random() * (@cache.length - 1)) >> 0]

  buildRandomMessage: ->
    amountOfMessages = ((Math.random() * 4) >> 0) + 2

    message = while amountOfMessages -= 1
      messageParts = @random().message.split(" ")
      startingPoint = (Math.random() * messageParts.length) >> 0
      messageParts[startingPoint...messageParts.length].join(" ")

    message.join(" ").replace(/((\.|\!|\?)*)(?!$)/,'')

  retrieveLast: (amount) ->
    if amount > 15 then amount = 15

    @cache[(@cache.length-amount)...(@cache.length)]

  beClever: false
  timeSinceLastCleverness: Date.now()

module.exports = (robot) ->
  messages = new Messages(robot)
  c = new cleverbot()
  initiateTimeout = null

  # History command
  robot.respond /history (.*)/i, (msg) ->
    amount = msg.match[1].trim()

    message = for i, obj of messages.retrieveLast(amount) 
      "#{i}. #{obj.message}"

    msg.send(message.join("\r\n"))

  # History command
  robot.respond /be clever/i, (msg) ->
    messages.beClever = !messages.beClever
    msg.send "Cleverness: #{messages.beClever}"

  # General conversation
  robot.hear /(.*)/i, (msg) ->
    incoming = msg.match[1].trim()
    chance = 1000

    if(incoming.toLowerCase().indexOf(robot.name.toLowerCase()) > 0)
      chance = 10

    if(incoming.toLowerCase() == "markov")
      chance = 10

    messages.add msg.match[1]

    if (timeSinceLastRandomMessage == null or Date.now() - timeSinceLastRandomMessage > 1000 * 60 * 20)
      if messages.nextMessageNum() > 100
        if ((Math.random() * chance) >> 0) == 0
          timeSinceLastRandomMessage = Date.now()
          msg.send messages.buildRandomMessage()

    if incoming.toLowerCase() == "rebooting exobot"
      msg.send "OHGOD NO PLEASE NO"

    if initiateTimeout?
      clearTimeout(initiateTimeout)

    initiateTimeout = setTimeout((() -> msg.send(messages.buildRandomMessage())), (1000 * 60 * 60)) # if it's quiet, start talking once an hour

  robot.respond /(.*)/i, (msg) ->
    incoming = msg.match[1].trim()
    if messages.beClever && (Date.now() - messages.timeSinceLastCleverness > 5000)
      data = msg.match[1].trim()
      c.write(data, (c) => 
        msg.send(c.message)
        messages.timeSinceLastCleverness = Date.now()
      )

  robot.hear /^wat(\.?)$/i, (msg) ->
    chance = 10
    if ((Math.random() * chance) >> 0) == 0
      msg.send "http://i.imgur.com/UBhAX.png"

