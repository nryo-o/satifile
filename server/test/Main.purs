module Test.Main where

import Prelude

import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class.Console (log)
import Test.MongoDb as Test.MongoDb

main :: Effect Unit
main = do
  log "Test MongoDb"
  launchAff_ Test.MongoDb.tests
