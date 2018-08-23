from json import JsonNode, getStr, `[]`

type
  SlackUser* = object
    id*: string
    name*: string

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

