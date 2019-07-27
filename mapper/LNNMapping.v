Require Import Compose.
Require Import Equivalences.
Require Import List.
Require Import Top.Tactics.
Open Scope ucom.

Local Close Scope C_scope.
Local Close Scope R_scope.

(*************************)
(** LNN Mapping Example **)
(*************************)

(* Naive mapping algorithm. *)
Fixpoint move_target_left {dim} (base dist : nat) : ucom dim :=
  match dist with 
  | O => CNOT base (base + 1)
  | S n' => SWAP (base + dist) (base + dist + 1); 
           move_target_left base n'; 
           SWAP (base + dist) (base + dist + 1)
  end.

Fixpoint move_target_right {dim} (base dist : nat) : ucom dim :=
  match dist with 
  | O => CNOT (base + 1) base
  | S n' => SWAP (base - dist) (base - dist + 1); 
           move_target_right base n'; 
           SWAP (base - dist) (base - dist + 1)
  end.

Fixpoint map_to_lnn {dim} (c : ucom dim) : ucom dim :=
  match c with
  | c1; c2 => map_to_lnn c1; map_to_lnn c2
  | uapp2 U_CNOT n1 n2 =>
      if n1 <? n2
      then move_target_left n1 (n2 - n1 - 1)
      else if n2 <? n1
           then move_target_right (n1 - 1) (n1 - n2 - 1)
           else CNOT n1 n2 (* badly-typed case, n1=n2 *)
  | _ => c
  end.

(* Small test case. *)
Definition q0 : nat := 0.
Definition q1 : nat := 1.
Definition q2 : nat := 2.
Definition q3 : nat := 3.
Definition q4 : nat := 4.
Definition example3 : ucom 5 := CNOT q0 q3; CNOT q4 q1.
Compute (map_to_lnn example3).

(* There are many more interesting & general properties we can prove about SWAP, e.g.

       forall a b, SWAP a b; U b; SWAP a b ≡ U a

   but the properties below are sufficient for this problem.

   For reference, the general definition of the swap matrix for m < n is:

   @pad (1+(n-m-1)+1) m dim 
        ( ∣0⟩⟨0∣ ⊗ I (2^(n-m-1)) ⊗ ∣0⟩⟨0∣ .+
          ∣0⟩⟨1∣ ⊗ I (2^(n-m-1)) ⊗ ∣1⟩⟨0∣ .+
          ∣1⟩⟨0∣ ⊗ I (2^(n-m-1)) ⊗ ∣0⟩⟨1∣ .+
          ∣1⟩⟨1∣ ⊗ I (2^(n-m-1)) ⊗ ∣1⟩⟨1∣ )
*)

(* TODO: clean up denote_swap_adjacent by adding the lemmas below to M_db. *)
Lemma swap_spec_general : forall (A B : Matrix 2 2),
  WF_Matrix A -> WF_Matrix B -> swap × (A ⊗ B) × swap = B ⊗ A.
Proof.
  intros A B WF_A WF_B.
  solve_matrix.
Qed.

Lemma rewrite_ket_prod00 : forall (q1 :  Matrix 2 1) (q2 : Matrix 1 2),
  WF_Matrix q1 -> WF_Matrix q2 -> (q1 × ⟨0∣) × (∣0⟩ × q2) = q1 × q2.
Proof. intros. solve_matrix. Qed.

Lemma rewrite_ket_prod01 : forall (q1 :  Matrix 2 1) (q2 : Matrix 1 2),
  (q1 × ⟨0∣) × (∣1⟩ × q2) = Zero.
Proof. intros. solve_matrix. Qed.

Lemma rewrite_ket_prod10 : forall (q1 :  Matrix 2 1) (q2 : Matrix 1 2),
  (q1 × ⟨1∣) × (∣0⟩ × q2) = Zero.
Proof. intros. solve_matrix. Qed.

Lemma rewrite_ket_prod11 : forall (q1 :  Matrix 2 1) (q2 : Matrix 1 2),
  WF_Matrix q1 -> WF_Matrix q2 -> (q1 × ⟨1∣) × (∣1⟩ × q2) = q1 × q2.
Proof. intros. solve_matrix. Qed.

(* Show that SWAP ≡ swap. *)
Lemma denote_SWAP_adjacent : forall {dim} n,
  @uc_well_typed dim (SWAP n (n + 1)) ->
  @uc_eval dim (SWAP n (n + 1)) = (I (2 ^ n)) ⊗ swap ⊗ (I (2 ^ (dim - 2 - n))).
