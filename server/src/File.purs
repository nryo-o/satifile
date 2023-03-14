module File where

import Prelude

import Monad.MonadDb (class MonadDb, findOne)
import Monad.MonadLog (class MonadLog, debug)
import Formidable as Formidable

-- TODO This needs to be interop with elm type
type Metadata =
  { id :: String
  , name :: String
  , mime :: String
  , size :: Int
  -- , hash :: String
  }

fromFormidableWithId :: String -> Formidable.File -> Metadata
fromFormidableWithId id f =
  { id: id
  , name: f.originalFilename
  , mime: f.mimetype
  , size: f.size
  }

getMetadata :: forall m. MonadDb m => MonadLog m => String -> m Metadata
getMetadata id =
  do
    -- TODO: Handle not found
    file <- findOne { db: "purs", collection: "uploads" } { id } :: m Formidable.File
    debug $ "File: " <> show file
    pure $ fromFormidableWithId id file
