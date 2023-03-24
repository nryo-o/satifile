port module Main exposing (..)

import Api exposing (ApiEnv)
import Browser exposing (UrlRequest(..))
import Browser.Navigation as Nav exposing (Key)
import Context exposing (runContext)
import Element exposing (Element, alignBottom, centerX, centerY, column, el, fill, fillPortion, height, htmlAttribute, link, maximum, padding, paragraph, pointer, px, row, spacing, width)
import Element.Background
import Element.Border
import Element.Events exposing (onClick)
import Element.Font
import Element.Input
import File exposing (File)
import File.Select
import FileState exposing (DownloadState(..), UploadState(..))
import Files exposing (Metadata, humanReadableSize)
import Flags exposing (Flags)
import Html
import Html.Attributes exposing (style)
import Http exposing (Error(..), Progress(..))
import Json.Decode as D
import Json.Encode as E
import List exposing (head, reverse, singleton, tail)
import Maybe.Extra as Maybe
import Platform.Cmd exposing (none)
import Resources exposing (FileStatus, getFileUrl)
import Routes exposing (Route)
import String exposing (append, fromInt)
import Svgs exposing (AssetsEnv)
import Task
import UI exposing (..)
import Url exposing (Url)
import Utils exposing (delay, getResourceUrl, ifThenElese, prepend)
import WebComponents exposing (qrCode)


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = document
        , subscriptions = subscriptions
        , onUrlChange = UrlChage
        , onUrlRequest = UrlRequest
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ portReceive decodePortValue
        , case model.uploadState of
            Uploading trackId _ ->
                Http.track trackId (TrackFile trackId)

            _ ->
                Sub.none
        ]


decodePortValue : D.Value -> Msg
decodePortValue val =
    case D.decodeValue (D.field "tag" D.string) val of
        Err err ->
            SetError (DecodeErr err)

        Ok tag ->
            case tag of
                "copied" ->
                    SetCopied True

                _ ->
                    Noop



-- PORTS


port portSend : E.Value -> Cmd msg


toAction : String -> List ( String, E.Value ) -> Cmd msg
toAction type_ data =
    portSend <| E.object (( "tag", E.string type_ ) :: data)


port portReceive : (D.Value -> msg) -> Sub msg



-- Init


init : Flags -> Url -> Key -> ( Model, Cmd Msg )
init flags url key =
    let
        model =
            getInitialModel url key flags
    in
    handleUrlUpdate url model


getInitialModel : Url -> Key -> Flags -> Model
getInitialModel url key flags =
    { key = key
    , url = url
    , route = Routes.Home
    , counter = 0
    , messages = []
    , error = Nothing
    , uploadState = NoFilesSelected
    , downloadState = NotAsked
    , copied = False
    , env =
        { api = { url = flags.apiUrl }
        , assets = flags.assets
        }
    }



-- Model


type alias Model =
    { key : Key
    , url : Url
    , route : Route
    , counter : Int
    , messages : List String
    , error : Maybe AppError
    , uploadState : UploadState
    , downloadState : DownloadState
    , copied : Bool
    , env : AppEnv
    }


type alias AppEnv =
    ApiEnv (AssetsEnv {})


type AppError
    = ApiError Api.Error
    | DecodeErr D.Error


appErrorToString : AppError -> String
appErrorToString ae =
    case ae of
        ApiError httpError ->
            Api.httpErrorToString httpError

        DecodeErr err ->
            D.errorToString err



-- Messages


type Msg
    = Noop
      -- Url
    | UrlChage Url
    | UrlRequest UrlRequest
    | GotMessage String
      -- Upload
    | SelectFile
    | SelectedFiles (List File)
    | UploadFiles
    | Uploaded (Result AppError FileStatus)
    | UploadPaymentReceived (Result AppError FileStatus)
    | DelegatePaymentMsg Metadata
      -- Download
    | GotFileStatus (Result AppError FileStatus)
    | ClickedDownload Metadata
      --
    | Copy String
    | TrackFile String Progress
    | SetCopied Bool
    | SetError AppError



-- Controller


