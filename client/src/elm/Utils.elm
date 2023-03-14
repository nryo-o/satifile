module Utils exposing (..)

import Process
import String exposing (append, fromInt)
import Task
import Url


prepend : appendable -> appendable -> appendable
prepend arg1 arg2 =
    arg2 ++ arg1


ifThenElese : Bool -> a -> a -> a
ifThenElese con a b =
    if con then
        a

    else
        b


delay : Float -> msg -> Cmd msg
delay t a =
    Process.sleep t
        |> Task.perform (always a)


getResourceUrl : String -> { model | url : Url.Url } -> String
getResourceUrl relativePath { url } =
    urlProtocolToString url.protocol ++ url.host ++ urlPortToString url.port_ ++ relativePath


urlPortToString : Maybe Int -> String
urlPortToString =
    Maybe.withDefault "" << Maybe.map (append ":" << fromInt)


urlProtocolToString : Url.Protocol -> String
urlProtocolToString arg1 =
    case arg1 of
        Url.Http ->
            "http://"

        Url.Https ->
            "https://"
