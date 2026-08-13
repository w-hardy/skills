#!/usr/bin/env python3
"""
nice_calcs.py — deterministic helpers for NICE-aligned economic evaluation.

These are the calculations a NICE committee scrutinises and that are easy to get
wrong by hand (extended dominance especially). Use them instead of eyeballing.

All values reflect the 31 March 2026 PMG36 manual:
  - standard cost-effectiveness range: £25,000-£35,000 / QALY
  - HST: £100,000 / QALY
  - severity weights (Table 6.1) and HST size-of-benefit weights (Table 6.2)

Importable functions + a small CLI demo (`python nice_calcs.py`).
"""
from __future__ import annotations
from dataclasses import dataclass
from typing import Optional

# ---- thresholds (this manual version) -------------------------------------
THRESHOLD_LOWER = 25_000
THRESHOLD_UPPER = 35_000
HST_THRESHOLD = 100_000


# ---- fully incremental analysis (4.10.8) ----------------------------------
@dataclass
class Option:
    name: str
    cost: float
    qaly: float


def fully_incremental(options: list[dict]) -> dict:
    """Fully incremental analysis: drop dominated and extendedly dominated
    options, then return sequential ICERs along the efficiency frontier.

    options: list of {"name": str, "cost": float, "qaly": float}
    Returns dict with 'frontier' (kept options, with sequential ICER vs the
    previous frontier option), 'dominated', and 'extended_dominated'.
    """
    opts = [Option(o["name"], float(o["cost"]), float(o["qaly"])) for o in options]

    # 1. simple (strong) dominance: another option is no costlier AND no less
    #    effective, and strictly better on at least one axis.
    dominated = []
    nondom = []
    for o in opts:
        is_dom = any(
            p is not o
            and p.cost <= o.cost
            and p.qaly >= o.qaly
            and (p.cost < o.cost or p.qaly > o.qaly)
            for p in opts
        )
        (dominated if is_dom else nondom).append(o)

    nondom.sort(key=lambda x: (x.cost, x.qaly))

    # 2. extended (weak) dominance: a blend of two other options dominates.
    #    Detect via non-monotonic sequential ICERs and remove the middle option.
    ext_dom = []
    changed = True
    while changed and len(nondom) > 2:
        changed = False
        icers = []
        for i in range(1, len(nondom)):
            dc = nondom[i].cost - nondom[i - 1].cost
            dq = nondom[i].qaly - nondom[i - 1].qaly
            icers.append(dc / dq if dq > 0 else float("inf"))
        for j in range(1, len(icers)):
            if icers[j] < icers[j - 1] - 1e-9:
                ext_dom.append(nondom.pop(j))  # middle option is ext. dominated
                changed = True
                break

    # 3. sequential ICERs along the final frontier
    frontier = []
    for i, o in enumerate(nondom):
        if i == 0:
            icer = None
        else:
            dc = o.cost - nondom[i - 1].cost
            dq = o.qaly - nondom[i - 1].qaly
            icer = dc / dq if dq > 0 else float("inf")
        frontier.append(
            {"name": o.name, "cost": o.cost, "qaly": o.qaly,
             "icer_vs_prev": icer, "vs": nondom[i - 1].name if i else None}
        )
    return {
        "frontier": frontier,
        "dominated": [o.name for o in dominated],
        "extended_dominated": [o.name for o in ext_dom],
    }


# ---- severity modifier (Table 6.1) ----------------------------------------
def severity_weight(absolute_shortfall: Optional[float] = None,
                    proportional_shortfall: Optional[float] = None) -> dict:
    """QALY weight for severity. Uses whichever of absolute/proportional
    implies the GREATER severity (6.2.18). A value exactly on a cut-off takes
    the higher level. Supply either or both shortfalls (discounted, age/sex
    matched to the treated population)."""
    def w_abs(a):
        if a is None:
            return None
        if a >= 18:
            return 1.7
        if a >= 12:
            return 1.2
        return 1.0

    def w_prop(p):
        if p is None:
            return None
        if p >= 0.95:
            return 1.7
        if p >= 0.85:
            return 1.2
        return 1.0

    wa, wp = w_abs(absolute_shortfall), w_prop(proportional_shortfall)
    candidates = [w for w in (wa, wp) if w is not None]
    if not candidates:
        raise ValueError("Provide at least one of absolute_/proportional_shortfall")
    weight = max(candidates)
    return {"weight": weight, "weight_from_absolute": wa,
            "weight_from_proportional": wp,
            "binding": "absolute" if wa == weight and (wp is None or wp < weight)
            else "proportional" if wp == weight and (wa is None or wa < weight)
            else "both"}


# ---- severity shortfall from first principles (DSU TSD 23 method) ----------
def genpop_eq5d_norm(age: float, male: bool = True) -> float:
    """UK general-population EQ-5D-3L utility by age/sex — published Ara &
    Brazier (2010) predictor. Used to value general-population life years when
    building the severity shortfall (TSD 23). Clamped at 0."""
    u = 0.9508566 + 0.0212126 * (1 if male else 0) \
        - 0.0002587 * age - 0.0000332 * age ** 2
    return max(u, 0.0)


def _load_life_table(path: str) -> dict:
    import csv
    qx = {"male": {}, "female": {}}
    with open(path) as fh:
        for row in csv.DictReader(fh):
            a = int(row["age"])
            qx["male"][a] = float(row["qx_male"])
            qx["female"][a] = float(row["qx_female"])
    return qx


