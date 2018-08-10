import httpclient
from strutils import `%`, rsplit
from uri import parseUri
from json import `[]`, getStr, parseJson, JsonNode, newJString, add, `$`, newJObject, `%*`
import net
import asyncdispatch
from websocket import newAsyncWebsocketClient, AsyncWebsocket, sendText

type
    RTMConnection* = object
        token*: string
        client*: HttpClient
        data*: MultipartData
        port*: Port
        wsUrl*: string
        msgId: uint
        sock*: AsyncWebsocket

    SlackUser* = object
        id*: string
        name*: string

    SlackMessage* = object
        `type`: SlackRTMType
        channel: string
        text: string

    SlackRTMType* {.pure.} = enum
        Message = "message"

type
    FailedToConnectException* = object of Exception

proc getMessageID(connection: RTMConnection): (RTMConnection, uint) =
    #[
    Get the current unique message ID
    ]#
    var currentConnection = connection
    let id = connection.msgId
    currentConnection.msgId.inc
    result = (currentConnection, id)

proc formatMessageForSend(message: SlackMessage, msgId: uint): JsonNode =
    #[
    Format a message for slack
    Each message from a connection requires a unique uint so that subsequent messages can respond to it
    ]#
    result = %*
        {
            "id": $msgId,
            "type": $message.type,
            "channel": message.channel,
            "text": message.text
        }
        
proc sendMessage*(connection: RTMConnection, message: SlackMessage): RTMConnection =
    #[
    Sends a message through the websocket
    Returns a Future that completes once the message has been sent
    ]#
    let (conn, id) = getMessageID(connection)
    let formattedMessage = formatMessageForSend(message, id)
    waitFor conn.sock.sendText($formattedMessage, masked = true)

proc newSlackUser*(): SlackUser =
    #[
    Creates a new, empty slack user
    ]#
    result.id = newStringOfCap(255)
    result.name = newStringOfCap(255)

proc parseUserData*(data: JsonNode): SlackUser =
    #[
    Parses data for the connecting user
    ]#
    result = newSlackUser()
    result.id = data["self"]["id"].getStr
    result.name = data["self"]["name"].getStr

proc newSlackMessage(): SlackMessage =
    result.channel = newStringOfCap(255)
    result.text = newStringOfCap(8192)

proc newSlackMessage*(msgType: SlackRTMType, channel, text: string): SlackMessage =
    #[
    Creates a new slack message
    msgType: One of the RTM message types: https://api.slack.com/rtm
    channel: A channel ID or direct message ID
    ]#
    result = newSlackMessage()
    result.type = msgType
    result.channel = channel
    result.text = text

proc findSlackRTMType(msgType: string): SlackRTMType =
    case msgType
        of $SlackRTMType.Message:
            result = SlackRTMType.Message

proc newSlackMessage*(msgType, channel, text: string): SlackMessage =
    let messageType = findSlackRTMType(msgType)
    newSlackMessage(messageType, channel, text)

proc `%*`*(message: SlackMessage): JsonNode =
    result = newJObject()
    result.add("type", newJString($message.type))
    result.add("channel", newJString($message.channel))
    result.add("message", newJString($message.text))

proc `$`*(message: SlackMessage): string =
    $(%*message)

proc newRTMConnection*(token: string, port: int): RTMConnection =
    result = RTMConnection(token: token, client: newHttpClient(), data: newMultipartData(), port: Port(port), msgId: 1, sock: nil)
    result.data["token"] = token

proc newRTMConnection*(token: string, port: Port): RTMConnection =
    result = RTMConnection(token: token, client: newHttpClient(), data: newMultipartData(), port: port, msgId: 1, sock: nil)
    result.data["token"] = token

proc newRTMConnection*(token: string): RTMConnection =
    newRTMConnection(token, Port(443))

proc isConnected(connection: RTMConnection): bool =
    #[
    Check if we have a connected websocket
    ]#
    not isNil(connection.sock)

proc makeRTMConnection*(connection: RTMConnection, use_start_endpoint=false): (RTMConnection, SlackUser) =
    #[
    Make the initial connection to the connect endpoint, returning us 
    ]#
    result[0] = connection
    var url = "https://slack.com/api/rtm."
    if use_start_endpoint:
        url = url & "start"
    else:
        url = url &  "connect"

    let jsResponse = parseJson(postContent(connection.client, url, multipart=connection.data))
    result[0].wsUrl = jsResponse["url"].getStr
    result[1] = parseUserData(jsResponse)

proc initWebsocketConnection*(connection: RTMConnection): RTMConnection =
    #[
    Initialise a connection with the web socket so we can start receiving and sending data
    ]#
    result = connection
    var components = connection.wsUrl.rsplit('/', 2)
    let uri = parseUri("$#:443/$#/$#" % components)

    result.sock = waitFor newAsyncWebsocketClient(uri)
    if not isConnected(result):
        raise newException(FailedToConnectException, "failed to connect to websocket")
