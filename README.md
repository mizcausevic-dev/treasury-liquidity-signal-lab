# treasury-liquidity-signal-lab

Julia operator surface for treasury liquidity coverage, settlement buffers, funding pressure, and close-safe posture.

## What it shows

- real Julia added to the public Kinetic Gain language atlas
- monetizable treasury signal analysis across cash, revolver, reserve, and settlement lanes
- buyer-readable operator reporting generated from the same liquidity optimization core

## Routes

- `/`
- `/treasury-lane/`
- `/liquidity-matrix/`
- `/funding-posture/`
- `/verification/`
- `/docs/`

## Local development

```powershell
julia --project=. scripts/run_demo.jl
julia --project=. scripts/generate_site.jl
```

## Validation

```powershell
julia --project=. -e "using Pkg; Pkg.test()"
julia --project=. scripts/smoke_check.jl
```

## Why this matters

Kinetic Gain Embedded tie-back:

This repo proves Kinetic Gain can ship auditable treasury and liquidity logic in Julia, not just wrap dashboards around generic finance metrics. The language-atlas signal is real: model, verify, and publish the same operator surface from Julia code.

## Commercial path

- `Hosted preview planned`
- `Consulting hook`

This is the kind of surface that can ladder into liquidity templates, treasury reviews, and embedded close-safe funding work for finance and payments teams.

---

Part of the [Kinetic Gain operator portfolio](https://kineticgain.com/) · docs: [suite.kineticgain.com](https://suite.kineticgain.com/) · live: [treasury.kineticgain.com](https://treasury.kineticgain.com/)