def _genpop_qalys_one_sex(start_age: float, male: bool, qx: dict,
                          discount: float, max_age: int) -> float:
    """Discounted expected QALYs for the general population from start_age,
    combining survival (life table) with age-specific EQ-5D norms, with a
    half-cycle (trapezoidal) correction on survival."""
    sex = "male" if male else "female"
    lx, total, t = 1.0, 0.0, 0
    a = int(round(start_age))
    while a + t <= max_age and lx > 1e-9:
        q = qx[sex].get(a + t, 1.0)
        lx_next = lx * (1 - q)
        alive = (lx + lx_next) / 2.0                 # half-cycle correction
        disc = 1.0 / (1.0 + discount) ** t
        total += disc * alive * genpop_eq5d_norm(a + t, male)
        lx, t = lx_next, t + 1
    return total


def general_population_qalys(start_age: float, prop_male: float,
                             life_table_path: str,
                             discount: float = 0.035, max_age: int = 100) -> float:
    """Sex-weighted discounted general-population QALYs over remaining lifetime.
    Supply a life table CSV (age, qx_male, qx_female). The bundled
    example_life_table.csv is ILLUSTRATIVE — use ONS National Life Tables and
    TSD 23-consistent values for real submissions."""
    qx = _load_life_table(life_table_path)
    qm = _genpop_qalys_one_sex(start_age, True, qx, discount, max_age)
    qf = _genpop_qalys_one_sex(start_age, False, qx, discount, max_age)
    return prop_male * qm + (1 - prop_male) * qf


def severity_shortfall(condition_qalys: float,
                       genpop_qalys: Optional[float] = None,
                       start_age: Optional[float] = None,
                       prop_male: Optional[float] = None,
                       life_table_path: Optional[str] = None,
                       discount: float = 0.035) -> dict:
    """Full severity assessment (TSD 23 method). Provide the condition cohort's
    expected QALYs under current NHS treatment (discounted), plus EITHER a
    precomputed general-population QALY value (e.g. from the TSD 23 reference
    table) OR start_age + prop_male + a life table to compute it here.
    Returns absolute/proportional shortfall and the Table 6.1 weight."""
    if genpop_qalys is None:
        if None in (start_age, prop_male, life_table_path):
            raise ValueError("Provide genpop_qalys, or start_age + prop_male + "
                             "life_table_path to compute it.")
        genpop_qalys = general_population_qalys(start_age, prop_male,
                                                life_table_path, discount)
    abs_sf = genpop_qalys - condition_qalys
    prop_sf = abs_sf / genpop_qalys if genpop_qalys > 0 else float("inf")
    out = {"general_population_qalys": genpop_qalys,
           "condition_qalys": condition_qalys,
           "absolute_shortfall": abs_sf,
           "proportional_shortfall": prop_sf}
    out.update(severity_weight(abs_sf, prop_sf))
    return out


# ---- HST size-of-benefit modifier (Table 6.2) -----------------------------
def hst_size_of_benefit_weight(incremental_qalys: float) -> float:
    """HST-only weight (6.2.22-24), per patient over a lifetime horizon.
    1 at <=10 QALYs, 3 at >=30, linear (equal increments) between."""
    if incremental_qalys <= 10:
        return 1.0
    if incremental_qalys >= 30:
        return 3.0
    return 1.0 + (incremental_qalys - 10) / 10.0  # (10,1)->(30,3)


# ---- net health benefit & weighted positioning ----------------------------
def net_health_benefit(incremental_cost: float, incremental_qaly: float,
                       threshold: float = THRESHOLD_LOWER,
                       qaly_weight: float = 1.0) -> dict:
    """NHB (health units) and NMB (monetary), with optional QALY weight.
    NHB = weighted_QALY - cost/threshold ; positive => cost-effective."""
    wq = incremental_qaly * qaly_weight
    nhb = wq - incremental_cost / threshold
    nmb = wq * threshold - incremental_cost
    icer = incremental_cost / incremental_qaly if incremental_qaly > 0 else float("inf")
    weighted_icer = (incremental_cost / wq) if wq > 0 else float("inf")
    return {"threshold": threshold, "qaly_weight": qaly_weight,
            "icer": icer, "weighted_icer": weighted_icer,
            "effective_threshold": threshold * qaly_weight,
            "net_health_benefit": nhb, "net_monetary_benefit": nmb,
            "cost_effective": nhb > 0}


def _demo():
    print("Fully incremental analysis")
    res = fully_incremental([
        {"name": "Established practice", "cost": 0, "qaly": 0},
        {"name": "A", "cost": 10_000, "qaly": 1.0},
        {"name": "B (ext-dom)", "cost": 30_000, "qaly": 1.5},
        {"name": "C", "cost": 40_000, "qaly": 2.5},
        {"name": "D (dominated)", "cost": 45_000, "qaly": 2.4},
    ])
    for f in res["frontier"]:
        icer = "-" if f["icer_vs_prev"] is None else f"£{f['icer_vs_prev']:,.0f}/QALY vs {f['vs']}"
        print(f"  {f['name']:22} cost £{f['cost']:>8,.0f}  QALY {f['qaly']:.2f}  {icer}")
    print("  dominated:", res["dominated"], "| extended-dominated:", res["extended_dominated"])

    print("\nSeverity weight (abs SF=16, prop SF=0.97):",
          severity_weight(16, 0.97))
    print("Severity shortfall from age/sex (cohort 65yo, 60% male, condition QALYs 4.0):")
    import os
    lt = os.path.join(os.path.dirname(__file__), "example_life_table.csv")
    print(" ", severity_shortfall(condition_qalys=4.0, start_age=65,
                                  prop_male=0.6, life_table_path=lt))
    print("HST size-of-benefit weight (20 QALYs):", hst_size_of_benefit_weight(20))
    print("Net health benefit (Δcost £45k, ΔQALY 2.0, severity ×1.2):")
    print(" ", net_health_benefit(45_000, 2.0, THRESHOLD_LOWER, 1.2))


if __name__ == "__main__":
    _demo()
