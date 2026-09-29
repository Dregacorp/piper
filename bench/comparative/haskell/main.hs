{-# LANGUAGE BangPatterns #-}

module Main where

import Control.Category ((>>>))
import Control.Exception (evaluate)
import Control.Monad (unless)
import Data.Array.Unboxed (UArray, (!), listArray)
import Data.Bits ((.&.))
import Data.Function ((&))
import Data.Int (Int64)
import Data.List (sort)
import GHC.Clock (getMonotonicTimeNSec)
import System.Environment (getArgs)
import Text.Printf (printf)


iterations :: Int
iterations = 3000000


repeats :: Int
repeats = 9


inputCount :: Int
inputCount = 1024


expected2 :: Int64
expected2 = 26756370240


expected3 :: Int64
expected3 = 324207267022400


expected4 :: Int64
expected4 = -324207267022400


doubleF :: Int64 -> Int64
doubleF x = x * 2
{-# NOINLINE doubleF #-}


addOneF :: Int64 -> Int64
addOneF x = x + 1
{-# NOINLINE addOneF #-}


squareF :: Int64 -> Int64
squareF x = x * x
{-# NOINLINE squareF #-}


negateF :: Int64 -> Int64
negateF x = -x
{-# NOINLINE negateF #-}


makeInputs :: Int64 -> UArray Int Int64
makeInputs seed =
  listArray
    (0, inputCount - 1)
    [ ((fromIntegral i * 17) + 31 + seed) `mod` 10000
    | i <- [0 .. inputCount - 1]
    ]


direct2 :: UArray Int Int64 -> Int64
direct2 xs =
  go 0 0
  where
    go !i !total
      | i == iterations =
          total

      | otherwise =
          let !x =
                xs ! (i .&. (inputCount - 1))

              !y =
                addOneF
                  (doubleF x)

          in go
               (i + 1)
               (total + y)

{-# NOINLINE direct2 #-}


direct3 :: UArray Int Int64 -> Int64
direct3 xs =
  go 0 0
  where
    go !i !total
      | i == iterations =
          total

      | otherwise =
          let !x =
                xs ! (i .&. (inputCount - 1))

              !y =
                squareF
                  (addOneF
                    (doubleF x))

          in go
               (i + 1)
               (total + y)

{-# NOINLINE direct3 #-}


direct4 :: UArray Int Int64 -> Int64
direct4 xs =
  go 0 0
  where
    go !i !total
      | i == iterations =
          total

      | otherwise =
          let !x =
                xs ! (i .&. (inputCount - 1))

              !y =
                negateF
                  (squareF
                    (addOneF
                      (doubleF x)))

          in go
               (i + 1)
               (total + y)

{-# NOINLINE direct4 #-}


pipe2 :: UArray Int Int64 -> Int64
pipe2 xs =
  go 0 0
  where
    go !i !total
      | i == iterations =
          total

      | otherwise =
          let !x =
                xs ! (i .&. (inputCount - 1))

              !y =
                x
                  & doubleF
                  & addOneF

          in go
               (i + 1)
               (total + y)

{-# NOINLINE pipe2 #-}


pipe3 :: UArray Int Int64 -> Int64
pipe3 xs =
  go 0 0
  where
    go !i !total
      | i == iterations =
          total

      | otherwise =
          let !x =
                xs ! (i .&. (inputCount - 1))

              !y =
                x
                  & doubleF
                  & addOneF
                  & squareF

          in go
               (i + 1)
               (total + y)

{-# NOINLINE pipe3 #-}


pipe4 :: UArray Int Int64 -> Int64
pipe4 xs =
  go 0 0
  where
    go !i !total
      | i == iterations =
          total

      | otherwise =
          let !x =
                xs ! (i .&. (inputCount - 1))

              !y =
                x
                  & doubleF
                  & addOneF
                  & squareF
                  & negateF

          in go
               (i + 1)
               (total + y)

{-# NOINLINE pipe4 #-}


composed2F :: Int64 -> Int64
composed2F =
  doubleF >>> addOneF

{-# NOINLINE composed2F #-}


composed3F :: Int64 -> Int64
composed3F =
  doubleF >>>
  addOneF >>>
  squareF

{-# NOINLINE composed3F #-}


composed4F :: Int64 -> Int64
composed4F =
  doubleF >>>
  addOneF >>>
  squareF >>>
  negateF

{-# NOINLINE composed4F #-}


compose2 :: UArray Int Int64 -> Int64
compose2 xs =
  go 0 0
  where
    go !i !total
      | i == iterations =
          total

      | otherwise =
          let !x =
                xs ! (i .&. (inputCount - 1))

          in go
               (i + 1)
               (total + composed2F x)

{-# NOINLINE compose2 #-}


compose3 :: UArray Int Int64 -> Int64
compose3 xs =
  go 0 0
  where
    go !i !total
      | i == iterations =
          total

      | otherwise =
          let !x =
                xs ! (i .&. (inputCount - 1))

          in go
               (i + 1)
               (total + composed3F x)

{-# NOINLINE compose3 #-}


compose4 :: UArray Int Int64 -> Int64
compose4 xs =
  go 0 0
  where
    go !i !total
      | i == iterations =
          total

      | otherwise =
          let !x =
                xs ! (i .&. (inputCount - 1))

          in go
               (i + 1)
               (total + composed4F x)

{-# NOINLINE compose4 #-}


median :: [Integer] -> Integer
median xs =
  let ys = sort xs
  in ys !! (length ys `div` 2)


measure
  :: UArray Int Int64
  -> String
  -> (UArray Int Int64 -> Int64)
  -> IO ()
measure inputs name f = do

  _ <- evaluate (f inputs)

  mapM_
    (\_ -> evaluate (f inputs))
    [1 .. 3 :: Int]

  samples <-
    mapM
      (\_ -> do
          started <-
            getMonotonicTimeNSec

          result <-
            evaluate (f inputs)

          finished <-
            getMonotonicTimeNSec

          pure
            ( fromIntegral (finished - started)
            , result
            ))
      [1 .. repeats]

  let times =
        map fst samples

      med =
        median times

      nsPerOp :: Double
      nsPerOp =
        fromIntegral med /
        fromIntegral iterations

      checksum =
        snd (last samples)

  printf
    "RESULT,Haskell,%s,%.6f,%d\n"
    name
    nsPerOp
    checksum


main :: IO ()
main = do

  args <-
    getArgs

  let seed =
        case args of
          [] ->
            0

          value : _ ->
            read value

      inputs =
        makeInputs seed

      d2 =
        direct2 inputs

      d3 =
        direct3 inputs

      d4 =
        direct4 inputs

  unless (d2 == expected2) $
    error "direct2 checksum mismatch"

  unless (d3 == expected3) $
    error "direct3 checksum mismatch"

  unless (d4 == expected4) $
    error "direct4 checksum mismatch"

  unless (composed2F 7 == addOneF (doubleF 7)) $
    error "compose2 correctness failure"

  unless (composed3F 7 == squareF (addOneF (doubleF 7))) $
    error "compose3 correctness failure"

  unless (composed4F 7 == negateF (squareF (addOneF (doubleF 7)))) $
    error "compose4 correctness failure"

  printf "VERSION,Haskell,unknown\n"

  measure inputs "direct2" direct2
  measure inputs "pipe2" pipe2
  measure inputs "compose2" compose2

  measure inputs "direct3" direct3
  measure inputs "pipe3" pipe3
  measure inputs "compose3" compose3

  measure inputs "direct4" direct4
  measure inputs "pipe4" pipe4
  measure inputs "compose4" compose4