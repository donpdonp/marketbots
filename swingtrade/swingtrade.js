var fs = require('fs')
var moment = require('moment')
var nodemailer = require("nodemailer")
var CoinbaseExchange = require('coinbase-exchange');
var request = require('request')

var pkg = require('./package.json')
var config = JSON.parse(fs.readFileSync("./config.json"))
var coinbase = new CoinbaseExchange.AuthenticatedClient(config.coinbase.key,
                                                        config.coinbase.secret,
                                                        config.coinbase.pass);

var inventory = JSON.parse(fs.readFileSync("./inventory.json"))

// internal vars
var highwater = 0.0
var target_highwater = highwater
var sell_price = 0.0
var lowwater = 10000.0
var target_lowwater = lowwater
var buy_price = 0.0
var lag_secs = 0
var last_msg_time
var swing_side
var deadman_interval_id
var last_tick
var deadman_seconds_limit = 60

json_log({msg:"*** STARTING ***",version: pkg.version})
json_log({quant: config.quant})
json_log({inventory:inventory})
console.log('connecting to coinbase...')
var coinbasebook = new CoinbaseExchange.OrderbookSync();
//var coinbasebook = cointhink_data('coinbase', '2015-06-01')

if((typeof(inventory.btc.amount) != 'number') ||
   (typeof(inventory.usd.amount) != 'number') ||
   ((typeof(inventory.btc.price) != 'number') &&
    (typeof(inventory.usd.price) != 'number')) ||
   (inventory.btc.amount > 0 && inventory.usd.amount > 0) ) {
  console.log("bogus inventories. stopping")
  process.exit()
}

if(inventory.btc.amount > 0) {
  swing_side = "sell"
  set_target_highwater_for(inventory.usd.price)
  buy_price = inventory.usd.price
}
if(inventory.usd.amount > 0) {
  swing_side = "buy"
  set_target_lowwater_for(inventory.btc.price)
  sell_price = inventory.btc.price
}

if(config.quant.gap_percentage < config.coinbase.fee_percentage) {
  console.log("gap percentage is less than fee percentage! stopping")
  process.exit()
}

order_info()

coinbasebook.on('open', function(trade){
  json_log({msg: "connected to coinbase orderbook"})
  freshen_last_msg_time()
  deadman_interval_id = setInterval(deadman_switch, 5000)
})

coinbasebook.on('close', function(trade){
  json_log({msg: "disconnected from coinbase orderbook"})
  clearInterval(deadman_interval_id)
})

coinbasebook.on('syncing', function(msg){
  console.log('orderbook sync started')
  freshen_last_msg_time()
})

coinbasebook.on('synced', function(msg){
  console.log('orderbook synced', 'asks', msg.asks.length, '$'+coinbasebook.book._bids.max().price.toString(),
                                  'bids', msg.bids.length, '$'+coinbasebook.book._asks.min().price.toString())
  freshen_last_msg_time()
})

coinbasebook.on('order.open', function(msg){
  /*
    onMessage { type: 'open',
    sequence: 474384882,
    side: 'sell',
    price: '453.87',
    order_id: '7b96909a-881f-429d-900d-c5efddf7515b',
    remaining_size: '0.311',
    product_id: 'BTC-USD',
    time: '2015-12-24T18:54:34.901671Z' }
  */
  freshen_last_msg_time()
})

coinbasebook.on('order.done', function(msg){
  freshen_last_msg_time()
})


coinbasebook.on('order.change', function(msg){
  console.log('order change', msg)
  freshen_last_msg_time()
})

