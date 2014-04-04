{-# OPTIONS --no-positivity-check #-}
module BytecodeF where

open import Data.List using (_∷_)

open import Basic using (𝔹ₛ; ℕₛ; StackType; Bytecode; ⁅_⁆')


record HFunctor {Ip Iq : Set} (F : (Ip -> Iq -> Set) -> (Ip -> Iq -> Set)) : Set₁ where
  constructor isHFunctor
  field
    hmap : {a : Ip -> Iq -> Set} -> {b : Ip -> Iq -> Set} 
         -> ( {ixp : Ip} -> {ixq : Iq} ->   a ixp ixq ->   b ixp ixq )
         -> ( {ixp : Ip} -> {ixq : Iq} -> F a ixp ixq -> F b ixp ixq )  

record HTree {Ip Iq : Set} (F : (Ip -> Iq -> Set) -> (Ip -> Iq -> Set) ) (ixp : Ip) (ixq : Iq) : Set where
  constructor HTreeIn
  field
    treeOut : F (HTree F) ixp ixq

data HGraph' {Ip Iq : Set} (F : (Ip -> Iq -> Set) -> (Ip -> Iq -> Set) ) (v : Set) (ixp : Ip) (ixq : Iq) : Set where
  HGraphIn : F (HGraph' F v) ixp ixq -> HGraph' F v ixp ixq
  HGraphLet : (HGraph' F v ixp ixq) -> (v -> HGraph' F v ixp ixq) -> HGraph' F v ixp ixq  
  HGraphVar : v -> HGraph' F v ixp ixq

data HGraph {Ip Iq : Set} (F : (Ip -> Iq -> Set) -> (Ip -> Iq -> Set) ) (ixp : Ip) (ixq : Iq) : Set₁ where
  mkHGraph : (v : Set) -> (HGraph' F v ixp ixq) -> HGraph F ixp ixq


data BytecodeF (r : StackType -> StackType -> Set) : (StackType -> StackType -> Set) where  
    SKIP : ∀ {s}    → BytecodeF r s s
    PUSH : ∀ {α s}  → (x : ⁅ α ⁆') → BytecodeF r s (α ∷ s)
    ADD  : ∀ {s}    → BytecodeF r (ℕₛ ∷ ℕₛ ∷ s) (ℕₛ ∷ s)
    IF   : ∀ {s s′} → (t : r s s′) → (e : r s s′) → BytecodeF r (𝔹ₛ ∷ s) s′
    _⟫_  : ∀ {s₀ s₁ s₂} → (c₁ : r s₀ s₁) → (c₂ : r s₁ s₂) → BytecodeF r s₀ s₂

mapBytecodeF : {a b : StackType -> StackType -> Set} -> ( {ixp ixq : StackType} ->           a ixp ixq ->           b ixp ixq) 
                                                     -> ( {ixp ixq : StackType} -> BytecodeF a ixp ixq -> BytecodeF b ixp ixq)
mapBytecodeF f SKIP = SKIP
mapBytecodeF f (PUSH x) = PUSH x
mapBytecodeF f ADD = ADD
mapBytecodeF f (IF t e) = IF (f t) (f e)
mapBytecodeF f (_⟫_ c₁ c₂)= f c₁ ⟫ f c₂


BytecodeFisFunctor : HFunctor BytecodeF
BytecodeFisFunctor =
  record {
    hmap = mapBytecodeF
  } 

toTree : {ixp ixq : StackType} -> Bytecode ixp ixq -> HTree BytecodeF ixp ixq
toTree Basic.SKIP = HTreeIn SKIP
toTree (Basic.PUSH x) = HTreeIn (PUSH x)
toTree Basic.ADD = HTreeIn ADD
toTree (Basic.IF bc₁ bc₂) = HTreeIn (IF (toTree bc₁) (toTree bc₂))
toTree (bc₁ Basic.⟫ bc₂) = HTreeIn (toTree bc₁ ⟫ toTree bc₂)  

fromTree : {ixp ixq : StackType} -> HTree BytecodeF ixp ixq -> Bytecode ixp ixq
fromTree (HTreeIn SKIP) = Basic.SKIP
fromTree (HTreeIn (PUSH x)) = Basic.PUSH x
fromTree (HTreeIn ADD) = Basic.ADD
fromTree (HTreeIn (IF t e)) = Basic.IF (fromTree t) (fromTree e)
fromTree (HTreeIn (c₁ ⟫ c₂)) = fromTree c₁ Basic.⟫ fromTree c₂

fold : {Ip Iq : Set} 
    -> {F : (Ip -> Iq -> Set) -> (Ip -> Iq -> Set)}
    -> HFunctor F
       
    -> {r : Ip -> Iq -> Set}
    -> ( {ixp : Ip} {ixq : Iq} ->       F r ixp ixq -> r ixp ixq) 
    -> ( {ixp : Ip} {ixq : Iq} -> HTree F   ixp ixq -> r ixp ixq)
fold functor alg (HTreeIn r) = 
  let hmap = HFunctor.hmap functor
  in alg (hmap (fold functor alg) r)