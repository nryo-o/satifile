module WebComponents exposing (..)

import Element exposing (html)
import Html
import Html.Attributes exposing (attribute)
import String exposing (fromInt)


type Format
    = Png
    | Html
    | Svg


type alias QrCodeProps =
    { data : String --  	string 	null 	The information encoded by the QR code.
    , format : Format -- 	png, html, svg 	png 	Format of the QR code rendered inside the component.
    , modulesize : Int -- 	int 	5 	Size of the modules in pixels.
    , margin : String -- 	int 	4 	Margin of the QR code in modules.
    }


qrCode : List (Element.Attribute msg) -> String -> Element.Element msg
qrCode attrs data =
    Element.el attrs <|
        html <|
            Html.node "qr-code"
                [ attribute "data" data
                , attribute "modulesize" (fromInt 3)
                , attribute "margin" (fromInt 0)
                ]
                []