coinbasebook.on('order.match', function(trade){
  /*
  { type: 'match',
  sequence: 474401219,
  trade_id: 5745007,
  maker_order_id: '86ea2bdc-2831-4491-babf-79caad1d24e4',
  taker_order_id: 'e678507e-f07f-4999-923d-e87ecfef0a75',
  side: 'sell',
  size: '0.874',
  price: '454.21',
  product_id: 'BTC-USD',
  time: '2015-12-24T19:00:52.89176Z' }
  */
  freshen_last_msg_time()

  trade.price = parseFloat(trade.price) // floathack
  trade.size = parseFloat(trade.size)
  var trade_delay = (new Date() - new Date(trade.time))
  lag_secs = trade_delay

  var trade_msg = '$'+trade.price+
                  ' x'+trade.size.toFixed(4)
  if(last_tick) {
    trade_msg += ' sp$'+(last_tick.sell.value-last_tick.buy.value).toFixed()
  }

  var msg = ""
  var target_msg = ""
  if(swing_side == "sell"){
    msg += 'highwater $'+highwater.toFixed(2)+' '
    target_msg += '>$'+target_highwater.toFixed(2)+' falling to '+
                  '$'+sell_price.toFixed(2)
    if(buy_price > 0) {
      var buy_diff = trade.price-buy_price
      var diff_sign = ''
      if (buy_diff > 0) { diff_sign = '+'}
      msg = msg + ' '+diff_sign+buy_diff.toFixed(2)
    }
  }

  if(swing_side == "buy"){
    msg += 'lowwater $'+lowwater.toFixed(2)+' '
    target_msg += '<$'+target_lowwater.toFixed(2)+' rising to '+
                  '$'+buy_price.toFixed(2)
    if(sell_price > 0) {
      var sell_diff = sell_price-trade.price
      var diff_sign = 'loss '
      if (sell_diff > 0) { diff_sign = 'profit +'}
      msg = msg + diff_sign+sell_diff.toFixed(2)
    }
  }
  if(trade_delay > 3){
    msg = msg + ' (delay '+trade_delay.toFixed(1)+'s)'
  }

  json_log({trade:trade_msg,
            quant: msg,
            target: target_msg,
            btc: inventory.btc.amount.toFixed(3)+(inventory.usd.price&&('/$'+inventory.usd.price.toFixed(2))),
            usd: inventory.usd.amount.toFixed(2)+(inventory.btc.price&&('/$'+inventory.btc.price.toFixed(2)))
           })

  if(swing_side == "sell") {
    if(trade.price > highwater) {
      // price rising
      set_highwater(trade.price)
    } else {
      if(trade.price > target_highwater &&
         trade.price < sell_price) {
        // swing
        sell(trade.price)
      }
    }
  }

  if(swing_side == "buy") {
    if(trade.price < lowwater) {
      // price falling
      set_lowwater(trade.price)
    } else {
      if(trade.price < target_lowwater &&
         trade.price > buy_price) {
        // swing!
        buy(trade.price)
      }
    }
  }
})

function set_target_highwater_for(price){
  target_highwater = price*(1+config.quant.gap_percentage/100)
}

function set_target_lowwater_for(price){
  target_lowwater = price*(1-config.quant.gap_percentage/100)
}

function set_highwater(price) {
  highwater = price
  sell_price = (highwater * (1-config.quant.bounce_percentage/100))
  json_log({msg:'new highwater', highwater:highwater.toFixed(2),
           sell_price:sell_price.toFixed(2)})
}

function set_lowwater(price) {
  lowwater = price
  buy_price = (lowwater * (1+config.quant.bounce_percentage/100))
  json_log({msg:'new lowwater', lowwater:lowwater.toFixed(2),
           buy_price:buy_price.toFixed(2)})
}

function sell(price){
  if (low_lag()) {
    var sale_away_percentage = price / highwater
    if(sale_away_percentage > 0.5 && sale_away_percentage < 1.5 ) {
      if(inventory.btc.amount >= 0.01){
        if(swing_side == "sell"){
          json_log({msg: "SELL", sell_price: sell_price,
                                 price: price,
                                 amount: inventory.btc.amount,
                                 lag: lag_secs})
          btc = inventory.btc.amount
          add_order('ask', price, btc)
          profit = (price-inventory.usd.price)*btc
          email_alert("sell "+price.toFixed(2)+" down from "+highwater+" x"+btc.toFixed(2)+"btc. profit: $"+profit.toFixed(2))
          inventory.btc.price = price
          inventory.usd.amount = inventory.btc.price*inventory.btc.amount*(1-(config.coinbase.fee_percentage/100))
          inventory.usd.price = null
          inventory.btc.amount = 0
          save_inventory()
          swing_side = "buy"
          set_target_lowwater_for(price)
          set_lowwater(price)
          sell_price = price
        } else {
          json_log({msg: "sell order blocked by swing side", swing_side: swing_side})
        }
      } else {
        json_log({msg: "sell order blocked by low BTC inventory",
                  inventory: inventory})
      }
    } else {
      json_log({msg: "sell order blocked by crazy price",
                highwater: highwater, price: price})
    }
  } else {
    json_log({msg: "sell aborted due to lag.",
                                               lag_secs:lag_secs,
                                               sell_price: sell_price})
  }
}

