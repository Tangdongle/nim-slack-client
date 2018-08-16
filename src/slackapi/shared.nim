import httpclient
from strutils import `%`, rsplit
from uri import parseUri
import json
import net
import asyncdispatch
import websocket
from os import joinPath, getConfigDir
import macros, tables

proc getEnumFieldDefNodes(stmtList: NimNode): seq[NimNode] =
    #[
    Get all the defined fields and their string enum equivalent
    ]#
    expectKind(stmtList, nnkStmtList)
    result = @[]

    for child in stmtList:
        expectKind(child, nnkAsgn)
        result.add(newNimNode(nnkEnumFieldDef).add(child[0]).add(child[1]))

proc createFindSlackRTMTypeProc(typeName: NimIdent, identDefs: seq[NimNode]): NimNode =
    #[
    Build our proc to convert string to these Message Type objects
    ]#
    var msgTypeIdent = newIdentNode("msgType")
    var body = newStmtList()

    body.add(newProc(name = newTree(nnkPostFix, ident("*"), newIdentNode("stringTo$#" % $typeName)),
        params = @[newIdentNode(typeName),
            newIdentDefs(msgTypeIdent, ident("string"))
        ]))

    body[0].body.add(newTree(nnkCaseStmt, msgTypeIdent))
    for identDef in identDefs:
        body[0].body[0].add(newTree(nnkOfBranch,
            newTree(nnkPrefix,
                newIdentNode("$"),
                newTree(nnkDotExpr,
                    newIdentNode(typeName),
                    identDef[0]
                )
            ),
            newStmtList(
                newTree(nnkAsgn,
                    ident("result"),
                    newTree(nnkDotExpr,
                        newIdentNode(typeName),
                        identDef[0]
                    )
                )
            )
        ))
    return body

macro rtmtypes(typeName: untyped, fields: untyped): untyped =
    #[
    As there's many many slack message types, with new ones being added, 
    we want to build an enum from this definition and define a proc
    that translates a string into an Enum 
    ]#
    result = newStmtList()

    result.add(newStmtList(newEnum(
        name = newIdentNode(typeName.ident),
        fields = getEnumFieldDefNodes(fields),
        public = true,
        pure = true)
    ))

    result.add(createFindSlackRTMTypeProc(ident(typeName), getEnumFieldDefNodes(fields)))

rtmtypes SlackRTMType:
    Message = "message"
    UserTyping = "user_typing"
    GroupJoined = "group_joined"
    GroupOpen = "group_open"
    IMCreated = "im_created"
    IMOpen = "im_open"
    Error = "error"

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
        `type`*: SlackRTMType
        channel*: string
        text*: string
        user*: string 
        error: string


type
    FailedToConnectException* = object of Exception
    InvalidConfigurationException* = object of Exception
    MissingConfigFile* = object of Exception
    InvalidAuthException* = object of Exception



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
    return conn

proc newSlackUser*(): SlackUser =
    #[
    Creates a new, empty slack user
    ]#
    result.id = newStringOfCap(255)
    result.name = newStringOfCap(255)

proc newSlackUser*(id, name: string): SlackUser =
    #[
    Creates a new, empty slack user
    ]#
    result.id = id
    result.name = name

proc parseUserData*(data: JsonNode): SlackUser =
    #[
    Parses data for the connecting user
    ]#
    result = newSlackUser()
    result.id = data["self"]["id"].getStr
    result.name = data["self"]["name"].getStr

proc newSlackMessage(): SlackMessage =
    result.channel = newStringOfCap(254)
    result.text = newStringOfCap(8192)
    result.user = newStringOfCap(254)
    result.error = newStringOfCap(8192)

#proc newSlackMessage(data: JsonNode): SlackMessage =

proc newSlackMessage*(msgType: SlackRTMType, channel, text, user: string): SlackMessage =
    #[
    Creates a new slack message
    msgType: One of the RTM message types: https://api.slack.com/rtm
    channel: A channel ID or direct message ID
    ]#
    result = newSlackMessage()
    result.type = msgType
    result.channel = channel
    result.text = text
    result.user = user
    result.error = nil

proc newSlackErrorMessage*(error: string): SlackMessage =
    result = newSlackMessage()
    result.type = SlackRTMType.Error
    result.error = error

proc hasError*(message: SlackMessage): bool =
    isNil(message.error)

proc newSlackMessage*(msgType, channel, text, user: string): SlackMessage =
    let messageType = stringToSlackRTMType(msgType)
    newSlackMessage(messageType, channel, text, user)

proc `%*`*(message: SlackMessage): JsonNode =
    #[
    Slack message to JSON Node
    ]#
    result = newJObject()
    result.add("type", newJString($message.type))
    result.add("channel", newJString($message.channel))
    result.add("message", newJString($message.text))

proc `$`*(message: SlackMessage): string =
    $(%*message)

proc readMessage*(connection: RTMConnection): Future[(Opcode, string)] {.async.} =
    var tmpConnection = connection
    result = await tmpConnection.sock.readData()

