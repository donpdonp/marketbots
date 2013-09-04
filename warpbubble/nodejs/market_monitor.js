var nanomsg = require('nanomsg')
var redis = require('redis').createClient(),
    redis_sub = require('redis').createClient()

var db = require('./db.js')
db.setup(redis)

var wb_channel = 'warp_bubble'

redis_sub.on("subscribe", function (channel, count) {
  console.log('subscribed to '+channel)
})

redis_sub.on('message', function(channel, data){
  var packet = JSON.parse(data)
  switch(packet.action){
    case 'setup':
      setup(packet)
      break;
    case 'time':
      time(packet)
      break;
  }
})

redis_sub.subscribe(wb_channel)
//redis.publish(wb_channel, '{"action":"setup"}')

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
  console.log("time! "+JSON.stringify(packet))
  Object.keys(exchange_roster).forEach(function(exchange_name){
    var exchange = exchange_roster[exchange_name]
    older_than(exchange, 60, function(){
      poll(exchange)
    })
  })
}


function older_than(exchange, max_age, cb){
  var age;
  if(exchange.time){
    age =  exchange.time - (new Date())
  } else {
    age = 1000
  }
  if(age > max_age) {
    cb()
  }
}

function poll(exchange){
  console.log("polling "+exchange["name"])
}