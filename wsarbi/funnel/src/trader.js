"use strict"
// system
let fs = require('fs')

// npm
let request = require('request')

// config
let config = JSON.parse(fs.readFileSync(__dirname+'/../../config.json'))

// Exchanges
let bitfinex = require('bitfinex-api-node');
let poloniex = require('plnx')
let krakenClient = require('kraken-api')
var kraken = new krakenClient(config.exchanges.kraken.key,
                              config.exchanges.kraken.secret)

// Redis
let redis = require('redis').createClient()

let balances = {}

console.log('trader')

console.log('poloniex balance load')
let creds = config.exchanges.poloniex
poloniex.returnCompleteBalances({ key: creds.key, secret: creds.secret }, function(err, data) {
  if(!err) {
    Object.keys(data).forEach(function(currency){
      let money = data[currency]
      if(money.available > 0) {
        console.log('poloniex', currency, money)
      }
    })
  } else {
    console.log('poloniex', err, data);
  }
});

console.log('kraken balance load')
kraken.api('Balance', null, function(error, data) {
  console.log('kraken', error, data)
})
kraken.api('OpenOrders', null, function(error, data) {
  console.log('kraken', error, data)
})

