module Formidable where

import Prelude

import Control.Promise (Promise)
import Control.Promise as Promise
import Effect (Effect)
import Effect.Aff (Aff)
import Node.HTTP as HTTP

-- | A tempoary file uploaded 
type File =
  {
    -- | The size of the uploaded file in bytes. If the file is still being uploaded (see `'fileBegin'`
    -- | event), this property says how many bytes of the file have been written to disk yet.
    size :: Int

  -- | The path this file is being written to. You can modify this in the `'fileBegin'` event in case
  -- | you are unhappy with the way formidable generates a temporary path for your files.
  , filepath :: String

  -- | The name this file had according to the uploading client.
  , originalFilename :: String

  -- | Calculated based on options provided
  , newFilename :: String

  -- | The mime type of this file, according to the uploading client.
  , mimetype :: String

  -- | sha256 hash of the file
  , hash :: String
  }

foreign import uploadFiles_ :: Options -> HTTP.Request -> HTTP.Response -> Effect (Promise File)

uploadFilesTmp :: Options -> HTTP.Request -> HTTP.Response -> Aff File
uploadFilesTmp options request response = Promise.toAffE $ uploadFiles_ options request response

foreign import fetchAsync_ :: Int -> Effect (Promise String)

fetchAsync :: Int -> Aff String
fetchAsync = Promise.toAffE <<< fetchAsync_

-- | Options
-- TODO Actually use options https://pursuit.purescript.org/packages/purescript-option/9.0.0
type Options =
  { -- encoding :: BufferEncoding
    uploadDir :: String
  -- , keepExtensions :: Boolean
  -- , allowEmptyFiles :: Boolean
  -- , minFileSize :: Int
  -- , maxFiles :: Int
  , maxFileSize :: Int
  , maxTotalFileSize :: Int
  -- , maxFields :: Int
  -- , maxFieldsSize :: Int
  , hashAlgorithm :: String
  -- , fileWriteStreamHandler :: (Effect.Writable)
  -- , multiples :: Boolean
  -- , filename :: (String -> String -> Part -> Formidable -> String)
  -- , enabledPlugins :: (Array String)
  -- , filter :: (Part -> Boolean)
  }