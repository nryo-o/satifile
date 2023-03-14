module HTTPServer where

import Prelude

import Control.Monad.Error.Class (catchError)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Aff (message, runAff)
import Effect.Class (liftEffect)
import Effect.Console (error)
import HTTPure (ResponseM, ServerM, internalServerError)
import HTTPure.Response (send)
import Node.HTTP (ListenOptions, close, listen)
import Node.HTTP as HTTP

-- | Given a `ListenOptions` object, a function mapping `Request` to
-- | `ResponseM`, and a `ServerM` containing effects to run on boot, creates and
-- | runs a HTTPure server without SSL.
serve' :: ListenOptions -> (HTTP.Request -> HTTP.Response -> ResponseM) -> Effect Unit -> ServerM
serve' options router onStarted = do
  server <- HTTP.createServer (handleRequest router)
  listen server options onStarted
  pure $ close server

-- | This function takes a method which takes a `Request` and returns a
-- | `ResponseM`, an HTTP `Request`, and an HTTP `Response`. It runs the
-- | request, extracts the `Response` from the `ResponseM`, and sends the
-- | `Response` to the HTTP `Response`.
handleRequest
  :: (HTTP.Request -> HTTP.Response -> ResponseM)
  -> HTTP.Request
  -> HTTP.Response
  -> Effect Unit
handleRequest router request httpresponse =
  void $ runAff (\_ -> pure unit) $
    onError500 router request httpresponse
      >>= send httpresponse

-- | Given a router, handle unhandled exceptions it raises by
-- | responding with 500 Internal Server Error.
onError500 :: (HTTP.Request -> HTTP.Response -> ResponseM) -> HTTP.Request -> HTTP.Response -> ResponseM
onError500 router request response =
  catchError (router request response) \err -> do
    liftEffect $ error $ message err
    internalServerError "Internal server error"

-- | Given a port number, return a `HTTP.ListenOptions` `Record`.
listenOptions :: Int -> ListenOptions
listenOptions port =
  { hostname: "0.0.0.0"
  , port
  , backlog: Nothing
  }

-- | Create and start a server. This is the main entry point for HTTPure. Takes
-- | a port number on which to listen, a function mapping `Request` to
-- | `ResponseM`, and a `ServerM` containing effects to run after the server has
-- | booted (usually logging). Returns an `ServerM` containing the server's
-- | effects.
serve :: Int -> (HTTP.Request -> HTTP.Response -> ResponseM) -> Effect Unit -> ServerM
serve = serve' <<< listenOptions
