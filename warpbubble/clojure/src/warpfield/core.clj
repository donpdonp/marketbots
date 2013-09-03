(ns warpfield.core
  (:gen-class)
  (:require [clj-http.client :as client])
  )

(defn -main
  "I don't do a whole lot ... yet."
  [& args]
  (println "WarpField starting" )
  (println (client/get "https://data.mtgox.com/api/2/BTCUSD/money/ticker"))
  )
