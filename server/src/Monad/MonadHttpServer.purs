module Monad.MonadHttpServer where

import Control.Monad (class Monad)
import Data.Time.Duration (Milliseconds)
import Data.Unit (Unit)
import Effect.Ref (Ref)
import HTTPure (Response)
import HTTPure.Body (class Body, RequestBody)
import HTTPure.Headers (Headers)
import Node.Buffer (Buffer)
import Node.HTTP as HTTP

class Monad m <= MonadHttpServer m where
  serve :: Int -> (HTTP.Request -> HTTP.Response -> m Response) -> m Unit -> m Unit
  errorResponse :: String -> m Response
  okResponse :: forall b. Body b => b -> m Response
  ok' :: forall b. Body b => Headers -> b -> m Response
  toBuffer :: RequestBody → m Buffer
  sleep :: Milliseconds -> m Unit
  onClose :: HTTP.Request -> m Unit -> m Unit
  getClosedRef :: HTTP.Request -> m (Ref Boolean)
  isClosed :: (Ref Boolean) -> m Boolean
