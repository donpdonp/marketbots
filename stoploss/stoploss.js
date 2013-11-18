var fs = require('fs')
var moment = require('moment')
var Mtgoxjs = require('mtgox')
var mtgoxob = require('mtgox-orderbook')

var pkg = require('./package.json')
var config = JSON.parse(fs.readFileSync("./config.json"))
var mtgox = new Mtgoxjs(config.mtgox)

// internal vars
var lag_secs = 0
var last_msg_time
var lag_confidence = false
var deadman_interval_id
var last_trade

json_log({msg:"*** STARTING ***",version: pkg.version})
json_log({config: config.quant})

if(!parseFloat(config.quant.trigger_speed) > 0){
  console.log('bad quant.trigger_speed value')
  process.exit()
}

order_info()

mtgoxob.on('connect', function(trade){
  json_log({msg: "connected to mtgox"})
  setTimeout(function(){mtgoxob.subscribe("lag")}, 1000) // trade.lag
  freshen_last_msg_time()
  deadman_interval_id = setInterval(deadman_switch, 5000)
})

mtgoxob.on('disconnect', function(trade){
  json_log({msg: "disconnected to mtgox"})
  clearInterval(deadman_interval_id)
})

mtgoxob.on('subscribe', function(sub){
  //console.log('subscribed '+sub)
})

mtgoxob.on('message', function(sub){
  freshen_last_msg_time()
})

mtgoxob.on('lag', function(lag){
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

mtgoxob.on('trade', function(trade){
  if(trade.price_currency == 'USD') {
    var trade_delay = (new Date() - (trade.date*1000))/1000

    var trade_msg = '$'+trade.price.toFixed(2)+
                    ' x'+trade.amount.toFixed(1)
    var msg = ""
    if(last_trade){
      var pricediff = last_trade.price - trade.price
      msg = msg + '$'+pricediff.toFixed(3)+' '
      var timediff = (new Date(trade.date*1000) - new Date(last_trade.date*1000))/1000.0
      msg = msg + timediff.toFixed(1)+'s. '
      var speed = pricediff / timediff
      msg = msg + speed.toFixed(1)+'$/s '
      if (speed > config.quant.trigger_speed){
        msg = msg + "SPEED MAX! "
      }
    }
    if(trade_delay > 3){
      msg = msg + '(delay '+trade_delay.toFixed(1)+'s) '
    }
    if(lag_secs > 5){
      msg = msg + '(lag '+lag_secs.toFixed(1)+'s) '
    }

    json_log({trade:trade_msg,
              quant: msg})
    last_trade = trade
  }
})

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
          inventory.usd.amount = inventory.btc.price*inventory.btc.amount*(1-(config.mtgox.fee_percentage/100))
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
          profit = (inventory.btc.price-price)*btc
          email_alert("stoploss buy "+price.toFixed(2)+" up from "+lowwater+" x"+btc.toFixed(2)+"btc. profit: $"+profit.toFixed(2))
          inventory.usd.price = price
          inventory.btc.amount = btc*(1-(config.mtgox.fee_percentage/100))
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
  mtgox.query('/1/generic/orders', function(error, result){
    if(error){
      json_log(error)
    } else {
      if(result.length == 0) { console.log('no open mtgox orders') }
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
  var display_msg = moment().format("ddd HH:MM:ss")+" "+msg
  var log_msg = moment().format()+" "+msg
  process.stdout.write(display_msg)
  fs.appendFile('act.log', log_msg)
}

function deadman_switch(){
  var last_msg_delay = (new Date() - last_msg_time)/1000
  if(last_msg_delay > 30) {
    json_log({msg: "deadman: mtgox connection not responding! halting!",
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

/* CONNECT TO MTGOX */
mtgoxob.connect('usd')
