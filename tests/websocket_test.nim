import websocket, asyncnet, asyncdispatch

let ws = waitFor newAsyncWebsocketClient("echo.websocket.org", Port 80, "/?encoding=text", ssl = false)
echo "connected"

proc reader() {.async.} =
    while true:
        let read = await ws.readData()
        echo "read: ", read
        await sleepAsync(900)
        var t = ws.sendText("Test", masked = true)
        t.addCallback(
            proc() =
                echo t.read
        )

proc ping() {.async.} =
    while true:
        await sleepAsync(6000)
        echo "ping"
        await ws.sendPing(masked = true)

asyncCheck reader()
asyncCheck ping()
runForever()
