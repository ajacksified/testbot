# Description:
#   None
#
# Dependencies:
#   "accounting": "0.3.2"
#   "xml2json": "0.3.2"
#
# Configuration:
#   None
#
# Commands:
#   hubot marketstat <item> [in <region>] - item market information
#
# Author:
#   ajacksified

parser = require('xml2json')
accounting = require('accounting')

itemIDCache = {}

module.exports = (robot) ->
  robot.respond /kb/i, (msg) ->
    loadKBData(msg, (kill) ->
      recent = kill.row[0]

      killers = []

      for i in [0..Math.min(5, recent.rowset.row.length)]
        if recent.rowset.row[i].finalBlow == "1"
          killer = "*" + recent.rowset.row[i].characterName
        else
          killer = recent.rowset.row[i].characterName

        killers.push(killer)

      loadItemData(msg, recent.victim.shipTypeID, (item) ->
        msg.send("#{recent.victim.characterName} [#{recent.victim.corporationName}] #{if recent.victim.allianceName then "<" + recent.victim.allianceName + ">"} was killed in a #{item.typeName} by #{killers.join(", ")} and others at #{recent.killTime}. https://kb.pleaseignore.com/?a=kill_detail&kll_id=#{recent.killInternalID}")
      )
    )

loadKBData = (msg, cb) ->
  msg.http('https://kb.pleaseignore.com/')
    .query(a: "idfeed")
    .get() (err, res, body) ->
      try
        cb(parser.toJson(body, { object: true }).eveapi.result.rowset)
      catch e
        cb()

loadItemData = (msg, itemQuery, cb) ->
  return cb(itemIDCache[itemQuery]) if itemIDCache[itemQuery]

  msg.http('http://util.eveuniversity.org/xml/itemLookup.php')
    .query(id: itemQuery)
    .get() (err, res, body) ->
      try
        itemData = parser.toJson(body, { object: true }).itemLookup
        itemIDCache[itemQuery] = itemData
        cb(itemData)
      catch e
        cb()
