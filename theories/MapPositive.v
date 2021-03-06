Require Import Bool.
Require Import ZArith.
Require Import OrderedType.
Require Import OrderedTypeEx.
Require Import MapInterface.

(** File adapted from FMapPositive.v in the standard lib *)

Set Implicit Arguments.
Generalizable All Variables.

Open Local Scope positive_scope.

(** * An implementation of [FMapInterface.S] for positive keys. *)

(** This file is an adaptation to the [FMap] framework of a work by
  Xavier Leroy and Sandrine Blazy (used for building certified compilers).
  Keys are of type [positive], and maps are binary trees: the sequence
  of binary digits of a positive number corresponds to a path in such a tree.
  This is quite similar to the [IntMap] library, except that no path compression
  is implemented, and that the current file is simple enough to be
  self-contained. *)

(** Even if [positive] can be seen as an ordered type with respect to the
  usual order (see [OrderedTypeEx]), we use here a lexicographic order
  over bits, which is more natural here (lower bits are considered first). *)
(** The corresponding instance is already defined in OrderedTypeEx,
   as [positive_l2r_OrderedType]. *)

(** Other positive stuff *)

Fixpoint append (i j : positive) {struct i} : positive :=
    match i with
      | xH => j
      | xI ii => xI (append ii j)
      | xO ii => xO (append ii j)
    end.

Lemma append_assoc_0 :
  forall (i j : positive), append i (xO j) = append (append i (xO xH)) j.
Proof.
 induction i; intros; destruct j; simpl;
 try rewrite (IHi (xI j));
 try rewrite (IHi (xO j));
 try rewrite <- (IHi xH);
 auto.
Qed.

Lemma append_assoc_1 :
  forall (i j : positive), append i (xI j) = append (append i (xI xH)) j.
Proof.
 induction i; intros; destruct j; simpl;
 try rewrite (IHi (xI j));
 try rewrite (IHi (xO j));
 try rewrite <- (IHi xH);
 auto.
Qed.

Lemma append_neutral_r : forall (i : positive), append i xH = i.
Proof.
 induction i; simpl; congruence.
Qed.

Lemma append_neutral_l : forall (i : positive), append xH i = i.
Proof.
 simpl; auto.
Qed.


