module Monad.MonadTime where

import Prelude

import Data.Time.Duration (Milliseconds)

class Monad m <= MonadTime m where
  getCurrentTime :: m Milliseconds