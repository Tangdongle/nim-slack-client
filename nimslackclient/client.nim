import maybe/maybe
import json
import httpclient
import options
import asyncdispatch
from strutils import toLowerAscii, splitLines, `%`
from sequtils import any
import server
from slackrequest import appendUserAgent
import slacktypes
import slackchannel

proc rtmConnect(self: SlackClient, token: string, with_team_state: bool = false, payload: JsonNode = newJObject(), proxies: seq[Proxy] = newSeq[Proxy](0)): SlackClient = 
  new result
  result = self
  echo "IN RTM CONNECT CLIENT"
  try:
    result.server = rtmConnect(use_rtm_start=with_team_state, payload=payload, proxies=proxies)
  except:
    echo "Failed to connect"
    raise

proc newSlackClient*(token: string, with_team_state: bool = false, proxies: seq[Proxy] = @[]): SlackClient = 
  new result

  result.token = token
  result = result.rtmConnect(token=token, with_team_state=with_team_state, proxies=proxies)

proc appendUserAgent*(self: SlackClient, name, version: string): SlackClient =
  new result
  result.token = self.token
  result.server = self.server
  result.server.apiRequester = self.server.apiRequester.appendUserAgent(name=name, version=version)

proc apiCall(self: SlackClient, request: string, timeout: int, payload: JsonNode = newJObject()): SlackMessage = 
  ## Makes a call to the slack websocket
  ##
  ## Args:
  ##   request: API endpoint to send to
  ##   timeout: Timout for api call
  ##   payload: JSON payload to send to the 
  ##
  
  result = self.server.apiCall(request=request, timeout=timeout, payload=payload)
  echo result.msgType

  
  case result.msgType.toLowerAscii
    of "im.open":
      if result.ok and result.ok == true:
        discard self.server.attachChannel(result.user.name, result.channel.id)
    of "mpim.open", "groups.create", "groups.createchild":
      if result.ok and result.ok == true:
        discard self.server.attachChannel(
          name=result.user.name,
          user_id=result.user.id,
          members=payload["group"]["members"].getElems()
        )
    of "channels.create", "channels.join":
      if result.ok and result.ok == true:
        discard self.server.attachChannel(
          name=payload["channel"]["name"].getStr(),
          user_id=payload["channel"]["id"].getStr(),
          members=payload["channel"]["members"].getElems()
        )

    else:
      echo "Message Type: " & result.msgType

proc processChanges(self: var SlackClient, data: JsonNode): ChangeStatus =
  ## Internal proc which updates the internal data stores
  ## Returns:
  ##  ChangeStatus.noChange - No change to data
  ##  ChangeStatus.channelCreated - A channel/group has been created
  ##  ChangeStatus.imCreated - An Instant Message channel was created
  ##  ChangeStatus.teamJoin - A user has joined a team
  ##
  var channel: JsonNode

  if data.hasKey("type"):
    case data["type"].getStr()
      of "channel_created", "group_joined":
        channel = data["channel"]
        self.server = self.server.attachChannel(
          name=channel["name"].getStr(),
          user_id=channel["id"].getStr(),
          tz=channel["tz"].getStr(default="UTC")
        )
        return ChangeStatus.channelCreated
      of "im_created":
        channel = data["channel"]
        self.server = self.server.attachChannel(
          name=channel["name"].getStr(),
          user_id=channel["id"].getStr(),
          tz=channel["tz"].getStr(default="UTC")
        )
        return ChangeStatus.imCreated
      of "team_join":
        var user: JsonNode = data["user"]
        discard self.server.parseUsers(user)

        return ChangeStatus.teamJoin
      else:
        return ChangeStatus.noChange
  return ChangeStatus.noChange

proc rtmRead*(self: SlackClient): Future[seq[JsonNode]] {.async.} =
  ## Reads an RTM message from slack
  ## 
  ## Raises:
  ##  SlackNotConnectedError - When the server connection has been lost
  ##  RTMReadFailError - When the data returned fails to parse into JSON
  ##
  var client = self
  var serverExists = maybe.just(client.server)

  #Check if the server exist
  maybeCase serverExists:
    just server:
      try:
        var data = await server.websocketSafeRead()
        var dataLines: seq[JsonNode] = @[]
        echo data

        #Our data can be split into multiple messages
        for line in splitLines(data):
          dataLines.add(parseJson(line))

        #For each line, load it into our delta function
        for item in dataLines:
          var status: ChangeStatus = client.processChanges(item)
          echo "Change Status $1" % $status
      except JsonParsingError:
        #If this fails, we returned a blank string
        raise newException(RTMReadFailError, "RTM read failed!")
    nothing:
      raise newException(SlackNotConnectedError, "No server to read from!")

proc sendRTMMessage*(self: SlackClient, channel, message: string, thread: string = "", reply_broadcast: bool = false): int {.discardable.} =
  ## Sends a message to the slack RTM
  ## 
  ##

  var slackChannel = findChannelById(channel_id=channel, server=self.server)

  if isNil(slackChannel):
    slackChannel = initSlackChannel(channel_id=channel, server=self.server)

  return self.server.sendRTMMessage(
      channel=slackChannel,
      message=message, thread=thread,
      reply_broadcast=reply_broadcast
    )
