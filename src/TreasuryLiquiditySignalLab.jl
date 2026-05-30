# SPDX-License-Identifier: AGPL-3.0-or-later

module TreasuryLiquiditySignalLab

using Dates
using Printf

export LiquidityPool, FundingLane, LiquidityScenario, sample_scenario, optimize_liquidity, build_dashboard, write_site

struct LiquidityPool
    id::String
    label::String
    available_millions::Int
    minimum_buffer::Int
    confidence::Float64
end

struct FundingLane
    id::String
    label::String
    pool_index::Int
    required_millions::Int
    value_score::Float64
    urgency::Float64
    stress_penalty::Float64
end

struct LiquidityScenario
    title::String
    generated_on::Date
    pools::Vector{LiquidityPool}
    lanes::Vector{FundingLane}
    standby_capacity_millions::Int
end

function sample_scenario()
    pools = [
        LiquidityPool("LP-1", "Operating cash and sweep accounts", 42, 8, 0.96),
        LiquidityPool("LP-2", "Revolver and backup credit facility", 28, 6, 0.89),
        LiquidityPool("LP-3", "Investment runoff and treasury reserve", 19, 5, 0.84),
    ]

    lanes = [
        FundingLane("TL-11", "Payroll and tax settlement window", 1, 16, 510.0, 0.99, 22.0),
        FundingLane("TL-15", "Card network settlement reconciliation", 1, 11, 470.0, 0.95, 26.0),
        FundingLane("TL-21", "Vendor disbursement protection lane", 2, 12, 430.0, 0.93, 31.0),
        FundingLane("TL-27", "Merchant reserve top-up", 2, 9, 445.0, 0.90, 34.0),
        FundingLane("TL-34", "Warehouse line collateral cure", 3, 13, 540.0, 0.97, 41.0),
        FundingLane("TL-39", "Acquisition bridge holdback", 3, 8, 495.0, 0.88, 38.0),
    ]

    LiquidityScenario(
        "Treasury liquidity signal lab for close-safe cash, settlement, and covenant posture",
        Date(2026, 5, 29),
        pools,
        lanes,
        14,
    )
end

score_millions(lane::FundingLane, millions::Int) = millions * (lane.value_score * lane.urgency - lane.stress_penalty)

