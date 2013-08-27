Markets := Object clone do (
  poll := method(market,
    ("Starting " .. market .. " " .. Date asString("%H:%M:%S")) println
    if(market == "mtgox", mtgox)
    if(market == "btce", btce)
  )

  mtgox := method(
    book := HCUrl with("https://data.mtgox.com/api/2/BTCUSD/money/depth/full") get parseJson
    book println
  )

  btce := method(
    book := HCUrl with("https://btc-e.com/api/2/BTC_USD/depth") get parseJson
    book println
  )
)