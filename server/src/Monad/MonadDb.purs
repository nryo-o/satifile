module Monad.MonadDb where

import Control.Monad (class Monad)
import Data.Argonaut (class EncodeJson)
import Data.Unit (Unit)
import Database.MongoDb (Client, Document, Query, Target)

class Monad m <= MonadDbClient m where
  getClient :: m Client

class MonadDbClient m <= MonadDb m where
  close :: m Unit
  findOne :: forall q document. EncodeJson q => Target -> Query q -> m document
  findMany :: forall q document. EncodeJson q => Target -> Query q -> m document
  insertOne :: forall doc. EncodeJson doc => Target -> Document doc -> m String
  updateOne :: forall q update document. EncodeJson q => EncodeJson update => Target -> Query q -> Document update -> m document

