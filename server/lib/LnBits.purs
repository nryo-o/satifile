module LnBits where

import Prelude

import Data.Argonaut (class DecodeJson, class EncodeJson, Json, JsonDecodeError, decodeJson, (.:))
import Data.Argonaut.Encode (toJsonString)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Time.Duration (Seconds(..))
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Fetch (Method(..), fetch)
import Fetch.Argonaut.Json (fromJson)
import Utils (unwrapSeconds)

type InvoiceResponse =
  { payment_hash :: String
  -- | The request that needs to be displayed as an qr code
  , payment_request :: String
  , checking_id :: String
  }

type InvoiceRequest extra =
  { out :: Boolean -- False
  , amount :: Int
  , memo :: String
  , expiry :: Seconds
  , webhook :: String
  , extra :: extra
  }

type Config =
  { apiUrl :: String
  , invoiceKey :: String
  , webhook :: String
  }

type Payment r =
  { checking_id :: String
  , pending :: Boolean
  , amount :: Int
  , fee :: Int
  , memo :: Maybe String
  , time :: Int
  , bolt11 :: String
  , preimage :: String
  , payment_hash :: String
  , expiry :: Maybe Number
  , extra :: r
  , wallet_id :: String
  , webhook :: Maybe String
  , webhook_status :: Maybe Int
  }

data GetPaymentResponse r
  = Error String
  | Ok { paid :: Boolean, details :: r }

decodeError :: Json -> Either JsonDecodeError (Maybe String)
decodeError json =
  do
    errObj <- decodeJson json -- decode `Json` to `Object Json`
    let hasErrString = errObj .: "details" :: Either JsonDecodeError String
    case hasErrString of
      Right err -> pure $ Just err
      Left _ -> pure $ Nothing

instance DecodeJson r => DecodeJson (GetPaymentResponse r) where
  decodeJson :: Json -> Either JsonDecodeError (GetPaymentResponse r)
  decodeJson json = do
    hasError <- decodeError json
    case hasError of
      Just err ->
        pure $ (Error err)
      Nothing ->
        do
          obj <- decodeJson json
          paid <- obj .: "paid"
          details <- obj .: "details"
          pure $ Ok { paid, details }

instance Show r => Show (GetPaymentResponse r) where
  show (Error e) = e
  show (Ok rec) = show rec

defaultInvoiceRequest :: forall r. Config -> Int -> String -> r -> InvoiceRequest r
defaultInvoiceRequest config amount memo extra =
  { out: false
  , amount: amount
  , memo: memo
  , expiry: Seconds $ 5.0 * 60.0
  , webhook: config.webhook
  , extra: extra
  }

createInvoice :: forall r. EncodeJson r => Config -> InvoiceRequest r -> Aff InvoiceResponse
createInvoice { apiUrl, invoiceKey } invoirceReq = do
  { status, text, ok, json } <- fetch
    (apiUrl <> "/api/v1/payments")
    { method: POST
    , body: toJsonString (invoirceReq { expiry = unwrapSeconds invoirceReq.expiry })
    , headers:
        { "Content-Type": "application/json"
        , "X-Api-Key": invoiceKey
        }
    }
  if not ok then
    do
      text_ <- text
      liftEffect $ throw (show status <> "\n" <> show text_)
  else
    do
      fromJson json

getPayment :: forall d. DecodeJson d => Config -> String -> Aff (GetPaymentResponse d)
getPayment { apiUrl, invoiceKey } hash = do
  { text, ok, json } <- fetch
    (apiUrl <> "/api/v1/payments/" <> hash)
    { method: GET
    , headers:
        { "Content-Type": "application/json"
        , "X-Api-Key": invoiceKey
        }
    }
  if not ok then
    do
      text_ <- text
      pure (Error (show text_))
  else
    fromJson json

-- Development 

testConfig :: Config
testConfig =
  { apiUrl: "https://legend.lnbits.com"
  , invoiceKey: "3a30d6a7affe4be48093e6a1b38c0dcb"
  , webhook: "http://static.156.163.90.157.clients.your-server.de/api/payment/webhook"
  }

