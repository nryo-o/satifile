module Svgs exposing (..)

import Context exposing (withContext)
import Element exposing (Attribute, Element)
import Json.Decode as Decode exposing (Decoder)
import UI exposing (image)


type alias AssetsEnv a =
    { a | assets : Assets }


type alias Assets =
    { logo : String
    , logoRed : String
    }


imageAsset : List (Attribute msg) -> (Assets -> String) -> Context.Context { b | assets : Assets } (Element msg)
imageAsset attrs selector =
    withContext
        (\{ assets } ->
            image
                attrs
                { src = selector assets, description = "" }
        )



--


decodeAssets : Decoder Assets
decodeAssets =
    Decode.map2
        Assets
        (Decode.field "logo" Decode.string)
        (Decode.field "logoRed" Decode.string)
