# system libs
doFile("lib/json.io")
doFile("lib/Iodis.io")

# local libs
doFile("io/state.io")
doFile("io/markets.io")

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