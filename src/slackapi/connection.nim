from httpclient import HttpClient, MultipartData, newHttpClient, newMultipartData, `[]=`
from websocket import AsyncWebsocket, readData, Opcode, newAsyncWebsocketClient
from net import Port
import asyncdispatch
from strutils import rsplit, `%`
from uri import parseUri

import slackexceptions

type
  RTMConnection* = object
    token*: string
    client*: HttpClient
    data*: MultipartData
    port*: Port
    wsUrl*: string
    msgId: uint
    sock*: AsyncWebsocket

proc readMessage*(connection: RTMConnection): Future[(Opcode, string)] {.async.} =
  var tmpConnection = connection
  result = await tmpConnection.sock.readData()

proc getMessageID*(connection: RTMConnection): (RTMConnection, uint) =
  #[
  Get the current unique message ID
  ]#
  var currentConnection = connection
  let id = connection.msgId
  currentConnection.msgId.inc
  result = (currentConnection, id)

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
