doFile("json.io")
doFile("Iodis.io")

("WarpBubble starting " .. Date asString("%H:%M")) println

redis := Iodis clone connect

state := Map clone
state atPut("key1", "value1")
state atPut("key2", "value2")
redis set("hashy1", state asJson)

redis get("hashy1") parseJson println

("key1 is ".. state at("key1")) println

book := HCUrl with("https://data.mtgox.com/api/2/BTCUSD/money/ticker") get parseJson

book at("result") println

