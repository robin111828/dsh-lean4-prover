import Mathlib

/-!
# 多剂量给药的药物蓄积（固定间隔、固定比例消除、固定剂量）

设每经过一个给药周期，体内药物按固定比例 `q ∈ [0,1)` 留存（消除比例 `1-q`），
每次给药补充固定剂量 `D ≥ 0`。以「给药后瞬间」的峰浓度计：

  c(0) = c0,   c(n+1) = q * c(n) + D

下一周期「给药前」的谷浓度为 t(n) = q * c(n)。
稳态平台（不动点）为 L = D / (1 - q)。

本文件证明：
  1. 递推的闭式解（几何级数）；
  2. 浓度一致有界且收敛到稳态平台，谷浓度收敛到 q*L，全体浓度落在有界稳态带内；
  3. 只要 c0 ≥ 0，所有时刻峰、谷浓度均非负。
-/

open BigOperators

namespace MyApt.PK

/-- 峰浓度序列：第 n 次给药后瞬间的浓度。c(0)=c0，其后每周期先按 q 衰减再补 D。 -/
def pk (q D c0 : ℝ) : ℕ → ℝ
  | 0 => c0
  | n + 1 => q * pk q D c0 n + D

/-- 谷浓度序列：第 n 次给药后、经过一个周期衰减、下次给药前的浓度。 -/
def trough (q D c0 : ℝ) (n : ℕ) : ℝ := q * pk q D c0 n

/-- 1-q > 0。 -/
private lemma one_minus_q_pos (q : ℝ) (hq1 : q < 1) : 0 < 1 - q := by linarith

/-- 稳态平台 L = D/(1-q) 是递推的不动点：q*L + D = L。 -/
private lemma steady_fixed (q D : ℝ) (hq1 : q < 1) :
    q * (D / (1 - q)) + D = D / (1 - q) := by
  have hp : 1 - q ≠ 0 := (one_minus_q_pos q hq1).ne'
  field_simp [hp] <;> ring

/-- q 的任意自然数次幂非负。 -/
private lemma pow_q_nonneg (q : ℝ) (hq : 0 ≤ q) (n : ℕ) : 0 ≤ q ^ n :=
  pow_nonneg hq n

/-- q^n ≤ 1（因 0 ≤ q ≤ 1）。 -/
private lemma pow_q_le_one (q : ℝ) (hq : 0 ≤ q) (hq1 : q < 1) (n : ℕ) : q ^ n ≤ 1 := by
  have hqle : q ≤ 1 := by linarith
  induction n with
  | zero => norm_num
  | succ n ih =>
    calc
      q ^ (n + 1) = q * q ^ n := by ring
      _ ≤ q * 1 := by gcongr
      _ ≤ 1 := by linarith

/-- 几何级数望远镜恒等式：(1-q) * ∑_{k<n} q^k = 1 - q^n。 -/
private lemma geom_sum (q : ℝ) (n : ℕ) :
    (1 - q) * ∑ k ∈ Finset.range n, q ^ k = 1 - q ^ n := by
  induction n with
  | zero => norm_num
  | succ n ih =>
    rw [Finset.sum_range_succ, mul_add, ih] <;> ring

/-- q^n → 0（|q| < 1）。 -/
private lemma tendsto_qpow (q : ℝ) (hq : 0 ≤ q) (hq1 : q < 1) :
    Filter.Tendsto (fun n : ℕ => q ^ n) Filter.atTop (nhds 0) := by
  exact tendsto_pow_atTop_nhds_zero_of_lt_one hq hq1

/-! ## 命题 1：递推的闭式解 -/

/-- 峰浓度闭式解：c(n) = q^n*c0 + D * ∑_{k<n} q^k。 -/
theorem pk_closed_form_sum (q D c0 : ℝ) (n : ℕ) :
    pk q D c0 n = q ^ n * c0 + D * ∑ k ∈ Finset.range n, q ^ k := by
  induction n with
  | zero => simp [pk]
  | succ n ih =>
    set S := ∑ k ∈ Finset.range n, q ^ k with hS
    have hg : q * S + 1 = S + q ^ n := by linarith [geom_sum q n]
    calc
      pk q D c0 (n + 1)
        = q * (q ^ n * c0 + D * S) + D := by rw [pk, ih]
      _ = q ^ (n + 1) * c0 + D * (S + q ^ n) := by
          rw [pow_succ]
          have hD : D * (q * S + 1) = D * (S + q ^ n) := by rw [hg]
          linarith
      _ = q ^ (n + 1) * c0 + D * ∑ k ∈ Finset.range (n + 1), q ^ k := by
          rw [Finset.sum_range_succ] <;> ring

