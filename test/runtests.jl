using Test
using TreasuryLiquiditySignalLab

@testset "treasury liquidity signal lab" begin
    scenario = sample_scenario()
    result = optimize_liquidity(scenario)

    @test result["total_assigned_millions"] <= result["total_required_millions"]
    @test result["coverage_pct"] > 60
    @test length(result["lane_results"]) == 6
    @test length(result["pool_results"]) == 3
    @test any(item["shortfall_millions"] > 0 for item in result["lane_results"])
    @test any(item["minimum_buffer"] > 0 for item in result["pool_results"])
end