function buy(price){
  if (low_lag()) {
    var sale_away_percentage = price / lowwater
    if(sale_away_percentage > 0.5 && sale_away_percentage < 1.5 ) {
      if(inventory.usd.amount >= 0.01){
        if(swing_side == "buy"){
          var btc = inventory.usd.amount/price
          json_log({msg: "BUY", buy_price: buy_price,
                                 price: price,
                                 amount: btc,
                                 lag: lag_secs})
          add_order('bid', price, btc)
          profit = (inventory.btc.price-price)*btc
          email_alert("buy "+price.toFixed(2)+" up from "+lowwater+" x"+btc.toFixed(2)+"btc. profit: $"+profit.toFixed(2))
          inventory.usd.price = price
          inventory.btc.amount = btc*(1-(config.coinbase.fee_percentage/100))
          inventory.btc.price = null
          inventory.usd.amount = 0
          save_inventory()
          swing_side = "sell"
          set_target_highwater_for(price)
          set_highwater(price)
          buy_price = price
        } else {
          json_log({msg: "buy order blocked by swing side", swing_side: swing_side})
        }
      } else {
        json_log({msg: "buy order blocked by low USD inventory",
                  inventory: inventory})
      }
    } else {
      json_log({msg: "buy order blocked by crazy price",
                lowwater: lowwater, price: price})
    }
  } else {
    json_log({msg: "buy aborted due to lag.",
                                               lag_secs:lag_secs,
                                               sell_price: sell_price})
  }
}

function low_lag(){
  return true //(lag_secs < config.quant.max_lag)
}

function add_order(bidask, price, amount){
  json_log({msg: "add order called", bidask: bidask,
                              price: price,
                              amount: amount,
                              lag: lag_secs})

  if((typeof(price) == 'number' && price > 0) || (price == 'market')){
    var amount_int = parseInt(amount * 1E8)
    var order = { type: bidask,
                  amount_int: amount_int}
    if(price > 0) {
      order.price_int = parseInt(price * 1E5)
    }
    /*
    mtgox.query('/1/BTCUSD/order/add', order,
                  function(error, result){
                    if(error){
                      json_log({msg:"ADD ORDER error",error:error})
                    } else {
                      json_log({msg:"ADD ORDER result",result:result})
                    }
                  })
    */
    order.query = '/1/BTCUSD/order/add'
    json_log(order)
  }
}

function order_info(){
  coinbase.getOrders(function(error, response, data){
    if(error){
      json_log(error)
    } else {
      var result = JSON.parse(response.body)
      console.log('coinbase open orders count', result.length)
      result.forEach(function(e){
        json_log(e)
      })
    }
  })
}

function order_status(oid){
  mtgox.query('/1/generic/order/result', function(error, result){
    if(error){
      //json_log(error)
    } else {
      result.forEach(function(e){
        json_log(e)
      })
    }
  })
}

function json_log(o){
  var msg = JSON.stringify(o)+"\n"
  var display_msg = moment().format("ddd HH:mm:ss")+" "+msg
  var log_msg = moment().format()+" "+msg
  process.stdout.write(display_msg)
  fs.appendFile('act.log', log_msg)
}

function deadman_switch(){
  var last_msg_delay = (new Date() - last_msg_time)/1000
  if(last_msg_delay > deadman_seconds_limit) {
    json_log({msg: "deadman: orderbook connection not responding! halting!",
              last_msg_delay: last_msg_delay})
    process.exit()
  }
}

function freshen_last_msg_time(){
  last_msg_time = new Date()
}

function save_inventory(){
  // reformat numbers
  inventory.btc.amount = parseFloat(inventory.btc.amount.toFixed(8))
  inventory.usd.amount = parseFloat(inventory.usd.amount.toFixed(5))
  json_log({msg:"save_inventory",inventory:inventory})
  fs.writeFileSync("./inventory.json", JSON.stringify(inventory)+"\n")
}

function email_alert(msg){
  var body = {}
  body.from = config.email.from
  body.to = config.email.to
  body.subject = config.email.server+":"+msg
  body.text = 'pre-sale inventory '+JSON.stringify(inventory)
  json_log({msg:"email", body: body})
  var smtpTransport = nodemailer.createTransport("SMTP",{host: "localhost"});
  smtpTransport.sendMail(body, function(error, response){
    if(error){
        msg = error
    } else {
        msg = response.message;
    }
    smtpTransport.close()
  });
}


function cointhink_data(exchange, start_date) {
  var EventEmitter = require('events');

  events = new EventEmitter();
  events.emit('open')

  var date = moment(start_date)
  var interval_id = setInterval(function(){
    cointhink_grab(exchange, date)
    if(date < moment()) {
      date.add(1, 'day')
    } else {
      clearInterval(interval_id)
    }
  }, 1000)

 return events
}

function cointhink_grab(exchange, date) {
  var url = 'https://cointhink.com/data/orderbook?exchange='+exchange+'&market=btc:usd&date='+date.format()
  console.log(url)
  request(url, function (error, response, body) {
    if(error) {
      console.log('get err')
    } else {
      try {
        resp = JSON.parse(body)
        events.emit('order.match', {
            size: resp.ask.quantity,
            price: resp.ask.price,
            time: resp.date
        })
      } catch(e) {
        console.log('json parse error! skipping')
      }
    }
  })
}