proc readSlackMessage*(connection: RTMConnection): Future[SlackMessage] {.async.} =
    #[
    Only returns Text messages from the RTM connection
    Returns an error message if an error is returned
    ]#
    var tmpConnection = connection
    let (opcode, data) = await readMessage(tmpConnection)
    echo data

    #Only return Text types
    if opcode == Opcode.Text:
        let parsedData = parseJson(data)
        if parsedData.hasKey "error":
            return newSlackErrorMessage(parsedData["error"].getStr)
        elif parsedData.hasKey("type") and parsedData["type"].getStr == $SlackRTMType.Message:
            return newSlackMessage(parsedData["type"].getStr, parsedData["channel"].getStr, parsedData["text"].getStr, parsedData["user"].getStr)

proc newRTMConnection*(token: string, port: int): RTMConnection =
    #[
    Return an initialised RTM connection object
    ]#
    result = RTMConnection(token: token, client: newHttpClient(), data: newMultipartData(), port: Port(port), msgId: 1, sock: nil)
    result.data["token"] = token

proc newRTMConnection*(token: string, port: Port): RTMConnection =
    #[
    Return an initialised RTM connection object
    ]#
    result = RTMConnection(token: token, client: newHttpClient(), data: newMultipartData(), port: port, msgId: 1, sock: nil)
    result.data["token"] = token

proc newRTMConnection*(token: string): RTMConnection =
    #[
    Return an initialised RTM connection object
    ]#
    newRTMConnection(token, Port(443))

proc isConnected(connection: RTMConnection): bool =
    #[
    Check if we have a connected websocket
    ]#
    not isNil(connection.sock)

proc initRTMConnection(connection: RTMConnection, use_start_endpoint=false): (RTMConnection, SlackUser) =
    #[
    Make the initial connection to the connect endpoint, returning us 
    Raises an InvalidAuthException if the authorization request was unsuccessful
    Raises FailedToConnectException for any other connection error
    ]#
    result[0] = connection
    var url = "https://slack.com/api/rtm."
    if use_start_endpoint:
        url = url & "start"
    else:
        url = url &  "connect"

    let jsResponse = parseJson(postContent(connection.client, url, multipart=connection.data))
    try:
        result[0].wsUrl = jsResponse["url"].getStr
        result[1] = parseUserData(jsResponse)
    except KeyError:
        if jsResponse.hasKey("error"):
            if jsResponse["error"].getStr == "invalid_auth":
                raise newException(InvalidAuthException, "invalid token")
            else:
                raise newException(FailedToConnectException, "failed to connect (reason: $#)" % jsResponse["error"].getStr)

proc initWebsocketConnection(connection: RTMConnection): RTMConnection =
    #[
    Initialise a connection with the web socket so we can start receiving and sending data
    ]#
    result = connection
    var components = connection.wsUrl.rsplit('/', 2)
    let uri = parseUri("$#:443/$#/$#" % components)

    result.sock = waitFor newAsyncWebsocketClient(uri)
    if not isConnected(result):
        raise newException(FailedToConnectException, "failed to connect to websocket")

proc connectToRTM*(token: string, port: Port): (RTMConnection, SlackUser) =
    #[
    Connect to the RTM and return a connection with an active websocket connection 
    and a user object for the connection
    ]#
    var connection = newRTMConnection(token, port)

    let (validatedConnection, user) = connection.initRTMConnection()

    connection = initWebsocketConnection(validatedConnection)
    result = (connection, user)

proc connectToRTM*(token: string, port: int): (RTMConnection, SlackUser) =
    #[
    Connect to the RTM and return a connection with an active websocket connection
    and a user object for the connection
    ]#
    connectToRTM(token, Port port)

proc getTokenFromConfig*(): string = 
    #[
    Grabs our bot token from a token.cfg config file
    ]#
    let
        config = joinPath(getConfigDir(), "nim-slackapi")
    
    try:
        result = parseFile(joinPath(config, "token.cfg"))["token"].getStr
    except KeyError:
        echo "No Token key found in config file"
        raise newException(InvalidConfigurationException, "no token key found in config")
    except IOError:
        echo "No token.cfg file found in $#.\n Creating a blank one now.\n Please add your token to it" % config
        writeFile(joinPath(config, "token.cfg"), """{"token": "xxxxx"}""")
        raise newException(MissingConfigFile, "No token.cfg file found in $#" % config)

proc isTextOpcode*(opcode: Opcode): bool =
    opcode == Opcode.Text

proc buildUserTable*(connection: RTMConnection): Future[Table[string, SlackUser]] {.async.} =
    result = initTable[string, SlackUser](1)
    let url = "https://slack.com/api/users.list?token=" & connection.token 
    let response = parseJson(connection.client.getContent(url))
    if response.hasKey "error":
        #handle error
        echo "error getting user list"

    var nextCursor:string = nil 
    if response.hasKey "response_metadata":
        nextCursor = response["response_metadata"]["next_cursor"].getStr

    for member in response["members"].items:
        result[member["id"].getStr] = newSlackUser(member["id"].getStr, member["name"].getStr)
        
when isMainModule:
    echo stringToSlackRTMType("user_typing")
    assert(stringToSlackRTMType("message") == SlackRTMType.Message)
