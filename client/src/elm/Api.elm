module Api exposing (..)

import Browser.Dom exposing (Error)
import Context exposing (Context, withContext)
import File
import Http exposing (Error(..), Expect, Response(..), expectStringResponse)
import Json.Decode as Decode
import Resources exposing (FileStatus)
import String exposing (fromInt)
import Url exposing (Protocol(..))


type alias ApiEnv a =
    { a | api : { url : String } }


upload : File.File -> (Result Error FileStatus -> msg) -> Context (ApiEnv a) (Cmd msg)
upload file uploaded =
    withContext
        (\ctx ->
            Http.request
                { method = "POST"
                , headers = []
                , url = ctx.api.url ++ "/uploads"
                , body =
                    Http.multipartBody
                        [ Http.filePart "file" file
                        ]
                , expect = expectJson uploaded Resources.decodeFileStatus
                , timeout = Nothing
                , tracker = Just (File.name file)
                }
        )


getMetadata : String -> (Result Error FileStatus -> msg) -> Context (ApiEnv a) (Cmd msg)
getMetadata fileId gotMetadata =
    withContext
        (\ctx ->
            Http.request
                { method = "GET"
                , headers = []
                , url = ctx.api.url ++ "/metadata/" ++ fileId
                , body = Http.emptyBody
                , expect = expectJson gotMetadata Resources.decodeFileStatus
                , timeout = Nothing
                , tracker = Nothing
                }
        )


getPaymentIntent : String -> (Result Error FileStatus -> msg) -> Context (ApiEnv a) (Cmd msg)
getPaymentIntent fileId gotMetadata =
    withContext
        (\ctx ->
            Http.request
                { method = "GET"
                , headers = []
                , url = ctx.api.url ++ "/payment/" ++ fileId ++ "/intent"
                , body = Http.emptyBody
                , expect = expectJson gotMetadata Resources.decodeFileStatus
                , timeout = Nothing -- TODO: Add timeout
                , tracker = Just "payment-intent"
                }
        )


expectJson : (Result Error a -> msg) -> Decode.Decoder a -> Expect msg
expectJson toMsg decoder =
    expectStringResponse toMsg <|
        resolve <|
            \string ->
                Result.mapError Decode.errorToString (Decode.decodeString decoder string)


resolve : (String -> Result String a) -> Response String -> Result Error a
resolve toResult response =
    case response of
        BadUrl_ url ->
            Err (BadUrl url)

        Timeout_ ->
            Err Timeout

        NetworkError_ ->
            Err NetworkError

        BadStatus_ metadata body ->
            Err (BadStatus metadata.statusCode body)

        GoodStatus_ _ body ->
            Result.mapError BadBody (toResult body)


type Error
    = BadUrl String
    | Timeout
    | NetworkError
    | BadStatus Int String
    | BadBody String


httpErrorToString : Error -> String
httpErrorToString err =
    case err of
        BadUrl s ->
            "BadUrl: " ++ s

        Timeout ->
            "Timeout"

        NetworkError ->
            "NetworkError"

        BadStatus code body ->
            if body == "" then
                "BadStatus: " ++ fromInt code

            else
                body ++ " (" ++ fromInt code ++ ")"

        BadBody reason ->
            "BadBody: " ++ reason
