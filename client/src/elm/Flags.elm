module Flags exposing (..)

import Json.Decode as Decode exposing (Decoder)
import Svgs exposing (Assets)


type alias Flags =
    { apiUrl : String
    , assets : Assets
    }


decodeFlags : Decoder Flags
decodeFlags =
    Decode.map2
        Flags
        (Decode.field "apiUrl" Decode.string)
        (Decode.field "assets" Svgs.decodeAssets)