function optimize_liquidity(scenario::LiquidityScenario)
    deployable = [pool.available_millions - pool.minimum_buffer for pool in scenario.pools]
    limits = [lane.required_millions for lane in scenario.lanes]
    best_score = Ref(-Inf)
    best_millions = fill(0, length(scenario.lanes))

    function search!(index::Int, current_millions::Vector{Int}, used_capacity::Vector{Int}, current_score::Float64)
        if index > length(scenario.lanes)
            if current_score > best_score[]
                best_score[] = current_score
                best_millions .= current_millions
            end
            return
        end

        lane = scenario.lanes[index]
        pool_slot = lane.pool_index
        max_assignable = min(limits[index], deployable[pool_slot] - used_capacity[pool_slot])

        for millions in 0:max_assignable
            current_millions[index] = millions
            used_capacity[pool_slot] += millions
            search!(index + 1, current_millions, used_capacity, current_score + score_millions(lane, millions))
            used_capacity[pool_slot] -= millions
        end

        current_millions[index] = 0
    end

    search!(1, fill(0, length(scenario.lanes)), fill(0, length(deployable)), 0.0)

    lane_results = Any[]
    for (i, lane) in enumerate(scenario.lanes)
        assigned = best_millions[i]
        shortfall = lane.required_millions - assigned
        coverage = assigned / max(lane.required_millions, 1)
        push!(lane_results, Dict(
            "id" => lane.id,
            "label" => lane.label,
            "pool" => scenario.pools[lane.pool_index].label,
            "assigned_millions" => assigned,
            "required_millions" => lane.required_millions,
            "shortfall_millions" => shortfall,
            "coverage" => round(coverage * 100; digits=1),
            "urgency" => lane.urgency,
            "stress_penalty" => lane.stress_penalty,
            "score" => round(score_millions(lane, assigned); digits=1),
            "status" => shortfall == 0 ? "green" : shortfall <= 2 ? "yellow" : "red",
        ))
    end

    pool_results = Any[]
    for (i, pool) in enumerate(scenario.pools)
        assigned = sum(best_millions[j] for (j, lane) in enumerate(scenario.lanes) if lane.pool_index == i)
        deployable_capacity = deployable[i]
        utilization = assigned / max(deployable_capacity, 1)
        push!(pool_results, Dict(
            "id" => pool.id,
            "label" => pool.label,
            "available_millions" => pool.available_millions,
            "minimum_buffer" => pool.minimum_buffer,
            "deployable_millions" => deployable_capacity,
            "assigned_millions" => assigned,
            "free_millions" => deployable_capacity - assigned,
            "utilization" => round(utilization * 100; digits=1),
            "confidence" => round(pool.confidence * 100; digits=1),
            "status" => utilization >= 0.95 ? "red" : utilization >= 0.80 ? "yellow" : "green",
        ))
    end

    total_assigned = sum(best_millions)
    total_required = sum(lane.required_millions for lane in scenario.lanes)
    total_shortfall = total_required - total_assigned
    coverage_pct = round(total_assigned / total_required * 100; digits=1)
    weighted_value = round(sum(scenario.lanes[i].value_score * best_millions[i] for i in eachindex(best_millions)); digits=1)
    weighted_stress = round(sum(scenario.lanes[i].stress_penalty * best_millions[i] for i in eachindex(best_millions)); digits=1)

    return Dict(
        "scenario_title" => scenario.title,
        "generated_on" => string(scenario.generated_on),
        "score" => round(best_score[]; digits=1),
        "total_assigned_millions" => total_assigned,
        "total_required_millions" => total_required,
        "total_shortfall_millions" => total_shortfall,
        "coverage_pct" => coverage_pct,
        "weighted_value" => weighted_value,
        "weighted_stress" => weighted_stress,
        "standby_capacity_millions" => scenario.standby_capacity_millions,
        "lane_results" => lane_results,
        "pool_results" => pool_results,
    )
end

build_dashboard() = optimize_liquidity(sample_scenario())

escape_html(text) = replace(string(text), "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")

function json_string(value)
    if value isa Dict
        parts = ["\"$(escape_html(k))\":$(json_string(v))" for (k, v) in value]
        return "{" * join(parts, ",") * "}"
    elseif value isa AbstractVector
        return "[" * join(json_string.(value), ",") * "]"
    elseif value isa String
        return "\"" * replace(value, "\"" => "\\\"") * "\""
    elseif value isa Bool
        return value ? "true" : "false"
    elseif value isa Number
        return string(value)
    else
        return "\"" * replace(string(value), "\"" => "\\\"") * "\""
    end
end

