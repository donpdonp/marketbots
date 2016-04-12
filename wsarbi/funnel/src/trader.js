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
let poloniex = require('plnx')
let Kraken = require('kraken-api')

// Redis
let redis = require('redis').createClient()

console.log('trader')

key_master().then(function (keys) {
  balance_master(keys)
  plan_listen()
}, function (err) {
  console.log('auth failed', err)
})

function key_master () {
  return Promise.all(
    Object.keys(config.exchanges).map(function (name) {
      return new Promise(function (resolve, reject) {
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
  let balances = new Map()
  for (let exchange in creds) {
    balances[exchange] = {}
  }
  console.log('poloniex balance load')
  poloniex.returnCompleteBalances(
    creds.poloniex,
    function (err, data) {
      if (!err) {
        balances.poloniex.btc = data['BTC'].available
        balances.poloniex.eth = data['ETH'].available
        console.log('poloniex', 'btc', balances.poloniex.btc, 'eth', balances.poloniex.eth)
      } else {
        console.log('poloniex', err, data)
      }
    })

  let kraken = new Kraken(creds.kraken.key, creds.kraken.secret)
  console.log('kraken balance load')
  kraken.api('Balance', null, function (error, data) {
    console.log('kraken balance', error, data)
    if (data.result.btc) {
      balances.kraken = data.result.btc
    } else {
      balances.kraken = 0
    }
    console.log('kraken', 'btc', balances.kraken.btc, 'eth', balances.kraken.eth)
  })
  console.log('kraken order load')
  kraken.api('OpenOrders', null, function (error, data) {
    console.log('kraken orders', error, data)
  })

  let bitfinex = new Bitfinex(creds.bitfinex.key, creds.bitfinex.secret)
  console.log('bitfinex balance load')
  bitfinex.wallet_balances(function (error, balances) {
    console.log('bitfinex', error, balances)
  })
  console.log('bitfinex order load')
  bitfinex.active_orders(function (error, orders) {
    console.log('bitfinex', error, orders)
  })
}

function plan_listen () {
  redis.brpop('wsarbi:plan', 0, function (error, data) {
    if (error) {
      console.log('redis plan error!')
    } else {
      console.log('NEW PLAN')
      plan_execute(JSON.parse(data[1]))
    }
  })
}

function plan_execute (plan) {
  // check plan freshness

  // check balances
  Object.keys(plan).forEach(function (epair) {
    console.log('TRADE', epair)
  })

  // play it again, sam.
  plan_listen()
}
