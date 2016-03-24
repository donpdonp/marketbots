var BitfinexWS = require('bitfinex-api-node').WS;
var bws = new BitfinexWS();

var request = require('request')

var autobahn = require('autobahn');
var poloniex_stream = new autobahn.Connection({
  url: "wss://api.poloniex.com",
  realm: "realm1"
});

var redis = require('redis').createClient()
var channel_name = 'orderbook'


stream_setup()

// Poloniex stream
poloniex_stream.open()

// Kraken pump
setInterval(kraken_refresh, 5000)
// Bleutrade pump
setInterval(bleu_refresh, 5000)


function stream_setup() {

  // poloniex pump
  poloniex_stream.onopen = function (session) {
    function marketEvent (args, kwargs) {
      args.forEach(function(ob){
        if(ob.type == "orderBookModify" || ob.type == "orderBookRemove") {
          console.log("POLO", ob.type, ob.data);
          wsob = {
            exchange: 'poloniex',
            market: 'ETH:BTC',
            type:   ob.data.type,
            price:  ob.data.rate,
            amount: ob.type == "orderBookRemove" ? "0" : ob.data.amount
          }
          redis.publish(channel_name, JSON.stringify(wsob))
        }
      })
    }
    function tickerEvent (args,kwargs) {
    }
    function trollboxEvent (args,kwargs) {
    }

    session.subscribe('BTC_ETH', marketEvent);
    //session.subscribe('ticker', tickerEvent);
    //session.subscribe('trollbox', trollboxEvent);
  }



  // Bitfinex pump
  bws.on('open', function () {
    bws.subscribeOrderBook('ETHBTC');

    //bws.subscribeTrades('ETHBTC');
    //bws.subscribeTicker('LTCBTC');
  });

  bws.on('close', function (pair, trade) {
      console.log('btfx closed.', trade);
  });

  bws.on('trade', function (pair, trade) {
      console.log('Trade:', trade);
  });

  bws.on('orderbook', function (pair, book) {
    console.log('BTFX', book);
    wsob = {
      exchange: 'bitfinex',
      market: 'ETH:BTC',
      type:   book.amount > 0 ? "bid" : "ask",
      price:  ""+book.price, // str to float to str, crosses fingers
      amount: book.count == 0 ? "0" : (""+Math.abs(book.amount))
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
}


function bleu_refresh(){
  request.get('https://bleutrade.com/api/v2/public/getorderbook?type=ALL&market=ETH_BTC', function (error, response, body) {
    try {
      var book = JSON.parse(body)
      console.log('BLUE ', book.result.buy.length, book.result.sell.length)
      redis.publish(channel_name, JSON.stringify({exchange: "bleutrade", type: "clear"}))
      book.result.buy.forEach(function(o){
        wsob = {
          exchange: "bleutrade",
          market: "ETH:BTC",
          type:   "bid",
          price:  o.Rate,
          amount: o.Quantity
        }
        redis.publish(channel_name, JSON.stringify(wsob))
      })
      book.result.sell.forEach(function(o){
        wsob = {
          exchange: "bleutrade",
          market: "ETH:BTC",
          type:   "ask",
          price:  o.Rate,
          amount: o.Quantity
        }
        redis.publish(channel_name, JSON.stringify(wsob))
      })
    } catch (e) {
      console.log('BLUE JSON ERR', body[0,100])
    }
  })
}


function kraken_refresh(){
  request.get('https://api.kraken.com/0/public/Depth?pair=XETHXXBT&count=20', function (error, response, body) {
    try {
      var book = JSON.parse(body).result.XETHXXBT
      console.log('KRAKEN ', book.bids.length, book.asks.length)
      redis.publish(channel_name, JSON.stringify({exchange: "kraken", type: "clear"}))
      book.bids.forEach(function(o){
        wsob = {
          exchange: "kraken",
          market: "ETH:BTC",
          type:   "bid",
          price:  o[0],
          amount: o[1]
        }
        redis.publish(channel_name, JSON.stringify(wsob))
      })
      book.asks.forEach(function(o){
        wsob = {
          exchange: "kraken",
          market: "ETH:BTC",
          type:   "ask",
          price:  o[0],
          amount: o[1]
        }
        redis.publish(channel_name, JSON.stringify(wsob))
      })
    } catch (e) {
      console.log('KRAKEN JSON ERR', e, body.substr(0,100))
    }
  })
}

