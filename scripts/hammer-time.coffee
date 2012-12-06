# A way to interact with the Google Images API.
#
# hammer time - hammer time.

module.exports = (robot) ->
  robot.respond /hammer ?time/i, (msg) ->
    imageMe msg, (url) ->
      msg.send url

imageMe = (msg, cb) ->
  msg.http('http://ajax.googleapis.com/ajax/services/search/images')
    .query(v: "1.0", rsz: '8', q: "mc hammer time")
    .get() (err, res, body) ->
      images = JSON.parse(body)
      images = images.responseData.results
      if images.length > 0
        image  = msg.random images
        cb "#{image.unescapedUrl}#.png"
