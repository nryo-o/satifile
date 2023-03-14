module Yaml where

import Prelude

import Data.Argonaut (class DecodeJson, JsonDecodeError, decodeJson)
import Data.Either (Either)

foreign import parse_ :: forall r. String -> r

parse :: forall d. DecodeJson d => String -> Either JsonDecodeError d
parse = decodeJson <<< parse_