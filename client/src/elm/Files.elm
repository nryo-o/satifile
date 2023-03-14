module Files exposing (..)

import Element exposing (htmlAttribute)
import File exposing (File)
import Html.Events
import Json.Decode as Decode exposing (Decoder, field, list)
import String exposing (fromFloat)
import Url exposing (Protocol(..))


type alias FileId =
    String


type alias Metadata =
    { id : FileId
    , name : String
    , mime : String
    , size : Int
    }


kb : number
kb =
    1000


mb : number
mb =
    kb ^ 2


gb : number
gb =
    kb ^ 3


humanReadableSize : Int -> String
humanReadableSize =
    humanReadableSize_ << toFloat


floatingPoint : Int -> Float -> Float
floatingPoint precision num =
    toFloat (round (num * (10 ^ toFloat precision))) / (10 ^ toFloat precision)


showSize : Float -> String
showSize =
    fromFloat << floatingPoint 1


humanReadableSize_ : Float -> String
humanReadableSize_ size =
    if size < kb then
        showSize size ++ " byte"

    else if size < mb then
        showSize (size / kb) ++ " KB"

    else if size < gb then
        showSize (size / mb) ++ " MB"

    else
        showSize (size / gb) ++ " GB"


fromFile : String -> File -> Metadata
fromFile id f =
    { id = id
    , name = File.name f
    , mime = File.mime f
    , size = File.size f
    }


{-| A route to view the file

`https://satifile.com/file/:fileid`

-}
viewFileRoute : String
viewFileRoute =
    "file"


{-| A route the file can be viewed at
-}
setRoute : String -> String
setRoute fileId =
    "/" ++ viewFileRoute ++ "/" ++ fileId


filesDecoder : Decoder (List File)
filesDecoder =
    field "dataTransfer" (field "files" (list File.decoder))


onDropFiles : { a | noop : msg, onFiles : List File -> msg } -> List (Element.Attribute msg)
onDropFiles msgs =
    [ htmlAttribute
        -- Prevent browser from opening the file
        (Html.Events.preventDefaultOn "dragover" (Decode.succeed ( msgs.noop, True )))
    , htmlAttribute
        (Html.Events.preventDefaultOn "drop"
            (Decode.andThen
                (\fileList -> Decode.succeed ( msgs.onFiles fileList, True ))
                filesDecoder
            )
        )
    ]



-- Interop


decodeMetadata : Decoder Metadata
decodeMetadata =
    Decode.map4
        Metadata
        (Decode.field "id" Decode.string)
        (Decode.field "name" Decode.string)
        (Decode.field "mime" Decode.string)
        (Decode.field "size" Decode.int)
