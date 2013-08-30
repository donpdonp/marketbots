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
mtgox := Markets clone setMarket("mtgox")
btce := Markets clone setMarket("btce")
loop (
  btce asyncSend(poll)
  mtgox asyncSend(poll)
  wait(30)
)