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
let bittrex = require('node.bittrex.api')

// Redis
let redis = require('redis').createClient()

let Influx = require('influx')
let influx = Influx(config.influx)

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
  bitfinex.wallet_balances(function (error, data) {
    console.log('bitfinex', error, data)
    if (error) {
      //
    } else {
      balances.bitfinex.btc = data['btc'] || 0
      balances.bitfinex.eth = data['eth'] || 0
      balances.bitfinex.fresh = true
      console.log('bitfinex', 'btc', balances.bitfinex.btc, 'eth', balances.bitfinex.eth)
    }
  })
  console.log('bitfinex order load')
  bitfinex.active_orders(function (error, orders) {
    console.log('bitfinex', error, orders)
  })

  console.log('bittrex balance load')
  bittrex.options({
    'apikey': creds.bittrex.key,
    'apisecret': creds.bittrex.secret })
  bittrex.getbalances(function (data) {
    if (data.success) {
      let btc_data = data.result.filter(function (dat) { return dat.Currency === 'BTC' })[0]
      if (btc_data) {
        balances.bittrex.btc = btc_data.Available
      } else {
        balances.bittrex.btc = 0
      }
      let eth_data = data.result.filter(function (dat) { return dat.Currency === 'ETH' })[0]
      if (eth_data) {
        balances.bittrex.eth = eth_data.Available
      } else {
        balances.bittrex.eth = 0
      }
      balances.bittrex.fresh = true
      console.log('bittrex', 'btc', balances.bittrex.btc, 'eth', balances.bittrex.eth)
    }
  })
}

function plan_listen (balances) {
  redis.brpop('wsarbi:plan', 0, function (error, data) {
    if (error) {
      console.log('redis plan error!')
    } else {
      console.log(new Date(), 'NEW PLAN')
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
      let profit_ratio = (order['sell_price'] - order['buy_price']) / order['buy_price']
      let profit = order['amount'] * profit_ratio
      let profit_fee_ratio = profit_ratio - 0.005
      let profit_fee = order['amount'] * profit_fee_ratio
      if (profit_ratio > 0) {
        if (profit_fee > 1) {
          alert += '  profit ratio ' + profit_ratio.toFixed(4) + ' minus 0.5% ' + profit_fee_ratio.toFixed(4) + '\n'
          alert += '  ask balance ' + aske.fresh + ' ' + aske.btc + 'btc' + '\n'
          alert += '  bid balance ' + bide.fresh + ' ' + bide.eth + 'eth' + '\n'
          alert += '  balances min' + order['amount'] + ', ' + (aske.btc * 0.020).toFixed(4) +
                   ', ' + bide.eth + '\n'
          let eth_spend = Math.min(order['amount'], aske.btc * 0.020, bide.eth)
          let btc_spend = eth_spend * 420 // placeholder
          alert += '  btc_spend ' + btc_spend.toFixed(4) + '\n'
          alert += '  eth_spend ' + eth_spend.toFixed(1) + ' (min win)\n'
          alert += '  eth_profit ' + eth_spend * profit_fee_ratio + '\n'

          email(os.hostname() + ' total ' + profit.toFixed(1) + 'eth', alert)
        }
        console.log('influxdb', 'pairs', profit, {pair: epair.replace(':', '')})
        influx.writePoint('pairs', profit, {pair: epair.replace(':', '')}, function (err, response) {
          if (err) { console.log(err) }
        })
      }
    } else {
      alert += 'error missing/unfresh balances' + JSON.stringify(exs) + '\n'
      console.log(alert)
    }
  })

  // play it again, sam.
  plan_listen(balances)
}

function email (subject, text) {
  let email = {
    from: config.email.from, // sender address
    to: config.email.to, // list of receivers
    subject: subject,
    text: text
  }
  mailer.sendMail(email, function (error, info) {
    if (error) {
      return console.log(error)
    }
    console.log('Message sent: ', info.accepted)
  })
}
