module.exports = (robot) ->
  robot.respond /slap (.*)/i, (msg) ->
    msg.send "*#{msg.message.user.name} slaps #{msg.match[1].trim()} around a bit with a large trout.*"

