include(joinpath(@__DIR__, "..", "src", "TreasuryLiquiditySignalLab.jl"))
using .TreasuryLiquiditySignalLab

result = build_dashboard()
println("Scenario: ", result["scenario_title"])
println("Coverage: ", result["coverage_pct"], "%")
println("Assigned liquidity: \$", result["total_assigned_millions"], "m")
println("Funding shortfall: \$", result["total_shortfall_millions"], "m")