function base_css()
    return """
    :root{
      --bg:#070a0f; --panel:#0b1220; --panel2:#0a1426;
      --line:rgba(120,255,170,.18); --line2:rgba(120,255,170,.10);
      --text:#e9f3ff; --muted:rgba(233,243,255,.72); --muted2:rgba(233,243,255,.55);
      --bert:#37ff8b; --bert2:#19c7ff; --warn:#ffcc66; --bad:#ff5c7a; --plum:#b88cff;
      --shadow:0 18px 60px rgba(0,0,0,.55); --radius:18px;
      --mono:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Courier New",monospace;
      --sans:ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
    }
    *{box-sizing:border-box} html,body{height:100%}
    body{
      margin:0;font-family:var(--sans);color:var(--text);
      background:
        radial-gradient(1200px 600px at 20% -10%, rgba(55,255,139,.18), transparent 60%),
        radial-gradient(900px 520px at 90% 0%, rgba(25,199,255,.16), transparent 55%),
        radial-gradient(1000px 600px at 50% 110%, rgba(55,255,139,.10), transparent 60%),
        linear-gradient(180deg,#05070c 0%,#070a0f 35%,#05070c 100%);
    }
    .grid-bg{position:fixed;inset:0;pointer-events:none;opacity:.12;z-index:-1;background-image:
      linear-gradient(to right, rgba(55,255,139,.14) 1px, transparent 1px),
      linear-gradient(to bottom, rgba(55,255,139,.10) 1px, transparent 1px);
      background-size:46px 46px;mask-image: radial-gradient(900px 600px at 40% 10%, #000 60%, transparent 100%);}
    .wrap{max-width:1280px;margin:0 auto;padding:24px 22px 80px}
    .topbar{display:flex;justify-content:space-between;align-items:flex-start;gap:14px;border-bottom:1px solid var(--line2);padding-bottom:14px;margin-bottom:22px;font-family:var(--mono);font-size:11px;letter-spacing:.16em;color:var(--muted);text-transform:uppercase}
    .topbar .left{color:var(--bert)} .topbar .right{text-align:right}
    .herorow{display:grid;grid-template-columns:1.45fr .85fr;gap:18px} @media (max-width:1000px){.herorow{grid-template-columns:1fr}}
    .hero,.panel,.mini,.tablewrap{
      background:linear-gradient(180deg, rgba(11,18,32,.95), rgba(8,14,26,.92));
      border:1px solid var(--line);border-radius:22px;box-shadow:var(--shadow)
    }
    .hero{padding:28px 28px 24px;border-top:2px solid var(--bert2)}
    .hero h1{font-size:64px;line-height:.95;margin:0 0 18px;font-weight:800;letter-spacing:-.5px}
    @media (max-width:700px){.hero h1{font-size:42px}}
    .hero p,.panel p,.mini p,.tablewrap p{color:var(--muted);font-size:15px;line-height:1.55}
    .chiprow{display:flex;flex-wrap:wrap;gap:8px}
    .meta-chip,.pill{font-family:var(--mono);font-size:11px;padding:7px 12px;border-radius:999px;border:1px solid var(--line);background:rgba(6,10,18,.4);color:var(--muted)}
    .side{display:flex;flex-direction:column;gap:14px}
    .mini{padding:18px}
    .mini .lbl,.section-note{font-family:var(--mono);font-size:10px;letter-spacing:.18em;text-transform:uppercase;color:var(--bert2)}
    .mini h3{margin:8px 0 6px;font-size:28px;line-height:1.02}
    .section{margin-top:34px}
    .sh{display:flex;justify-content:space-between;align-items:baseline;gap:14px;padding-bottom:10px;border-bottom:1px solid var(--line2);margin-bottom:14px}
    .sh h2{margin:0;font-size:24px;font-weight:600}
    .sh .note{font-family:var(--mono);font-size:11px;color:var(--muted2);letter-spacing:.16em;text-transform:uppercase}
    .kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px} @media (max-width:900px){.kpis{grid-template-columns:repeat(2,1fr)}} @media (max-width:640px){.kpis{grid-template-columns:1fr}}
    .kpi,.card{border:1px solid var(--line);border-radius:16px;padding:16px;background:linear-gradient(180deg, rgba(11,18,32,.85), rgba(8,14,26,.65))}
    .kpi .v{font-family:var(--mono);font-size:28px;font-weight:700}
    .kpi .lbl{font-family:var(--mono);font-size:10px;letter-spacing:.18em;text-transform:uppercase;color:var(--muted);margin-top:6px}
    .kpi .h{font-size:12px;color:var(--muted);line-height:1.45;margin-top:8px}
    .green{color:var(--bert)} .cyan{color:var(--bert2)} .warn{color:var(--warn)} .plum{color:var(--plum)} .bad{color:var(--bad)}
    .cards{display:grid;grid-template-columns:repeat(3,1fr);gap:14px} @media (max-width:1000px){.cards{grid-template-columns:1fr}}
    .card h3{margin:8px 0 8px;font-size:22px}
    .card .eyebrow{font-family:var(--mono);font-size:10px;letter-spacing:.18em;text-transform:uppercase;color:var(--bert)}
    table{width:100%;border-collapse:collapse} th,td{padding:13px 14px;text-align:left;font-size:13.5px;vertical-align:top}
    thead th{font-family:var(--mono);font-size:11px;letter-spacing:.16em;text-transform:uppercase;color:var(--muted2);border-bottom:1px solid var(--line);background:rgba(11,18,32,.5)}
    tbody tr:hover{background:rgba(55,255,139,.03)} tbody td{color:var(--muted);border-bottom:1px solid var(--line2)}
    .tablewrap{padding:0;overflow:hidden}
    .status{display:inline-block;padding:4px 9px;border-radius:6px;border:1px solid currentColor;font-family:var(--mono);font-size:10px;letter-spacing:.1em;text-transform:uppercase}
    .quote{margin-top:34px;border:1px solid rgba(55,255,139,.22);background:radial-gradient(700px 200px at 0% 0%, rgba(55,255,139,.10), transparent 60%),linear-gradient(180deg, rgba(11,18,32,.92), rgba(8,14,26,.88));border-radius:18px;padding:24px 26px}
    .quote .lbl{font-family:var(--mono);font-size:11px;color:var(--bert);letter-spacing:.22em;text-transform:uppercase}
    .quote .q{margin-top:12px;font-size:32px;line-height:1.25;font-weight:600;max-width:1000px}
    footer{margin-top:30px;padding-top:14px;border-top:1px dashed var(--line2);display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap;font-family:var(--mono);font-size:11px;color:var(--muted2);letter-spacing:.08em}
    a{color:var(--bert2);text-decoration:none}
    """