/-- 峰浓度闭式解（比率形式）：c(n) = q^n*c0 + D*(1-q^n)/(1-q)。 -/
theorem pk_closed_form (q D c0 : ℝ) (hq1 : q < 1) (n : ℕ) :
    pk q D c0 n = q ^ n * c0 + D * (1 - q ^ n) / (1 - q) := by
  rw [pk_closed_form_sum q D c0 n]
  have hp : 1 - q ≠ 0 := (one_minus_q_pos q hq1).ne'
  have hs := geom_sum q n
  have h : D * ∑ k ∈ Finset.range n, q ^ k = D * (1 - q ^ n) / (1 - q) := by
    have h9 : (1 - q) * (D * ∑ k ∈ Finset.range n, q ^ k) = D * (1 - q ^ n) := by
      calc
        (1 - q) * (D * ∑ k ∈ Finset.range n, q ^ k)
          = D * ((1 - q) * ∑ k ∈ Finset.range n, q ^ k) := by ring
        _ = D * (1 - q ^ n) := by rw [hs] <;> ring
    field_simp [hp] at h9 ⊢ <;> linarith
  rw [h]

/-- 围绕稳态平台的仿射形式：c(n) = L + q^n*(c0 - L)。 -/
private theorem pk_affine (q D c0 : ℝ) (hq1 : q < 1) (n : ℕ) :
    pk q D c0 n = (D / (1 - q)) + q ^ n * (c0 - D / (1 - q)) := by
  induction n with
  | zero => simp [pk] <;> ring
  | succ n ih =>
    rw [pk, ih]
    calc
      q * ((D / (1 - q)) + q ^ n * (c0 - D / (1 - q))) + D
        = (q * (D / (1 - q)) + D) + q * (q ^ n * (c0 - D / (1 - q))) := by ring
      _ = (D / (1 - q)) + q ^ (n + 1) * (c0 - D / (1 - q)) := by
          rw [steady_fixed q D hq1] <;> ring

/-! ## 命题 3：非负性 -/

/-- 所有时刻峰浓度非负：c0 ≥ 0 ⇒ ∀ n, c(n) ≥ 0。 -/
theorem pk_nonneg (q D c0 : ℝ) (hq : 0 ≤ q) (hD : 0 ≤ D) (hc0 : 0 ≤ c0) (n : ℕ) :
    0 ≤ pk q D c0 n := by
  induction n with
  | zero => exact hc0
  | succ n ih =>
    rw [pk]
    exact add_nonneg (mul_nonneg hq ih) hD

/-- 所有时刻谷浓度非负。 -/
theorem trough_nonneg (q D c0 : ℝ) (hq : 0 ≤ q) (hD : 0 ≤ D) (hc0 : 0 ≤ c0) (n : ℕ) :
    0 ≤ trough q D c0 n :=
  mul_nonneg hq (pk_nonneg q D c0 hq hD hc0 n)

/-! ## 命题 2：一致有界与收敛到稳态 -/

