# system libs
doFile("json.io")
doFile("Iodis.io")

# local libs
doFile("state.io")
doFile("markets.io")

("WarpBubble starting " .. Date asString("%H:%M")) println

# persistent connections
redis := Iodis clone connect

# global state
state := State setup

state rstate println
loop (
  Markets asyncSend(poll("mtgox"))
  Markets asyncSend(poll("btce"))
  wait(30)
)