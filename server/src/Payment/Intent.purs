module Payment.Intent where

import Prelude

import File (getMetadata)
import Monad.MonadHttpServer (errorResponse, getClosedRef, isClosed, okResponse, sleep)
import Monad.MonadLog (info)
import Monad.MonadLog as Log
import Monad.MonadServer (class MonadServer, getEnv, runParallel, sequential')
import Payment (PaymentStatus(..), checkLnBitsPaymentStatus, getPaymentStatus)
import Data.Argonaut (encodeJson, stringify)
import Data.Foldable (oneOf)
import Data.Int (floor)
import Data.Maybe (Maybe(..))
import Data.Time.Duration (class Duration, Milliseconds(..), Minutes(..))
import Effect.Ref (Ref)
import HTTPure (Response)
import Node.HTTP as Node.HTTP
import Utils (toMilliseconds)

-- | A payment intent issued by the client
paymentIntent
  :: forall m
   . MonadServer m
  => Node.HTTP.Request
  -> String
  -> m Response
paymentIntent request fileId =
  do
    closedRef <- getClosedRef request
    env <- getEnv
    sequential' $ oneOf
      [ runParallel (waitForPayment fileId closedRef 0 :: m Response) env
      , runParallel (periodicallyCheckLnBits fileId closedRef 0 :: m Response) env
      ]

-- | A general timeout for our payments
timeout :: Minutes
timeout = Minutes 5.0

-- | Given an interval duration, calculate the amount of reties until timeout
maxRetriesOf :: forall a. Duration a => a -> Int
maxRetriesOf interval =
  floor $ (toMilliseconds timeout) / (toMilliseconds interval)

periodicallyCheckLnBits
  :: forall m
   . MonadServer m
  => String
  -> Ref Boolean
  -> Int
  -> m Response
periodicallyCheckLnBits fileId closedRef cycle =
  do
    info "Periodically checking ln bits..."
    let
      interval = Milliseconds 1000.0
      maxRetries = maxRetriesOf interval

    periodicallyCheckLnBitsRec fileId closedRef cycle maxRetries interval

periodicallyCheckLnBitsRec
  :: forall m
   . MonadServer m
  => String
  -> Ref Boolean
  -> Int
  -> Int
  -> Milliseconds
  -> m Response
periodicallyCheckLnBitsRec fileId closedRef cycle maxRetries interval =
  do
    -- Is http request closed?
    isClosed closedRef >>=
      if _ then
        do
          Log.info "Waiting for payment closed. Aborting"
          okResponse ""
      else if cycle > maxRetries then
        errorResponse "Payment intent failed after waiting a bit"
      else
        checkLnBitsPaymentStatus fileId >>=
          case _ of
            Paid ->
              do
                metadata <- getMetadata fileId
                info "Invoice paid!"

                okResponse $ stringify $ encodeJson $ { metadata, invoice: Nothing :: Maybe Unit }
            _ ->
              do
                sleep interval
                periodicallyCheckLnBitsRec fileId closedRef (cycle + 1) maxRetries interval

waitForPayment :: forall m. MonadServer m => String -> Ref Boolean -> Int -> m Response
waitForPayment fileId closedRef cycle =
  do
    info "Waiting for payment..."
    let
      interval = Milliseconds 100.0
      maxRetries = maxRetriesOf interval

    waitForPaymentRec fileId closedRef cycle maxRetries interval

waitForPaymentRec :: forall m. MonadServer m => String -> Ref Boolean -> Int -> Int -> Milliseconds -> m Response
waitForPaymentRec fileId closedRef cycle maxRetries interval =
  getPaymentStatus fileId >>=
    case _ of
      Paid ->
        do
          metadata <- getMetadata fileId
          info "Invoice paid!"

          okResponse $ stringify $ encodeJson $ { metadata, invoice: Nothing :: Maybe Unit }
      _ ->
        if cycle > maxRetries then
          errorResponse "Payment intent failed after waiting a bit"
        else
          isClosed closedRef >>=
            if _ then
              do
                Log.info "Waiting for payment closed. Aborting"
                okResponse ""
            else
              do
                sleep interval
                waitForPaymentRec fileId closedRef (cycle + 1) maxRetries interval