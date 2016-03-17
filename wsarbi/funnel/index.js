var BitfinexWS = require('bitfinex-api-node').WS;
var bws = new BitfinexWS();

var request = require('request')

var autobahn = require('autobahn');
var connection = new autobahn.Connection({
  url: "wss://api.poloniex.com",
  realm: "realm1"
});

var redis = require('redis').createClient()
var channel_name = 'orderbook'

// poloniex pump
connection.onopen = function (session) {
  function marketEvent (args, kwargs) {
    args.forEach(function(ob){
      console.log("POLO", ob);
      wsob = {
        exchange: 'poloniex',
        market: 'ETH:BTC',
        type:   ob.data.type,
        price:  ob.data.rate,
        amount: ob.type == "orderBookRemove" ? "0" : ob.data.amount
      }
      redis.publish(channel_name, JSON.stringify(wsob))
    })
  }
  function tickerEvent (args,kwargs) {
          console.log("POLO", args);
  }
  function trollboxEvent (args,kwargs) {
          console.log(args);
  }

  session.subscribe('BTC_ETH', marketEvent);
  //session.subscribe('ticker', tickerEvent);
  //session.subscribe('trollbox', trollboxEvent);
}

connection.open()


// Bitfinex pump
bws.on('open', function () {
    bws.subscribeOrderBook('ETHBTC');

    //bws.subscribeTrades('ETHBTC');
    //bws.subscribeTicker('LTCBTC');
});

bws.on('trade', function (pair, trade) {
    console.log('Trade:', trade);
});

bws.on('orderbook', function (pair, book) {
  console.log('Order book:', book);
  wsob = {
    exchange: 'bitfinex',
    market: 'ETH:BTC',
    type:   book.amount > 0 ? "bid" : "ask",
    price:  ""+book.price,
    amount: ""+Math.abs(book.amount)
  }
  redis.publish(channel_name, JSON.stringify(wsob))
});

bws.on('ticker', function (pair, ticker) {
    console.log('Ticker:', ticker);
});

bws.on('subscribed', function (data) {
    console.log('New subscription', data);
});

bws.on('error', console.error);

// Bleutrade pump
setInterval(function(){
  request.get('https://bleutrade.com/api/v2/public/getorderbook?type=ALL&market=ETH_BTC', function (error, response, body) {
    var book = JSON.parse(body)
    console.log('bluetrade orderbook ', book.success)
    book.result.buy.forEach(function(o){
      wsob = {
        exchange: 'bleutrade',
        market: 'ETH:BTC',
        type:   "bid",
        price:  o.Rate,
        amount: o.Quantity
      }
      redis.publish(channel_name, JSON.stringify(wsob))
    })
    book.result.sell.forEach(function(o){
      wsob = {
        exchange: 'bleutrade',
        market: 'ETH:BTC',
        type:   "ask",
        price:  o.Rate,
        amount: o.Quantity
      }
      redis.publish(channel_name, JSON.stringify(wsob))
    })
  })
}, 5000)


