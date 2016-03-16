var BitfinexWS = require('bitfinex-api-node').WS;
var bws = new BitfinexWS();

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
        market: 'poloniex',
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
    market: 'bitfinex',
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