/-- 峰浓度的通用上下界：min(c0,L) ≤ c(n) ≤ max(c0,L)，故全体浓度有界。 -/
theorem pk_bounded (q D c0 : ℝ) (hq : 0 ≤ q) (hq1 : q < 1) (n : ℕ) :
    min c0 (D / (1 - q)) ≤ pk q D c0 n ∧
    pk q D c0 n ≤ max c0 (D / (1 - q)) := by
  set L := D / (1 - q) with hL
  set x := L + q ^ n * (c0 - L) with hx
  have h_eq : pk q D c0 n = x := pk_affine q D c0 hq1 n
  have h0 : 0 ≤ q ^ n := pow_q_nonneg q hq n
  have h1q : 0 ≤ 1 - q ^ n := by linarith [pow_q_le_one q hq hq1 n]
  rw [h_eq]
  by_cases h : c0 ≤ L
  · -- c0 ≤ L：min = c0，max = L；c0 ≤ x ≤ L
    have hmn : min c0 L = c0 := min_eq_left h
    have hmx : max c0 L = L := max_eq_right h
    rw [hmn, hmx]
    have hLC : 0 ≤ L - c0 := by linarith
    constructor
    · have hd : x - c0 = (L - c0) * (1 - q ^ n) := by simp only [hx]; ring
      have : 0 ≤ (L - c0) * (1 - q ^ n) := mul_nonneg hLC h1q
      linarith
    · have hd : L - x = q ^ n * (L - c0) := by simp only [hx]; ring
      have : 0 ≤ q ^ n * (L - c0) := mul_nonneg h0 hLC
      linarith
  · -- L < c0：min = L，max = c0；L ≤ x ≤ c0
    have h' : L ≤ c0 := by linarith
    have hmn : min c0 L = L := min_eq_right h'
    have hmx : max c0 L = c0 := max_eq_left h'
    rw [hmn, hmx]
    have hCL : 0 ≤ c0 - L := by linarith
    constructor
    · have hd : x - L = q ^ n * (c0 - L) := by simp only [hx]; ring
      have : 0 ≤ q ^ n * (c0 - L) := mul_nonneg h0 hCL
      linarith
    · have hd : c0 - x = (c0 - L) * (1 - q ^ n) := by simp only [hx]; ring
      have : 0 ≤ (c0 - L) * (1 - q ^ n) := mul_nonneg hCL h1q
      linarith

/-- 峰浓度有有限上界（稳态区间上界）。 -/
theorem pk_le_max (q D c0 : ℝ) (hq : 0 ≤ q) (hq1 : q < 1) (n : ℕ) :
    pk q D c0 n ≤ max c0 (D / (1 - q)) :=
  (pk_bounded q D c0 hq hq1 n).2

/-- 峰浓度收敛到稳态平台 L = D/(1-q)。 -/
theorem pk_tendsto_steady (q D c0 : ℝ) (hq : 0 ≤ q) (hq1 : q < 1) :
    Filter.Tendsto (pk q D c0) Filter.atTop (nhds (D / (1 - q))) := by
  have h_aff : ∀ n, pk q D c0 n = (D / (1 - q)) + q ^ n * (c0 - D / (1 - q)) :=
    fun n => pk_affine q D c0 hq1 n
  rw [funext h_aff]
  have hq0 := tendsto_qpow q hq hq1
  have ht : Filter.Tendsto (fun n : ℕ =>
      (D / (1 - q)) + (c0 - D / (1 - q)) * q ^ n) Filter.atTop (nhds (D / (1 - q))) := by
    have h := (hq0.const_mul (c0 - D / (1 - q))).const_add (D / (1 - q))
    simpa [mul_zero] using h
  exact ht.congr' (Filter.Eventually.of_forall (fun _ => by ring))

/-- 谷浓度不超过同期峰浓度（因 0 ≤ q < 1 且峰浓度非负）。 -/
theorem trough_le_pk (q D c0 : ℝ) (hq : 0 ≤ q) (hq1 : q < 1) (hD : 0 ≤ D) (hc0 : 0 ≤ c0)
    (n : ℕ) :
    trough q D c0 n ≤ pk q D c0 n := by
  have hn : 0 ≤ pk q D c0 n := pk_nonneg q D c0 hq hD hc0 n
  simp only [trough]
  have : q * pk q D c0 n ≤ 1 * pk q D c0 n := by
    gcongr <;> linarith
  simpa using this

/-- 谷浓度收敛到 q*L。 -/
theorem trough_tendsto_steady (q D c0 : ℝ) (hq : 0 ≤ q) (hq1 : q < 1) :
    Filter.Tendsto (trough q D c0) Filter.atTop (nhds (q * (D / (1 - q)))) :=
  (pk_tendsto_steady q D c0 hq hq1).const_mul q

