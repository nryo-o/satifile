module Node.HTTP.Request where

import Prelude

import Effect (Effect)
import Node.HTTP as Node.HTTP

type Request = Node.HTTP.Request

foreign import onCloseImpl :: Request -> Effect Unit -> Effect Unit
