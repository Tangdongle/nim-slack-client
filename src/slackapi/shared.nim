from os import joinPath, getConfigDir
from strutils import `%`
from httpclient import postContent, getContent
import asyncdispatch
from tables import Table, initTable, pairs, `[]=`
from json import parseJson, hasKey, `[]`, getStr, items, parseFile, `$`
from websocket import Opcode, sendText
import nimobserver

import slackapi/[connection, user, message, slackexceptions]

proc buildUserTable*(connection: RTMConnection): Future[Table[string, SlackUser]] {.async.} =
  ##Constructs a table mapping users to their IDs for easy translation
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

proc findUserByName*(userTable: Table[string, SlackUser], name: string): SlackUser =
  ##Find a user by their slack name
  for id, user in userTable.pairs:
    if user.name == name:
      return user

proc initRTMConnection(connection: RTMConnection, use_start_endpoint=false): (RTMConnection, SlackUser) =
  ##Make the initial connection to the connect endpoint, returning an active connection and user data
  ##Raises an InvalidAuthException if the authorization request was unsuccessful
  ##Raises FailedToConnectException for any other connection error
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

proc connectToRTM*(token: string, port: Port): (RTMConnection, SlackUser) =
  ##Connect to the RTM and return a connection with an active websocket connection and a user object for the connection
  var connection = newRTMConnection(token, port)

  let (validatedConnection, user) = connection.initRTMConnection()

  connection = initWebsocketConnection(validatedConnection)
  result = (connection, user)

proc connectToRTM*(token: string, port: int): (RTMConnection, SlackUser) =
  ##Connect to the RTM and return a connection with an active websocket connection and a user object for the connection
  connectToRTM(token, Port port)

proc readSlackMessage*(connection: RTMConnection): Future[SlackMessage] {.async.} =
  ##Only returns Text messages from the RTM connection. Returns an error message if an error is returned
  echo "In readSlackMessage"
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
        
proc getTokenFromConfig*(): string = 
  ##Grabs our access token from $CONFIG_DIR/token.cfg
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

proc sendMessage*(connection: RTMConnection, message: SlackMessage): RTMConnection =
  ##Sends a message through the websocket
  ##Returns a Future that completes once the message has been sent
  let (conn, id) = getMessageID(connection)
  let formattedMessage = formatMessageForSend(message, id)

  waitFor conn.sock.sendText($formattedMessage, masked = true)
  return conn

export message, user, connection, slackexceptions
