{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE UndecidableInstances #-}

{-|
Module      : Lobot.Types
Description : The types of the Lobot language.
Copyright   : (c) Ben Selfridge, Matthew Yacavone, 2020
License     : BSD3
Maintainer  : benselfridge@galois.com
Stability   : experimental
Portability : POSIX

This module defines the types of data and functions in Lobot, as well as some
type families and functions for ensuring types are non-abstract.
-}

module Lobot.Types
  ( -- * Types
    Type(..), BoolType, IntType, EnumType, SetType, StructType, AbsType
  , TypeRepr(..)
  , FieldRepr(..)
    -- * Functions
  , FunctionType(..), FunType
  , FunctionTypeRepr(..)
    -- * Abstract type utilities
  , HasAbstractTypes(..)
  , Proof(..)
  , nonAbstractIndex
  ) where

import Data.Parameterized.BoolRepr
import Data.Parameterized.Classes
import Data.Parameterized.Context
import Data.Parameterized.SymbolRepr
import GHC.TypeLits
import GHC.Exts (Constraint)

-- | The types of LOBOT.
data Type = BoolType
          | IntType
          | EnumType (Ctx Symbol)
          | SetType (Ctx Symbol)
          | StructType (Ctx (Symbol, Type))
          | AbsType Symbol

type BoolType = 'BoolType
type IntType = 'IntType
type EnumType = 'EnumType
type SetType = 'SetType
type StructType = 'StructType
type AbsType = 'AbsType

-- | Term-level representative of a type.
data TypeRepr tp where
  BoolRepr   :: TypeRepr BoolType
  IntRepr    :: TypeRepr IntType
  EnumRepr   :: 1 <= CtxSize cs
             => Assignment SymbolRepr cs
             -> TypeRepr (EnumType cs)
  SetRepr    :: 1 <= CtxSize cs
             => Assignment SymbolRepr cs
             -> TypeRepr (SetType cs)
  StructRepr :: Assignment FieldRepr ftps
             -> TypeRepr (StructType ftps)
  AbsRepr    :: SymbolRepr s -> TypeRepr (AbsType s)
deriving instance Show (TypeRepr tp)
instance ShowF TypeRepr

instance TestEquality TypeRepr where
  testEquality BoolRepr BoolRepr = Just Refl
  testEquality IntRepr IntRepr = Just Refl
  testEquality (EnumRepr cs) (EnumRepr cs') = case testEquality cs cs' of
    Just Refl -> Just Refl
    Nothing -> Nothing
  testEquality (SetRepr cs) (SetRepr cs') = case testEquality cs cs' of
    Just Refl -> Just Refl
    Nothing -> Nothing
  testEquality (StructRepr flds) (StructRepr flds') = case testEquality flds flds' of
    Just Refl -> Just Refl
    Nothing -> Nothing
  testEquality (AbsRepr s) (AbsRepr s') = case testEquality s s' of
    Just Refl -> Just Refl
    Nothing -> Nothing
  testEquality _ _ = Nothing

instance KnownRepr TypeRepr BoolType
  where knownRepr = BoolRepr
instance KnownRepr TypeRepr IntType
  where knownRepr = IntRepr
instance (1 <= CtxSize cs, KnownRepr (Assignment SymbolRepr) cs) => KnownRepr TypeRepr (EnumType cs)
  where knownRepr = EnumRepr knownRepr
instance (1 <= CtxSize cs, KnownRepr (Assignment SymbolRepr) cs) => KnownRepr TypeRepr (SetType cs)
  where knownRepr = SetRepr knownRepr
instance KnownRepr (Assignment FieldRepr) ftps => KnownRepr TypeRepr (StructType ftps)
  where knownRepr = StructRepr knownRepr
instance KnownRepr SymbolRepr s => KnownRepr TypeRepr (AbsType s)
  where knownRepr = AbsRepr knownRepr

-- | A 'FieldRepr' is a key, type pair. A struct type is defined by a list of
-- 'FieldRepr's.
data FieldRepr (pr :: (Symbol, Type)) where
  FieldRepr :: { fieldName :: SymbolRepr nm
               , fieldType :: TypeRepr tp } -> FieldRepr '(nm, tp)

instance TestEquality FieldRepr where
  testEquality (FieldRepr nm tp) (FieldRepr nm' tp') =
    case (testEquality nm nm', testEquality tp tp') of
      (Just Refl, Just Refl) -> Just Refl
      _ -> Nothing

deriving instance Show (FieldRepr pr)
instance ShowF FieldRepr
instance (KnownSymbol nm, KnownRepr TypeRepr tp) => KnownRepr FieldRepr '(nm, tp) where
  knownRepr = FieldRepr knownRepr knownRepr

-- | Types for functions in Lobot.
data FunctionType = FunType Symbol (Ctx Type) Type

type FunType = 'FunType

-- | Term-level representative of a 'FunctionType'.
data FunctionTypeRepr fntp where
  FunctionTypeRepr :: { functionName :: SymbolRepr nm
                      , functionArgTypes :: Assignment TypeRepr args
                      , functionRetType :: TypeRepr ret
                      } -> FunctionTypeRepr (FunType nm args ret)

deriving instance Show (FunctionTypeRepr fntp)
instance ShowF FunctionTypeRepr
instance TestEquality FunctionTypeRepr where
  testEquality (FunctionTypeRepr nm args ret) (FunctionTypeRepr nm' args' ret')=
    case (testEquality nm nm', testEquality args args', testEquality ret ret') of
      (Just Refl, Just Refl, Just Refl) -> Just Refl
      _ -> Nothing
instance ( KnownSymbol nm
         , KnownRepr (Assignment TypeRepr) args
         , KnownRepr TypeRepr ret
         ) => KnownRepr FunctionTypeRepr (FunType nm args ret) where
  knownRepr = FunctionTypeRepr knownRepr knownRepr knownRepr


-- | A proof that a given constraint holds.
-- TODO: Move this elsewhere? (does it belong in parameterized-utils?)
data Proof (c :: Constraint) where
  Proof :: c => Proof c

class HasAbstractTypes k (r :: k -> *) where
  -- | A type family which indicates which @t :: k@ are abstract. Note that
  -- since associated type families are not closed, if @t :: k@ should be
  -- considered abstract then @NonAbstract t@ should be an absurd constraint,
  -- e.g. @'True ~ 'False@.
  type NonAbstract (t :: k) :: Constraint
  -- | A function which, if it can, provides a proof that a @t :: k@ is
  -- abstract, given a term-level representation @r t@.
  isNonAbstract :: r t -> Maybe (Proof (NonAbstract t))

instance HasAbstractTypes Type TypeRepr where
  type NonAbstract BoolType = ()
  type NonAbstract IntType = ()
  type NonAbstract (EnumType cs) = ()
  type NonAbstract (SetType cs) = ()
  type NonAbstract (StructType ftps) = NonAbstract ftps
  type NonAbstract (AbsType _) = 'True ~ 'False
  isNonAbstract BoolRepr = Just Proof
  isNonAbstract IntRepr = Just Proof
  isNonAbstract (EnumRepr _) = Just Proof
  isNonAbstract (SetRepr _) = Just Proof
  isNonAbstract (StructRepr flds) = do Proof <- isNonAbstract flds
                                       Just Proof
  isNonAbstract (AbsRepr _) = Nothing

instance HasAbstractTypes (Symbol, Type) FieldRepr where
  type NonAbstract '(_, tp) = NonAbstract tp
  isNonAbstract (FieldRepr _ tp) = isNonAbstract tp

instance HasAbstractTypes k r => HasAbstractTypes (Ctx k) (Assignment r) where
  type NonAbstract EmptyCtx = ()
  type NonAbstract (ctx ::> t) = (NonAbstract ctx, NonAbstract t)
  isNonAbstract Empty = Just Proof
  isNonAbstract (ctx :> x) = do Proof <- isNonAbstract ctx
                                Proof <- isNonAbstract x
                                Just Proof

newtype ProofNonAbstract t = PfNonAbs { pfNonAbs :: Proof (NonAbstract t) }

nonAbstractCtx :: (HasAbstractTypes k r, NonAbstract ctx)
               => Assignment r ctx
               -> Assignment ProofNonAbstract ctx
nonAbstractCtx Empty = Empty
nonAbstractCtx (ctx :> _) = nonAbstractCtx ctx :> PfNonAbs Proof

-- | Given an index into a context of non-abstract things, provide a proof
-- that the thing at the given index is indeed non-abstract.
nonAbstractIndex :: (HasAbstractTypes k r, NonAbstract ctx)
                 => Assignment r ctx
                 -> Index ctx t
                 -> Proof (NonAbstract t)
nonAbstractIndex rs i = pfNonAbs $ (nonAbstractCtx rs) ! i
