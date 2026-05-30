include(joinpath(@__DIR__, "..", "src", "TreasuryLiquiditySignalLab.jl"))
using .TreasuryLiquiditySignalLab

result = build_dashboard()
root = write_site(result)
println("Generated site at: ", root)
