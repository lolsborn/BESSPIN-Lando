{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeOperators #-}
module Main where

import Lobot.Core.Instances
import Lobot.Core.Kind
import Lobot.Core.Kind.Pretty
import Lobot.Core.Lexer
import Lobot.Core.Parser
import Lobot.Core.TypeCheck

import Data.Parameterized.Classes
import Data.Parameterized.Context hiding (last)
import Data.Parameterized.Some
import Options.Applicative

data Options = Options { inFileName :: String }
  deriving Show

options :: Parser Options
options = Options
      <$> argument str (metavar "FILE")

main :: IO ()
main = ig =<< execParser i
  where i = info (options <**> helper)
          ( fullDesc
         <> progDesc "Generate instances from a Lobot file"
          )

ig :: Options -> IO ()
ig Options{..} = do
  fileStr <- readFile inFileName
  let tokens = lexLobot fileStr
      decls = parse tokens
  case typeCheck knownRepr decls of
    Left err -> do putStrLn $ "Type error."
                   print err
    Right [] -> print "No kinds in file"
    Right ks -> case last ks of
      Some k -> do
        putStrLn $
          "Last kind in " ++ inFileName ++ ":"
        putStrLn $ "----------------"
        print $ ppKind k
        putStrLn $ "----------------"
        putStrLn "Press enter to see a new instance."
        instanceSession evenEnv "/usr/local/bin/z3" knownRepr k

-- Default function environment. This will change.
type EvenEnv = EmptyCtx ::> FunType "is_even" (EmptyCtx ::> IntType) BoolType

is_even :: Assignment Literal (EmptyCtx ::> IntType) -> IO (Literal BoolType)
is_even (Empty :> IntLit x) = return $ BoolLit (even x)

evenEnv :: Assignment (FunctionImpl IO) EvenEnv
evenEnv = Empty :> FunctionImpl knownRepr is_even
