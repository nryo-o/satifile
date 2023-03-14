module Routes exposing (..)

import Url exposing (Url)
import Url.Parser exposing ((</>), map, oneOf, parse, s, string, top)


type Route
    = Home
    | ViewFile String


parseRoutes : Url -> Maybe Route
parseRoutes =
    parse <|
        oneOf
            [ map Home top
            , map ViewFile (s "file" </> string </> top)
            ]
