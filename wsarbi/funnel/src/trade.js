// npm
var request = require('request')

// Exchanges
var bitfinex = require('bitfinex-api-node');
var autobahn = require('autobahn');
var poloniex_stream = new autobahn.Connection({
  url: "wss://api.poloniex.com",
  realm: "realm1"
});

// Redis
var redis = require('redis').createClient()

var balances = {}

