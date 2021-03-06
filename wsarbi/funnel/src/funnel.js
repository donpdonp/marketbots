'use strict'
// public APIs are all http
var request = require('request')

// websocket specific support
var BitfinexWS = require('bitfinex-api-node').WS
var autobahn = require('autobahn')
var poloniex_stream = new autobahn.Connection({
  url: 'wss://api.poloniex.com',
  realm: 'realm1'
})

// redis common bus
var redis = require('redis').createClient()
var channel_name = 'orderbook'

// buggy delay
// setTimeout(stream_setup, 15000)

// Kraken pump
setInterval(kraken_refresh, 5000)
// Bleutrade pump
setInterval(bleu_refresh, 5000)
// Poloniex pump
setInterval(poloniex_refresh, 5000)
// Bitfinex pump
setInterval(bitfinex_refresh, 5000)
// Bittrex pump
setInterval(bittrex_refresh, 5000)

function stream_setup () {
  // poloniex pump
  poloniex_stream.onopen = function (session) {
    function marketEvent (args, kwargs) {
      args.forEach(function (ob) {
        if (ob.type === 'orderBookModify' || ob.type === 'orderBookRemove') {
          console.log('POLO', ob.type, ob.data)
          let wsob = {
            exchange: 'poloniex',
            market: 'ETH:BTC',
            type: ob.data.type,
            price: ob.data.rate,
            amount: ob.type === 'orderBookRemove' ? '0' : ob.data.amount
          }
          redis.publish(channel_name, JSON.stringify(wsob))
        }
      })
    }
    function tickerEvent (args, kwargs) {
    }
    function trollboxEvent (args, kwargs) {
    }

    session.subscribe('BTC_ETH', marketEvent)
  // session.subscribe('ticker', tickerEvent)
  // session.subscribe('trollbox', trollboxEvent)
  }

  // start here because reasons
  poloniex_stream.open()

  // starts automatically. boo.
  var bws = new BitfinexWS()
  // Bitfinex pump
  bws.on('open', function () {
    bws.subscribeOrderBook('ETHBTC')

  // bws.subscribeTrades('ETHBTC')
  // bws.subscribeTicker('LTCBTC')
  })

  bws.on('close', function (pair, trade) {
    console.log('btfx closed.', trade)
  })

  bws.on('trade', function (pair, trade) {
    console.log('Trade:', trade)
  })

  bws.on('orderbook', function (pair, book) {
    console.log('BTFX', book)
    let wsob = {
      exchange: 'bitfinex',
      market: 'ETH:BTC',
      type: book.amount > 0 ? 'bid' : 'ask',
      price: '' + book.price, // str to float to str, crosses fingers
      amount: book.count === 0 ? '0' : ('' + Math.abs(book.amount))
    }
    redis.publish(channel_name, JSON.stringify(wsob))
  })

  bws.on('ticker', function (pair, ticker) {
    console.log('Ticker:', ticker)
  })

  bws.on('subscribed', function (data) {
    console.log('New subscription', data)
  })

  bws.on('error', console.error)
}

function bleu_refresh () {
  exchange_reset('bleutrade',
    'https://bleutrade.com/api/v2/public/getorderbook?type=ALL&market=ETH_BTC',
    function (answer) {
      return {
        market: 'ETH:BTC',
        bids: answer.result.buy,
        asks: answer.result.sell
      }
    },
    function (offer) {
      return {
        price: offer.Rate,
        amount: offer.Quantity
      }
    })
}

function kraken_refresh () {
  exchange_reset('kraken',
    'https://api.kraken.com/0/public/Depth?pair=XETHXXBT&count=50',
    function (answer) {
      return {
        market: 'ETH:BTC',
        bids: answer.result.XETHXXBT.bids,
        asks: answer.result.XETHXXBT.asks
      }
    },
    function (offer) {
      return {
        price: offer[0],
        amount: offer[1]
      }
    })
}

function poloniex_refresh () {
  exchange_reset('poloniex',
    'https://poloniex.com/public?command=returnOrderBook&currencyPair=BTC_ETH',
    function (answer) {
      return {
        market: 'ETH:BTC',
        bids: answer.bids,
        asks: answer.asks
      }
    },
    function (offer) {
      return {
        price: offer[0],
        amount: '' + offer[1]
      }
    })
}

function bitfinex_refresh () {
  exchange_reset('bitfinex',
    'https://api.bitfinex.com/v1/book/ETHBTC',
    function (answer) {
      return {
        market: 'ETH:BTC',
        bids: answer.bids,
        asks: answer.asks
      }
    },
    function (offer) {
      return {
        price: offer.price,
        amount: offer.amount
      }
    })
}

function bittrex_refresh () {
  exchange_reset('bittrex',
    'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-ETH&type=both&depth=50',
    function (answer) {
      return {
        market: 'ETH:BTC',
        bids: answer.result.buy,
        asks: answer.result.sell
      }
    },
    function (offer) {
      return {
        price: '' + offer.Rate,
        amount: '' + offer.Quantity
      }
    })
}

function exchange_reset (name, api_url, answer_morph, offer_morph) {
  // console.log(api_url)
  request.get(api_url, function (error, response, body) {
    var load = {
      type: 'load',
      exchange: name
    }

    try {
      var data = JSON.parse(body)

      var book = answer_morph(data)
      load['market'] = book.market

      var sides = [ 'bid', 'ask' ]
      sides.forEach(function (side) {
        load[side + 's'] = book[side + 's'].map(offer_morph)
      })

      console.log('*', name)
      console.log('* top bid', JSON.stringify(book.bids[0]), JSON.stringify(load.bids[0]))
      console.log('* top ask', JSON.stringify(book.asks[0]), JSON.stringify(load.asks[0]))

      redis.publish(channel_name, JSON.stringify(load))
    } catch (e) {
      console.log(name, 'JSON ERR', e, body ? body.substr(0, 100) : 'empty body')
    }
  })
}
