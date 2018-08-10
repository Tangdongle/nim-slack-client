# slack
# Copyright Ryanc_signiq
# Wrapper for Slack
import slack/shared
import asyncnet, asyncdispatch
import websocket

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
        if data.len > 0:
            let message = newSlackMessage("message", 
            var t = sendMessage(connection, message)

asyncCheck serve()
asyncCheck ping(connection.sock)
runForever()

