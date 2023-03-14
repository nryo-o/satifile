module Main where

import Prelude

import Config (getConfig)
import Server (server)
import Database.MongoDb (connect)
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Effect.Console (log)
import Impl.ServerM (runServerM)

main :: Effect Unit
main =
  launchAff_ do
    config <- liftEffect $ getConfig
    liftEffect $ log $ "Config: " <> (show config)
    mongodbClient <- connect config.mongodbUrl

    runServerM server
      { mongodbClient
      , lnbits: config.lnbits
      , maxFileSize_mb: config.maxFileSize_mb
      }