/-! ## 标准情形 c0 = 0：精确稳态带 [0, L]，极限带 [q*L, L] -/

/-- 从零开始给药时，峰浓度 c(n)=L*(1-q^n) 始终在 [0,L] 内。 -/
theorem pk_zero_band (q D c0 : ℝ) (hq : 0 ≤ q) (hq1 : q < 1) (hD : 0 ≤ D)
    (h0 : c0 = 0) (n : ℕ) :
    0 ≤ pk q D c0 n ∧ pk q D c0 n ≤ D / (1 - q) := by
  set L := D / (1 - q) with hL
  have hLnonneg : 0 ≤ L := div_nonneg hD (by linarith)
  have h : pk q D c0 n = L * (1 - q ^ n) := by
    rw [pk_affine q D c0 hq1 n, h0] <;> ring
  rw [h]
  have hpn0 : 0 ≤ q ^ n := pow_q_nonneg q hq n
  have h1 : 0 ≤ 1 - q ^ n := by linarith [pow_q_le_one q hq hq1 n]
  have hlo : 0 ≤ L * (1 - q ^ n) := mul_nonneg hLnonneg h1
  have hhi : L * (1 - q ^ n) ≤ L := by
    have : L - L * (1 - q ^ n) = L * q ^ n := by ring
    have : 0 ≤ L * q ^ n := mul_nonneg hLnonneg hpn0
    linarith
  exact ⟨hlo, hhi⟩

/-- 从零开始给药时，谷浓度 t(n) 始终在 [0, q*L] 内。 -/
theorem trough_zero_band (q D c0 : ℝ) (hq : 0 ≤ q) (hq1 : q < 1) (hD : 0 ≤ D)
    (h0 : c0 = 0) (n : ℕ) :
    0 ≤ trough q D c0 n ∧ trough q D c0 n ≤ q * (D / (1 - q)) := by
  set L := D / (1 - q) with hL
  have hLnonneg : 0 ≤ L := div_nonneg hD (by linarith)
  have hcn : pk q D c0 n = L * (1 - q ^ n) := by
    rw [pk_affine q D c0 hq1 n, h0] <;> ring
  have hpn0 : 0 ≤ q ^ n := pow_q_nonneg q hq n
  have h1 : 0 ≤ 1 - q ^ n := by linarith [pow_q_le_one q hq hq1 n]
  simp only [trough, hcn]
  have h3 : 0 ≤ q * (L * (1 - q ^ n)) := by positivity
  have h4 : q * (L * (1 - q ^ n)) ≤ q * L := by
    have h5 : L * (1 - q ^ n) ≤ L := by
      have : L - L * (1 - q ^ n) = L * q ^ n := by ring
      have : 0 ≤ L * q ^ n := mul_nonneg hLnonneg hpn0
      linarith
    gcongr
  exact ⟨h3, h4⟩

/-- 稳态带总览（c0=0）：对所有时刻 0 ≤ 谷浓度 ≤ 峰浓度 ≤ L；
峰浓度 → L，谷浓度 → q*L，故长期浓度被夹在稳态区间 [q*L, L] 内。 -/
theorem steady_band (q D c0 : ℝ) (hq : 0 ≤ q) (hq1 : q < 1) (hD : 0 ≤ D) (hc0 : 0 ≤ c0)
    (h0 : c0 = 0) :
    (∀ n : ℕ, 0 ≤ trough q D c0 n ∧ trough q D c0 n ≤ pk q D c0 n
        ∧ pk q D c0 n ≤ D / (1 - q)) ∧
    Filter.Tendsto (pk q D c0) Filter.atTop (nhds (D / (1 - q))) ∧
    Filter.Tendsto (trough q D c0) Filter.atTop (nhds (q * (D / (1 - q)))) := by
  constructor
  · intro n
    exact ⟨(trough_zero_band q D c0 hq hq1 hD h0 n).1,
            trough_le_pk q D c0 hq hq1 hD hc0 n,
            (pk_zero_band q D c0 hq hq1 hD h0 n).2⟩
  · exact ⟨pk_tendsto_steady q D c0 hq hq1,
           trough_tendsto_steady q D c0 hq hq1⟩

end MyApt.PK
