module Payment where

import Prelude

import Monad.MonadDb (class MonadDb, findMany, findOne, insertOne, updateOne)
import Monad.MonadLog (class MonadLog, debug)
import Monad.MonadPayment (class MonadPayment, checkPayment, createInvoice, getConfig)
import Monad.MonadTime (class MonadTime, getCurrentTime)
import Data.Argonaut (JsonDecodeError, decodeJson)
import Data.Argonaut.Decode.Decoders (decodeArray)
import Data.Array (any, find, length)
import Data.Either (Either(..))
import Data.Generic.Rep (class Generic)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Show.Generic (genericShow)
import Data.Time.Duration (Milliseconds, fromDuration)
import Data.Traversable (sequence)
import LnBits (GetPaymentResponse, Payment, defaultInvoiceRequest)
import LnBits as LnBits
import Utils (unwrapMilliseconds)

type Invoice =
  { -- id :: String
    fileId :: String
  , paid :: Boolean -- This might be status "unpaid" | "paid" | "expired"
  , expiresAt :: Number
  , lnbits_payment_hash :: String
  , lnbits_payment_request :: String
  }

-- | A payment for a file
type FilePayment = Payment { fileId :: String }

type FileGetPaymentResponse = GetPaymentResponse FilePayment

data PaymentStatus
  = NoInvoice
  | HasInvoice Invoice
  | InvoiceExpired
  | Paid

derive instance Generic PaymentStatus _

instance Show PaymentStatus where
  show = genericShow

getPaymentStatus :: forall m. MonadDb m => MonadLog m => MonadTime m => MonadPayment m => String -> m PaymentStatus
getPaymentStatus fileId = do
  maybeInvoices <- getInvoices fileId
  case maybeInvoices of
    Nothing ->
      pure NoInvoice
    Just invoices ->
      do
        if any (_.paid) invoices then
          pure Paid
        else if length invoices == 0 then
          pure NoInvoice
        else
          handleInvoices fileId invoices

getInvoices
  :: forall m
   . MonadDb m
  => MonadLog m
  => String
  -> m (Maybe (Array Invoice))
getInvoices fileId =
  do
    res <- findMany { db: "purs", collection: "invoices" } { fileId }
    let invoicesDecodeResult = decodeArray decodeJson res :: Either JsonDecodeError (Array Invoice)
    case invoicesDecodeResult of
      Left _ -> pure $ Nothing
      Right invoices -> pure $ Just invoices

withInvoices
  :: forall m
   . MonadDb m
  => MonadLog m
  => String
  -> (Array Invoice -> m PaymentStatus)
  -> m PaymentStatus
withInvoices fileId invoicesHandler =
  getInvoices fileId
    <#> (invoicesHandler <$> _)
    >>= fromMaybe (pure NoInvoice)

checkLnBitsPaymentStatus :: forall m. MonadDb m => MonadLog m => MonadPayment m => MonadTime m => String -> m PaymentStatus
checkLnBitsPaymentStatus fileId =
  withInvoices fileId checkInvoiceLnbits

handleInvoices :: forall m. MonadDb m => MonadLog m => MonadTime m => MonadPayment m => String -> Array Invoice -> m PaymentStatus
handleInvoices fileId invoices =
  do
    mongoRes <- findOne { db: "purs", collection: "lnbits_payments" } { "extra.fileId": fileId }
    let res_ = decodeJson mongoRes :: Either JsonDecodeError (Maybe FilePayment)
    case res_ of
      Left _ ->
        checkInvoiceExpiries invoices

      Right maybeLnBitsPayment ->
        case maybeLnBitsPayment of
          Nothing ->
            checkInvoiceExpiries invoices
          Just { pending } ->
            if not pending then
              pure Paid
            else
              checkInvoiceExpiries invoices

checkInvoicePayment :: forall m. MonadPayment m => Invoice -> m FileGetPaymentResponse
checkInvoicePayment invoice = checkPayment $ invoice.lnbits_payment_hash

checkInvoiceLnbits :: forall m. MonadDb m => MonadPayment m => MonadTime m => MonadLog m => Array Invoice -> m PaymentStatus
checkInvoiceLnbits invoices =
  do
    checks <- sequence $ map checkInvoicePayment invoices

    let
      anyPaid = find
        ( \paymentResponese ->
            case paymentResponese of
              LnBits.Error _ -> false
              LnBits.Ok { paid } -> paid
        )
        checks

    void $ insertMissingPayments checks
    case anyPaid of
      Just (LnBits.Ok { details }) ->
        do
          void $ updateOne { db: "purs", collection: "invoices" } { fileId: details.extra.fileId } { "$set": { paid: true } }
          pure Paid
      _ ->
        checkInvoiceExpiries invoices

insertMissingPayments :: forall m. MonadDb m => MonadPayment m => MonadTime m => MonadLog m => Array (FileGetPaymentResponse) -> m Unit
insertMissingPayments checks = do
  void $ sequence $ map
    ( \paymentResponese ->
        case paymentResponese of
          LnBits.Error _ -> pure unit
          LnBits.Ok payment ->
            void $ insertOne { db: "purs", collection: "lnbits_payments" } payment.details
    )
    checks

checkInvoiceExpiries :: forall m. MonadTime m => Array Invoice -> m PaymentStatus
checkInvoiceExpiries is =
  do
    now <- getCurrentTime
    pure $ fromMaybe InvoiceExpired $ HasInvoice <$> find (not <<< hasInvoiceExpired now) is

hasInvoiceExpired :: Milliseconds -> Invoice -> Boolean
hasInvoiceExpired now invoice =
  invoice.expiresAt < unwrapMilliseconds now

createInvoiceForFileId
  :: forall m
   . MonadPayment m
  => MonadDb m
  => MonadLog m
  => MonadTime m
  => String
  -> Int
  -> String
  -> m (Maybe Invoice)
createInvoiceForFileId fileId amount memo =
  do
    cfg <- getConfig
    debug "Requesting invoice: "
    let invoiceRequest = defaultInvoiceRequest cfg amount memo { fileId }

    lnbitsInvoice <- createInvoice invoiceRequest
    now <- getCurrentTime

    let
      invoice =
        { fileId
        , paid: false
        , expiresAt: unwrapMilliseconds $ now `append` (fromDuration invoiceRequest.expiry)
        , lnbits_payment_hash: lnbitsInvoice.payment_hash
        , lnbits_payment_request: lnbitsInvoice.payment_request
        } :: Invoice

    _ <- insertOne { db: "purs", collection: "invoices" } invoice

    pure $ Just invoice

-- | Check if it's paid and if not, create an invoice
maybeGetInvoice
  :: forall m
   . MonadDb m
  => MonadPayment m
  => MonadTime m
  => MonadLog m
  => String
  -> Int
  -> String
  -> m (Maybe Invoice)
maybeGetInvoice fileId amount memo = do
  paid <- getPaymentStatus fileId
  debug $ "Is paid: " <> show paid
  case paid of
    NoInvoice ->
      createInvoiceForFileId fileId amount memo
    InvoiceExpired ->
      createInvoiceForFileId fileId amount memo
    HasInvoice i ->
      pure $ Just i
    Paid ->
      pure Nothing