msgCmd : a -> Cmd a
msgCmd =
    Task.perform identity << Task.succeed


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        handleError =
            tryResult (\err -> ( { model | error = Just err }, none ))
    in
    case msg of
        UrlChage url ->
            handleUrlUpdate url model

        UrlRequest urlRequest ->
            case urlRequest of
                Internal url ->
                    ( model
                    , Nav.pushUrl model.key (Url.toString url)
                    )

                External url ->
                    ( model
                    , Nav.load url
                    )

        GotMessage m ->
            ( { model | messages = m :: model.messages }, none )

        SelectedFiles fs ->
            ( { model
                | uploadState =
                    case model.uploadState of
                        GotFiles currentFiles ->
                            GotFiles (currentFiles ++ fs)

                        NoFilesSelected ->
                            if List.isEmpty fs then
                                NoFilesSelected

                            else
                                GotFiles fs

                        _ ->
                            model.uploadState
              }
            , msgCmd UploadFiles
            )

        TrackFile tracker progress ->
            -- TODO Possible race condition
            ( { model | uploadState = Uploading tracker progress }
            , none
            )

        UploadFiles ->
            case model.uploadState of
                GotFiles fs ->
                    ( model
                    , Maybe.unwrap none
                        (\f ->
                            Cmd.batch
                                [ runContext (Api.upload f (Uploaded << Result.mapError ApiError)) model.env
                                , msgCmd (TrackFile (File.name f) (Sending { sent = 0, size = File.size f }))
                                ]
                        )
                        (List.head fs)
                    )

                _ ->
                    ( model, none )

        Uploaded res ->
            handleError res
                (\fileStatus ->
                    ( { model | uploadState = PaymentIntent fileStatus }
                    , runContext (Api.getPaymentIntent fileStatus.metadata.id (UploadPaymentReceived << Result.mapError ApiError)) model.env
                    )
                )

        UploadPaymentReceived res ->
            handleError res
                (\fileStatus ->
                    ( { model | uploadState = PaymentIntent fileStatus }
                    , none
                    )
                )

        DelegatePaymentMsg metadata ->
            ( { model | uploadState = DelegatePayment metadata }
            , Http.cancel "payment-intent"
            )

        SelectFile ->
            ( model
            , File.Select.file [ "*/*" ]
                (SelectedFiles << singleton)
            )

        Noop ->
            ( model, none )

        Copy str ->
            ( model, toAction "copy" [ ( "text", E.string str ) ] )

        SetCopied b ->
            ( { model | copied = b }, ifThenElese b (delay 1200 (SetCopied False)) none )

        SetError e ->
            ( { model | error = Just e }, none )

        ClickedDownload meta ->
            ( { model | downloadState = GotFile meta }, none )

        GotFileStatus res ->
            handleError res
                (\{ metadata, invoice } ->
                    case invoice of
                        Just i ->
                            ( { model | downloadState = HasInvoice metadata i }
                            , runContext (Api.getPaymentIntent metadata.id (GotFileStatus << Result.mapError ApiError)) model.env
                            )

                        Nothing ->
                            ( { model | downloadState = HasMetadata metadata }
                            , none
                            )
                )



-- Routing


handleUrlUpdate : Url -> Model -> ( Model, Cmd Msg )
handleUrlUpdate url model =
    let
        route =
            Maybe.withDefault Routes.Home (Routes.parseRoutes url)
    in
    model
        |> setUrl url
        |> setRoute route
        |> handleRouteActions route


setRoute : Route -> Model -> Model
setRoute r model =
    { model | route = r }


setUrl : Url -> Model -> Model
setUrl url model =
    { model | url = url }


handleRouteActions : Route -> Model -> ( Model, Cmd Msg )
handleRouteActions route model =
    case route of
        Routes.Home ->
            ( model, none )

        Routes.ViewFile id ->
            ( model
            , case model.downloadState of
                NotAsked ->
                    runContext (Api.getMetadata id (GotFileStatus << Result.mapError ApiError)) model.env

                _ ->
                    none
            )


tryResult : (error -> a) -> Result error value -> (value -> a) -> a
tryResult onError res onSuccess =
    case res of
        Err err ->
            onError err

        Ok ok ->
            onSuccess ok



-- View


