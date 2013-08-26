doFile("json.io")
("WarpBubble starting " .. Date asString("%H:%M")) println

state := Map clone
state atPut("mtgox", nil)

book := HCUrl with("https://data.mtgox.com/api/2/BTCUSD/money/ticker") get parseJson

book at("result") println

