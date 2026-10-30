import Mathlib

/-!
# APT（套利定价理论）有限维核心引理

资产超额收益对因子载荷做横截面最小二乘回归时，
满足正规方程（因子组合与残差正交）的因子风险溢价 `lam`，
使各资产平方定价误差之和最小。这是 APT 的有限维线性代数核心；
渐近无套利（Ross 的分散化结论）属后续渐近层。
-/

open BigOperators

namespace MyApt.APT

/-- APT 有限维核心引理：正规方程下的因子定价残差使平方误差和最小。 -/
theorem apt_core_leastSquares
    {N K : ℕ}
    (r : Fin N → ℝ)
    (b : Fin N → Fin K → ℝ)
    (lam : Fin K → ℝ)
    (normal :
      ∀ k : Fin K,
        ∑ i : Fin N, b i k * (r i - ∑ j : Fin K, b i j * lam j) = 0)
    (μ : Fin K → ℝ) :
    ∑ i : Fin N, (r i - ∑ j : Fin K, b i j * lam j)^2
      ≤ ∑ i : Fin N, (r i - ∑ j : Fin K, b i j * μ j)^2 := by
  let e : Fin N → ℝ := fun i => r i - ∑ j : Fin K, b i j * lam j
  let d : Fin K → ℝ := fun j => μ j - lam j
  let s : Fin N → ℝ := fun i => ∑ j : Fin K, b i j * d j

  -- 新组合 μ = lam + d 下的残差等于 e i - s i
  have h_resid : ∀ i : Fin N, r i - ∑ j : Fin K, b i j * μ j = e i - s i := by
    intro i
    have hμ : ∀ j : Fin K, μ j = lam j + d j := by
      intro j; simp only [d]; ring
    have hsum : ∑ j : Fin K, b i j * μ j = (∑ j : Fin K, b i j * lam j) + s i := by
      calc
        (∑ j : Fin K, b i j * μ j)
          = ∑ j : Fin K, b i j * (lam j + d j) :=
            Finset.sum_congr rfl (fun j _ => by rw [hμ j])
        _ = ∑ j : Fin K, (b i j * lam j + b i j * d j) :=
            Finset.sum_congr rfl (fun j _ => by ring)
        _ = (∑ j : Fin K, b i j * lam j) + s i := by
          simp only [s]; exact Finset.sum_add_distrib
    simp only [e]; rw [hsum]; ring

  -- 正规方程给出每个因子与残差正交：∑ i, b i j * e i = 0
  have h_orth : ∀ j : Fin K, ∑ i : Fin N, b i j * e i = 0 := fun j => normal j

  -- 交叉项 ∑ i, e i * s i = ∑ j, d j * (∑ i, b i j * e i) = 0
  have h_cross : ∑ i : Fin N, e i * s i = 0 := by
    simp only [s]
    have h_swap : (∑ i : Fin N, e i * (∑ j : Fin K, b i j * d j)) =
                    ∑ j : Fin K, d j * (∑ i : Fin N, b i j * e i) := by
      have hl : (∑ i : Fin N, e i * (∑ j : Fin K, b i j * d j)) =
                  ∑ i : Fin N, ∑ j : Fin K, (e i * b i j * d j) := by
        apply Finset.sum_congr rfl; intro i _
        rw [Finset.mul_sum]
        exact Finset.sum_congr rfl (fun j _ => by ring)
      rw [hl, Finset.sum_comm]
      apply Finset.sum_congr rfl; intro j _
      have hi : (∑ i : Fin N, e i * b i j * d j) = d j * (∑ i : Fin N, b i j * e i) := by
        have hfactor : (∑ i : Fin N, e i * b i j * d j) = (∑ i : Fin N, e i * b i j) * d j := by
          rw [Finset.sum_mul]
        rw [hfactor]
        have hcomm : (∑ i : Fin N, e i * b i j) = ∑ i : Fin N, b i j * e i :=
          Finset.sum_congr rfl (fun i _ => by ring)
        rw [hcomm]; ring
      exact hi
    rw [h_swap]
    have hz : ∀ j : Fin K, d j * (∑ i : Fin N, b i j * e i) = 0 := by
      intro j; rw [h_orth j]; ring
    rw [Finset.sum_congr rfl (fun j _ => hz j), Finset.sum_const_zero]

  -- 展开 (e i - s i)^2，交叉项归零，右侧平方和 = 原平方和 + 非负平方和
  have h2 : ∑ i : Fin N, (2 * e i * s i) = 2 * (∑ i : Fin N, e i * s i) := by
    have hc : ∑ i : Fin N, (2 * e i * s i) = ∑ i : Fin N, (2 * (e i * s i)) :=
      Finset.sum_congr rfl (fun _ _ => by ring)
    rw [hc, Finset.mul_sum]
  have h_expand : ∑ i : Fin N, (e i - s i)^2 =
                    (∑ i : Fin N, (e i)^2) + ∑ i : Fin N, (s i)^2 := by
    have hsq : ∀ i : Fin N, (e i - s i)^2 = (e i)^2 + (s i)^2 - 2 * e i * s i := by
      intro i; ring
    calc
      (∑ i : Fin N, (e i - s i)^2)
        = ∑ i : Fin N, ((e i)^2 + (s i)^2 - 2 * e i * s i) :=
          Finset.sum_congr rfl (fun i _ => hsq i)
      _ = (∑ i : Fin N, (e i)^2) + (∑ i : Fin N, (s i)^2) - ∑ i : Fin N, (2 * e i * s i) := by
          simp [Finset.sum_add_distrib, Finset.sum_sub_distrib]
      _ = (∑ i : Fin N, (e i)^2) + (∑ i : Fin N, (s i)^2) := by
          rw [h2, h_cross]; ring

  have h_rhs : (∑ i : Fin N, (r i - ∑ j : Fin K, b i j * μ j)^2) =
                 ∑ i : Fin N, (e i - s i)^2 :=
    Finset.sum_congr rfl (fun i _ => by rw [h_resid i])
  have h_lhs : (∑ i : Fin N, (r i - ∑ j : Fin K, b i j * lam j)^2) = ∑ i : Fin N, (e i)^2 :=
    Finset.sum_congr rfl (fun i _ => by simp only [e])
  have h_nonneg : 0 ≤ ∑ i : Fin N, (s i)^2 :=
    Finset.sum_nonneg (fun i _ => sq_nonneg (s i))
  rw [h_lhs, h_rhs, h_expand]
  linarith

end MyApt.APT

