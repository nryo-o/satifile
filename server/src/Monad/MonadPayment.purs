module Monad.MonadPayment where

import Prelude

import Data.Argonaut (class DecodeJson, class EncodeJson)
import LnBits (Config, InvoiceRequest, InvoiceResponse, GetPaymentResponse)

class Monad m <= MonadPayment m where
  getConfig :: m Config
  createInvoice :: forall r. EncodeJson r => InvoiceRequest r -> m InvoiceResponse
  checkPayment :: forall r. DecodeJson r => String -> m (GetPaymentResponse r)