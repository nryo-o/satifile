module UI exposing (..)

import Element exposing (Attr, Attribute, Color, Element, centerX, centerY, column, el, fill, focused, height, htmlAttribute, layout, minimum, modular, padding, paddingEach, paddingXY, paragraph, rgb, rgb255, scrollbars, shrink, spacing, width)
import Element.Background
import Element.Border
import Element.Font
import Element.Input
import Html exposing (Html)
import Html.Attributes
import List exposing (singleton)
import Maybe.Extra
import String exposing (toUpper)


{-| Top level node
-}
root : List (Attr () msg) -> Element msg -> Html msg
root attrs =
    layout
        ([ fontScale 1
         , padding 20
         , Element.Font.regular
         , width fill
         , height fill
         , Element.Background.color colors.shade1
         , Element.Font.color colors.shade3
         , Element.Font.family
            [ Element.Font.typeface "SplineSans"
            , Element.Font.sansSerif
            ]
         , scrollbars
         ]
            ++ attrs
        )


fontScale : Int -> Attr decorative msg
fontScale =
    Element.Font.size << round << modular 16 1.5


title : List (Attr () msg)
title =
    [ fontScale 4
    , Element.Font.bold
    ]


subtitle : List (Attr () msg)
subtitle =
    [ fontScale 2
    , Element.Font.bold
    ]



-- Exposed ui elements


button : List (Attribute msg) -> String -> msg -> Element msg
button attrs =
    buttonWith attrs << textLabel << toUpper


{-| Default text element

Wrap text in a paragraph by default, since text will not break words.

-}
text : String -> Element msg
text =
    paragraph [] << singleton << Element.text


center : List (Element.Attribute msg)
center =
    [ centerX, centerY ]



-- Local


colors : { shade1 : Color, shade2 : Color, shade3 : Color, yellow : Color }
colors =
    { shade1 = rgb 1 1 1
    , shade2 = rgb 0.92 0.92 0.92
    , shade3 = rgb 0.33 0.33 0.33
    , yellow = rgb255 255 233 73
    }


buttonWith : List (Attribute c) -> Element c -> c -> Element c
buttonWith attrs label msg =
    Element.Input.button
        ([ Element.Border.width borderWidth
         , Element.Border.color colors.yellow
         , Element.Font.bold
         , width (shrink |> minimum 25)
         , paddingXY 14 11
         , focused
            [ Element.Border.color colors.yellow
            ]
         ]
            ++ subtitle
            ++ attrs
        )
        { onPress = Just msg
        , label = label
        }


borderWidth : number
borderWidth =
    3


textLabel : String -> Element msg
textLabel =
    el [ centerX, centerY ] << Element.text


section : List (Element.Attribute msg) -> List (Element.Element msg) -> Element.Element msg
section attrs =
    column
        ([ spacing 20
         , width fill
         ]
            ++ attrs
        )


textInput : List (Attribute msg) -> { onChange : String -> msg, text : String, placeholder : Maybe (Element.Input.Placeholder msg), label : Element.Input.Label msg } -> Element msg
textInput attrs =
    Element.Input.text
        ([ Element.Border.width borderWidth
         , Element.Border.color colors.shade2
         , focused
            [ Element.Border.color colors.yellow
            ]
         ]
            ++ attrs
        )


textInputWithLabelEnd : Element msg -> List (Attribute msg) -> { onChange : String -> msg, text : String, placeholder : Maybe (Element.Input.Placeholder msg), label : Element.Input.Label msg } -> Element msg
textInputWithLabelEnd labelEnd attrs =
    textInput
        ([ paddingEach
            { left = 14
            , top = 14
            , bottom = 14
            , right = 40
            }
         , Element.inFront
            (el
                [ Element.alignRight
                , paddingXY 14 14
                ]
                labelEnd
            )
         ]
            ++ attrs
        )


textInputWithLabelStart : Element msg -> List (Attribute msg) -> { onChange : String -> msg, text : String, placeholder : Maybe (Element.Input.Placeholder msg), label : Element.Input.Label msg } -> Element msg
textInputWithLabelStart labelEnd attrs =
    textInput
        ([ paddingEach
            { left = 45
            , top = 14
            , bottom = 14
            , right = 14
            }
         , Element.inFront
            (el
                [ Element.alignLeft
                , paddingXY 14 14
                ]
                labelEnd
            )
         ]
            ++ attrs
        )


whiteSpacePreWrap : Attribute msg
whiteSpacePreWrap =
    class "wspw"


class : String -> Attribute msg
class =
    htmlAttribute << Html.Attributes.class


whiteSpaceNoWrap : Attribute msg
whiteSpaceNoWrap =
    class "wsnw"


image : List (Attribute msg) -> { src : String, description : String } -> Element msg
image attrs =
    Element.image
        (pointerEventsNone
            :: attrs
        )


red : Color
red =
    rgb255 0xFF 0x25 0x25


when : Bool -> Element msg -> Element msg
when bool elem =
    if bool then
        elem

    else
        Element.none


unwrap : (a -> Element msg) -> Maybe a -> Element msg
unwrap =
    Maybe.Extra.unwrap Element.none


pointerEventsNone : Element.Attribute msg
pointerEventsNone =
    Element.htmlAttribute (Html.Attributes.style "pointer-events" "none")


centerItems : Attribute msg
centerItems =
    htmlAttribute (Html.Attributes.style "align-items" "center")


centerContent : Attribute msg
centerContent =
    htmlAttribute (Html.Attributes.style "justify-content" "center")
