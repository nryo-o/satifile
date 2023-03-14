module Payment exposing (..)

import Json.Decode as Decode exposing (Decoder)


{-| @server/Payment/Invoice
-}
type alias Invoice =
    { fileId : String
    , paid : Bool
    , expiresAt : Float
    , lnbits_payment_hash : String
    , lnbits_payment_request : String
    }


decodeInvoice : Decoder Invoice
decodeInvoice =
    Decode.map5
        Invoice
        (Decode.field "fileId" Decode.string)
        (Decode.field "paid" Decode.bool)
        (Decode.field "expiresAt" Decode.float)
        (Decode.field "lnbits_payment_hash" Decode.string)
        (Decode.field "lnbits_payment_request" Decode.string)
