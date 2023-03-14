module Test.MongoDb where

import Prelude

import Monad.MonadDb (close, findMany, findOne, insertOne, updateOne)
import Monad.MonadLog (info)
import Monad.MonadServer (class MonadServer)
import Crypto (randomBytesString)
import Data.Array (length)
import Database.MongoDb (connect)
import Effect.Aff (Aff)
import Effect.Aff.Class (liftAff)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Impl.ServerM (runServerM)
import LnBits (testConfig)

tests :: Aff Unit
tests = do
  mongodbClient <- connect "mongodb://localhost:27017"
  runServerM server { mongodbClient, lnbits: testConfig, maxFileSize_mb: 2 }
  pure unit

type SampleDoc =
  { id :: String
  , string :: String
  , number :: Number
  , int :: Int
  , subdocument ::
      { a :: String
      , b :: String
      }
  , array :: Array Int
  , bool :: Boolean
  }

sampleDocWithId :: String -> SampleDoc
sampleDocWithId id =
  { id
  , string: "a string"
  , number: 1.123
  , int: 1
  , subdocument: { a: "a", b: "b" }
  , array: [ 1, 2, 3 ]
  , bool: true
  }

server :: forall m. MonadServer m => m Unit
server = do
  uuid <- liftAff $ randomBytesString (128 / 8)

  let
    env = { db: "purs", collection: "purr" }
    sampleDoc = sampleDocWithId uuid

  info $ "Given a record r = " <> show sampleDoc

  info "Run insertOne"
  void $ insertOne env sampleDoc
  void $ insertOne env sampleDoc
  void $ insertOne env sampleDoc

  info "Run findOne"
  doc <- findOne env { id: sampleDoc.id } :: m SampleDoc

  info "Assert that both are equal"
  liftEffect $ when (doc /= sampleDoc) (throw "Assertion that doc and sampleDoc are equal failed")

  info "Run updateOne"
  updated <- updateOne env { id: doc.id } { "$set": { bool: false } } :: m SampleDoc

  liftEffect $ when (updated.bool /= false) (throw "Assertion that updated.bool is false failed")

  info "Find many"
  res <- findMany env { id: doc.id } :: m (Array SampleDoc)

  liftEffect $ when (length res /= 3) (throw "Find many errored")

  close
