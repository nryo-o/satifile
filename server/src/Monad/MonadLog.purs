module Monad.MonadLog where

import Prelude

class MonadLog m where
  info :: String -> m Unit
  debug :: String -> m Unit
  error :: String -> m Unit
