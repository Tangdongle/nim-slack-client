import strutils, httpclient, os, asyncdispatch, tables, json
from slacktypes import SlackRequest, SlackMessage, SlackServer
from slackmessage import buildSlackMessage

proc initSlackRequest*(proxies: seq[Proxy], customAgent: string = ""): SlackRequest = 
  ## Create and return a default slack request
  new result

  var customAgentSeq = newSeq[string](0)
  var defaultsUA = initTable[string, string]()
  defaultsUA["client"] = defUserAgent
  defaultsUA["nim"] = "Nim/0.17.0"
  defaultsUA["system"] = hostOS & "/"

  if customAgent != "":
    customAgentSeq.add(customAgent)

  result.defaultUserAgent = defaultsUA
  result.customUserAgent = customAgentSeq
  result.proxies = proxies

proc getUserAgent*(self: SlackRequest): string = 
  if len(self.customUserAgent) > 0:
    var customUaList = newSeq[string](0)
    for uaString in self.customUserAgent:
      customUaList.add(uaString)
    let customUaString = join(customUaList, " " )
    self.defaultUserAgent["custom"] = customUaString

  var uaString = newSeq[string](0)
  for ua in values(self.defaultUserAgent):
    uaString.add(ua)

  result = join(uaString, " ")

proc appendUserAgent*(self: SlackRequest, name: string, version: string): SlackRequest {.discardable.} = 
  new result
  result = self
  if len(self.customUserAgent) > 0:
    result.customUserAgent.add(replace(name, "/", ":") & " " & replace(version, "/", ":"))
  
proc sendRequest*(self: SlackRequest, server: SlackServer, token: string, request = "?", data: JsonNode, domain = "slack.com", timeout: int = -1): SlackMessage {.discardable.} =
  ## Send a request to the slack api
  ## We add all elements from our json data node passed in and 
  ## send it up with a token
  var client = newHttpClient()

  let url = "https://" & domain & "/api/" & request
  client.headers = newHttpHeaders({
      "user-agent": getUserAgent(self),
      "Content-Type": "application/json; charset=utf-8"
    })

  var postBody = %*
    {
      "token": token,
    }
  
  for key, value in data.pairs:
    postBody[key] = value

  var clientResponse = client.request(url, httpMethod=HttpPost, body = $postBody)
  result = buildSlackMessage(server=server, data=data, response=clientResponse)
  
