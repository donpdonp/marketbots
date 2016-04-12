'use strict'
// system
let fs = require('fs')
let path = require('path')

// npm
let request = require('request')

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

console.log('trader')

key_master().then(function (keys) {
  console.log('auth done', keys)
  balance_master(keys)
}, function (err) {
  console.log('auth failed', err)
})

function key_master () {
  return Promise.all(
    Object.keys(config.exchanges).map(function (name) {
      return new Promise(function (resolve, reject) {
        console.log('vault try', name)
        request.get({ url: config.vault.url + '/v1/secret/exchanges/' + name,
           headers: {'X-Vault-Token': config.vault.token}},
          function (err, result, body) {
            if (err) {
              reject(err)
            } else {
              let response = JSON.parse(body)
              if (response.errors) {
                console.log('vault error', name, response.errors)
                reject(response.errors)
              } else {
                console.log('vault good', name)
                resolve([name, response.data])
              }
            }
          })
      })
    })).then(function (parts) {
      let keys = new Map()
      parts.forEach(function (part) {
        keys[part[0]] = part[1]
      })
      return keys
    })
}

function balance_master (creds) {
  console.log('poloniex balance load')
  poloniex.returnCompleteBalances(
    { key: creds.poloniex.key, secret: creds.poloniex.secret },
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
}

function plan_listen () {
  redis.brpop('wsarbi:plan', 0, function (error, data) {
    console.log('NEW PLAN')
    plan_execute(JSON.parse(data[1]))
  })
}

plan_listen()

function plan_execute (plan) {
  // check plan freshness

  // check balances
  Object.keys(plan).forEach(function (epair) {
    console.log('TRADE', epair)
  })
  plan_listen()
}
