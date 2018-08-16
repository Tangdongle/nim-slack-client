import src/slackapi/shared
import unittest, httpclient, json, strutils, websocket, asyncnet, asyncdispatch, uri, os
import net

suite "Websocket Connection":

    setup:
        let
            config = joinPath(getConfigDir(), "nim-slackapi")
            token = parseFile(joinPath(config, "token.cfg"))["token"].getStr
            connect_url = "https://slack.com/api/rtm.connect"
            client = newHttpClient()
            port = Port(443)
            endpoint = "message"

        var
            data = newMultipartData()

        data["token"] = token
        sleep(600)

    test "Websocket URL can be retreved":
        let response = client.postContent(connect_url, multipart=data)

        let ws_url = parseJson(response)["url"].getStr

        check(startsWith(ws_url, "wss://cerberus-xxxx"))

    test "Can connect to websocket":
        let ws_url = parseJson(client.postContent(connect_url, multipart=data))["url"].getStr
        var components = ws_url.rsplit('/', 2)
        let uri = parseUri("$#:443/$#/$#" % components)

        let ws = waitFor newAsyncWebsocketClient(uri)

        proc serve() {.async.} =
            while true:
                let (opcode, data) = await ws.readData()
                check data.contains("hello")
                return

        waitFor serve()

    test "Can Load connection into model":
        var connection = newRTMConnection(token, port)

        check(connection.token == token)
        check(not isNil(connection.ws_url))

    test "Can get websocket connection":
        var connection = newRTMConnection(token, port)

        let (validatedConnection, user) = connection.initRTMConnection()

        connection = initWebsocketConnection(validatedConnection)

        check(isSsl(connection.sock.sock))
        check(connection.sock.kind == SocketKind.Client)

    test "Can send to websocket to self":

        var connection = newRTMConnection(token, port)

        let (validatedConnection, user) = connection.initRTMConnection()

        connection = initWebsocketConnection(validatedConnection)


        proc ping() {.async.} =
            while true:
                await sleepAsync(6000)
                echo "ping"
                await connection.sock.sendPing()
                return

        proc serve() {.async.} =
            var first_run = true
            let 
                messageType = "message"
                messageText = "Howdy"
                message = newSlackMessage(messageType, "G64HV5E0Y", messageText)

            while true:
                let (opcode, data) = await connection.sock.readData()
                echo data
                if data.len > 0:
                    if first_run:
                        #Send this text to our test slack channel
                        var t = sendMessage(connection, message)

                        first_run = false
                        await sleepAsync(700)
                    else:
                        check data.contains "Howdy"
                        return

        waitFor serve()
        waitFor ping()
