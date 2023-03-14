module Server where

import Prelude

import File (Metadata, getMetadata)
import Monad.MonadDb (findOne, insertOne)
import Monad.MonadHttpServer (errorResponse, okResponse, serve, toBuffer)
import Monad.MonadLog (debug, info)
import Monad.MonadLog as Log
import Monad.MonadServer (class MonadServer, getEnv)
import Payment (FilePayment, PaymentStatus(..), getPaymentStatus, maybeGetInvoice)
import Payment.Intent (paymentIntent)
import Crypto (randomBytesString, sha256sum)
import Data.Argonaut (JsonDecodeError, decodeJson, encodeJson, parseJson, stringify)
import Data.Either (Either(..))
import Data.Int (fromString)
import Data.Maybe (fromMaybe)
import Data.String (Pattern(..), contains, joinWith)
import Effect.Aff.Class (liftAff)
import Effect.Class (liftEffect)
import Formidable (File, uploadFilesTmp)
import HTTPure (Headers, Method(..), Request, Response, header, toString)
import HTTPure as HTTPure
import HTTPure.Body (RequestBody)
import HTTPure.Lookup (lookup)
import HTTPure.Request (fromHTTPRequest)
import Impl.ServerM (ServerM)
import Node.FS.Stream (createReadStream)
import Node.HTTP (responseAsStream, setHeader)
import Node.HTTP as HTTP
import Node.Stream (pipe)
import Record (merge)
import Utils (atLeast, mb)

server :: ServerM Unit
server = do
  info "Hello from Server"
  serve 8080 router $ info "Server now up on port 8080"

router :: HTTP.Request -> HTTP.Response -> ServerM Response
router request response =
  do
    -- ? this is handled by our proxy,
    -- TODO only set when dev env
    liftEffect $ setHeader response "Access-Control-Allow-Origin" "*"

    req <- liftAff $ fromHTTPRequest request
    case req of
      { method: Options } -> okResponse "Go ahead"
      { path: [ "api", "sha256" ] } -> checkFile sha256 req
      { path: [ "api", "uploads" ], method: Options } -> checkFile (const $ okResponse "") req
      { path: [ "api", "uploads" ], method: Post } -> checkFile (\_ -> handleFileUpload request response) req
      { path: [ "api", "file", id ], method: Get } -> getUpload id
      { path: [ "api", "metadata", id ], method: Get } -> handleGetFileStatus id
      { path: [ "api", "payment", "webhook" ], method: Post } -> handleLnBitsWebHook request response
      { path: [ "api", "payment", fileId, "intent" ], method: Get } -> paymentIntent request fileId
      { path } -> do
        Log.error $ "Path not found:" <> joinWith "/" path
        errorResponse "Not Found"

handleLnBitsWebHook
  :: HTTP.Request
  -> HTTP.Response
  -> ServerM Response
handleLnBitsWebHook request _ = do
  info "Incoming webhook"
  { body } <- liftAff $ fromHTTPRequest request
  body_ <- liftAff $ toString body
  let paymentD = decodeJson =<< parseJson body_ :: Either JsonDecodeError FilePayment
  case paymentD of
    Left err -> do
      Log.error $ show err
      -- Since this is an incoming webhook, always signal received with 200 response
      okResponse ""

    Right payment ->
      do
        debug $ show payment
        _ <- insertOne { db: "purs", collection: "lnbits_payments" } payment
        okResponse ""

sha256 :: forall r m. MonadServer m => { body :: RequestBody | r } -> m Response
sha256 { body } = okResponse <<< sha256sum =<< toBuffer body

handleFileUpload :: forall m. MonadServer m => HTTP.Request -> HTTP.Response -> m Response
handleFileUpload request response =
  do
    { maxFileSize_mb } <- getEnv

    let
      uploadOptions =
        { uploadDir: "uploads"
        , maxFileSize: mb maxFileSize_mb
        , maxTotalFileSize: mb maxFileSize_mb
        , hashAlgorithm: "sha256"
        }
    file <- liftAff $ uploadFilesTmp uploadOptions request response

    id <- liftAff $ randomBytesString (256 / 8)

    _ <- insertOne { db: "purs", collection: "uploads" } $ { id } `merge` file

    metadata <- getMetadata id

    invoice <- maybeGetInvoice id (getAmount metadata) "Payment for a file upload via satifile.com"

    isCurl <- liftAff $ fromHTTPRequest request >>= pure <<< checkUserAgentCurl
    if isCurl then
      okResponse $ "\n\nOk, here is your link\n" <> "" <> ("http://localhost:8080/api/uploads/" <> id) <> "\n"
    else
      okResponse $ stringify $ encodeJson $ { metadata, invoice }

checkUserAgentCurl :: HTTPure.Request -> Boolean
checkUserAgentCurl request = contains (Pattern "curl") $ fromMaybe "" $ lookup request.headers "user-agent"

checkFile :: forall m. MonadServer m => (Request -> m Response) -> Request -> m Response
checkFile next req =
  do
    let x = fromMaybe 0 $ fromString =<< lookup req.headers "content-length"
    { maxFileSize_mb } <- getEnv
    if (x == 0) then
      errorResponse "Length required"
    else if (x > mb maxFileSize_mb) then
      errorResponse $ "Payload too large. Maximum allowed size is " <> show maxFileSize_mb <> "MB"
    else
      next req

getUpload :: forall m. MonadServer m => String -> m Response
getUpload id =
  do
    paid <- getPaymentStatus id

    case paid of
      Paid ->
        do
          -- TODO: Handle not found
          file <- findOne { db: "purs", collection: "uploads" } { id } :: m File
          debug $ "File: " <> show file

          readStream <- liftEffect $ createReadStream file.filepath

          pure $
            { status: 200
            , headers: fileStreamResponseHeaders file
            , multiHeaders: mempty
            , writeBody:
                \httpResponse -> do
                  void $ liftEffect $ pipe readStream (responseAsStream httpResponse)
            }

      _ ->
        errorResponse "This has not been payed for."

getAmount :: Metadata -> Int
getAmount { size } =
  atLeast 1 $ size / (mb 1)

handleGetFileStatus :: forall m. MonadServer m => String -> m Response
handleGetFileStatus id =
  do
    metadata <- getMetadata id
    maybeInvoice <- maybeGetInvoice id (getAmount metadata) "Payment for a file download via satifile.com"

    let responseData = { metadata, invoice: maybeInvoice }

    okResponse $ stringify $ encodeJson responseData

fileResponseHeaders :: File -> Headers
fileResponseHeaders { size, originalFilename, mimetype } =
  header "Content-Type" mimetype
    <> header "Content-Disposition" ("attachment; filename=\"" <> originalFilename <> "\"")
    <> header "Content-Length" (show size)

fileStreamResponseHeaders :: File -> Headers
fileStreamResponseHeaders { size, mimetype, originalFilename } =
  header "Content-Type" mimetype
    <> header "Content-Type" "application/octet-stream"
    <> header "Content-Disposition" ("attachment; filename=\"" <> originalFilename <> "\"")
    <> header "Content-Length" (show size)
