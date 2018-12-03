from json import JsonNode, `[]`, getStr, getBool

type
  SlackChannel* = object
    id*: string
    is_im*: bool

proc newSlackChannel*(): SlackChannel =
  result.id = newStringOfCap(255)
  result.is_im = false

proc newSlackChannel*(id: string, is_im: bool): SlackChannel =
  result.id = id
  result.is_im = false

proc parseChannelData*(data: JsonNode): SlackChannel =
  #[
  Parses data for the connecting user
  ]#
  result = newSlackChannel()
  result.id = data["channel"]["id"].getStr
  result.is_im = data["channel"]["is_im"].getBool