document : Model -> Browser.Document Msg
document model =
    { title = "Satisfile ⚡️"
    , body =
        [ root
            (Files.onDropFiles
                { noop = Noop
                , onFiles = SelectedFiles
                }
            )
            (view model)
        , Html.node "style"
            []
            [ Html.text """
                .wspw > * > .t {
                    white-space: pre-wrap !important;
                }

                .wsnw > * > .t {
                    white-space: nowrap !important;
                }
                """
            ]
        ]
    }


view : Model -> Element Msg
view model =
    section
        [ width fill
        , height fill
        ]
        [ case model.error of
            Just err ->
                column [ centerX, width fill, centerY, spacing 20 ]
                    [ bolt model.env.assets.logoRed "Error :("
                    , el [ centerX, Element.Font.color UI.red ] <| text (appErrorToString err)
                    ]

            Nothing ->
                case model.route of
                    Routes.Home ->
                        viewHome model

                    Routes.ViewFile id ->
                        viewFileDownload model id
        , el [ centerX ]
            (paragraph []
                [ Element.text "1sat/mb | 5gb max | beta | "
                , Element.link []
                    { url = "https://github.com/nryo-o/satifile"
                    , label = Element.text "repo"
                    }
                ]
            )
        ]


viewFileDownload : Model -> String -> Element Msg
viewFileDownload model fid =
    section [ width fill, height fill ]
        [ el [ height (fillPortion 1), width fill ] <| Element.none
        , el [ height (fillPortion 1), width fill ] <| viewFileDownloadState model fid
        , el [ height (fillPortion 1), width fill, alignBottom ] <|
            el [ centerX, alignBottom ] <|
                Element.link
                    [ Element.Font.underline
                    , centerX
                    , alignBottom
                    ]
                    { url = "/", label = text "send a file" }
        ]


viewFileDownloadState : Model -> String -> Element Msg
viewFileDownloadState model _ =
    case model.downloadState of
        NotAsked ->
            section []
                [ title model "Download"
                ]

        MetadataRequested _ ->
            section []
                [ title model "Download"
                ]

        HasMetadata metadata ->
            section []
                [ title model "Download"
                , el [ width fill, centerX ] <| viewMetadata metadata
                , Element.download [ centerX ]
                    { url = getFileUrl model metadata
                    , label = UI.button [] "Download" (ClickedDownload metadata)
                    }
                ]

        HasInvoice metadata invoice ->
            section []
                [ title model "Pay to download"
                , showSats [ centerX ] metadata
                , column [ centerX, spacing 5 ]
                    [ qrCode
                        [ padding 3
                        , centerX
                        , onClick (Copy invoice.lnbits_payment_request)
                        ]
                        invoice.lnbits_payment_request
                    , el [ centerX, fontScale -1 ] (text "(click qr to copy invoice)")
                    ]
                , el [ width fill, centerX ] <| viewMetadata metadata
                ]

        GotFile metadata ->
            section []
                [ title model "Such wow"
                , el [ width fill, centerX ] <| viewMetadata metadata
                , Element.download [ centerX ]
                    { url = getFileUrl model metadata
                    , label = UI.button [] "Download again" Noop
                    }
                ]


