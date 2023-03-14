module Resources exposing (..)

import Files exposing (Metadata, decodeMetadata)
import Json.Decode as Decode exposing (Decoder)
import Payment exposing (Invoice, decodeInvoice)


{-| Wether a file has been payed or not
-}
type alias FileStatus =
    { metadata : Metadata
    , invoice : Maybe Invoice
    }


getFileUrl : { a | env : { b | api : { c | url : String } } } -> { d | id : String } -> String
getFileUrl model meta =
    model.env.api.url ++ "/file/" ++ meta.id


decodeFileStatus : Decoder FileStatus
decodeFileStatus =
    Decode.map2 FileStatus
        (Decode.field "metadata" decodeMetadata)
        (Decode.field "invoice" (Decode.maybe decodeInvoice))
