"strict on"
var fs = require('fs')
var moment = require('moment')
var mtgox = require('mtgox-orderbook')
var nodemailer = require("nodemailer")

var pkg = require('./package.json')
var config = JSON.parse(fs.readFileSync("./config.json"))

mtgox.setup('websocket', config.mtgox)
//mtgox.setup('pubnub', config.mtgox)

mtgox.on('connect', function(trade){
  json_log({msg: "connected to mtgox"})
  order_info()
  mtgox.unsubscribe('depth')
  mtgox.unsubscribe('ticker')
  mtgox.unsubscribe('trades')
  setInterval(function(){order_info();console.log("-*-")}, 9000)
})

mtgox.on('disconnect', function(trade){
  json_log({msg: "disconnected to mtgox"})
})

mtgox.on('subscribe', function(sub){
  console.log('subscribed '+sub)
})

mtgox.on('unsubscribe', function(sub){
  console.log('unsubscribed '+sub)
})

mtgox.on('message', function(message){
  //payload = (message.op == 'private') ? message.private : message[message.op]
  //console.log('msg '+ JSON.stringify(payload))
})

mtgox.on('ticker', function(tick){
  console.dir('got tick')
})

mtgox.on('remark', function(remark){
  console.dir(remark)
})

mtgox.on('lag', function(lag){
  console.dir('got lag')
})


function order_info(){
  mtgox.call('private/info', {}, function(error, result){
    if(error){
      console.log('** private/info error!!')
      json_log({error:error, params: result})
    } else {
      json_log({login:result.Login, rights: result.Rights})
      json_log({btc:result.Wallets.BTC.Balance.display_short,
                usd:result.Wallets.USD.Balance.display_short})
    }
  })
  mtgox.call('private/idkey', {}, function(error, channel_key){
    mtgox.subscribe(channel_key)
  })

  mtgox.call('private/orders', {}, function(error, result){
    if(error){
      console.log('** private/orders error!!')
      json_log({error:error, params: result})
    } else {
      json_log({orders:(result.length+' open mtgox orders')})
      result.forEach(function(e){
        json_log({open_order:e.type+" "+e.amount.display_short+" "+e.price.display_short})
      })
      if(result.length > 1) {
        console.log('too many open orders. halt!')
        process.exit()
      }
    }
  })

}

function order_status(oid){
  mtgox.query('/1/generic/order/result', function(error, result){
    if(error){
      console.log('** order/result error!!')
      console.dir(error)
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

/* CONNECT TO MTGOX */
mtgox.connect('usd')
