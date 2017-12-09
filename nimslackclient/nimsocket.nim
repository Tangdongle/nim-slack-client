import strutils, asynchttpserver, asyncdispatch, json, cgi, httpclient, os

var 
  slackServer* = newAsyncHttpServer()
  slackPort* = Port(33556)
  slackIncomingWebhookUrl*: string
  slackReq*: asynchttpserver.Request

proc slackMsg*(channel, username, fallback, pretext, color, title, value: string): string =
  let jsonNode = %*{"channel": channel,
    "username": username,
    "attachments":[
        {
          "fallback": fallback,
          "pretext": pretext,
          "color": color,
          "fields":[
            {
              "title": title,
              "value": value,
              "short": false
            }
          ]
        }
      ]
    }
  result = $jsonNode

proc slackSend*(msg: string): Future[string] {.async.} = 
  ## Sends messages as sync
  if slackIncomingWebhookUrl != nil:
    var clientSlack = newAsyncHttpClient()
    clientSlack.headers = newHttpHeaders({ "Content-Type": "application/json" })

    var clientSlackReq = await clientSlack.request(slackIncomingWebhookUrl, httpMethod=HttpPost, body=msg)
    clientSlack.close()
    result = await clientSlackReq.body
  else:
    echo "Missing incoming webhook URL"

proc slackVerifyConnection*(slackReq: asynchttpserver.Request) {.async.} = 
  ##Grabs the vlaue from field with value "challenge" and sends it back to the client
  
  let headers = newHttpHeaders([("Content-Type","application/json")])
  let msg = %* {"challenge": parseJson(slackReq.body)["challenge"].getStr()}
  echo "Sending verification for connection"
  echo "Challenge: " & $msg
  await slackReq.respond(Http200, $msg, headers)

proc toJson(slackReq: asynchttpserver.Request): JsonNode = 
  #Parse the request

  var json_string = ""
  for items in split(decodeUrl(slackReq.body), '&'):
    json_string.add("\"" & split(items, "=")[0] & "\": \"" & split(items, "=")[1] & "\",\n")
  let jsonNode = parseJson("{" & json_string[0 .. ^2] & "}")
  return jsonNode

proc slackEventString*(slackReq: asynchttpserver.Request): string = 
  #Decodes the request and returns a URL
  return decodeURL(slackReq.body)

proc slackEventJson*(slackReq: asynchttpserver.Request): JsonNode = 
  # Return the request as a JsonNode
  
  return toJson(slackReq)

proc slackRespond*(slackReq: asynchttpserver.Request, msg: string) {.async.} =
  # Sending a message to slack

  let headers = newHttpHeaders([("Content-Type", "application/json")])

  await slackReq.respond(Http200, msg, headers)

proc slackEvent*(slackReq: asynchttpserver.Request, jsonKey: string): string = 

  return toJson(slackReq)[jsonKey].getStr()


