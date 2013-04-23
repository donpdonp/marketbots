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
var lowwater = 0.0
var sell_price = 0.0
var lag_secs = 0
var last_msg_time
var lag_confidence = false
var trade_block = false
var deadman_interval_id


json_log({msg:"*** STARTING ***",version: pkg.version, inventory:inventory})
console.log('sell percentage %'+(config.quant.sell_percentage))
process.stdout.write('connecting to mtgox...')

var sockio = socketio.connect(mtgoxob.socketio_url,{
  'try multiple transports': false,
  'connect timeout': 5000
})
var mtsox = mtgoxob.attach(sockio, 'usd')

mtsox.on('connect', function(trade){
  json_log({msg: "connected to mtgox"})
  setTimeout(function(){mtsox.subscribe("lag")}, 1000) // trade.lag
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
  last_msg_time = new Date()
})

mtsox.on('lag', function(lag){
  if (lag.qid) {
    var lag_age_secs = lag.age/1000000
    var delay_secs = (new Date() - new Date(lag.stamp/1000))/1000
    if (delay_secs < 6) {
      lag_confidence = true
      lag_secs = lag_age_secs
      if (lag_secs > 5) {
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

    console.log('trade $'+trade.price.toFixed(2)+
                ' qty. '+trade.amount.toFixed(1)+
                ' highwater '+highwater.toFixed(2)+
                ' sell_price '+sell_price.toFixed(2)+
                ' (delay '+trade_delay.toFixed(0)+'s)')

    if(trade.price > highwater) {
      // price rising
      highwater = trade.price
      sell_price = (highwater * (1-config.quant.sell_percentage/100))
      console.log('new highwater '+highwater.toFixed(2)+
                  ' new sell_price '+sell_price.toFixed(2))
    } else {
      // price dropping
      if(trade.price < sell_price) {
        sell()
      }
    }
  }
})

function sell(){
  if (low_lag()) {
    var sale_away_percentage = sell_price / highwater
    if(sale_away_percentage > 0.5 && sale_away_percentage < 1.5 ) {
      if(inventory.btc >= 0.01){
        if(trade_block == false){
          trade_block = true
          json_log({msg: "SELL", sell_price: sell_price,
                                 amount: inventory.btc,
                                 lag: lag_secs})
          add_order('ask', 'market', inventory.btc)
          email_alert("stoploss SOLD "+sell_price.toFixed(2)+" "+inventory.btc+"btc")
          inventory.btc = 0
          save_inventory()
        } else {
          json_log({msg: "ADD ORDER blocked by flag"})
        }
      } else {
        json_log({msg: "ADD ORDER blocked by low inventory",
                  inventory: inventory})
      }
    } else {
      json_log({msg: "ADD ORDER blocked by crazy price",
                highwater: highwater, sell_price: sell_price})
    }
  } else {
    json_log({msg: "SELL aborted due to lag.", lag_confidence:lag_confidence,
                                               lag_secs:lag_secs,
                                               sell_price: sell_price})
  }
}

function low_lag(){
  return lag_confidence == true && (lag_secs < 5)
}

function add_order(bidask, price, amount){
  json_log({msg: "add order called", bidask: bidask,
                              price: price,
                              amount: amount,
                              lag: lag_secs})

  var price_int = price * 1E5
  var amount_int = amount * 1E8

  if((typeof(price) == 'number' && price > 0) || (price == 'market')){
    var order = { type: bidask,
                  amount_int: amount_int}
    if(price > 0) {
      order.price_int = price_int
    }
    //mtgox.query('/1/BTCUSD/order/add',
    //              {type: 'ask',
    //               amount_int: amount_int },
    //              function(error, result){})
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
  var msg = ""+moment().format()+" "+JSON.stringify(o)+"\n"
  process.stdout.write(msg)
  fs.appendFile('act.log', msg)
}

function deadman_switch(){
  var last_msg_delay = (new Date() - last_msg_time)/1000
  if(last_msg_delay > 30) {
    json_log({msg: "deadman: mtgox connection not responding!",
              last_msg_delay: last_msg_delay})
    email_alert("deadman: mtgox not responding! "+last_msg_delay+"s")
  }
}

function save_inventory(){
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