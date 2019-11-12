module Main exposing (main)

import Browser
import Html
    exposing
        ( Html
        , button
        , div
        , h1
        , input
        , li
        , ol
        , span
        , text
        )
import Html.Attributes
    exposing
        ( checked
        , class
        , disabled
        , type_
        , value
        )
import Html.Events
    exposing
        ( onCheck
        , onClick
        , onInput
        )
import Http
import Json.Decode as Json



--- MODEL


type alias Todo =
    { id : Int
    , title : String
    , completed : Bool
    }


type alias Model =
    { todos : TodoList
    , newTodoTitle : String
    }


type TodoList
    = Fetching
    | Loaded (List Todo)
    | Updating (List Todo)
    | Failed


initialModel : Model
initialModel =
    { todos = Fetching, newTodoTitle = "" }


toLoadingState : Model -> Model
toLoadingState model =
    let
        newTodos =
            case model.todos of
                Fetching ->
                    Fetching

                Loaded todos ->
                    Updating todos

                Updating todos ->
                    Updating todos

                Failed ->
                    Fetching
    in
    { model | todos = newTodos }


todosDecoder : Json.Decoder (List Todo)
todosDecoder =
    Json.list todoDecoder


todoDecoder : Json.Decoder Todo
todoDecoder =
    Json.map3 Todo
        (Json.field "id" Json.int)
        (Json.field "title" Json.string)
        (Json.field "completed" Json.bool)



--- UPDATE


type Msg
    = FetchedTodos (Result Http.Error (List Todo))
    | TodoCompleteToggled Int Bool
    | GotUpdateTodoResponse (Result Http.Error ())
    | NewTodoTitleChanged String
    | AddTodoClicked
    | GotAddTodoClickedResponse (Result Http.Error ())


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FetchedTodos result ->
            case result of
                Err _ ->
                    ( { model | todos = Failed }, Cmd.none )

                Ok todos ->
                    ( { model | todos = Loaded todos }, Cmd.none )

        TodoCompleteToggled id completed ->
            ( toLoadingState model, updateTodo id completed )

        GotUpdateTodoResponse result ->
            case result of
                Err _ ->
                    ( { model | todos = Failed }, Cmd.none )

                Ok () ->
                    ( toLoadingState model, fetchTodos )

        NewTodoTitleChanged title ->
            ( { model | newTodoTitle = title }, Cmd.none )

        AddTodoClicked ->
            ( toLoadingState model, addTodo model.newTodoTitle )

        GotAddTodoClickedResponse result ->
            case result of
                Err _ ->
                    ( { model | todos = Failed }, Cmd.none )

                Ok () ->
                    ( { model | newTodoTitle = "" }, fetchTodos )


todoUrl : String -> String
todoUrl post =
    "http://localhost:8080/" ++ post


fetchTodos : Cmd Msg
fetchTodos =
    Http.get
        { url = todoUrl "todos"
        , expect = Http.expectJson FetchedTodos todosDecoder
        }


updateTodo : Int -> Bool -> Cmd Msg
updateTodo id completed =
    let
        completedStr =
            if completed then
                "true"

            else
                "false"
    in
    Http.post
        { url = todoUrl ("todos/" ++ String.fromInt id ++ "?completed=" ++ completedStr)
        , body = Http.emptyBody
        , expect = Http.expectWhatever GotUpdateTodoResponse
        }


addTodo : String -> Cmd Msg
addTodo title =
    Http.post
        { url = todoUrl "todos?title=" ++ title
        , body = Http.emptyBody
        , expect = Http.expectWhatever GotAddTodoClickedResponse
        }



--- VIEW


view : Model -> Html Msg
view model =
    let
        innerView =
            case model.todos of
                Fetching ->
                    div [ class "loading" ] []

                Loaded todos ->
                    div [] [ todosView todos ]

                Updating todos ->
                    div [ class "loading" ] [ todosView todos ]

                Failed ->
                    errorView
    in
    div [ class "todo-app" ]
        [ h1 [] [ text "Todos" ]
        , innerView
        , addTodoView model
        ]


todosView : List Todo -> Html Msg
todosView todos =
    let
        todoRows =
            List.map todoRow todos
    in
    ol [ class "todo-list" ] todoRows


todoRow : Todo -> Html Msg
todoRow todo =
    li []
        [ input [ type_ "checkbox", checked todo.completed, onCheck (TodoCompleteToggled todo.id) ] []
        , span [] [ text todo.title ]
        ]


addTodoView : Model -> Html Msg
addTodoView model =
    let
        allowAdd =
            String.isEmpty model.newTodoTitle
    in
    div []
        [ span [] [ text "Add todo" ]
        , input [ type_ "text", onInput NewTodoTitleChanged, value model.newTodoTitle ] []
        , button [ onClick AddTodoClicked, disabled allowAdd ] [ text "Add" ]
        ]


errorView : Html Msg
errorView =
    div [] [ text "There was an error" ]



--- PROGRAM


init : () -> ( Model, Cmd Msg )
init _ =
    ( initialModel, fetchTodos )


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }
