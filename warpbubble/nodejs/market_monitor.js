var redis = require('redis').createClient(),
    redis_sub = require('redis').createClient()
var request = require('request')
var xml = require('xml2js').parseString;

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
      exchange_roster[exchange_name] = {name:exchange_name,
                                        time: new Date("1970")}
    })
    console.dir(exchange_roster)
  })
}

function time(packet){
  //console.log("time! "+JSON.stringify(packet))
  Object.keys(exchange_roster).forEach(function(exchange_name){
    var exchange = exchange_roster[exchange_name]
    older_than(exchange, 60, function(age){
      if(age){
        poll(exchange, function(depth){
          if(depth){
            var db_key = 'warpbubble:'+exchange_name
            console.log(exchange.name+" "+exchange.time+
                        " ask count "+depth.asks.length+
                        " bid count "+depth.bids.length)
            publish({"action":"depth ready", "payload": {"name":exchange.name,
                                                            "depth":depth,
                                                            "at":exchange.time}})
          } else {
            console.log("!! "+exchange.name+" update failed")
          }
        })
      }
    })
  })
}


function older_than(exchange, max_age, cb){
  var age;
  if(!exchange.in_progress){
    age =  ((new Date()) - exchange.time)/1000
    if(age > max_age) {
      console.log(exchange.name+" firing!")
      exchange.time = exchange.in_progress = new Date()
      cb(age)
    } else {
      console.log(exchange.name+" waiting. "+(max_age - age).toFixed(1)+" secs to go")
    }
  } else {
    console.log(exchange.name+" blocked. in-progress.")
    cb()
  }
}

function poll(exchange, cb){
  poll_levers[exchange.name].apply(exchange, [function(depth){
    exchange.in_progress = null
    cb(depth)
  }])
}

var poll_levers = {
  mcxnow: function(cb){
    var url = "https://mcxnow.com/orders?cur=LTC"
    request({url:url, timeout:5000}, function (error, response, body) {
      var data;
      var standard_depth;
      if(error){
      } else {
        xml(body, function (err, result) {
          standard_depth = {}
          standard_depth.asks = result.doc.sell[0].o.map(function(offer){
            return [parseFloat(offer.p[0]), parseFloat(offer.c1[0])]
          })
          standard_depth.bids = result.doc.buy[0].o.map(function(offer){
            return [parseFloat(offer.p[0]), parseFloat(offer.c1[0])]
          })
        })
      }
      cb(standard_depth)
    })
  },
  btce: function(cb){
    var url = "https://btc-e.com/api/2/ltc_btc/depth"
    var depth = json_get(url, cb)

  },
  cryptsy: function(cb){
    var url = "http://pubapi.cryptsy.com/api.php?method=orderdata"
    var data = json_get(url, function(depth){
      var standard_depth
      if(depth){
        standard_depth = {"asks":depth.return.LTC.sellorders,
                          "bids":depth.return.LTC.buyorders}
        standard_depth.asks = standard_depth.asks.map(function(offer){
          return [parseFloat(offer.price), parseFloat(offer.quantity)]
        })
        standard_depth.bids = standard_depth.bids.map(function(offer){
          return [parseFloat(offer.price), parseFloat(offer.quantity)]
        })
      }
      cb(standard_depth)
    })
  }
}

function json_get(url, cb){
  request({url:url, timeout:5000}, function (error, response, body) {
    var data;
    if(error){
      console.log('!! Error')
      console.dir(error)
    } else {
      try {
        data = JSON.parse(body)
      } catch (e) {
        console.log("!! JSON error "+url+" "+body.slice(0,80))
      }
    }
    cb(data)
  })
}
