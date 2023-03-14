module FileState exposing (..)

import File exposing (File)
import Files exposing (Metadata)
import Http
import Payment exposing (Invoice)
import Resources exposing (FileStatus)


type UploadState
    = NoFilesSelected
    | GotFiles (List File)
    | Uploading String Http.Progress
    | PaymentIntent FileStatus
    | DelegatePayment Metadata


type DownloadState
    = NotAsked
    | MetadataRequested String
    | HasMetadata Metadata
    | HasInvoice Metadata Invoice
    | GotFile Metadata


hasMetadata : DownloadState -> Maybe Metadata
hasMetadata ds =
    case ds of
        HasMetadata m ->
            Just m

        _ ->
            Nothing