Proof.
  intros dim n WT.
  assert (n + 1 < dim).
  { inversion WT; inversion H2. assumption. }
  clear WT.
  simpl; unfold ueval_cnot, pad.
  repad.
  replace d with 0 in * by lia.
  subst. clear. simpl. Msimpl. simpl.
  restore_dims_strong.
  repeat rewrite kron_mixed_product. Msimpl.
  restore_dims_fast.
  replace (n + 2 + d0 - 2 - n) with d0 by lia.
  apply f_equal2; trivial.
  apply f_equal2; trivial.
  solve_matrix.
Qed.

Lemma swap_adjacent_WT: forall b dim,
  b + 1 < dim -> @uc_well_typed dim (SWAP b (b + 1)).
Proof.
  intros b dim H.
  repeat apply WT_seq; apply WT_app2; lia.
Qed.

Lemma swap_adjacent_not_WT: forall b dim,
  b + 1 >= dim -> @uc_eval dim (SWAP b (b + 1)) = Zero.
Proof.
  intros b dim H.
  simpl; unfold ueval_cnot, pad.
  bdestruct (b <? b + 1); try lia.
  bdestruct (b + (1 + (b + 1 - b - 1) + 1) <=? dim); try lia.
  remove_zero_gates; trivial.
Qed.

Lemma swap_swap_id_adjacent: forall a dim,
  @uc_well_typed dim (SWAP a (a+1)) ->
  @uc_equiv dim (SWAP a (a+1); SWAP a (a+1)) uskip.
Proof.
  intros a dim WT.
  assert (a + 1 < dim).
  { inversion WT; inversion H2; assumption. }
  unfold uc_equiv.
  remember (SWAP a (a+1)) as s; simpl; subst.
  rewrite denote_SWAP_adjacent; try assumption.
  replace (2 ^ dim) with (2 ^ a * (2 ^ 1 * 2 ^ 1) * 2 ^ (dim - 2 - a)) by unify_pows_two.
  replace (2 ^ 1) with 2 by easy.
  repeat rewrite kron_mixed_product.
  rewrite swap_swap.
  Msimpl.
  reflexivity.
Qed.

Opaque SWAP.
Lemma swap_cnot_adjacent_left : forall {dim} a b,
  a < b ->
  @uc_equiv dim (SWAP b (b+1); CNOT a b; SWAP b (b+1)) (CNOT a (b+1)).
