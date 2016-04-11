'use strict'
// system
let fs = require('fs')
let path = require('path')

// npm
//let request = require('request')

// config
let config = JSON.parse(fs.readFileSync(path.join(__dirname, '/../../config.json')))

// Exchanges
let Bitfinex = require('bitfinex-api-node').APIRest
var bitfinex = new Bitfinex(config.exchanges.bitfinex.key,
  config.exchanges.bitfinex.secret)
let poloniex = require('plnx')
let Kraken = require('kraken-api')
var kraken = new Kraken(config.exchanges.kraken.key,
  config.exchanges.kraken.secret)

// Redis
let redis = require('redis').createClient()

let balances = new Map()

console.log('trader')

console.log('poloniex balance load')
let creds = config.exchanges.poloniex
poloniex.returnCompleteBalances(
  { key: creds.key, secret: creds.secret },
  function (err, data) {
    if (!err) {
      Object.keys(data).forEach(function (currency) {
        let money = data[currency]
        if (money.available > 0) {
          console.log('poloniex', currency, money)
        }
      })
    } else {
      console.log('poloniex', err, data)
    }
  })

console.log('kraken balance load')
kraken.api('Balance', null, function (error, data) {
  console.log('kraken', error, data)
})
kraken.api('OpenOrders', null, function (error, data) {
  console.log('kraken', error, data)
})

console.log('bitfinex balance load')
bitfinex.wallet_balances(function (error, balances) {
  console.log('bitfinex', error, balances)
})
bitfinex.active_orders(function (error, orders) {
  console.log('bitfinex', error, orders)
})

function plan_listen () {
  redis.brpop('wsarbi:plan', 0, function (error, data) {
    console.log('NEW PLAN')
    plan_execute(JSON.parse(data[1]))
  })
}

plan_listen()

function plan_execute (plan) {
  // check balances
  Object.keys(plan).forEach(function (epair) {
    console.log('TRADE', epair)
  })
  plan_listen()
}