showSats : List (Element.Attribute msg) -> { a | size : Int } -> Element msg
showSats attrs metadata =
    el attrs <| text <| fromInt (max 1 (metadata.size // 10 ^ 6)) ++ "sat ⚡️"


viewMetadata : Metadata -> Element Msg
viewMetadata meta =
    row [ centerX, spacing 20, width (fill |> Element.maximum 320) ]
        [ el [] <| Element.text (ellipseFilename meta.name)
        , el [ Element.alignRight ] <| text (humanReadableSize meta.size)
        ]


seperateFileExt : String -> ( String, String )
seperateFileExt s =
    String.split "." s
        |> reverse
        |> (\ls ->
                ( String.join "." <| List.reverse <| Maybe.withDefault [] (tail ls)
                , Maybe.unwrap "" (append ".") (head ls)
                )
           )


ellipse : Int -> String -> String
ellipse max str =
    let
        strLen =
            String.length str

        take =
            (strLen // 2) + (strLen - max + 3) // 2
    in
    if max < strLen then
        String.dropRight take str ++ "..." ++ String.dropLeft take str

    else
        str


ellipseFilename : String -> String
ellipseFilename string =
    if String.length string > 21 then
        seperateFileExt string
            |> (\( name, ext ) -> ellipse (21 - String.length ext) name ++ ext)

    else
        string


title : Model -> String -> Element msg
title model txt =
    bolt model.env.assets.logo txt


bolt : String -> String -> Element msg
bolt logoVariant txt =
    el
        [ width fill
        , centerY
        , Element.inFront
            (el
                ([ centerX
                 , centerY
                 , htmlAttribute (style "transform" "rotate(-11deg)")
                 , width fill
                 , Element.Font.center
                 ]
                    ++ UI.title
                )
             <|
                text (String.toUpper txt)
            )
        ]
    <|
        el [ centerX, centerY ] <|
            image [ width (px 100) ] { src = logoVariant, description = "" }


viewHomeContent : Model -> Element Msg
viewHomeContent model =
    column [ height fill, spacing 20, width fill ]
        [ title model "Drop file"
        , el
            [ alignBottom
            , Element.Font.underline
            , pointer
            , onClick SelectFile
            , centerX
            ]
          <|
            text "or select a file"
        ]


viewHome : Model -> Element Msg
viewHome model =
    section [ centerX, height fill ] <|
        [ case model.uploadState of
            NoFilesSelected ->
                viewHomeContent model

            GotFiles _ ->
                viewHomeContent model

            Uploading _ httpProgress ->
                let
                    progress =
                        fractionFromProgress httpProgress
                in
                section [ centerY, centerX, Element.Font.center ]
                    [ title model "Uploading..."
                    , el [ centerX ] <| progressBarNew progress
                    , el [ centerX ] <| text <| (progress * 100 |> floor |> fromInt |> prepend "⚡️")
                    ]

            PaymentIntent { metadata, invoice } ->
                let
                    link =
                        getResourceUrl (Files.setRoute metadata.id) model
                in
                section [ centerX, centerY ] <|
                    case invoice of
                        Nothing ->
                            [ title model "Nice!"
                            , el [ centerX ] <| text "Here is your sharing link"
                            , el [ centerX ] <| showlink model link
                            ]

                        Just inv ->
                            [ title model "Pay your invoice"
                            , section [ centerX ]
                                [ qrCode
                                    [ padding 3
                                    , centerX
                                    , onClick (Copy inv.lnbits_payment_request)
                                    ]
                                    inv.lnbits_payment_request
                                , showSats [ centerX ] metadata
                                , UI.button [ centerX, width (fill |> maximum 300) ]
                                    "Let the receiver pay"
                                    (DelegatePaymentMsg metadata)
                                ]
                            ]

            DelegatePayment metadata ->
                let
                    link =
                        getResourceUrl (Files.setRoute metadata.id) model
                in
                section [ centerItems, centerY, width fill ]
                    [ title model "Here is your sharing link"
                    , el [ centerX ] <| showlink model link
                    ]
        ]


showlink : { a | copied : Bool } -> String -> Element Msg
showlink model link =
    section [ centerX ] <|
        [ --  el (center ++ []) (text "Here is your link")
          UI.textInputWithLabelStart
            (el
                [ pointer
                , onClick (Copy link)
                ]
                (text
                    (if False then
                        "✅"

                     else
                        "⚡️"
                    )
                )
            )
            [ width (px 300) ]
            { onChange = \_ -> Noop
            , text = link
            , placeholder = Nothing
            , label = Element.Input.labelHidden "Download link"
            }
        , UI.button
            ([ centerX
             , width (fill |> maximum 300)
             ]
                ++ ifThenElese model.copied [ Element.Background.color UI.colors.yellow ] []
            )
            (ifThenElese model.copied "COPIED" "COPY LINK")
            (Copy link)
        ]


progressBarNew : Float -> Element msg
progressBarNew progress =
    let
        progressPortion =
            round (progress * 100)
    in
    row
        [ width (px 300)
        , padding 8
        , Element.Border.width UI.borderWidth
        ]
        [ el
            [ width (fillPortion progressPortion)
            , Element.Background.color UI.colors.yellow
            , height (px 20)
            ]
            Element.none
        , el
            [ width (fillPortion (100 - progressPortion))
            ]
            Element.none
        ]


fractionFromProgress : Http.Progress -> Float
fractionFromProgress arg1 =
    case arg1 of
        Http.Sending s ->
            Http.fractionSent s

        Http.Receiving r ->
            Http.fractionReceived r