end

function html_page(title::String, description::String, content::String; canonical::String)
    return """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>$(escape_html(title))</title>
      <meta name="description" content="$(escape_html(description))">
      <meta name="robots" content="index,follow">
      <meta property="og:title" content="$(escape_html(title))">
      <meta property="og:description" content="$(escape_html(description))">
      <meta property="og:type" content="website">
      <meta property="og:url" content="$(canonical)">
      <link rel="canonical" href="$(canonical)">
      <style>$(base_css())</style>
    </head>
    <body>
      <div class="grid-bg"></div>
      <div class="wrap">
        $(content)
      </div>
    </body>
    </html>
    """
end

status_badge(status::String) = "<span class=\"status $(status == "green" ? "green" : status == "yellow" ? "warn" : "bad")\">$(uppercase(status))</span>"

function overview_content(result::Dict)
    lane_rows = join([
        """
        <tr>
          <td><b>$(escape_html(item["label"]))</b><br><span class="section-note">$(escape_html(item["id"])) · $(escape_html(item["pool"]))</span></td>
          <td>\$$(item["assigned_millions"])m / \$$(item["required_millions"])m</td>
          <td>\$$(item["shortfall_millions"])m</td>
          <td>$(item["score"])</td>
          <td>$(status_badge(item["status"]))</td>
        </tr>
        """ for item in result["lane_results"]
    ], "\n")

    pool_cards = join([
        """
        <div class="card">
          <div class="eyebrow">$(escape_html(item["id"]))</div>
          <h3>$(escape_html(item["label"]))</h3>
          <p>Deployable liquidity of <b>\$$(item["deployable_millions"])m</b> after a minimum buffer of <b>\$$(item["minimum_buffer"])m</b>, with <b>\$$(item["free_millions"])m</b> still free and confidence at $(item["confidence"])%.</p>
          <p>$(status_badge(item["status"]))</p>
        </div>
        """ for item in result["pool_results"]
    ], "\n")

    return """
    <div class="topbar">
      <div class="left">language atlas · julia treasury surface</div>
      <div class="right">
        <div>treasury.kineticgain.com</div>
        <div>generated $(escape_html(result["generated_on"])) · fintech / treasury ops</div>
      </div>
    </div>

    <div class="herorow">
      <section class="hero">
        <div class="chiprow">
          <span class="meta-chip">Julia treasury modeling</span>
          <span class="meta-chip">liquidity posture</span>
          <span class="meta-chip">fintech</span>
          <span class="meta-chip">cash coverage</span>
        </div>
        <h1>See tomorrow's liquidity pressure before settlement windows and covenant buffers get tight.</h1>
        <p>A Julia treasury operator surface for Kinetic Gain: route limited deployable cash across payroll, settlement, vendor, and collateral lanes, quantify shortfall, and publish a buyer-readable liquidity posture from the same optimization core.</p>
        <div class="chiprow">
          <span class="pill">Route: /treasury-lane/</span>
          <span class="pill">Route: /liquidity-matrix/</span>
          <span class="pill">Route: /funding-posture/</span>
        </div>
      </section>
      <aside class="side">
        <div class="mini">
          <div class="lbl">coverage</div>
          <h3 class="green">$(result["coverage_pct"])%</h3>
          <p>Required treasury obligations covered by the current allocation sweep across three liquidity pools and six funding lanes.</p>
        </div>
        <div class="mini">
          <div class="lbl">score</div>
          <h3 class="cyan">$(result["score"])</h3>
          <p>Weighted objective combining business value, urgency, and treasury stress penalty for each funding lane.</p>
        </div>
        <div class="mini">
          <div class="lbl">shortfall watch</div>
          <h3 class="warn">\$$(result["total_shortfall_millions"])m</h3>
          <p>Unfunded demand left after the optimization pass, with standby capacity of $(result["standby_capacity_millions"])m still off balance sheet.</p>
        </div>
      </aside>
    </div>

    <section class="section">
      <div class="sh"><h2>Operator KPIs</h2><div class="note">dashboard summary</div></div>
      <div class="kpis">
        <div class="kpi"><div class="v green">\$$(result["total_assigned_millions"])m</div><div class="lbl">assigned liquidity</div><div class="h">Millions routed into the highest-value treasury lanes in the best plan.</div></div>
        <div class="kpi"><div class="v cyan">$(result["weighted_value"])</div><div class="lbl">weighted value</div><div class="h">Modeled business value protected by the chosen funding plan.</div></div>
        <div class="kpi"><div class="v warn">$(result["weighted_stress"])</div><div class="lbl">weighted stress</div><div class="h">Accumulated stress cost still carried by the assigned treasury posture.</div></div>
        <div class="kpi"><div class="v plum">$(length(result["pool_results"]))</div><div class="lbl">liquidity pools</div><div class="h">Cash and facility pools represented in the optimization sweep.</div></div>
      </div>
    </section>

    <section class="section">
      <div class="sh"><h2>Liquidity posture</h2><div class="note">where buffers are tight</div></div>
      <div class="cards">
        $(pool_cards)
      </div>
    </section>

    <section class="section">
      <div class="sh"><h2>Funding lane allocation</h2><div class="note">coverage vs constraint</div></div>
      <div class="tablewrap">
        <table>
          <thead>
            <tr><th>Lane</th><th>Assigned</th><th>Shortfall</th><th>Score</th><th>Status</th></tr>
          </thead>
          <tbody>
            $(lane_rows)
          </tbody>
        </table>
      </div>
    </section>

    <section class="quote">
      <div class="lbl">why this matters</div>
      <div class="q">Kinetic Gain Embedded tie-back: this repo proves the portfolio can carry treasury and liquidity logic in Julia while still publishing the same buyer-readable operator surface language for finance, payment, and risk teams.</div>
    </section>

    <footer>
      <span>treasury-liquidity-signal-lab · Julia 1.12</span>
      <span><a href="https://github.com/mizcausevic-dev/">GitHub</a> · <a href="https://www.linkedin.com/in/mirzacausevic/">LinkedIn</a> · <a href="https://kineticgain.com/">Kinetic Gain</a></span>
      <span><a href="/docs/">Docs</a> · <a href="/verification/">Verification</a></span>
    </footer>
    """
