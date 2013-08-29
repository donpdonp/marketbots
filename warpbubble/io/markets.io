Markets := Object clone do (
  market ::= nil

  poll := method(
    ("Starting " .. market .. " " .. Date asString("%H:%M:%S")) println
    if(market == "mtgox", mtgox)
    if(market == "btce", btce)
  )

  mtgox := method(
    json := HCUrl clone with("https://data.mtgox.com/api/2/BTCUSD/money/depth/full") get
    "mtgox start" println
    json exSlice(0,200) println
    #json parseJson size println
    "mtgox end" println
  )

  btce := method(
    http := HCRequest with(HCUrl clone with("https://btc-e.com/api/2/btc_usd/depth"))
    http headers atPut("User-Agent","Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:23.0) Gecko/20100101 Firefox/23.0")
    response :=  http connection sendRequest response
    "btce start" println
    response content exSlice(0,200) println
    "btce end" println
  )
)