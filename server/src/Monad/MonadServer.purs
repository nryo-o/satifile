module Monad.MonadServer where

import Prelude

import Monad.MonadDb (class MonadDb)
import Monad.MonadHttpServer (class MonadHttpServer)
import Monad.MonadLog (class MonadLog)
import Monad.MonadPayment (class MonadPayment)
import Monad.MonadTime (class MonadTime)
import Database.MongoDb (Client)
import Effect.Aff (ParAff)
import Effect.Aff.Class (class MonadAff)
import Effect.Class (class MonadEffect)
import LnBits as LnBits

type Env =
  { mongodbClient :: Client
  , lnbits :: LnBits.Config
  , maxFileSize_mb :: Int
  }

class
  ( Monad m
  , MonadLog m
  , MonadEffect m
  , MonadAff m
  , MonadHttpServer m
  , MonadDb m
  , MonadPayment m
  , MonadTime m
  ) <=
  MonadServer m
  where
  getEnv :: m Env
  sequential' :: forall a. ParAff a → m a
  runParallel :: forall a. m a → Env -> ParAff a

