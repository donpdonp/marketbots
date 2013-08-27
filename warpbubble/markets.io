Markets := Object clone do (
  poll := method(
    book := HCUrl with("https://data.mtgox.com/api/2/BTCUSD/money/ticker") get parseJson
    book at("result") println
  )
)