var fs = require('fs')
var moment = require('moment')
var nodemailer = require("nodemailer")
var socketio = require('socket.io-client')
var Mtgoxjs = require('mtgox')
var mtgoxob = require('mtgox-orderbook')

var pkg = require('./package.json')
var config = JSON.parse(fs.readFileSync("./config.json"))
var mtgox = new Mtgoxjs(config.mtgox)

var inventory = JSON.parse(fs.readFileSync("./inventory.json"))

// internal vars
var highwater = 0.0
var target_highwater = 0
var sell_price = 0.0
var lowwater = 500.0
var target_lowwater = 500.0
var buy_price = 0.0
var lag_secs = 0
var last_msg_time
var lag_confidence = false
var swing_side
var deadman_interval_id

json_log({msg:"*** STARTING ***",version: pkg.version})
json_log({quant: config.quant})
json_log({inventory:inventory})
process.stdout.write('connecting to mtgox...')

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

if(config.quant.gap_percentage < config.mtgox.fee) {
  console.log("gap percentage is less than fee percentage! stopping")
  process.exit()
}
var sockio = socketio.connect(mtgoxob.socketio_url,{
  'try multiple transports': false,
  'connect timeout': 5000
})
var mtsox = mtgoxob.attach(sockio, 'usd')

mtsox.on('connect', function(trade){
  json_log({msg: "connected to mtgox"})
  setTimeout(function(){mtsox.subscribe("lag")}, 1000) // trade.lag
  freshen_last_msg_time()
  deadman_interval_id = setInterval(deadman_switch, 5000)
})

mtsox.on('disconnect', function(trade){
  json_log({msg: "disconnected to mtgox"})
  clearInterval(deadman_interval_id)
})

mtsox.on('subscribe', function(sub){
  //console.log('subscribed '+sub)
})

mtsox.on('message', function(sub){
  freshen_last_msg_time()
})

mtsox.on('lag', function(lag){
  if (lag.qid) {
    var lag_age_secs = lag.age/1000000
    var delay_secs = (new Date() - new Date(lag.stamp/1000))/1000
    if (delay_secs < 30) {
      lag_confidence = true
      lag_secs = lag_age_secs
      if (lag_secs > config.quant.max_lag) {
        console.log('lag '+ lag_secs + "s delay: "+delay_secs+"s.")
      }
    } else {
      lag_confidence = false
      console.log('no confidence in lag of '+ lag_secs + "s with delay: "+delay_secs+"s.")
    }
  } else {
    // lag idle
    lag_secs = 0
    lag_confidence = true
  }
})

mtsox.on('trade', function(trade){
  if(trade.price_currency == 'USD') {
    var trade_delay = (new Date() - (trade.date*1000))/1000

    var msg = ""
    msg = msg + '$'+trade.price.toFixed(2)+
                ' x'+trade.amount.toFixed(1)
    if(swing_side == "sell"){
      msg = msg + ' highwater '+highwater.toFixed(2)+
                ' target '+target_highwater.toFixed(2)+
                ' sell '+sell_price.toFixed(2)
      if(buy_price > 0) {
        var buy_diff = trade.price-buy_price
        var diff_sign = ''
        if (buy_diff > 0) { diff_sign = '+'}
        msg = msg + ' '+diff_sign+buy_diff.toFixed(2)
      }
    }
    if(swing_side == "buy"){
      msg = msg + ' lowwater '+lowwater.toFixed(2)+
                ' target '+target_lowwater.toFixed(2)+
                ' buy '+buy_price.toFixed(2)
      if(sell_price > 0) {
        var sell_diff = sell_price-trade.price
        var diff_sign = ''
        if (sell_diff > 0) { diff_sign = '+'}
        msg = msg + ' '+diff_sign+sell_diff.toFixed(2)
      }
    }
    if(trade_delay > 3){
      msg = msg + ' (delay '+trade_delay.toFixed(1)+'s)'
    }
    if(lag_secs > 5){
      msg = msg + ' (lag '+lag_secs.toFixed(1)+'s)'
    }

    json_log({trade:msg, btc: inventory.btc.amount, usd: inventory.usd.amount})

    if(swing_side == "sell") {
      if(trade.price > highwater) {
        // price rising
        set_highwater(trade.price)
      } else {
        if(trade.price > target_highwater &&
           trade.price < sell_price) {
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
          buy(trade.price)
        }
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
           target_highwater: target_highwater.toFixed(2),
           sell_price:sell_price.toFixed(2)})
}

function set_lowwater(price) {
  lowwater = price
  buy_price = (lowwater * (1+config.quant.bounce_percentage/100))
  json_log({msg:'new lowwater', lowwater:lowwater.toFixed(2),
           target_lowwater: target_lowwater.toFixed(2),
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
          add_order('ask', price, inventory.btc.amount)
          email_alert("stoploss SELL "+price.toFixed(2)+" "+inventory.btc.amount+"btc")
          inventory.btc.price = price*(1-(config.mtgox.fee_percentage/100))
          inventory.usd.amount = inventory.btc.price*inventory.btc.amount
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
    json_log({msg: "sell aborted due to lag.", lag_confidence:lag_confidence,
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
          email_alert("stoploss buy "+price.toFixed(2)+" "+btc.toFixed(5)+"btc")
          inventory.usd.price = price*(1-(config.mtgox.fee_percentage/100))
          inventory.btc.amount = btc*inventory.usd.price
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
    json_log({msg: "buy aborted due to lag.", lag_confidence:lag_confidence,
                                               lag_secs:lag_secs,
                                               sell_price: sell_price})
  }
}

function low_lag(){
  return lag_confidence == true && (lag_secs < config.quant.max_lag)
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
  console.log('--order info--')
  mtgox.query('/1/generic/orders', function(error, result){
    console.log('--got info--')
    if(error){
      console.log(error)
    } else {
      result.forEach(function(e){
        console.log(e.type+' '+e.price.display+' '+e.amount.display)
      })
    }
  })
}

function json_log(o){
  var msg = JSON.stringify(o)+"\n"
  var display_msg = moment().format("ddd HH:MM:ss")+" "+msg
  var log_msg = moment().format()+" "+msg
  process.stdout.write(display_msg)
  fs.appendFile('act.log', log_msg)
}

function deadman_switch(){
  var last_msg_delay = (new Date() - last_msg_time)/1000
  if(last_msg_delay > 30) {
    json_log({msg: "deadman: mtgox connection not responding!",
              last_msg_delay: last_msg_delay})
    //email_alert("deadman: mtgox not responding! "+last_msg_delay+"s")
  }
}

function freshen_last_msg_time(){
  last_msg_time = new Date()
}

function save_inventory(){
  // reformat numbers
  inventory.btc.amount.amount = parseFloat(inventory.btc.amount.toFixed(8))
  inventory.usd.amount.amount = parseFloat(inventory.usd.amount.toFixed(5))
  json_log({msg:"save_inventory",inventory:inventory})
  fs.writeFileSync("./inventory.json", JSON.stringify(inventory))
}

function email_alert(msg){
  var body = {}
  body.from = config.email.from
  body.to = config.email.to
  body.subject = config.email.server+":"+msg
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
