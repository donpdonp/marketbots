var nanomsg = require('nanomsg')
var redis_sub = require('redis').createClient(),
    redis_pub = require('redis').createClient()

var wb_channel = 'warp_bubble'

redis_sub.on("subscribe", function (channel, count) {
  console.log('subscribed to '+channel)
})

redis_sub.on('message', function(channel, data){
  var packet = JSON.parse(data)
  console.dir(packet)
})

redis_sub.subscribe(wb_channel)