(** The module of maps over positive keys *)
Module PositiveMap.
  Module E.
    Definition eq (x y : positive) := @_eq positive
      (@SOT_as_OT positive _ positive_l2r_OrderedType) x y.
    Definition lt (x y : positive) := @_lt positive
      (@SOT_as_OT positive _ positive_l2r_OrderedType) x y.
  End E.
  Hint Unfold E.eq E.lt.
  Module ME := KeyOrderedType.
  Definition key := positive.

  Inductive tree (A : Type) :=
    | Leaf : tree A
    | Node : tree A -> option A -> tree A -> tree A.

  Definition t := tree.

  Section A.
  Variable A:Type.

  Implicit Arguments Leaf [A].

  Definition empty : t A := Leaf.

  Fixpoint is_empty (m : t A) {struct m} : bool :=
   match m with
    | Leaf => true
    | Node l None r => (is_empty l) && (is_empty r)
    | _ => false
   end.

  Fixpoint find (i : positive) (m : t A) {struct i} : option A :=
    match m with
    | Leaf => None
    | Node l o r =>
        match i with
        | xH => o
        | xO ii => find ii l
        | xI ii => find ii r
        end
    end.

  Fixpoint mem (i : positive) (m : t A) {struct i} : bool :=
    match m with
    | Leaf => false
    | Node l o r =>
        match i with
        | xH => match o with None => false | _ => true end
        | xO ii => mem ii l
        | xI ii => mem ii r
        end
    end.

  Fixpoint add (i : positive) (v : A) (m : t A) {struct i} : t A :=
    match m with
    | Leaf =>
        match i with
        | xH => Node Leaf (Some v) Leaf
        | xO ii => Node (add ii v Leaf) None Leaf
        | xI ii => Node Leaf None (add ii v Leaf)
        end
    | Node l o r =>
        match i with
        | xH => Node l (Some v) r
        | xO ii => Node (add ii v l) o r
        | xI ii => Node l o (add ii v r)
        end
    end.

  Fixpoint insert (i : positive) (v : A) (f : A -> A) (m : t A) : t A :=
    match m with
    | Leaf =>
        match i with
        | xH => Node Leaf (Some v) Leaf
        | xO ii => Node (insert ii v f Leaf) None Leaf
        | xI ii => Node Leaf None (insert ii v f Leaf)
        end
    | Node l o r =>
        match i with
        | xH =>
          Node l (match o with None => Some v | Some v' => Some (f v') end) r
        | xO ii => Node (insert ii v f l) o r
        | xI ii => Node l o (insert ii v f r)
        end
    end.

  Fixpoint adjust (i : positive) (f : A -> A) (m : t A) : t A :=
    match m with
    | Leaf =>
        match i with
        | xH => m
        | xO ii => Node (adjust ii f Leaf) None Leaf
        | xI ii => Node Leaf None (adjust ii f Leaf)
        end
    | Node l o r =>
        match i with
        | xH =>
          Node l (match o with None => None | Some v => Some (f v) end) r
        | xO ii => Node (adjust ii f l) o r
        | xI ii => Node l o (adjust ii f r)
        end
    end.

  Fixpoint remove (i : positive) (m : t A) {struct i} : t A :=
    match i with
    | xH =>
        match m with
        | Leaf => Leaf
        | Node Leaf o Leaf => Leaf
        | Node l o r => Node l None r
        end
    | xO ii =>
        match m with
        | Leaf => Leaf
        | Node l None Leaf =>
            match remove ii l with
            | Leaf => Leaf
            | mm => Node mm None Leaf
            end
        | Node l o r => Node (remove ii l) o r
        end
    | xI ii =>
        match m with
        | Leaf => Leaf
        | Node Leaf None r =>
            match remove ii r with
            | Leaf => Leaf
            | mm => Node Leaf None mm
            end
        | Node l o r => Node l o (remove ii r)
        end
    end.

  (** [elements] *)

    Fixpoint xelements (m : t A) (i : positive) {struct m}
             : list (positive * A) :=
      match m with
      | Leaf => nil
      | Node l None r =>
          (xelements l (append i (xO xH))) ++ (xelements r (append i (xI xH)))
      | Node l (Some x) r =>
          (xelements l (append i (xO xH)))
          ++ ((i, x) :: xelements r (append i (xI xH)))
      end.

  (* Note: function [xelements] above is inefficient.  We should apply
     deforestation to it, but that makes the proofs even harder. *)

  Definition elements (m : t A) := xelements m xH.

  (** [cardinal] *)

  Fixpoint cardinal (m : t A) : nat :=
    match m with
      | Leaf => 0%nat
      | Node l None r => (cardinal l + cardinal r)%nat
      | Node l (Some _) r => S (cardinal l + cardinal r)
    end.

  Section CompcertSpec.

  Theorem gempty:
    forall (i: positive), find i empty = None.
  Proof.
    destruct i; simpl; auto.
  Qed.

  Theorem gss:
    forall (i: positive) (x: A) (m: t A), find i (add i x m) = Some x.
  Proof.
    induction i; destruct m; simpl; auto.
  Qed.

  Lemma gleaf : forall (i : positive), find i (Leaf : t A) = None.
  Proof. exact gempty. Qed.

  Theorem gso:
    forall (i j: positive) (x: A) (m: t A),
    i <> j -> find i (add j x m) = find i m.
  Proof.
    induction i; intros; destruct j; destruct m; simpl;
       try rewrite <- (gleaf i); auto; try apply IHi; congruence.
  Qed.

  Theorem gis:
    forall (i: positive) (x x' : A) (f : A -> A) (m : t A),
      find i m = Some x' ->
      find i (insert i x f m) = Some (f x').
  Proof.
    induction i; destruct m; simpl; auto; try (intro; discriminate).
    intro R; rewrite R; reflexivity.
  Qed.

  Theorem gin:
    forall (i: positive) (x : A) (f : A -> A) (m : t A),
      find i m = None ->
      find i (insert i x f m) = Some x.
  Proof.
    induction i; destruct m; simpl; auto; try (intro; discriminate);
      try (rewrite <- (gleaf i) at 1; auto).
    intro R; rewrite R; reflexivity.
  Qed.

  Theorem gio:
    forall (i j: positive) (x : A) (f : A -> A) (m : t A),
      i <> j -> find i (insert j x f m) = find i m.
  Proof.
    induction i; intros; destruct j; destruct m; simpl;
      try rewrite <- (gleaf i); auto; try apply IHi; congruence.
  Qed.

  Theorem gas:
    forall (i: positive) (x' : A) (f : A -> A) (m : t A),
      find i m = Some x' -> find i (adjust i f m) = Some (f x').
  Proof.
    induction i; destruct m; simpl; auto; try (intro; discriminate).
    intro R; rewrite R; reflexivity.
  Qed.

  Theorem gan:
    forall (i: positive) (f : A -> A) (m : t A),
      find i m = None -> find i (adjust i f m) = None.
  Proof.
    induction i; destruct m; simpl; auto; try (intro; discriminate);
      try (rewrite <- (gleaf i) at 1; auto).
    intro R; rewrite R; reflexivity.
  Qed.

  Theorem gao:
    forall (i j: positive) (f : A -> A) (m : t A),
      i <> j -> find i (adjust j f m) = find i m.
  Proof.
    induction i; intros; destruct j; destruct m; simpl;
      try rewrite <- (gleaf i); auto; try apply IHi; congruence.
  Qed.

  Lemma rleaf : forall (i : positive), remove i (Leaf : t A) = Leaf.
  Proof. destruct i; simpl; auto. Qed.

  Theorem grs:
    forall (i: positive) (m: t A), find i (remove i m) = None.
  Proof.
    induction i; destruct m.
     simpl; auto.
     destruct m1; destruct o; destruct m2 as [ | ll oo rr]; simpl; auto.
      rewrite (rleaf i); auto.
      cut (find i (remove i (Node ll oo rr)) = None).
        destruct (remove i (Node ll oo rr)); auto; apply IHi.
        apply IHi.
     simpl; auto.
     destruct m1 as [ | ll oo rr]; destruct o; destruct m2; simpl; auto.
      rewrite (rleaf i); auto.
      cut (find i (remove i (Node ll oo rr)) = None).
        destruct (remove i (Node ll oo rr)); auto; apply IHi.
        apply IHi.
     simpl; auto.
     destruct m1; destruct m2; simpl; auto.
  Qed.

  Theorem gro:
    forall (i j: positive) (m: t A),
    i <> j -> find i (remove j m) = find i m.
  Proof.
    induction i; intros; destruct j; destruct m;
        try rewrite (rleaf (xI j));
        try rewrite (rleaf (xO j));
        try rewrite (rleaf 1); auto;
        destruct m1; destruct o; destruct m2;
        simpl;
        try apply IHi; try congruence;
        try rewrite (rleaf j); auto;
        try rewrite (gleaf i); auto.
     cut (find i (remove j (Node m2_1 o m2_2)) = find i (Node m2_1 o m2_2));
        [ destruct (remove j (Node m2_1 o m2_2)); try rewrite (gleaf i); auto
        | apply IHi; congruence ].
     destruct (remove j (Node m1_1 o0 m1_2)); simpl; try rewrite (gleaf i);
        auto.
     destruct (remove j (Node m2_1 o m2_2)); simpl; try rewrite (gleaf i);
        auto.
     cut (find i (remove j (Node m1_1 o0 m1_2)) = find i (Node m1_1 o0 m1_2));
        [ destruct (remove j (Node m1_1 o0 m1_2)); try rewrite (gleaf i); auto
        | apply IHi; congruence ].
     destruct (remove j (Node m2_1 o m2_2)); simpl; try rewrite (gleaf i);
        auto.
     destruct (remove j (Node m1_1 o0 m1_2)); simpl; try rewrite (gleaf i);
        auto.
  Qed.

  Lemma xelements_correct:
      forall (m: t A) (i j : positive) (v: A),
      find i m = Some v -> List.In (append j i, v) (xelements m j).
    Proof.
      induction m; intros.
       rewrite (gleaf i) in H; congruence.
       destruct o; destruct i; simpl; simpl in H.
        rewrite append_assoc_1; apply in_or_app; right; apply in_cons;
          apply IHm2; auto.
        rewrite append_assoc_0; apply in_or_app; left; apply IHm1; auto.
        rewrite append_neutral_r; apply in_or_app; injection H;
          intro EQ; rewrite EQ; right; apply in_eq.
        rewrite append_assoc_1; apply in_or_app; right; apply IHm2; auto.
        rewrite append_assoc_0; apply in_or_app; left; apply IHm1; auto.
        congruence.
    Qed.

  Theorem elements_correct:
    forall (m: t A) (i: positive) (v: A),
    find i m = Some v -> List.In (i, v) (elements m).
  Proof.
    intros m i v H.
    exact (xelements_correct m i xH H).
  Qed.

  Fixpoint xfind (i j : positive) (m : t A) {struct j} : option A :=
      match i, j with
      | _, xH => find i m
      | xO ii, xO jj => xfind ii jj m
      | xI ii, xI jj => xfind ii jj m
      | _, _ => None
      end.

  Lemma xfind_left :
    forall (j i : positive) (m1 m2 : t A) (o : option A) (v : A),
      xfind i (append j (xO xH)) m1 = Some v -> xfind i j (Node m1 o m2) = Some v.
  Proof.
    induction j; intros; destruct i; simpl; simpl in H; auto; try congruence.
    destruct i; congruence.
  Qed.

    Lemma xelements_ii :
      forall (m: t A) (i j : positive) (v: A),
      List.In (xI i, v) (xelements m (xI j)) -> List.In (i, v) (xelements m j).
    Proof.
      induction m.
       simpl; auto.
       intros; destruct o; simpl; simpl in H; destruct (in_app_or _ _ _ H);
         apply in_or_app.
        left; apply IHm1; auto.
        right; destruct (in_inv H0).
         injection H1; intros Eq1 Eq2; rewrite Eq1; rewrite Eq2; apply in_eq.
         apply in_cons; apply IHm2; auto.
        left; apply IHm1; auto.
        right; apply IHm2; auto.
    Qed.

    Lemma xelements_io :
      forall (m: t A) (i j : positive) (v: A),
      ~List.In (xI i, v) (xelements m (xO j)).
    Proof.
      induction m.
       simpl; auto.
       intros; destruct o; simpl; intro H; destruct (in_app_or _ _ _ H).
        apply (IHm1 _ _ _ H0).
        destruct (in_inv H0).
         congruence.
         apply (IHm2 _ _ _ H1).
        apply (IHm1 _ _ _ H0).
        apply (IHm2 _ _ _ H0).
    Qed.

    Lemma xelements_oo :
      forall (m: t A) (i j : positive) (v: A),
      List.In (xO i, v) (xelements m (xO j)) -> List.In (i, v) (xelements m j).
    Proof.
      induction m.
       simpl; auto.
       intros; destruct o; simpl; simpl in H; destruct (in_app_or _ _ _ H);
         apply in_or_app.
        left; apply IHm1; auto.
        right; destruct (in_inv H0).
         injection H1; intros Eq1 Eq2; rewrite Eq1; rewrite Eq2; apply in_eq.
         apply in_cons; apply IHm2; auto.
        left; apply IHm1; auto.
        right; apply IHm2; auto.
    Qed.

    Lemma xelements_oi :
      forall (m: t A) (i j : positive) (v: A),
      ~List.In (xO i, v) (xelements m (xI j)).
    Proof.
      induction m.
       simpl; auto.
       intros; destruct o; simpl; intro H; destruct (in_app_or _ _ _ H).
        apply (IHm1 _ _ _ H0).
        destruct (in_inv H0).
         congruence.
         apply (IHm2 _ _ _ H1).
        apply (IHm1 _ _ _ H0).
        apply (IHm2 _ _ _ H0).
    Qed.

    Lemma xelements_ih :
      forall (m1 m2: t A) (o: option A) (i : positive) (v: A),
      List.In (xI i, v) (xelements (Node m1 o m2) xH) -> List.In (i, v) (xelements m2 xH).
    Proof.
      destruct o; simpl; intros; destruct (in_app_or _ _ _ H).
        absurd (List.In (xI i, v) (xelements m1 2)); auto; apply xelements_io; auto.
        destruct (in_inv H0).
         congruence.
         apply xelements_ii; auto.
        absurd (List.In (xI i, v) (xelements m1 2)); auto; apply xelements_io; auto.
        apply xelements_ii; auto.
    Qed.

    Lemma xelements_oh :
      forall (m1 m2: t A) (o: option A) (i : positive) (v: A),
      List.In (xO i, v) (xelements (Node m1 o m2) xH) -> List.In (i, v) (xelements m1 xH).
    Proof.
      destruct o; simpl; intros; destruct (in_app_or _ _ _ H).
        apply xelements_oo; auto.
        destruct (in_inv H0).
         congruence.
         absurd (List.In (xO i, v) (xelements m2 3)); auto; apply xelements_oi; auto.
        apply xelements_oo; auto.
        absurd (List.In (xO i, v) (xelements m2 3)); auto; apply xelements_oi; auto.
    Qed.

    Lemma xelements_hi :
      forall (m: t A) (i : positive) (v: A),
      ~List.In (xH, v) (xelements m (xI i)).
    Proof.
      induction m; intros.
       simpl; auto.
       destruct o; simpl; intro H; destruct (in_app_or _ _ _ H).
        generalize H0; apply IHm1; auto.
        destruct (in_inv H0).
         congruence.
         generalize H1; apply IHm2; auto.
        generalize H0; apply IHm1; auto.
        generalize H0; apply IHm2; auto.
    Qed.

    Lemma xelements_ho :
      forall (m: t A) (i : positive) (v: A),
      ~List.In (xH, v) (xelements m (xO i)).
    Proof.
      induction m; intros.
       simpl; auto.
       destruct o; simpl; intro H; destruct (in_app_or _ _ _ H).
        generalize H0; apply IHm1; auto.
        destruct (in_inv H0).
         congruence.
         generalize H1; apply IHm2; auto.
        generalize H0; apply IHm1; auto.
        generalize H0; apply IHm2; auto.
    Qed.

    Lemma find_xfind_h :
      forall (m: t A) (i: positive), find i m = xfind i xH m.
    Proof.
      destruct i; simpl; auto.
    Qed.

    Lemma xelements_complete:
      forall (i j : positive) (m: t A) (v: A),
      List.In (i, v) (xelements m j) -> xfind i j m = Some v.
    Proof.
      induction i; simpl; intros; destruct j; simpl.
       apply IHi; apply xelements_ii; auto.
       absurd (List.In (xI i, v) (xelements m (xO j))); auto; apply xelements_io.
       destruct m.
        simpl in H; tauto.
        rewrite find_xfind_h. apply IHi. apply (xelements_ih _ _ _ _ _ H).
       absurd (List.In (xO i, v) (xelements m (xI j))); auto; apply xelements_oi.
       apply IHi; apply xelements_oo; auto.
       destruct m.
        simpl in H; tauto.
        rewrite find_xfind_h. apply IHi. apply (xelements_oh _ _ _ _ _ H).
       absurd (List.In (xH, v) (xelements m (xI j))); auto; apply xelements_hi.
       absurd (List.In (xH, v) (xelements m (xO j))); auto; apply xelements_ho.
       destruct m.
        simpl in H; tauto.
        destruct o; simpl in H; destruct (in_app_or _ _ _ H).
         absurd (List.In (xH, v) (xelements m1 (xO xH))); auto; apply xelements_ho.
         destruct (in_inv H0).
          congruence.
          absurd (List.In (xH, v) (xelements m2 (xI xH))); auto; apply xelements_hi.
         absurd (List.In (xH, v) (xelements m1 (xO xH))); auto; apply xelements_ho.
         absurd (List.In (xH, v) (xelements m2 (xI xH))); auto; apply xelements_hi.
    Qed.

  Theorem elements_complete:
    forall (m: t A) (i: positive) (v: A),
    List.In (i, v) (elements m) -> find i m = Some v.
  Proof.
    intros m i v H.
    unfold elements in H.
    rewrite find_xfind_h.
    exact (xelements_complete i xH m v H).
  Qed.

  Lemma cardinal_1 :
   forall (m: t A), cardinal m = length (elements m).
  Proof.
   unfold elements.
   intros m; set (p:=1); clearbody p; revert m p.
   induction m; simpl; auto; intros.
   rewrite (IHm1 (append p 2)), (IHm2 (append p 3)); auto.
   destruct o; rewrite app_length; simpl; omega.
  Qed.

  End CompcertSpec.

  Definition MapsTo (i:positive)(v:A)(m:t A) := find i m = Some v.

  Definition In (i:positive)(m:t A) := exists e:A, MapsTo i e m.

  Definition Empty m := forall (a : positive)(e:A) , ~ MapsTo a e m.

  Definition eq_key (p p':positive*A) := E.eq (fst p) (fst p').

  Definition eq_key_elt (p p':positive*A) :=
    E.eq (fst p) (fst p') /\ (snd p) = (snd p').

  Definition lt_key (p p':positive*A) :=
    @ME.ltk positive (@SOT_as_OT _ _ positive_l2r_OrderedType) _ p p'.

  Lemma mem_find :
    forall m x, mem x m = match find x m with None => false | _ => true end.
  Proof.
  induction m; destruct x; simpl; auto.
  Qed.

  Lemma Empty_alt : forall m, Empty m <-> forall a, find a m = None.
  Proof.
  unfold Empty, MapsTo.
  intuition.
  generalize (H a).
  destruct (find a m); intuition.
  elim (H0 a0); auto.
  rewrite H in H0; discriminate.
  Qed.

  Lemma Empty_Node : forall l o r, Empty (Node l o r) <-> o=None /\ Empty l /\ Empty r.
  Proof.
  intros l o r.
  split.
  rewrite Empty_alt.
  split.
  destruct o; auto.
  generalize (H 1); simpl; auto.
  split; rewrite Empty_alt; intros.
  generalize (H (xO a)); auto.
  generalize (H (xI a)); auto.
  intros (H,(H0,H1)).
  subst.
  rewrite Empty_alt; intros.
  destruct a; auto.
  simpl; generalize H1; rewrite Empty_alt; auto.
  simpl; generalize H0; rewrite Empty_alt; auto.
  Qed.

  Section FMapSpec.

  Lemma mem_1 : forall m x, In x m -> mem x m = true.
  Proof.
  unfold In, MapsTo; intros m x; rewrite mem_find.
  destruct 1 as (e0,H0); rewrite H0; auto.
  Qed.

  Lemma mem_2 : forall m x, mem x m = true -> In x m.
  Proof.
  unfold In, MapsTo; intros m x; rewrite mem_find.
  destruct (find x m).
  exists a; auto.
  intros; discriminate.
  Qed.

  Variable  m m' m'' : t A.
  Variable x y z : key.
  Variable e e' : A.

  Lemma MapsTo_1 : E.eq x y -> MapsTo x e m -> MapsTo y e m.
  Proof. intros; rewrite <- H; auto. Qed.

  Lemma find_1 : MapsTo x e m -> find x m = Some e.
  Proof. unfold MapsTo; auto. Qed.

  Lemma find_2 : find x m = Some e -> MapsTo x e m.
  Proof. red; auto. Qed.

  Lemma empty_1 : Empty empty.
  Proof.
  rewrite Empty_alt; apply gempty.
  Qed.

  Lemma is_empty_1 : Empty m -> is_empty m = true.
  Proof.
  induction m; simpl; auto.
  rewrite Empty_Node.
  intros (H,(H0,H1)).
  subst; simpl.
  rewrite IHt0_1; simpl; auto.
  Qed.

  Lemma is_empty_2 : is_empty m = true -> Empty m.
  Proof.
  induction m; simpl; auto.
  rewrite Empty_alt.
  intros _; exact gempty.
  rewrite Empty_Node.
  destruct o.
  intros; discriminate.
  intro H; destruct (andb_prop _ _ H); intuition.
  Qed.

  Lemma add_1 : E.eq x y -> MapsTo y e (add x e m).
  Proof.
  unfold MapsTo.
  intro H; rewrite H; clear H.
  apply gss.
  Qed.

  Lemma add_2 : ~ E.eq x y -> MapsTo y e m -> MapsTo y e (add x e' m).
  Proof.
  unfold MapsTo.
  intros; rewrite gso; auto.
  Qed.

  Lemma add_3 : ~ E.eq x y -> MapsTo y e (add x e' m) -> MapsTo y e m.
  Proof.
  unfold MapsTo.
  intro H; rewrite gso; auto.
  Qed.

  Lemma insert_1 : forall d f, E.eq x y -> MapsTo y e m ->
    MapsTo y (f e) (insert x d f m).
  Proof.
    unfold MapsTo; intros d f H; rewrite H; clear H; apply gis.
  Qed.

  Lemma insert_2 : forall d f, E.eq x y -> ~ In y m ->
    MapsTo y d (insert x d f m).
  Proof.
    unfold MapsTo.
    intros d f H abs; rewrite H, gin; auto.
    case_eq (find y m); auto; intros; contradiction abs; exists a; auto.
  Qed.

  Lemma insert_3 : forall d f, ~ E.eq x y -> MapsTo y e m ->
    MapsTo y e (insert x d f m).
  Proof.
    unfold MapsTo.
    intros; rewrite gio; auto.
  Qed.

  Lemma insert_4 : forall d f, ~ E.eq x y -> MapsTo y e (insert x d f m) ->
    MapsTo y e m.
  Proof.
    unfold MapsTo.
    intros d f H; rewrite gio; auto.
  Qed.

  Lemma adjust_1 : forall f, E.eq x y -> MapsTo y e m ->
    MapsTo y (f e) (adjust x f m).
  Proof.
    unfold MapsTo; intros f H; rewrite H; clear H; apply gas.
  Qed.

  Lemma adjust_2 : forall f, ~ E.eq x y -> MapsTo y e m ->
    MapsTo y e (adjust x f m).
  Proof.
    unfold MapsTo.
    intros; rewrite gao; auto.
  Qed.

  Lemma adjust_3 : forall f, ~ E.eq x y -> MapsTo y e (adjust x f m) ->
    MapsTo y e m.
  Proof.
    unfold MapsTo.
    intros f H; rewrite gao; auto.
  Qed.

  Lemma remove_1 : E.eq x y -> ~ In y (remove x m).
  Proof.
  intros; intro.
  generalize (mem_1 H0).
  rewrite mem_find.
  rewrite H.
  rewrite grs.
  intros; discriminate.
  Qed.

  Lemma remove_2 : ~ E.eq x y -> MapsTo y e m -> MapsTo y e (remove x m).
  Proof.
  unfold MapsTo.
  intro H; rewrite gro; auto.
  Qed.

  Lemma remove_3 : MapsTo y e (remove x m) -> MapsTo y e m.
  Proof.
  unfold MapsTo.
  destruct (eq_dec x y).
  rewrite H in *.
  rewrite grs; intros; discriminate.
  rewrite gro; auto.
  Qed.

  Lemma elements_1 :
     MapsTo x e m -> InA eq_key_elt (x,e) (elements m).
  Proof.
  unfold MapsTo.
  rewrite InA_alt.
  intro H.
  exists (x,e).
  split.
  red; simpl; unfold E.eq; auto.
  apply elements_correct; auto.
  Qed.

  Lemma elements_2 :
     InA eq_key_elt (x,e) (elements m) -> MapsTo x e m.
  Proof.
  unfold MapsTo.
  rewrite InA_alt.
  intros ((e0,a),(H,H0)).
  red in H; simpl in H; destruct H; compute in H; subst.
  apply elements_complete; auto.
  Qed.

  Notation bits_lt := Plt_l2r.
  Notation bits_lt_trans := Plt_l2r_trans.
  Lemma xelements_bits_lt_1 : forall p p0 q m v,
     List.In (p0,v) (xelements m (append p (xO q))) -> bits_lt p0 p.
  Proof.
  intros.
  generalize (xelements_complete _ _ _ _ H); clear H; intros.
  revert p0 q m v H.
  induction p; destruct p0; simpl; intros; eauto; try discriminate.
  Qed.

  Lemma xelements_bits_lt_2 : forall p p0 q m v,
     List.In (p0,v) (xelements m (append p (xI q))) -> bits_lt p p0.
  Proof.
  intros.
  generalize (xelements_complete _ _ _ _ H); clear H; intros.
  revert p0 q m v H.
  induction p; destruct p0; simpl; intros; eauto; try discriminate.
  Qed.

  Lemma xelements_sort : forall p, sort lt_key (xelements m p).
  Proof.
  induction m.
  simpl; auto.
  destruct o; simpl; intros.
  (* Some *)
  apply (SortA_app (eqA:=eq_key_elt)); auto.
  apply KeyOrderedType.eqke_Equiv.
  constructor; repeat intro; unfold lt_key, ME.ltk in *; try solve [order].
  apply In_InfA; intros.
  destruct y0.
  red; red; simpl.
  eapply xelements_bits_lt_2; eauto.
  intros x0 y0.
  do 2 rewrite InA_alt.
  intros (y1,(Hy1,H)) (y2,(Hy2,H0)).
  destruct y1; destruct x0; compute in Hy1; destruct Hy1; subst.
  destruct y2; destruct y0; compute in Hy2; destruct Hy2; subst.
  red; red; simpl.
  destruct H0.
  injection H0; clear H0; intros _ H0; subst.
  eapply xelements_bits_lt_1; eauto.
  apply bits_lt_trans with p.
  eapply xelements_bits_lt_1; eauto.
  eapply xelements_bits_lt_2; eauto.
  (* None *)
  apply (SortA_app (eqA:=eq_key_elt)); auto.
  apply KeyOrderedType.eqke_Equiv.
  intros x0 y0.
  do 2 rewrite InA_alt.
  intros (y1,(Hy1,H)) (y2,(Hy2,H0)).
  destruct y1; destruct x0; compute in Hy1; destruct Hy1; subst.
  destruct y2; destruct y0; compute in Hy2; destruct Hy2; subst.
  red; red; simpl.
  apply bits_lt_trans with p.
  eapply xelements_bits_lt_1; eauto.
  eapply xelements_bits_lt_2; eauto.
  Qed.

  Lemma elements_3 : sort lt_key (elements m).
  Proof.
  unfold elements.
  apply xelements_sort; auto.
  Qed.

  Lemma elements_3w : NoDupA eq_key (elements m).
  Proof.
    apply ME.Sort_NoDupA; apply elements_3; auto.
  Qed.

  End FMapSpec.

  (** [map] and [mapi] *)

  Variable B : Type.

  Section Mapi.

    Variable f : positive -> A -> B.

    Fixpoint xmapi (m : t A) (i : positive) {struct m} : t B :=
       match m with
        | Leaf => @Leaf B
        | Node l o r => Node (xmapi l (append i (xO xH)))
                             (option_map (f i) o)
                             (xmapi r (append i (xI xH)))
       end.

    Definition mapi m := xmapi m xH.

  End Mapi.

  Definition map (f : A -> B) m := mapi (fun _ => f) m.

  End A.

  Lemma xgmapi:
      forall (A B: Type) (f: positive -> A -> B) (i j : positive) (m: t A),
      find i (xmapi f m j) = option_map (f (append j i)) (find i m).
  Proof.
  induction i; intros; destruct m; simpl; auto.
  rewrite (append_assoc_1 j i); apply IHi.
  rewrite (append_assoc_0 j i); apply IHi.
  rewrite (append_neutral_r j); auto.
  Qed.

  Theorem gmapi:
    forall (A B: Type) (f: positive -> A -> B) (i: positive) (m: t A),
    find i (mapi f m) = option_map (f i) (find i m).
  Proof.
  intros.
  unfold mapi.
  replace (f i) with (f (append xH i)).
  apply xgmapi.
  rewrite append_neutral_l; auto.
  Qed.

  Lemma mapi_1 :
    forall (elt elt':Type)(m: t elt)(x:key)(e:elt)(f:key->elt->elt'),
    MapsTo x e m ->
    exists y, E.eq y x /\ MapsTo x (f y e) (mapi f m).
  Proof.
  intros.
  exists x.
  split; [red; auto|].
  apply find_2.
  generalize (find_1 H); clear H; intros.
  rewrite gmapi.
  rewrite H.
  simpl; auto.
  Qed.

  Lemma mapi_2 :
    forall (elt elt':Type)(m: t elt)(x:key)(f:key->elt->elt'),
    In x (mapi f m) -> In x m.
  Proof.
  intros.
  apply mem_2.
  rewrite mem_find.
  destruct H as (v,H).
  generalize (find_1 H); clear H; intros.
  rewrite gmapi in H.
  destruct (find x m); auto.
  simpl in *; discriminate.
  Qed.

  Lemma map_1 : forall (elt elt':Type)(m: t elt)(x:key)(e:elt)(f:elt->elt'),
    MapsTo x e m -> MapsTo x (f e) (map f m).
  Proof.
  intros; unfold map.
  destruct (mapi_1 (fun _ => f) H); intuition.
  Qed.

  Lemma map_2 : forall (elt elt':Type)(m: t elt)(x:key)(f:elt->elt'),
    In x (map f m) -> In x m.
  Proof.
  intros; unfold map in *; eapply mapi_2; eauto.
  Qed.

  Section map2.
  Variable A B C : Type.
  Variable f : option A -> option B -> option C.

  Implicit Arguments Leaf [A].

  Fixpoint xmap2_l (m : t A) {struct m} : t C :=
      match m with
      | Leaf => Leaf
      | Node l o r => Node (xmap2_l l) (f o None) (xmap2_l r)
      end.

  Lemma xgmap2_l : forall (i : positive) (m : t A),
          f None None = None -> find i (xmap2_l m) = f (find i m) None.
    Proof.
      induction i; intros; destruct m; simpl; auto.
    Qed.

  Fixpoint xmap2_r (m : t B) {struct m} : t C :=
      match m with
      | Leaf => Leaf
      | Node l o r => Node (xmap2_r l) (f None o) (xmap2_r r)
      end.

  Lemma xgmap2_r : forall (i : positive) (m : t B),
          f None None = None -> find i (xmap2_r m) = f None (find i m).
    Proof.
      induction i; intros; destruct m; simpl; auto.
    Qed.

  Fixpoint _map2 (m1 : t A)(m2 : t B) {struct m1} : t C :=
    match m1 with
    | Leaf => xmap2_r m2
    | Node l1 o1 r1 =>
        match m2 with
        | Leaf => xmap2_l m1
        | Node l2 o2 r2 => Node (_map2 l1 l2) (f o1 o2) (_map2 r1 r2)
        end
    end.

    Lemma gmap2: forall (i: positive)(m1:t A)(m2: t B),
      f None None = None ->
      find i (_map2 m1 m2) = f (find i m1) (find i m2).
    Proof.
      induction i; intros; destruct m1; destruct m2; simpl; auto;
      try apply xgmap2_r; try apply xgmap2_l; auto.
    Qed.

  End map2.

  Definition map2 (elt elt' elt'':Type)(f:option elt->option elt'->option elt'') :=
   _map2 (fun o1 o2 => match o1,o2 with None,None => None | _, _ => f o1 o2 end).

  Lemma map2_1 : forall (elt elt' elt'':Type)(m: t elt)(m': t elt')
    (x:key)(f:option elt->option elt'->option elt''),
    In x m \/ In x m' ->
    find x (map2 f m m') = f (find x m) (find x m').
  Proof.
  intros.
  unfold map2.
  rewrite gmap2; auto.
  generalize (@mem_1 _ m x) (@mem_1 _ m' x).
  do 2 rewrite mem_find.
  destruct (find x m); simpl; auto.
  destruct (find x m'); simpl; auto.
  intros.
  destruct H; intuition; try discriminate.
  Qed.

  Lemma  map2_2 : forall (elt elt' elt'':Type)(m: t elt)(m': t elt')
    (x:key)(f:option elt->option elt'->option elt''),
    In x (map2 f m m') -> In x m \/ In x m'.
  Proof.
  intros.
  generalize (mem_1 H); clear H; intros.
  rewrite mem_find in H.
  unfold map2 in H.
  rewrite gmap2 in H; auto.
  generalize (@mem_2 _ m x) (@mem_2 _ m' x).
  do 2 rewrite mem_find.
  destruct (find x m); simpl in *; auto.
  destruct (find x m'); simpl in *; auto.
  Qed.


  Section Fold.

    Variables A B : Type.
    Variable f : positive -> A -> B -> B.

    Fixpoint xfoldi (m : t A) (v : B) (i : positive) :=
      match m with
        | Leaf => v
        | Node l (Some x) r =>
          xfoldi r (f i x (xfoldi l v (append i 2))) (append i 3)
        | Node l None r =>
          xfoldi r (xfoldi l v (append i 2)) (append i 3)
      end.

    Lemma xfoldi_1 :
      forall m v i,
      xfoldi m v i = fold_left (fun a p => f (fst p) (snd p) a) (xelements m i) v.
    Proof.
      set (F := fun a p => f (fst p) (snd p) a).
      induction m; intros; simpl; auto.
      destruct o.
      rewrite fold_left_app; simpl.
      rewrite <- IHm1.
      rewrite <- IHm2.
      unfold F; simpl; reflexivity.
      rewrite fold_left_app; simpl.
      rewrite <- IHm1.
      rewrite <- IHm2.
      reflexivity.
    Qed.

    Definition fold m i := xfoldi m i 1.

  End Fold.

  Lemma fold_1 :
    forall (A:Type)(m:t A)(B:Type)(i : B) (f : key -> A -> B -> B),
    fold f m i = fold_left (fun a p => f (fst p) (snd p) a) (elements m) i.
  Proof.
    intros; unfold fold, elements.
    rewrite xfoldi_1; reflexivity.
  Qed.

  Fixpoint equal (A:Type)(cmp : A -> A -> bool)(m1 m2 : t A) {struct m1} : bool :=
    match m1, m2 with
      | Leaf, _ => is_empty m2
      | _, Leaf => is_empty m1
      | Node l1 o1 r1, Node l2 o2 r2 =>
           (match o1, o2 with
             | None, None => true
             | Some v1, Some v2 => cmp v1 v2
             | _, _ => false
            end)
           && equal cmp l1 l2 && equal cmp r1 r2
     end.

  Definition Equal (A:Type)(m m':t A) :=
    forall y, find y m = find y m'.
  Definition Equiv (A:Type)(eq_elt:A->A->Prop) m m' :=
    (forall k, In k m <-> In k m') /\
    (forall k e e', MapsTo k e m -> MapsTo k e' m' -> eq_elt e e').
  Definition Equivb (A:Type)(cmp: A->A->bool) := Equiv (Cmp cmp).

  Lemma equal_1 : forall (A:Type)(m m':t A)(cmp:A->A->bool),
    Equivb cmp m m' -> equal cmp m m' = true.
  Proof.
  induction m.
  (* m = Leaf *)
  destruct 1.
  simpl.
  apply is_empty_1.
  red; red; intros.
  assert (In a (Leaf A)).
  rewrite H.
  exists e; auto.
  destruct H2; red in H2.
  destruct a; simpl in *; discriminate.
  (* m = Node *)
  destruct m'.
  (* m' = Leaf *)
  destruct 1.
  simpl.
  destruct o.
  assert (In xH (Leaf A)).
  rewrite <- H.
  exists a; red; auto.
  destruct H1; red in H1; simpl in H1; discriminate.
  apply andb_true_intro; split; apply is_empty_1; red; red; intros.
  assert (In (xO a) (Leaf A)).
  rewrite <- H.
  exists e; auto.
  destruct H2; red in H2; simpl in H2; discriminate.
  assert (In (xI a) (Leaf A)).
  rewrite <- H.
  exists e; auto.
  destruct H2; red in H2; simpl in H2; discriminate.
  (* m' = Node *)
  destruct 1.
  assert (Equivb cmp m1 m'1).
    split.
    intros k; generalize (H (xO k)); unfold In, MapsTo; simpl; auto.
    intros k e e'; generalize (H0 (xO k) e e'); unfold In, MapsTo; simpl; auto.
  assert (Equivb cmp m2 m'2).
    split.
    intros k; generalize (H (xI k)); unfold In, MapsTo; simpl; auto.
    intros k e e'; generalize (H0 (xI k) e e'); unfold In, MapsTo; simpl; auto.
  simpl.
  destruct o; destruct o0; simpl.
  repeat (apply andb_true_intro; split); auto.
  apply (H0 xH); red; auto.
  generalize (H xH); unfold In, MapsTo; simpl; intuition.
  destruct H4; try discriminate; eauto.
  generalize (H xH); unfold In, MapsTo; simpl; intuition.
  destruct H5; try discriminate; eauto.
  apply andb_true_intro; split; auto.
  Qed.

  Lemma equal_2 : forall (A:Type)(m m':t A)(cmp:A->A->bool),
    equal cmp m m' = true -> Equivb cmp m m'.
  Proof.
  induction m.
  (* m = Leaf *)
  simpl.
  split; intros.
  split.
  destruct 1; red in H0; destruct k; discriminate.
  destruct 1; elim (is_empty_2 H H0).
  red in H0; destruct k; discriminate.
  (* m = Node *)
  destruct m'.
  (* m' = Leaf *)
  simpl.
  destruct o; intros; try discriminate.
  destruct (andb_prop _ _ H); clear H.
  split; intros.
  split; unfold In, MapsTo; destruct 1.
  destruct k; simpl in *; try discriminate.
  destruct (is_empty_2 H1 (find_2 _ _ H)).
  destruct (is_empty_2 H0 (find_2 _ _ H)).
  destruct k; simpl in *; discriminate.
  unfold In, MapsTo; destruct k; simpl in *; discriminate.
  (* m' = Node *)
  destruct o; destruct o0; simpl; intros; try discriminate.
  destruct (andb_prop _ _ H); clear H.
  destruct (andb_prop _ _ H0); clear H0.
  destruct (IHm1 _ _ H2); clear H2 IHm1.
  destruct (IHm2 _ _ H1); clear H1 IHm2.
  split; intros.
  destruct k; unfold In, MapsTo in *; simpl; auto.
  split; eauto.
  destruct k; unfold In, MapsTo in *; simpl in *.
  eapply H4; eauto.
  eapply H3; eauto.
  congruence.
  destruct (andb_prop _ _ H); clear H.
  destruct (IHm1 _ _ H0); clear H0 IHm1.
  destruct (IHm2 _ _ H1); clear H1 IHm2.
  split; intros.
  destruct k; unfold In, MapsTo in *; simpl; auto.
  split; eauto.
  destruct k; unfold In, MapsTo in *; simpl in *.
  eapply H3; eauto.
  eapply H2; eauto.
  try discriminate.
  Qed.

  Section MapAsOT.
    Context `{Helt : OrderedType elt}.

    Inductive t_eq : t elt -> t elt -> Prop :=
    | t_eq_Leaf : t_eq (Leaf _) (Leaf _)
    | t_eq_Node :
      forall l l' o o' r r', t_eq l l' -> o === o' -> t_eq r r' ->
        t_eq (Node l o r) (Node l' o' r').
    Property t_eq_refl : forall x, t_eq x x.
    Proof. Tactics.minductive_refl. Qed.
    Property t_eq_sym : forall x y, t_eq x y -> t_eq y x.
    Proof. Tactics.minductive_sym. Qed.
    Property t_eq_trans : forall x y z, t_eq x y -> t_eq y z -> t_eq x z.
    Proof. Tactics.minductive_trans. Qed.

    Inductive t_lt : t elt -> t elt -> Prop :=
    | t_lt_Leaf_Node : forall l o r, t_lt (Leaf _) (Node l o r)
    | t_lt_Node_Node_1 :
      forall l l' o o' r r', o <<< o' -> t_lt (Node l o r) (Node l' o' r')
    | t_lt_Node_Node_2 :
      forall l l' o o' r r', t_lt l l' -> o === o' ->
        t_lt (Node l o r) (Node l' o' r')
    | t_lt_Node_Node_3 :
      forall l l' o o' r r', t_eq l l' -> o === o' -> t_lt r r' ->
        t_lt (Node l o r) (Node l' o' r').
    Property t_lt_irrefl : forall x y, t_lt x y -> ~t_eq x y.
    Proof. Tactics.minductive_irrefl. Qed.
    Property t_eq_lt : forall x x' y, t_eq x x' -> t_lt x y -> t_lt x' y.
    Proof. Tactics.rinductive_eq_lt t_eq_sym t_eq_trans. Qed.
    Property t_eq_gt : forall x x' y, t_eq x x' -> t_lt y x -> t_lt y x'.
    Proof. Tactics.rinductive_eq_gt t_eq_trans. Qed.
    Property t_lt_trans : forall x y z, t_lt x y -> t_lt y z -> t_lt x z.
    Proof.
      Tactics.rinductive_lexico_trans t_eq_sym t_eq_trans t_eq_gt t_eq_lt.
    Qed.

    Fixpoint t_cmp (m m' : t elt) : comparison :=
      match m, m' with
        | Leaf, Leaf => Eq
        | Leaf, Node _ _ _ => Lt
        | Node _ _ _, Leaf => Gt
        | Node l o r, Node l' o' r' =>
          match o =?= o' with
            | Eq =>
              match t_cmp l l' with
                | Eq => t_cmp r r'
                | Lt => Lt
                | Gt => Gt
              end
            | Lt => Lt
            | Gt => Gt
          end
      end.
    Property t_cmp_spec : forall x y, compare_spec t_eq t_lt x y (t_cmp x y).
    Proof.
      induction x; destruct y; try (tconstructor (constructor)).
      simpl; destruct (compare_dec o o0); try (constructor; tconstructor (auto)).
      destruct (IHx1 y1); try constructor.
      tconstructor (assumption).
      destruct (IHx2 y2); try constructor;
        tconstructor (solve [auto using t_eq_sym]).
      tconstructor (solve [auto using t_eq_sym]).
    Qed.

    Program Instance Map_OrderedType : OrderedType (t elt) := {
      _eq := t_eq;
      OT_Equivalence := @Build_Equivalence _ _ t_eq_refl t_eq_sym t_eq_trans;
      _lt := t_lt;
      OT_StrictOrder := @Build_StrictOrder _ _ _ _ t_lt_trans t_lt_irrefl;
      _cmp := t_cmp;
      _compare_spec := t_cmp_spec
    }.
  End MapAsOT.

End PositiveMap.

(** Here come some additionnal facts about this implementation.
  Most are facts that cannot be derivable from the general interface. *)


Module PositiveMapAdditionalFacts.
  Import PositiveMap.

  (* Derivable from the Map interface *)
  Theorem gsspec:
    forall (A:Type)(i j: positive) (x: A) (m: t A),
    find i (add j x m) = if i == j then Some x else find i m.
  Proof.
    intros.
    destruct (eq_dec i j); [ rewrite H; apply gss | apply gso; auto ].
  Qed.

   (* Not derivable from the Map interface *)
  Theorem gsident:
    forall (A:Type)(i: positive) (m: t A) (v: A),
    find i m = Some v -> add i v m = m.
  Proof.
    induction i; intros; destruct m; simpl; simpl in H; try congruence.
     rewrite (IHi m2 v H); congruence.
     rewrite (IHi m1 v H); congruence.
  Qed.

  Lemma xmap2_lr :
      forall (A B : Type)(f g: option A -> option A -> option B)(m : t A),
      (forall (i j : option A), f i j = g j i) ->
      xmap2_l f m = xmap2_r g m.
    Proof.
      induction m; intros; simpl; auto.
      rewrite IHm1; auto.
      rewrite IHm2; auto.
      rewrite H; auto.
    Qed.

  Theorem map2_commut:
    forall (A B: Type) (f g: option A -> option A -> option B),
    (forall (i j: option A), f i j = g j i) ->
    forall (m1 m2: t A),
    _map2 f m1 m2 = _map2 g m2 m1.
  Proof.
    intros A B f g Eq1.
    assert (Eq2: forall (i j: option A), g i j = f j i).
      intros; auto.
    induction m1; intros; destruct m2; simpl;
      try rewrite Eq1;
      repeat rewrite (xmap2_lr f g);
      repeat rewrite (xmap2_lr g f);
      auto.
     rewrite IHm1_1.
     rewrite IHm1_2.
     auto.
  Qed.

End PositiveMapAdditionalFacts.
