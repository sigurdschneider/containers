Require Import MapInterface.

Notation "'[]'" := (empty _)(at level 0, no associativity) : map_scope.
Notation "M '[-' key '-]' " :=
  (find key M)(at level 31, left associativity) : map_scope.
Notation "M '[-' key '<-' v '-]' " :=
  (add key v M)(at level 29, left associativity) : map_scope.
