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

## Product depth

For executives, this turns liquidity pressure into a board-ready decision surface: coverage, shortfall, standby capacity, and pool constraints are visible before settlement windows or covenant buffers create avoidable urgency.

For finance and platform teams, the Julia model keeps every lane tied to funding demand, business value, urgency, stress cost, and pool limits so the result is inspectable instead of decorative.

For GTM and diligence, this demonstrates that the Kinetic Gain portfolio can carry finance-grade operating logic in addition to web, AI, compliance, and revenue-system surfaces.

## What these repos have in common

- `risk`: the fragile handoff is made explicit before it becomes a vague operating complaint.
- `owner`: the accountable function remains attached to the next action.
- `proof`: the repo includes model code, tests, generated JSON, static pages, and release checks that support the public story.

## Operating workflow

1. Define treasury lanes with required funding, urgency, value, and stress cost.
2. Evaluate deployable liquidity across operating cash, reserves, and facility headroom.
3. Publish lane allocation, shortfall, and contingency posture as a static executive surface.
4. Use the result as diligence evidence for liquidity reviews, embedded finance screens, and close-safe operating narratives.

## Commercial path

- `Hosted preview planned`
- `Consulting hook`

This is the kind of surface that can ladder into liquidity templates, treasury reviews, and embedded close-safe funding work for finance and payments teams.

---

Part of the [Kinetic Gain operator portfolio](https://kineticgain.com/) · docs: [suite.kineticgain.com](https://suite.kineticgain.com/) · live: [treasury.kineticgain.com](https://treasury.kineticgain.com/)
