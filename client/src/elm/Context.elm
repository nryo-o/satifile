module Context exposing (..)


type Context a b
    = WithContext (a -> b)


withContext : (a -> b) -> Context a b
withContext =
    WithContext


runContext : Context a b -> a -> b
runContext (WithContext fn) a =
    fn a
