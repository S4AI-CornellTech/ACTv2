# ACT — hands-on: model your own hardware (≈20 min)

Model a real machine's **embodied (manufacturing) carbon** bottom-up from a bill-of-materials,
learn which knobs move the number, build your own server, and extend the tool's data. This follows
the 5-minute ACT intro (`TALKING_POINTS.md`).

You'll drive ACT's **real CLI**, `act_model`, directly on BOM files you edit. Run everything **from the
ACT repo root** (so `act.act_model` and `act_core` import), with a Python that has ACT's deps (pint +
pyyaml — the suite's `make setup` builds `.envs/act`, or `pip install pint pyyaml` in your own env):

```bash
cd ACT                                                 # the repo root
python -m act.act_model -m <bom>.yaml -o /tmp/act-out  # the real tool
cat /tmp/act-out/act_report.yaml                       # total_carbon + result_by_category
```

(From the **full-stack-carbon** suite, `make tutorial-act` runs the stages below on the suite's env.)
Paths below are relative to the **ACT repo root**.

**What a BOM is.** A YAML list of components. Each `silicon:` entry is a **logic** die (`area` +
`process` node), **DRAM** (`model: dram`, `capacity` + `process`), **flash/SSD** (`model: flash`), or
**HDD**; plus optional `materials:` (PCB, enclosure, battery). ACT turns each into carbon — die area ×
carbon-per-area for logic, per-GB for memory/storage — adds 150 g per IC for packaging, and sums. Every
component takes optional `n_ics`, `fab_yield`, `fab_ci` (fab grid), and `gpa` (gas abatement).

---

## Stage 1 — Run & read a real server (≈4 min)

Run ACT on the committed Dell R740 server BOM:

```bash
python -m act.act_model -m act/boms/dellr740.yaml -o /tmp/act-out
cat /tmp/act-out/act_report.yaml
```

You'll see **`total_carbon ≈ 1523 kg`** with `result_by_category` (FABRICATION ~1468, PACKAGING ~55).
Open `act/boms/dellr740.yaml` alongside the report and match entries: 8× 3.84 TB SSDs, 12×
36 GB DDR3 modules, 2× 28 nm CPU dies.

**Notice:** storage dominates — **SSD ~1,120 · DRAM ~380 · CPU only ~23 kg**. The CPU, the part people
picture as "the chip," is ~1.5% of the embodied total. *(In the suite, this same BOM is `make demo-act`.)*

---

## Stage 2 — Change the config, watch the number move (≈6 min)

Open `tutorial/exercises/sensitivity.yaml` — one logic die (7 cm², 28 nm, coal grid) + one 64 GB DDR3 module:

```bash
python -m act.act_model -m tutorial/exercises/sensitivity.yaml -o /tmp/act-out   # total ≈ 55.5 kg
```

Now change **one** field, re-run, watch **one** number move:

| Knob | Edit | Effect (this BOM) |
|---|---|---|
| **A · node** | `soc.process: 28nm → 7nm` (grid still coal) | soc **11.3 → 20.9 kg** — advanced nodes cost *more* embodied carbon per cm² (more fab energy + process gases) |
| **B · fab grid** | `soc.fab_ci: coal → wind` (now at 7nm) | soc **20.9 → 7.0 kg** — *where* you fabricate drives the energy term (coal 820 vs wind 11 g/kWh) |
| **C · memory** | `mem.process: ddr3_50nm → ddr4_10nm` | mem **43.9 → 4.8 kg** (~9×) — newer DRAM is far less carbon per GB; or double `capacity` and watch it scale linearly |

All three at once is `tutorial/solutions/sensitivity_solved.yaml` (**total ≈ 12.0 kg**).

**Takeaway:** the headline number is a function of a handful of explicit assumptions — node, grid, memory
tech, capacity — and ACT makes every one editable. Note **A and B fight**: a newer node *raises*
embodied carbon while a cleaner grid *lowers* it, so "advanced node" is not automatically greener.

---

## Stage 3 — Build your own: a second PowerEdge (≈8 min)

Now model a whole server yourself. Open `tutorial/exercises/poweredge2_starter.yaml` and fill in every
`__FILL__` from a server's spec sheet — CPU socket count + die area + node, DRAM module count + capacity,
SSD count + capacity, PCB. Use `act/boms/dellr740.yaml` as a worked reference, and duplicate the
`cpu.* / dram.* / ssd.*` blocks to match the real counts. Then:

```bash
python -m act.act_model -m tutorial/exercises/poweredge2_starter.yaml -o /tmp/act-out
```

Compare your total + breakdown to `tutorial/solutions/EXPECTED.md`. The completed solution
(`tutorial/solutions/poweredge2.yaml`) is the **Fair-CO2 paper's test node** — 2× Xeon Gold 6240R (14 nm)
· 192 GB DDR4 · 480 GB SSD:

```bash
python -m act.act_model -m tutorial/solutions/poweredge2.yaml -o /tmp/act-out   # total ≈ 72.55 kg
```

**Takeaway:** the embodied profile is all about the config. The R740 (Stage 1) was 1,523 kg and
*storage*-dominated; this compute-focused box is just **72.55 kg** and **DRAM-dominated** (47 kg — its
192 GB of ECC DDR4 carries heavy per-module IC packaging, with little storage). Same tool, same method,
wildly different footprint — because the BOM is different. (Its CPU lands at 18.2 kg ≈ the Fair-CO2
paper's own ACT-derived per-CPU number, 18.53 kg.)

---

## Stage 4 — Extend the data: add a fab location (≈2 min)

ACT's coefficients are **data, not magic** — you can extend coverage. Say you want to fabricate on the
French grid (nuclear-heavy, ~56 g/kWh), which ACT doesn't ship. Two additive edits in this ACT repo:

1. **`act_core/common.py`** — add a member to the `EnergyLocation` enum (after `ICELAND`):
   ```python
   FRANCE = "france"
   ```
2. **`act_core/models/carbon_intensity/location_2022.yaml`** — add a row:
   ```yaml
   "france"    : 56 g / kWh
   ```
   > Note: the default `location.yaml` is a **symlink to `location_2022.yaml`** — edit the real file.

Now use it: set `fab_ci: france` on the die in `tutorial/exercises/sensitivity.yaml` (at 7 nm) and re-run — soc
drops to **≈ 7.8 kg**, near the wind result (7.0) and far below coal (20.9). The same pattern adds a new
**process node**, **memory type**, or **material**: one enum member + one data row.

> These are edits on *your* ACT checkout and are purely additive (no existing value changes), so ACT's
> tests — and the full-stack-carbon suite's regression baselines — stay green.

---

## Where this goes next

You modeled whole **servers** — bottom-up embodied carbon from a BOM. In the full-stack-carbon
walkthrough this hands off to **EServe**, which takes the **GPU accelerator** case: it models an H100
natively (including its HBM), then adds the **host server** it racks into — and shows that host (the kind
of box you just modeled) **dominates** the embodied footprint, ~10× the GPU, with the
embodied-vs-operational balance set by the grid (and the node). The skill you just practiced — reading a
system as a bill-of-materials — is exactly what makes EServe's "the host, not the accelerator" point land.
