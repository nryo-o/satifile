module Utils where

import Prelude

import Data.Either (Either(..))
import Data.Time.Duration (class Duration, Milliseconds(..), Seconds(..), fromDuration)
import Unsafe.Coerce (unsafeCoerce)

-- | Megabyte
mb :: Int -> Int
mb = (_ * (1024 * 1024))

undefined :: forall a. a
undefined = unsafeCoerce unit

mapLeft :: forall l l' r. (l -> l') -> Either l r -> Either l' r
mapLeft fn ei =
  case ei of
    Left err -> Left $ fn err
    Right val -> Right val

unwrapSeconds :: Seconds -> Number
unwrapSeconds (Seconds num) = num

unwrapMilliseconds :: Milliseconds -> Number
unwrapMilliseconds (Milliseconds ms) = ms

toMilliseconds :: forall a. Duration a => a -> Number
toMilliseconds = unwrapMilliseconds <<< fromDuration

atLeast :: forall a. Ord a => a -> a -> a
atLeast min num =
  if num < min then
    min
  else
    num

-- | The prefix for all escape codes.
esc :: String
esc = "\x1b["

black :: String -> String
black = colorize "30"

red :: String -> String
red = colorize "31"

green :: String -> String
green = colorize "32"

yellow :: String -> String
yellow = colorize "33"

blue :: String -> String
blue = colorize "34"

magenta :: String -> String
magenta = colorize "35"

cyan :: String -> String
cyan = colorize "36"

white :: String -> String
white = colorize "37"

colorize :: String -> String -> String
colorize colorCode str = esc <> colorCode <> "m" <> str <> esc <> "0m"