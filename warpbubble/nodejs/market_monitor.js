var nanomsg = require('nanomsg')
var redis = require('redis').createClient(),
    redis_sub = require('redis').createClient()
var request = require('request')

var db = require('./db.js')
db.setup(redis)

var wb_channel = 'warp_bubble'

redis_sub.on("subscribe", function (channel, count) {
  console.log('subscribed to '+channel)
})

redis_sub.on('message', function(channel, data){
  var packet = JSON.parse(data)
  switch(packet.action){
    case 'market_monitor setup':
      setup(packet)
      break;
    case 'time':
      time(packet)
      break;
  }
})

redis_sub.subscribe(wb_channel, function(channel, count){
  publish({"action":"market_monitor setup"})
})

function publish(msg){
  redis.publish(wb_channel, JSON.stringify(msg))
}

var exchange_roster = {}

function setup(packet){
  console.log('** Setup')
  db.get('exchange_list', function(value){
    value.forEach(function(exchange_name){
      exchange_roster[exchange_name] = {name:exchange_name}
    })
    console.dir(exchange_roster)
  })
}

function time(packet){
  //console.log("time! "+JSON.stringify(packet))
  Object.keys(exchange_roster).forEach(function(exchange_name){
    var exchange = exchange_roster[exchange_name]
    older_than(exchange, 60, function(age){
      poll(exchange, function(){
        var db_key = 'warpbubble:'+exchange_name
        console.log(exchange.name+" "+exchange.time+
                    " ask count "+exchange.depth.asks.length+
                    " bid count "+exchange.depth.bids.length)
        db.set(db_key, JSON.stringify(exchange))
        publish({"action":"exchange ready", "payload": {"name":exchange.name}})
      })
    })
  })
}


function older_than(exchange, max_age, cb){
  var age;
  if(exchange.time){
    age =  ((new Date()) - exchange.time)/1000
  } else {
    age = 300
  }
  console.log(exchange.name+" "+(max_age - age).toFixed(1)+" secs to go")
  if(age > max_age) {
    cb(age)
  }
}

function poll(exchange, cb){
  poll_levers[exchange.name].apply(exchange, [function(depth){
    exchange.depth = depth
    exchange.time = new Date()
    cb()
  }])
}

var poll_levers = {
  btce: function(cb){
    var url = "https://btc-e.com/api/2/ltc_btc/depth"
    var depth = json_get(url, cb)

  },
  cryptsy: function(cb){
    var url = "http://pubapi.cryptsy.com/api.php?method=orderdata"
    var data = json_get(url, function(depth){
      depth = {"asks":depth.return.LTC.sellorders,
               "bids":depth.return.LTC.buyorders}
      depth.asks = depth.asks.map(function(offer){
        return [parseFloat(offer.price), parseFloat(offer.quantity)]
      })
      depth.bids = depth.bids.map(function(offer){
        return [parseFloat(offer.price), parseFloat(offer.quantity)]
      })
      cb(depth)
    })
  }
}

function json_get(url, cb){
  request(url, function (error, response, body) {
    var data;
    if(error){
      console.log('!! Error')
      console.dir(error)
    } else {
      data = JSON.parse(body)
    }
    cb(data)
  })
}
