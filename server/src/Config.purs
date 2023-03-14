module Config where

import Prelude

import Control.Monad.Error.Class (liftEither)
import Effect (Effect)
import Effect.Exception (error)
import LnBits as LnBits
import Node.Encoding (Encoding(..))
import Node.FS.Sync (readTextFile)
import Utils (mapLeft)
import Yaml as Yaml

type Config =
  { mongodbUrl :: String
  , lnbits :: LnBits.Config
  , maxFileSize_mb :: Int
  }

getConfig :: Effect Config
getConfig = do
  yamlTest <- readTextFile UTF8 "config.yaml"
  liftEither $ mapLeft (error <<< show) $ Yaml.parse yamlTest