end

function generic_content(title::String, note::String, body::Vector{String}; back::String="/")
    bullet_html = join(["<li>$(escape_html(line))</li>" for line in body], "")
    return """
    <div class="topbar">
      <div class="left">treasury liquidity signal lab · julia operator surface</div>
      <div class="right"><div>$(escape_html(title))</div></div>
    </div>
    <section class="hero">
      <div class="section-note">$(escape_html(note))</div>
      <h1>$(escape_html(title))</h1>
      <p>$(join(escape_html.(body), " "))</p>
      <ul style="color:var(--muted);line-height:1.8">$(bullet_html)</ul>
      <p><a href="$(back)">Return to the overview</a></p>
    </section>
    """
end

function write_text(path::String, content::String)
    mkpath(dirname(path))
    open(path, "w") do io
        write(io, content)
    end
end

function write_site(result::Dict; domain::String="treasury.kineticgain.com", out_dir::String="site")
    root = abspath(out_dir)
    mkpath(root)
    write_text(joinpath(root, "index.html"), html_page(
        "Treasury Liquidity Signal Lab",
        "Julia operator surface for treasury liquidity, settlement buffers, and funding shortfall posture.",
        overview_content(result);
        canonical="https://$domain/",
    ))

    write_text(joinpath(root, "treasury-lane", "index.html"), html_page(
        "Treasury Lane",
        "Lane-level funding view for the Julia treasury liquidity signal lab.",
        generic_content("Treasury lane", "funding packet view", [
            "Each treasury lane blends required funding, business value, urgency, and stress cost into one explicit operator packet.",
            "The optimizer chooses cash assignment that maximizes protected value under deployable-liquidity limits.",
            "Use this route to explain how treasury coverage shifts when payroll, settlement, and reserve pressure compete.",
        ]);
        canonical="https://$domain/treasury-lane/",
    ))

    write_text(joinpath(root, "liquidity-matrix", "index.html"), html_page(
        "Liquidity Matrix",
        "Constraint and confidence view for the Julia treasury liquidity signal lab.",
        generic_content("Liquidity matrix", "buffer pressure", [
            "Pool availability, minimum buffers, lane requirements, and stress penalties determine the feasible treasury search space.",
            "This route is where operators see whether the bottleneck is operating cash, revolver headroom, or reserve runoff.",
            "It turns a quantitative Julia sweep into a buyer-legible treasury constraint map.",
        ]);
        canonical="https://$domain/liquidity-matrix/",
    ))

    write_text(joinpath(root, "funding-posture", "index.html"), html_page(
        "Funding Posture",
        "Shortfall and contingency posture for the Julia treasury liquidity signal lab.",
        generic_content("Funding posture", "contingency posture", [
            "The chosen plan makes funding shortfall, standby dependence, and near-buffer pressure explicit.",
            "Contingency posture ties the optimization result back to finance escalation and close-safe decision making.",
            "This is the buyer-readable layer that turns a Julia treasury model into an operating surface.",
        ]);
        canonical="https://$domain/funding-posture/",
    ))

    write_text(joinpath(root, "verification", "index.html"), html_page(
        "Verification",
        "Verification notes for the Julia treasury liquidity signal lab reference implementation.",
        generic_content("Verification", "release gate", [
            "Pkg.test validates the treasury optimization core and result invariants.",
            "The site generator publishes crawlable HTML, robots, sitemap, and JSON dashboard data.",
            "GitHub Pages serves the report under a custom kineticgain.com subdomain.",
        ]);
        canonical="https://$domain/verification/",
    ))

    write_text(joinpath(root, "docs", "index.html"), html_page(
        "Docs",
        "Documentation for the Julia treasury liquidity signal lab reference implementation.",
        generic_content("Docs", "reference implementation", [
            "This repo expands the language atlas with real Julia code and deployable proof for treasury operations.",
            "It uses a brute-force constrained allocation search to stay auditable and dependency-light.",
            "The output is a static liquidity operator report that recruiters and buyers can inspect without a local REPL.",
        ]);
        canonical="https://$domain/docs/",
    ))

    dashboard_json = json_string(result)
    write_text(joinpath(root, "api", "dashboard.json"), dashboard_json)
    write_text(joinpath(root, "CNAME"), domain * "\n")
    write_text(joinpath(root, "robots.txt"), "User-agent: *\nAllow: /\nSitemap: https://$domain/sitemap.xml\n")
    today = string(Dates.today())
    sitemap = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url><loc>https://$domain/</loc><lastmod>$today</lastmod></url>
      <url><loc>https://$domain/treasury-lane/</loc><lastmod>$today</lastmod></url>
      <url><loc>https://$domain/liquidity-matrix/</loc><lastmod>$today</lastmod></url>
      <url><loc>https://$domain/funding-posture/</loc><lastmod>$today</lastmod></url>
      <url><loc>https://$domain/verification/</loc><lastmod>$today</lastmod></url>
      <url><loc>https://$domain/docs/</loc><lastmod>$today</lastmod></url>
    </urlset>
    """
    write_text(joinpath(root, "sitemap.xml"), sitemap)
    write_text(joinpath(root, "404.html"), read(joinpath(root, "index.html"), String))
    return root
end

end
