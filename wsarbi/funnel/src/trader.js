"use strict"
// system
let fs = require('fs')

// npm
let request = require('request')

// Exchanges
let bitfinex = require('bitfinex-api-node');
let poloniex = require('plnx')

// Redis
let redis = require('redis').createClient()

// config
console.log()
let config = JSON.parse(fs.readFileSync(__dirname+'/../../config.json'))
let balances = {}

console.log('trader')
let creds = config.exchanges.poloniex
poloniex.returnCompleteBalances({ key: creds.key, secret: creds.secret }, function(err, data) {
  if(!err) {
    Object.keys(data).forEach(function(currency){
      let money = data[currency]
      if(money.available > 0) {
        console.log(currency, money)
      }
    })
  } else {
    console.log(err, data);
  }
});
