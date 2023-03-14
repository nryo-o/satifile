module Crypto
  ( sha256sum
  , randomBytesString
  ) where

import Prelude

import Control.Promise (Promise)
import Control.Promise as Promise
import Effect (Effect)
import Effect.Aff (Aff)
import Node.Buffer (Buffer)

foreign import sha256sum :: Buffer -> String

foreign import randomBytesString_ :: Int -> Effect (Promise String)

randomBytesString :: Int -> Aff String
randomBytesString = Promise.toAffE <<< randomBytesString_