Proof.
  intros dim a b H.
  unfold uc_equiv.
  simpl; unfold ueval_cnot, pad.
  gridify.
  - repeat rewrite plus_assoc.
    rewrite denote_SWAP_adjacent.
    2:{ apply swap_adjacent_WT. lia. }
    repeat rewrite Nat.pow_add_r; repeat rewrite <- id_kron; simpl;
      repeat rewrite Nat.mul_assoc. 
    replace (a + S (x + 1 + 1) + d2 - 2 - (a + 1 + x)) with d2 by lia.
    restore_dims_strong. (* _fast doesn't work? *)
    repeat rewrite <- kron_assoc; restore_dims_fast.
    rewrite (kron_assoc _ σx). remember (σx ⊗ I 2) as Xl. 
    rewrite (kron_assoc _ _ σx). remember (I 2 ⊗ σx) as Xr. 
    rewrite (kron_assoc _ _ (I 2)). rewrite (id_kron 2 2).
    simpl in *.
    restore_dims_fast.
    repeat rewrite kron_mixed_product.  
    Msimpl.
    subst.
    rewrite <- Mmult_assoc.
    rewrite swap_spec_general by (auto with wf_db).
    reflexivity.
  - rewrite swap_adjacent_not_WT by lia.
    remove_zero_gates. rewrite Mplus_0_l.
    reflexivity.
Qed.

Lemma swap_cnot_adjacent_right : forall {dim} a b,
  b + 1 < a ->
  @uc_equiv dim (SWAP b (b+1); CNOT a (b+1); SWAP b (b+1)) (CNOT a b).
Proof.
  intros dim a b H.
  unfold uc_equiv.
  simpl; unfold ueval_cnot, pad.
  gridify.
  - repeat rewrite plus_assoc.
    rewrite denote_SWAP_adjacent.
    2:{ apply swap_adjacent_WT. lia. }
    replace (b + S (S (x + 1)) + d2 - 2 - b) with (x + 1 + d2) by lia.
    repeat rewrite Nat.pow_add_r; repeat rewrite <- id_kron; simpl;
      repeat rewrite Nat.mul_assoc. 
    restore_dims_strong. (* _fast doesn't work? *)
    repeat rewrite <- kron_assoc. 
    clear.
    rewrite (kron_assoc _ _ σx). remember (I 2 ⊗ σx) as Xr. 
    rewrite (kron_assoc _ σx). remember (σx ⊗ I 2) as Xl. 
    rewrite (kron_assoc _ (I 2) (I 2)). rewrite (id_kron 2 2).
    simpl in *. 
    restore_dims_strong.
    repeat rewrite kron_mixed_product.  
    Msimpl.
    subst.
    rewrite <- Mmult_assoc.
    rewrite swap_spec_general by (auto with wf_db).
    reflexivity.
Qed.

Lemma move_target_left_equiv_cnot : forall {dim} base dist,
  @uc_equiv dim (move_target_left base dist) (CNOT base (base + dist + 1)).
Proof.
  intros dim base dist.
  induction dist.
  - replace (base + 0 + 1) with (base + 1) by lia; easy.
  - simpl.
    rewrite IHdist.
    replace (base + S dist) with (base + dist + 1) by lia.
    apply swap_cnot_adjacent_left.
    lia.
Qed. 

Lemma move_target_right_equiv_cnot : forall {dim} base dist,
   base >= dist -> @uc_equiv dim (move_target_right base dist) (CNOT (base + 1) (base - dist)).
Proof.
  intros dim base dist H.
  induction dist.
  - replace (base - 0) with base by lia; easy.
  - simpl.
    rewrite IHdist; try lia.
    replace (base - dist) with (base - S dist + 1) by lia.
    apply swap_cnot_adjacent_right.
    lia.
Qed.

(* map_to_lnn is semantics-preserving *)
Lemma map_to_lnn_sound : forall {dim} (c : ucom dim), c ≡ map_to_lnn c.
Proof.
  induction c; try easy.
  - simpl. rewrite <- IHc1. rewrite <- IHc2. reflexivity.
  - simpl. dependent destruction u.
    bdestruct (n <? n0).
    + rewrite (move_target_left_equiv_cnot n (n0 - n - 1)).
      replace (n + (n0 - n - 1) + 1) with n0 by lia.
      easy.
    + bdestruct (n0 <? n); try easy.
      rewrite (move_target_right_equiv_cnot (n - 1) (n - n0 - 1)) by lia.
      replace (n - 1 - (n - n0 - 1)) with n0 by lia.
      replace (n - 1 + 1) with n by lia.
      easy.
Qed.

(* linear nearest neighbor: 'all CNOTs are on adjacent qubits' *)
Inductive respects_LNN {dim} : ucom dim -> Prop :=
  | LNN_skip : respects_LNN uskip
  | LNN_seq : forall c1 c2, 
      respects_LNN c1 -> respects_LNN c2 -> respects_LNN (c1; c2)
  | LNN_app_u : forall (u : Unitary 1) n, respects_LNN (uapp1 u n)
  | LNN_app_cnot_left : forall n, respects_LNN (CNOT n (n+1))
  | LNN_app_cnot_right : forall n, respects_LNN (CNOT (n+1) n).

Transparent SWAP.
Lemma move_target_left_respects_lnn : forall {dim} base dist,
  @respects_LNN dim (move_target_left base dist).
Proof.
  intros dim base dist.
  induction dist.
  - simpl. apply LNN_app_cnot_left.
  - simpl. 
    repeat apply LNN_seq; 
    try apply LNN_app_cnot_left;
    try apply LNN_app_cnot_right.
    apply IHdist.
Qed. 

Lemma move_target_right_respects_lnn : forall {dim} base dist,
   base >= dist -> 
   @respects_LNN dim (move_target_right base dist).
Proof.
  intros dim base dist H.
  induction dist.
  - simpl. apply LNN_app_cnot_right.
  - simpl.
    repeat apply LNN_seq; 
    try apply LNN_app_cnot_left;
    try apply LNN_app_cnot_right.
    apply IHdist.
    lia.
Qed.

(* map_to_lnn produces programs that satisfy the LNN constraint. 

   The well-typedness constraint is necessary because gates applied
   to the incorrect number of arguments do not satisfy our LNN 
   property. (We can change this if we want). *)
Lemma map_to_lnn_correct : forall {dim} (c : ucom dim), 
  uc_well_typed c -> respects_LNN (map_to_lnn c).
Proof.
  intros dim c WT.
  induction WT.
  - apply LNN_skip.
  - simpl. apply LNN_seq; assumption.
  - dependent destruction u; apply LNN_app_u.
  - dependent destruction u; simpl.
    bdestruct (m <? n).
    apply move_target_left_respects_lnn.
    bdestruct (n <? m); try lia.
    apply move_target_right_respects_lnn; lia.
Qed.

