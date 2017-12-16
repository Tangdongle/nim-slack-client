## Sample Websocket URl
## wss://lbmulti-b6u4.lb.slack-msgs.com/websocket/XwNgiYkQkNLNQKf00sMoD-ILTwu2LMp6xWQydsui4fTV9EaYgyE0VlldXTQAUITTjLeOddPslVLEJBGFynnV4gh83i15uG9W5MzLAUN6czg0I5-RN8numlinK53l2xBDwFLSZ6-V9LGr8v-XyL82IgwXeEqXjBL5HfUnGWPVQLg=
## Sample messages:
# {"type":"user_typing","channel":"G64HV5E0Y","user":"U2TM44RN0"})
#read: (opcode: Text, data: {"type":"message","channel":"G64HV5E0Y","user":"U2TM44RN0","text":"<@U64HFLPG9> WOW","ts":"1504772511.000007","source_team":"T03DRH8QZ","team":"T03DRH8QZ"})
#read: (opcode: Text, data: {"type":"desktop_notification","title":"SignIQ","subtitle":"bottystuff","msg":"1504772511.000007","content":"ryanc: @sodabot WOW","channel":"G64HV5E0Y","launchUri":"slack:\/\/channel?id=G64HV5E0Y&message=1504772511000007&team=T03DRH8QZ","avatarImage":"https:\/\/avatars.slack-edge.com\/2017-08-02\/221029099876_496046da12c5ab7c9d86_192.jpg","ssbFilename":"knock_brush.mp3","imageUri":null,"is_shared":false,"event_ts":"1504772511.000132"})
##

import sequtils
import asyncnet, asyncdispatch
import nimslackclient/client, nimslackclient/server
import nimslackclient/slacktypes

#proc own_reader(ws: AsyncWebSocket, server: SlackServer): Future[SlackMessage] {.async.} =
#  var jsonData = parseJson("""{"type": "NoMessage"}""")
#
#  while jsonData["type"].getStr == "NoMessage":
#    let data = await ws.sock.readData(true)
#    #echo "Data" & $data
#    try:
#      jsonData = parseJson(data.data)
#    except JsonParsingError:
#      jsonData = parseJson("""{"type": "NoMessage"}""")
#
#  result = buildSlackMessage(server, jsonData)
#
#proc own_serve(self: SlackServer) {.async.} = 
#  ## The main event loop. Reads data from slack's RTM
#  ## Individual implementations should define their own loop
#  
#  let ws = self.websocket
#
#  while true:
#    var resp = await own_reader(ws, self)
#    try:
#      if isNil(resp.msgtype) == false:
#        echo "Type " & $resp.msgtype
#        if $resp.msgtype == "message":
#          if isNil(resp.text) == false:
#            echo "Message " & $resp.text
#          if isNil(resp.user) == false:
#            echo "User " & $resp.user.name
#          if isNil(resp.channel) == false:
#            echo "Channel" & $resp.channel.name
#    except:
#      echo "No message"
#
#var server = rtmConnect(reconnect=false, use_rtm_start=true)
#asyncCheck own_serve(server)
#asyncCheck ping(server.websocket)
#runForever()

proc server(slackClient: SlackClient) {.async.} =
  while true:
    var message = await slackClient.rtmRead()
    if len(message) > 0:
      for line in message:
        echo line.str
    



var slackClient = newSlackClient("", true, @[])
asyncCheck server(slackClient)
asyncCheck slackClient.server.ping()
runForever()


echo "AFTER LOOP"
