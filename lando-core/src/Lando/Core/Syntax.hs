{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeApplications #-}

{-|
Module      : Lando.Core.Syntax
Description : The untyped AST for the Lando LOBOT sublanguage.
Copyright   : (c) Ben Selfridge, Matthew Yacavone, 2020
License     : BSD3
Maintainer  : benselfridge@galois.com
Stability   : experimental
Portability : POSIX

This module defines the untyped AST for the LOBOT sublanguage of lando. When
parsing a concrete syntax for Lando, this is the data type we target. Then, this
type passes through the type checker to produce the typed AST in
'Lando.Core.Kind'.
-}
module Lando.Core.Syntax where

import Data.Text (Text)

data KindDecl = KindDecl { kindDeclName :: Text
                         , kindDeclType :: Type
                         , kindDeclConstraints :: [Expr]
                         }

data Type = BoolType
          | IntType
          | EnumType [Text]
          | SetType [Text]
          | StructType [(Text, Type)]
          | KindNames [Text]

data Expr = LiteralExpr Literal
          | SelfExpr
          | FieldExpr Expr Text -- ^ struct.field
          | EqExpr Expr Expr
          | LteExpr Expr Expr
          | MemberExpr Expr Expr
          | ImpliesExpr Expr Expr
          | NotExpr Expr
          | IsInstance Text Type -- ^ field : type (in a constraint)

data Literal = BoolLit Bool
             | IntLit Integer
             | EnumLit Text
             | SetLit [Text]
             | StructLit [(Text, Expr)]
