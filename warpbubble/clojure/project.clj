(defproject warpfield "0.1.0-SNAPSHOT"
  :description "FIXME: write description"
  :url "http://example.com/FIXME"
  :license {:name "Eclipse Public License"
            :url "http://www.eclipse.org/legal/epl-v10.html"}
  :dependencies [[org.clojure/clojure "1.5.1"]
                 [clj-http "0.7.6"]
                 [com.datomic/datomic-free "0.8.4143"]
                ]
  :main warpfield.core
  :profiles {:uberjar {:aot :all}})
