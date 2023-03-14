module Database.MongoDb where

import Prelude

import Control.Promise (Promise)
import Control.Promise as Promise
import Effect (Effect)
import Effect.Aff (Aff)

type Target = { db :: String, collection :: String }

type Query :: forall k. k -> k
type Query q = q

type Document :: forall k. k -> k
type Document d = d

type Update :: forall k. k -> k
type Update d = d

type Config = String

foreign import data Client :: Type

foreign import connect_ :: Config -> Effect (Promise Client)
foreign import close_ :: Client -> Effect (Promise Unit)

-- | Given a config, connect to a mongo client
connect :: Config -> Aff Client
connect = Promise.toAffE <<< connect_

-- | Given a client, close it's connection
close :: Client -> Aff Unit
close = Promise.toAffE <<< close_

-- MongoDb function

foreign import findOne_ :: forall q b. Client -> Target -> Query q -> Effect (Promise b)
foreign import findMany_ :: forall q b. Client -> Target -> Query q -> Effect (Promise b)
foreign import insertOne_ :: forall d. Client -> Target -> Document d -> Effect (Promise String)
foreign import updateOne_ :: forall q u d. Client -> Target -> Query q -> Update u -> Effect (Promise d)

findOne :: forall q document. Client -> Target -> Query q -> Aff document
findOne = toAffEFn3 findOne_

findMany :: forall q document. Client -> Target -> Query q -> Aff document
findMany = toAffEFn3 findMany_

insertOne :: forall d. Client -> Target -> Document d -> Aff String
insertOne = toAffEFn3 insertOne_

updateOne :: forall query update document. Client -> Target -> Query query -> Update update -> Aff document
updateOne = toAffEFn4 updateOne_

-- Util

toAffEFn3 :: forall fn a b c. (fn -> a -> b -> Effect (Promise c)) -> fn -> a -> b -> Aff c
toAffEFn3 fn a b c = Promise.toAffE $ fn a b c

toAffEFn4 :: forall a b c d e. (a -> b -> c -> d -> Effect (Promise e)) -> a -> b -> c -> d -> Aff e
toAffEFn4 fn a b c d = Promise.toAffE $ fn a b c d