module.exports = new (function(){
  var storage

  this.setup = function(slib){
    storage = slib
  }

  this.get = function(key, cb){
    storage.get(key, function(err, value){cb(JSON.parse(value))})
  }

  this.set = function(key, value){
    return storage.set(key, JSON.stringify(value))
  }
})
