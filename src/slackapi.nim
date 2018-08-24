##Example
##=======
##.. code-block::nim
##  import slackapi/shared
##  import asyncnet, asyncdispatch
##  import websocket
##  import json
##  
##  let 
##    token = getTokenFromConfig()
##    port = Port 443
##  
##  var (connection, user) = connectToRTM(token, port)
##  
##  proc serve() {.async.} =
##    while true:
##      let (opcode, data) = await connection.sock.readData()
##      echo data
##      if data.len > 0 and isTextOpcode(opcode):
##        let parsedData = parseJson(data)
##        if parsedData.hasKey("reply_to"):
##          #Reply to a directed message here
##          continue
##        elif parsedData["type"].getStr == $SlackRTMType.Message:
##          #Parse normal messages here
##          if parsedData["user"].getStr != user.id:
##            let message = newSlackMessage("message", parsedData["channel"].getStr, parsedData["text"].getStr)
##            discard sendMessage(connection, message)
##  
##  proc ping*() {.async.} =
##    while true:
##      await sleepAsync(6000)
##      echo "ping"
##      await connection.sock.sendPing(masked = true)
##  
##  asyncCheck serve()
##  asyncCheck ping()
##  runForever()

import slackapi/shared
import asyncnet, asyncdispatch
import websocket, tables
import json
import nimobserver

let 
  token = getTokenFromConfig()
  port = Port 443
  globalSlackSubject = initSubject[SlackMessagePtr]()

var 
  (rtmConnection, slackUser) = connectToRTM(token, port)
  slackUserTable = waitFor buildUserTable(rtmConnection)

proc serveRTM() {.async.} =
  while true:
    let (opcode, data) = await rtmConnection.sock.readData()
    if data.len > 0 and isTextOpcode(opcode):
      let parsedData = parseJson(data)
      if parsedData.hasKey("reply_to"):
        #Reply to a directed message here
        continue
      elif parsedData["type"].getStr == $SlackRTMType.Message:
        #Parse normal messages here
        if parsedData["user"].getStr != slackUser.id:
          var message = newSlackMessage("message", parsedData["channel"].getStr, parsedData["text"].getStr, parsedData["user"].getStr)
          globalSlackSubject.publish(addr message)

proc ping*() {.async.} =
  while true:
    await sleepAsync(6000)
    echo "ping"
    await rtmConnection.sock.sendPing(masked = true)

asyncCheck serveRTM()
asyncCheck ping()
runForever()

export shared, websocket, json, tables
export slackUser, slackUserTable, ping, rtmConnection
