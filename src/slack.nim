# slack
# Copyright Ryanc_signiq
# Wrapper for Slack
import slack/shared
import asyncnet, asyncdispatch
import websocket
import json

let 
    token = getTokenFromConfig()
    port = Port 443

var connection = newRTMConnection(token, port)

let (validatedConnection, user) = connection.initRTMConnection()

connection = initWebsocketConnection(validatedConnection)

proc serve() {.async.} =
    while true:
        let (opcode, data) = await connection.sock.readData()
        echo data
        if data.len > 0 and isTextOpcode(opcode):
            let parsedData = parseJson(data)
            if parsedData.hasKey("reply_to"):
                continue
            elif parsedData["type"].getStr == $SlackRTMType.Message:
                if parsedData["user"].getStr != user.id:
                    let message = newSlackMessage("message", parsedData["channel"].getStr, parsedData["text"].getStr)
                    discard sendMessage(connection, message)

proc ping*() {.async.} =
    while true:
        await sleepAsync(6000)
        echo "ping"
        await connection.sock.sendPing(masked = true)


asyncCheck serve()
asyncCheck ping()
runForever()

