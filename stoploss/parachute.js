"strict on"
var fs = require('fs')
var moment = require('moment')
var Mtgoxjs = require('mtgox')
var mtgoxob = require('mtgox-orderbook')
var nodemailer = require("nodemailer")

var pkg = require('./package.json')
var config = JSON.parse(fs.readFileSync("./config.json"))
var mtgox = new Mtgoxjs(config.mtgox)

// lag vars
var lag_secs = 0
var last_msg_time
var lag_confidence = false
var deadman_interval_id

// safetys
var big_button = true

// actions
var sell_price = config.quant.fixed_price
var buy_price = sell_price*(1+config.quant.stop_loss)
var low_water = buy_price
var last_tick

json_log({msg:"*** STARTING ***",version: pkg.version})
json_log({config: config.quant})
json_log({sold_at: "$"+sell_price.toFixed(2),
          abort_at: "$"+buy_price.toFixed(2),
          low_water: "$"+low_water.toFixed(2)})

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


mtgoxob.on('ticker', function(tick){
  last_tick = tick
  var ask_price = parseFloat(tick.sell.value)

  var tick_delay_s = (new Date() - (tick.now/1000))/1000
  var delay_msg = tick_delay_s.toFixed(1)+"s"
  var progress = ((sell_price-ask_price)/sell_price)*100

  if(ask_price < low_water) { set_low_water(ask_price) }

  json_log({order_book:"*",
            ask:last_tick.sell.display,
            progress: progress.toFixed(2)+"%",
            lag: delay_msg
            })

  if(low_lag(tick_delay_s)) {
    trade_decision(ask_price)
  } else {
    json_log({alert: "trade decision blocked by lag"})
  }

})

/*
mtgoxob.on('trade', function(trade){
  if(trade.price_currency == 'USD') {
    var msg = ""
    var trade_delay = (new Date() - (trade.date*1000))/1000

    if(trade_delay > 3){
      msg = msg + '(delay '+trade_delay.toFixed(1)+'s) '
    }

    json_log({trade:"*",
              price: '$'+trade.price.toFixed(2),
              amount: ' x'+trade.amount.toFixed(1)})
    last_trade = trade
  }
})
*/

function trade_decision(price){
  if(big_button){
    if(price > buy_price) {
      // abort
      json_log({swing:"ABORTING over $"+buy_price.toFixed(2)})
      buy(price)
    } else {
      if(price < sell_price*(1-config.quant.buy_security)) {
        // swing
        var buy_swing = low_water*(1+config.quant.swing_gap)
        if(price > buy_swing){
          json_log({swing:"BUYING over $"+buy_swing.toFixed(2), low_water: low_water})
          // profit
          buy(price)
        } else {
          json_log({swing:"ARMED. waiting above $"+buy_swing.toFixed(2),
                    low_water: low_water, sold_at: sell_price, buy_price: buy_price})
        }
      } else {
        json_log({swing:"dead between sell and abort.", low_water: low_water,
                  sold_at: sell_price, abort_price: buy_price})
      }
    }
  } else {
    json_log({alert:"Buy "+price+" blocked by big button"})
  }
}

function set_high_ask(price){
  json_log({msg:"new high ask "+price})
  high_ask = price
}

function set_low_water(price){
  json_log({msg:"new low_water "+price})
  low_water = price
}

function sell(price){
  var btc = config.quant.fixed_quantity
  json_log({msg: "SELL",
                         price: price,
                         amount: btc,
                         lag: lag_secs})
  add_order('ask', price, btc)
  email_alert("sell "+price.toFixed(2)+" x"+btc)
}

function buy(price){
  var safe_price = price*(1+config.quant.buy_security)
  var btc = config.quant.fixed_quantity*(config.quant.fixed_price/safe_price)
  json_log({msg: "BUY",
                        safety_adjusted_price: safe_price.toFixed(2),
                        profit_adjusted_amount: btc.toFixed(5),
                        lag: lag_secs})
  add_order('bid', safe_price, btc)
  big_button = false

  var email_msg = "stoploss buy "+safe_price.toFixed(2)+" x"+btc.toFixed(2)+"btc."
  if(price > buy_price) {
    email_msg = "Abort "+email_msg
  }
  email_alert(email_msg)
}

mtgoxob.on('lag', function(lag){
  if (lag.qid) {
    var lag_age_secs = lag.age/1000000
    var delay_secs = (new Date() - new Date(lag.stamp/1000))/1000
    if (delay_secs < 30) {
      lag_secs = lag_age_secs
      if (lag_secs > config.quant.max_lag) {
        console.log('no confidence in lag '+ lag_secs + "s delay: "+delay_secs+"s.")
        lag_confidence = false
      } else {
        if(lag_confidence == false) {
          console.log('reconfidence in lag '+ lag_secs + "s delay: "+delay_secs+"s.")
        }
        lag_confidence = true
      }
    } else {
      lag_confidence = false
      console.log('no confidence in delayed lag msg of '+ lag_secs + "s with delay: "+delay_secs+"s.")
    }
  } else {
    // lag idle
    if(lag_confidence == false) {
      console.log('reconfidence in idle lag')
    }
    lag_secs = 0
    lag_confidence = true
  }
})

function low_lag(secs){
  return lag_confidence == true && (lag_secs < config.quant.max_lag) && (secs < config.quant.max_lag)
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
                    order_info()
                  })
    */
    order.query = '/1/BTCUSD/order/add'
    json_log(order)
    order_info()
  }
}

function order_info(){
  console.log('querying open orders...')
  mtgox.query('/1/generic/orders', function(error, result){
    if(error){
      json_log(error)
    } else {
      console.log(result.length+' open mtgox orders')
      result.forEach(function(e){
        json_log({open_order:e.type+" "+e.amount.display_short+" "+e.price.display_short})
      })
      if(result.length > 1) {
        console.log('too many open orders. halt!')
        process.exit()
      }
    }
  })

  mtgox.query('/1/generic/private/info', function(error, result){
    if(error){
      //json_log(error)
    } else {
      json_log({btc:result.Wallets.BTC.Balance.display_short,
                usd:result.Wallets.USD.Balance.display_short})
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
