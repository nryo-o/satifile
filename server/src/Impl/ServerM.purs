module Impl.ServerM where

import Prelude

import Control.Monad.Reader (class MonadAsk, class MonadReader, ReaderT, ask, asks, runReaderT)
import HTTPServer as HTTPServer
import Monad.MonadDb (class MonadDb, class MonadDbClient, getClient)
import Monad.MonadHttpServer (class MonadHttpServer, onClose)
import Monad.MonadLog (class MonadLog)
import Monad.MonadPayment (class MonadPayment, getConfig)
import Monad.MonadServer (class MonadServer, Env)
import Monad.MonadTime (class MonadTime)
import Data.Argonaut (class EncodeJson, encodeJson)
import Data.JSDate as Data.JSDate
import Database.MongoDb (Target)
import Database.MongoDb as Database.MongoDb
import Effect.Aff (Aff, Milliseconds(..), delay, launchAff_, parallel, sequential)
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (class MonadEffect, liftEffect)
import Effect.Console as Effect.Console
import Effect.Ref as Ref
import HTTPure as HTTPure
import LnBits as LnBits
import Node.HTTP.Request as Node.HTTP.Request
import Utils (blue, cyan, red)

newtype ServerM a = ServerM (ReaderT Env Aff a)

derive newtype instance Apply ServerM
derive newtype instance Functor ServerM
derive newtype instance Applicative ServerM
derive newtype instance Bind ServerM
derive newtype instance Monad ServerM
derive newtype instance MonadEffect ServerM

instance MonadServer ServerM where
  getEnv = ask
  runParallel s env = parallel $ runServerM s env
  sequential' = liftAff <<< sequential

instance MonadHttpServer ServerM where
  serve port router onStart =
    do
      env <- ask
      void $ liftEffect $ HTTPServer.serve port
        (\request response -> runServerM (router request response) env)
        (launchAff_ $ runServerM onStart env)

  errorResponse = HTTPure.internalServerError
  okResponse = HTTPure.ok
  ok' = HTTPure.ok'
  toBuffer = liftAff <<< HTTPure.toBuffer
  sleep = liftAff <<< delay

  onClose req handler =
    do
      env <- ask
      liftEffect $ Node.HTTP.Request.onCloseImpl req (launchAff_ $ runServerM handler env)

  getClosedRef req =
    do
      ref <- liftEffect $ Ref.new false
      onClose req (liftEffect $ Ref.write true ref)
      pure ref

  isClosed = liftEffect <<< Ref.read

derive newtype instance MonadReader Env ServerM
derive newtype instance MonadAsk Env ServerM

instance MonadLog ServerM where
  debug str = liftEffect $ Effect.Console.debug $ cyan "debug: " <> str
  error str = liftEffect $ Effect.Console.error $ red "error: " <> str
  info str = liftEffect $ Effect.Console.info $ blue "info: " <> str

derive newtype instance MonadAff ServerM

instance MonadDbClient ServerM where
  getClient = asks _.mongodbClient

instance MonadDb ServerM where
  close = do
    client <- getClient
    liftAff $ Database.MongoDb.close client

  findOne target query = do
    client <- getClient
    liftAff $ Database.MongoDb.findOne client target (encodeJson query)

  findMany target query = do
    client <- getClient
    liftAff $ Database.MongoDb.findMany client target (encodeJson query)

  insertOne :: forall doc. EncodeJson doc => Target -> doc -> ServerM String
  insertOne target doc = do
    client <- getClient
    liftAff $ Database.MongoDb.insertOne client target (encodeJson doc)

  updateOne target query update = do
    client <- getClient
    liftAff $ Database.MongoDb.updateOne client target (encodeJson query) (encodeJson update)

instance MonadPayment ServerM where
  getConfig = asks _.lnbits
  createInvoice invoiceRequest = do
    cfg <- getConfig
    liftAff $ LnBits.createInvoice cfg invoiceRequest

  -- checkPayment :: forall d. DecodeJsonField d => String -> ServerM (GetPaymentResponse {})
  checkPayment hash = do
    cfg <- getConfig
    liftAff $ LnBits.getPayment cfg hash

instance MonadTime ServerM where
  getCurrentTime = liftEffect $ Milliseconds <$> Data.JSDate.getTime <$> Data.JSDate.now

-- Run

runServerM :: forall a. ServerM a -> Env -> Aff a
runServerM (ServerM m) = runReaderT m