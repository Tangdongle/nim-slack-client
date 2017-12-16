from lists import SinglyLinkedList, items
from slacktypes import SlackUser, SlackServer, TimeZone

proc initSlackUser*(user_id:string, name:string = "" , real_name:string = "", email: string  = "", timezone: TimeZone = TimeZone(zone: "UTC"), server: SlackServer): SlackUser = 
  ## Create and return a user
  new result
  result.id = user_id
  result.name = name
  result.real_name = real_name
  result.email = email
  result.timezone = timezone
  result.server = server

proc initSlackUser*(user_id: string, name: string = "", real_name: string = "", email: string = "", timezone: string = "UTC", server: SlackServer): SlackUser = 
  ## handles tz as string
  let tz = TimeZone(zone: timezone)
  result = initSlackUser(user_id=user_id, name=name, real_name=real_name, email=email, timezone=tz, server=server)

proc findUserById*(user_id: string, server: SlackServer): SlackUser =
  #[
  # Return a SlackUser given an ID or nil
  ]#
  for user in server.users:
    if user.id == user_id:
      return user
  return nil

