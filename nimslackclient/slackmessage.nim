import nre
import json
import lists
from slacktypes import SlackChannel, SlackServer, SlackUser, SlackMessage
from httpclient import Response
from slackchannel import findChannelById
from slackuser import findUserById

proc buildSlackMessage*(server: SlackServer, data: JsonNode, response: Response = Response()): SlackMessage = 
  new result
  let MESSAGETEXT = re"^<@\w*?> (.*)"

  var isMessage = false
  var acceptedType = "message"

  #
  if data.hasKey("ok"):
    result.ok = data["ok"].getBVal()
  else:
    #Set to false so we don't process messages without verification
    result.ok = false

  result.msgtype = data["type"].getStr("")
  if result.msgtype == acceptedType:
    isMessage = true
    echo "Is message type!"

  if data.hasKey("text"):
    if data["text"].str.contains(MESSAGETEXT):
      result.text = data["text"].str.match(MESSAGETEXT).get.captures[0]

  if data.hasKey("ts"):
    result.timeStamp = data["ts"].str
    
  var hasMatch = false
  if data.hasKey("user"):
    var user = findUserById(user_id=data["user"].getStr(), server=server)
    if not isNil(user):
      result.user = user

  if data.hasKey("channel"):
    var channel = findChannelById(channel_id=data["channel"].getStr(), server=server)
    if not isNil(channel):
      result.channel = channel

  result.response = response

