'use strict'
// system
let fs = require('fs')
let path = require('path')
let os = require('os')

// npm
let request = require('request')
let nodemailer = require('nodemailer')
let mailer = nodemailer.createTransport()

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
  let balances = new Map()

  balance_master(keys, balances)
  plan_listen(balances)
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

function balance_master (creds, balances) {
  for (let exchange in creds) {
    balances[exchange] = new Map([['fresh', false]])
  }
  console.log('poloniex balance load')
  poloniex.returnCompleteBalances(
    creds.poloniex,
    function (err, data) {
      if (!err) {
        balances.poloniex.btc = data['BTC'].available
        balances.poloniex.eth = data['ETH'].available
        console.log('poloniex', 'btc', balances.poloniex.btc, 'eth', balances.poloniex.eth)
        balances.poloniex.fresh = true
      } else {
        console.log('poloniex', err, data)
      }
    })

  let kraken = new Kraken(creds.kraken.key, creds.kraken.secret)
  console.log('kraken balance load')
  kraken.api('Balance', null, function (error, data) {
    console.log('kraken balance', error, data)
    if (data.result.XETH) {
      balances.kraken.eth = data.result.XETH
    } else {
      balances.kraken.eth = 0
    }
    if (data.result.BTC) {
      balances.kraken.btc = data.result.BTC
    } else {
      balances.kraken.btc = 0
    }
    balances.kraken.fresh = true
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

function plan_listen (balances) {
  redis.brpop('wsarbi:plan', 0, function (error, data) {
    if (error) {
      console.log('redis plan error!')
    } else {
      console.log('NEW PLAN RECEIVED')
      plan_execute(JSON.parse(data[1]), balances)
    }
  })
}

function plan_execute (plan, balances) {
  // check plan freshness

  // check balances
  Object.keys(plan).forEach(function (epair) {
    let order = plan[epair]
    console.log(epair, order)
    let exs = epair.split(':')
    let aske = balances[exs[0]]
    let bide = balances[exs[1]]

    let alert
    alert = 'Order ' + epair + '\n'
    alert += JSON.stringify(order) + '\n'
    if (aske.fresh && bide.fresh) {
      alert += '  ask balance ' + aske.fresh + ' ' + aske.btc + 'btc' + '\n'
      alert += '  bid balance ' + bide.fresh + ' ' + bide.btc + 'etc' + '\n'
      alert += '  balances FRESH' + '\n'
      let btc_amount = order['amount'] * 420 // placeholder
      let btc_spend = Math.min(btc_amount, aske.btc)
      alert += '  btc_spend ' + btc_spend + '\n'
      let eth_spend = Math.min(order['amount'], bide.eth)
      alert += '  eth_spend ' + eth_spend + '\n'
    } else {
      alert += 'error missing balances' + JSON.stringify(exs) + '\n'
    }
    email(alert)
  })

  // play it again, sam.
  plan_listen(balances)
}

function email (text) {
  let email = {
    from: config.email.from, // sender address
    to: config.email.to, // list of receivers
    subject: os.hostname() + ' plan execute',
    text: text
  }
  mailer.sendMail(email, function (error, info) {
    if (error) {
      return console.log(error)
    }
    console.log('Message sent: ', info)
  })
}
