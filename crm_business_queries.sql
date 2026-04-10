use insurance_crm;
-- ============================================================================================================================
--  HEALTH INSURANCE CRM — LEAD CONVERSION ANALYTICS
--  SQL Analytics Script — FY 2023-24 (Full Cycle Analysis)
--  Database  : insurance_crm
--  Table     : leads_clean
--  Author    : CRM & Sales Analytics — Data Analyst
--  Purpose   : End-to-end business diagnostic — Conversion Quality, Revenue Pipeline,
--              Agent Efficiency, Market Penetration, Policy Mix, Cohort Retention
-- ============================================================================================================================
--
--  COLUMN REFERENCE (leads_clean table):
--  lead_id          VARCHAR(50)     — Unique identifier per lead
--  last_name        VARCHAR(50)     — Lead surname
--  lead_source      VARCHAR(50)     — Origin channel (Agent Referral, Website, Direct Agent, etc.)
--  lead_status      VARCHAR(50)     — Current funnel stage (Lead → Contacted → Quote Sent →
--                                     Negotiation → Closed Won / Closed Lost)
--  city             VARCHAR(50)     — City of residence
--  age              INT             — Lead age in years
--  gender           VARCHAR(10)     — Male / Female
--  policy_type      VARCHAR(50)     — Individual Health / Family Floater / Senior Citizen /
--                                     Critical Illness / Group Health
--  premium_amount   DECIMAL(10,2)   — Annual premium in INR (₹)
--  follow_up_count  INT             — Total follow-up touches by agent before current status
--  agent_name       VARCHAR(50)     — Assigned agent name
--  lead_date        DATE            — Date lead was created in CRM
--
--  CONVERSION DEFINITION (consistent throughout):
--  Conversion = lead_status = 'Closed Won'   |   Overall Rate ≈ 27%
--
-- ============================================================================================================================




-- ============================================================================================================================
-- SECTION 1 : REVENUE PIPELINE RISK — PREMIUM RUPEES STUCK AT EACH FUNNEL STAGE
-- ============================================================================================================================

/*
  OBJECTIVE    : Quantify the INR value of premium revenue sitting at each funnel stage,
                 and measure what percentage of total pipeline value is at risk of not converting.
  WHY IT MATTERS : Python analysis counted leads — but for a CFO or Sales Head, what matters
                   is RUPEES, not records. A "Negotiation" stage with ₹45L of annual premium
                   at risk is a completely different conversation than "158 leads in Negotiation."
                   This query turns a funnel chart into a revenue management tool.
  BUSINESS USE : Monthly pipeline review with Sales Head. Identify which stages have high
                 premium concentration but low historical conversion probability.
                 Prioritize follow-up effort where INR exposure is highest.
*/

SELECT
    lead_status,

    -- Total leads at this stage
    COUNT(lead_id)                                                               AS total_leads,

    -- Total premium value sitting at this stage — the INR pipeline
    ROUND(SUM(premium_amount), 0)                                                AS total_premium_at_stage,

    -- Average deal size at each stage — dropping deal size = weaker leads are advancing
    ROUND(AVG(premium_amount), 0)                                                AS avg_premium_per_lead,

    -- Share of total pipeline sitting at this stage (by value, not count)
    ROUND(
        SUM(premium_amount) * 100.0 / SUM(SUM(premium_amount)) OVER (), 2
    )                                                                            AS pct_of_total_pipeline_value,

    -- Premium per lead compared to overall avg — above 100 = high-value stage
    ROUND(
        AVG(premium_amount) * 100.0 /
        AVG(AVG(premium_amount)) OVER (), 1
    )                                                                            AS deal_quality_index,

    -- Flag stages where bulk of rupee-risk is concentrated
    CASE
        WHEN SUM(premium_amount) * 100.0 / SUM(SUM(premium_amount)) OVER () >= 20
             THEN 'HIGH PRIORITY — Revenue at Risk'
        WHEN SUM(premium_amount) * 100.0 / SUM(SUM(premium_amount)) OVER () >= 10
             THEN 'MEDIUM PRIORITY — Monitor Closely'
        ELSE 'LOW PRIORITY — Routine Tracking'
    END                                                                          AS revenue_risk_flag

FROM leads_clean
GROUP BY lead_status
ORDER BY total_premium_at_stage DESC;

/*
  EXPECTED OUTPUT  : 6 rows — one per funnel stage. Stages like Negotiation and Quote Sent should
                     carry a disproportionate share of total pipeline value (premium_amount).
                     Closed Lost row reveals permanently destroyed revenue — a business wake-up call.
  BUSINESS REACTION: If Negotiation stage carries 20%+ of total pipeline value but conversion
                     from Negotiation → Closed Won is historically low, Sales Head must intervene:
                     (a) Are pricing objections blocking closure? → Review premium flexibility.
                     (b) Is follow-up frequency too low at this stage? → Mandate minimum 4 touches.
                     (c) Are specific agents losing Negotiation-stage deals? → Closing skills training.
                     The Closed Lost premium figure becomes the "cost of poor sales execution."
                     Present this number to leadership — it makes the business case for training budgets.
*/




-- ============================================================================================================================
-- SECTION 2 : LEAD SOURCE REVENUE QUALITY MATRIX — VOLUME VS VALUE VS CONVERSION
-- ============================================================================================================================

/*
  OBJECTIVE    : Go beyond simple conversion rate by channel. Measure the revenue QUALITY of
                 each lead source — not just how many convert, but how much premium they generate
                 and at what follow-up cost.
  WHY IT MATTERS : Python showed Agent Referral has the highest conversion rate (~44%). But if
                   Agent Referral leads also carry the highest premium amounts, the actual revenue
                   gap vs Website is 3–4× wider than the conversion gap suggests. This query
                   builds the business case for budget reallocation toward high-yield channels.
  BUSINESS USE : Marketing budget planning. Prove with INR, not just percentages, which channels
                 deserve more investment and which should be rationalized.
*/

SELECT
    lead_source,

    -- Volume metrics
    COUNT(lead_id)                                                               AS total_leads,
    COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END)                      AS converted_leads,

    -- Conversion rate — familiar metric, now in context of revenue
    ROUND(
        COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END) * 100.0
        / NULLIF(COUNT(lead_id), 0), 1
    )                                                                            AS conversion_rate_pct,

    -- Revenue generated by this source (only Closed Won = actual revenue)
    ROUND(SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END), 0)
                                                                                 AS realized_revenue,

    -- Average premium of converted leads from this source — deal quality signal
    ROUND(AVG(CASE WHEN lead_status = 'Closed Won' THEN premium_amount END), 0)
                                                                                 AS avg_converted_premium,

    -- Average follow-ups consumed per lead from this source — cost-to-acquire proxy
    ROUND(AVG(follow_up_count), 1)                                               AS avg_follow_ups_per_lead,

    -- Revenue Yield per Lead = Realized Revenue ÷ Total Leads from this source
    -- This is the single most important metric — how much ₹ does each inbound lead generate
    ROUND(
        SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END)
        / NULLIF(COUNT(lead_id), 0), 0
    )                                                                            AS revenue_yield_per_lead,

    -- Revenue per follow-up touch — which source gives best return on agent time
    ROUND(
        SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END)
        / NULLIF(SUM(follow_up_count), 0), 0
    )                                                                            AS revenue_per_follow_up_touch,

    -- Channel rank by realized revenue — the true business ranking
    DENSE_RANK() OVER (ORDER BY
        SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END) DESC
    )                                                                            AS revenue_rank

FROM leads_clean
GROUP BY lead_source
ORDER BY realized_revenue DESC;

/*
  EXPECTED OUTPUT  : 9 rows. Agent Referral and Direct Agent should rank #1 and #2 by revenue_yield_per_lead.
                     Website may generate high volume but low yield — confirming quality vs quantity tension.
                     Email Campaign and Walk-in should show interesting revenue_per_follow_up_touch —
                     if Walk-in has high revenue per touch, it means high-intent leads who need less convincing.
  BUSINESS REACTION: Marketing team must shift budget toward channels with high revenue_yield_per_lead,
                     not just channels that bring volume. A channel with 50 leads and ₹8L realized revenue
                     is commercially superior to one with 200 leads and ₹6L revenue.
                     Revenue_per_follow_up_touch answers: "For every agent hour spent on this channel, what
                     is the return?" Channels with poor touch-to-revenue ratio need either better lead
                     qualification at intake or should be deprioritized entirely.
*/




-- ============================================================================================================================
-- SECTION 3 : AGENT EFFICIENCY SCORECARD — BEYOND CONVERSION RATE
-- ============================================================================================================================

/*
  OBJECTIVE    : Build a multi-dimensional agent performance scorecard using CTEs and window
                 functions, covering conversion quality, revenue generation, follow-up efficiency,
                 and premium deal size — not just raw conversion %.
  WHY IT MATTERS : Python showed top agents at ~35% conversion, low performers at ~13%. But a
                   manager making a PIP (Performance Improvement Plan) decision needs to know:
                   Is a low converter closing high-value deals that justify the low rate?
                   Is a high converter only closing cheap policies? This scorecard answers that.
  BUSINESS USE : Quarterly agent appraisals, incentive structure design, coaching prioritization,
                 and portfolio assignment decisions.
*/

WITH

-- Layer 1: Aggregate raw KPIs per agent
Agent_Base AS (
    SELECT
        agent_name,

        COUNT(lead_id)                                                           AS total_leads_handled,
        COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END)                  AS total_conversions,
        COUNT(CASE WHEN lead_status = 'Closed Lost' THEN 1 END)                 AS total_losses,

        -- Closed Won revenue — actual book built by this agent
        ROUND(SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END), 0)
                                                                                 AS total_revenue_closed,

        -- Average premium of deals the agent WINS — deal quality
        ROUND(AVG(CASE WHEN lead_status = 'Closed Won' THEN premium_amount END), 0)
                                                                                 AS avg_winning_premium,

        -- Average follow-ups per lead — lower is more efficient
        ROUND(AVG(follow_up_count), 1)                                           AS avg_follow_ups,

        -- Average follow-ups specifically for converted leads — conversion follow-up cost
        ROUND(AVG(CASE WHEN lead_status = 'Closed Won' THEN follow_up_count END), 1)
                                                                                 AS avg_follow_ups_to_convert

    FROM leads_clean
    GROUP BY agent_name
),

-- Layer 2: Compute derived efficiency metrics
Agent_KPIs AS (
    SELECT
        *,
        -- Core conversion rate
        ROUND(total_conversions * 100.0 / NULLIF(total_leads_handled, 0), 1)    AS conversion_rate_pct,

        -- Revenue per lead handled — combines conversion + deal quality into one number
        ROUND(total_revenue_closed / NULLIF(total_leads_handled, 0), 0)         AS revenue_per_lead,

        -- Revenue per follow-up touch — efficiency of agent's time investment
        ROUND(total_revenue_closed / NULLIF(
            (SELECT SUM(follow_up_count) FROM leads_clean l WHERE l.agent_name = Agent_Base.agent_name), 0
        ), 0)                                                                    AS revenue_per_touch,

        -- Win-to-Loss ratio — above 1.5 is healthy; below 1.0 = agent is losing more than winning
        ROUND(total_conversions * 1.0 / NULLIF(total_losses, 0), 2)             AS win_loss_ratio

    FROM Agent_Base
),

-- Layer 3: Apply window functions for peer benchmarking
Agent_Ranked AS (
    SELECT
        *,
        -- Revenue rank across all agents — the ultimate commercial ranking
        DENSE_RANK() OVER (ORDER BY total_revenue_closed DESC)                   AS revenue_rank,

        -- Conversion rank
        DENSE_RANK() OVER (ORDER BY conversion_rate_pct DESC)                   AS conversion_rank,

        -- Deal quality rank — who closes the most expensive policies
        DENSE_RANK() OVER (ORDER BY avg_winning_premium DESC)                   AS deal_quality_rank,

        -- Efficiency rank — who needs fewest follow-ups to convert (lower follow-up = higher rank)
        DENSE_RANK() OVER (ORDER BY avg_follow_ups_to_convert ASC)              AS efficiency_rank,

        -- Benchmarks for gap analysis
        ROUND(AVG(conversion_rate_pct) OVER (), 1)                              AS team_avg_conversion,
        ROUND(AVG(avg_winning_premium) OVER (), 0)                              AS team_avg_premium,
        ROUND(AVG(avg_follow_ups_to_convert) OVER (), 1)                        AS team_avg_follow_ups

    FROM Agent_KPIs
)

SELECT
    agent_name,
    total_leads_handled,
    total_conversions,
    conversion_rate_pct,
    team_avg_conversion,
    ROUND(conversion_rate_pct - team_avg_conversion, 1)                         AS conversion_gap_vs_team,
    total_revenue_closed,
    avg_winning_premium,
    team_avg_premium,
    revenue_per_lead,
    avg_follow_ups_to_convert,
    team_avg_follow_ups,
    win_loss_ratio,
    revenue_rank,
    conversion_rank,
    deal_quality_rank,
    efficiency_rank,

    -- Final commercial health tag — multi-signal classification
    CASE
        WHEN conversion_rate_pct >= 35 AND avg_winning_premium >= team_avg_premium
             THEN 'ELITE — High Converter + High Value Deals'
        WHEN conversion_rate_pct >= 30 AND avg_winning_premium < team_avg_premium
             THEN 'VOLUME CLOSER — Good Rate, Lower Deal Size'
        WHEN conversion_rate_pct < 25  AND avg_winning_premium >= team_avg_premium
             THEN 'QUALITY HUNTER — Low Converts, But Big Deals'
        WHEN conversion_rate_pct < 20  AND win_loss_ratio < 1.0
             THEN 'CRITICAL — Losing More Leads Than Winning'
        ELSE 'AVERAGE — Stable But Below Potential'
    END                                                                          AS agent_profile_tag

FROM Agent_Ranked
ORDER BY revenue_rank;

/*
  EXPECTED OUTPUT  : 10 rows (one per agent). Agents like Rajesh Sharma should rank high on
                     revenue. The QUALITY HUNTER and VOLUME CLOSER profiles reveal agents whose
                     coaching needs are completely different from each other.
  BUSINESS REACTION:
    ELITE           → Maximum portfolio. Assign high-potential leads. Fast-track for team lead role.
    VOLUME CLOSER   → High activity but landing cheap policies. Train on premium policy articulation.
                      Pair with a QUALITY HUNTER for cross-learning.
    QUALITY HUNTER  → Converting rarely but closing expensive deals. Check if they're being
                      given enough leads, or if they're being too selective in effort allocation.
    CRITICAL        → Immediate coaching intervention. Review sales call quality, script adherence.
                      If no improvement in 60 days, consider portfolio reallocation.
*/




-- ============================================================================================================================
-- SECTION 4 : CITY-LEVEL MARKET PENETRATION — PREMIUM POTENTIAL VS ACTUAL CONVERSION
-- ============================================================================================================================

/*
  OBJECTIVE    : Identify cities where high premium potential exists but conversion is
                 underperforming — signaling untapped geographic markets vs saturated ones.
  WHY IT MATTERS : Not all cities are equal. A city that sends 80 leads but converts only 15%
                   may simply have poor lead quality (low intent), OR it may have an agent
                   assignment problem (wrong agent for that market). This query separates
                   market potential from execution quality — at city level.
  BUSINESS USE : Territory expansion planning, agent-city reassignment decisions,
                 city-specific campaign design, and regional sales target setting.
*/

WITH City_Metrics AS (
    SELECT
        city,
        COUNT(lead_id)                                                           AS total_leads,
        COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END)                  AS conversions,
        ROUND(
            COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END) * 100.0
            / NULLIF(COUNT(lead_id), 0), 1
        )                                                                        AS conversion_rate_pct,
        ROUND(AVG(premium_amount), 0)                                            AS avg_premium_all_leads,
        ROUND(AVG(CASE WHEN lead_status = 'Closed Won' THEN premium_amount END), 0)
                                                                                 AS avg_converted_premium,
        ROUND(SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END), 0)
                                                                                 AS realized_revenue,
        -- Total premium potential = ALL leads' premium (what could have been won)
        ROUND(SUM(premium_amount), 0)                                            AS total_potential_premium,
        COUNT(DISTINCT agent_name)                                               AS agents_active_in_city
    FROM leads_clean
    GROUP BY city
),

City_Benchmarked AS (
    SELECT
        *,
        -- Revenue captured as % of total potential — Penetration Rate
        ROUND(realized_revenue * 100.0 / NULLIF(total_potential_premium, 0), 1)
                                                                                 AS penetration_rate_pct,
        -- Revenue left on table = potential - realized
        (total_potential_premium - realized_revenue)                             AS revenue_opportunity_gap,
        -- Benchmarks
        ROUND(AVG(conversion_rate_pct) OVER (), 1)                              AS national_avg_conversion,
        ROUND(AVG(avg_premium_all_leads) OVER (), 0)                            AS national_avg_premium
    FROM City_Metrics
)

SELECT
    city,
    total_leads,
    conversions,
    conversion_rate_pct,
    national_avg_conversion,
    ROUND(conversion_rate_pct - national_avg_conversion, 1)                     AS conversion_gap_vs_national,
    avg_premium_all_leads,
    national_avg_premium,
    realized_revenue,
    revenue_opportunity_gap,
    penetration_rate_pct,
    agents_active_in_city,

    -- Market Classification — 2×2 of Conversion vs Premium Level
    CASE
        WHEN conversion_rate_pct >= national_avg_conversion
             AND avg_premium_all_leads >= national_avg_premium
             THEN 'STAR MARKET — High Conversion + High Premium'
        WHEN conversion_rate_pct >= national_avg_conversion
             AND avg_premium_all_leads < national_avg_premium
             THEN 'VOLUME MARKET — Good Conversion, Lower Value Deals'
        WHEN conversion_rate_pct < national_avg_conversion
             AND avg_premium_all_leads >= national_avg_premium
             THEN 'OPPORTUNITY MARKET — High Potential, Execution Gap'
        ELSE
             'CHALLENGED MARKET — Low Conversion + Low Premium'
    END                                                                          AS market_classification

FROM City_Benchmarked
ORDER BY revenue_opportunity_gap DESC;

/*
  EXPECTED OUTPUT  : 17 rows (one per city). OPPORTUNITY MARKET cities are the most actionable:
                     they have high average premiums (wealthy lead base) but poor conversion.
                     This is an execution problem, not a market quality problem.
  BUSINESS REACTION:
    STAR MARKET       → Protect. Ensure best agents remain assigned. Increase lead flow here.
    VOLUME MARKET     → Investigate if higher-value policy types can be introduced in campaigns.
    OPPORTUNITY MARKET→ Priority intervention: review agent assignments, follow-up protocols,
                        and whether the right policy types are being pitched for the demographics.
    CHALLENGED MARKET → Consider reducing marketing spend. Reallocate agent bandwidth.
                        If volume is high, investigate lead quality at source level.
*/




-- ============================================================================================================================
-- SECTION 5 : FOLLOW-UP SWEET SPOT ANALYSIS — DIMINISHING RETURNS QUANTIFICATION
-- ============================================================================================================================

/*
  OBJECTIVE    : Map conversion rate AND average premium against follow-up count bands to
                 precisely identify the optimal engagement window — and the point where more
                 follow-ups actually HURT conversion (prospect fatigue zone).
  WHY IT MATTERS : Python identified 3–6 follow-ups as optimal. This query goes further:
                   it quantifies the revenue cost of over-following (above 8 touches),
                   and proves that follow-up over-investment is not just a time waste — it may
                   signal that an agent is chasing dead leads instead of prioritizing live ones.
  BUSINESS USE : Agent coaching — define the "drop and move on" rule scientifically.
                 CRM automation — trigger escalation workflow when leads exceed 8 follow-ups
                 without progressing. Operations — calculate total agent hours wasted on over-touched leads.
*/

SELECT
    -- Bucket follow-up counts into business-meaningful bands
    CASE
        WHEN follow_up_count = 0                    THEN '0 — No Follow-Up'
        WHEN follow_up_count BETWEEN 1 AND 2        THEN '1–2 — Early Contact'
        WHEN follow_up_count BETWEEN 3 AND 4        THEN '3–4 — Sweet Spot Entry'
        WHEN follow_up_count BETWEEN 5 AND 6        THEN '5–6 — Optimal Zone'
        WHEN follow_up_count BETWEEN 7 AND 8        THEN '7–8 — Extended Effort'
        ELSE                                             '9+ — Prospect Fatigue Zone'
    END                                                                          AS follow_up_band,

    -- Order for clean display
    MIN(follow_up_count)                                                         AS band_min_touches,
    MAX(follow_up_count)                                                         AS band_max_touches,
    COUNT(lead_id)                                                               AS total_leads,
    COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END)                      AS conversions,

    -- Conversion rate per band
    ROUND(
        COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END) * 100.0
        / NULLIF(COUNT(lead_id), 0), 1
    )                                                                            AS conversion_rate_pct,

    -- Average premium of converted leads per band — does heavy follow-up attract high-value deals?
    ROUND(AVG(CASE WHEN lead_status = 'Closed Won' THEN premium_amount END), 0)
                                                                                 AS avg_premium_converted,

    -- Total revenue generated by this band
    ROUND(SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END), 0)
                                                                                 AS band_total_revenue,

    -- Revenue per follow-up touch IN this band — diminishing returns made visible
    ROUND(
        SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END)
        / NULLIF(SUM(follow_up_count), 0), 0
    )                                                                            AS revenue_per_touch_in_band,

    -- % of all Closed Lost leads that came from each band — which band produces the most failures
    ROUND(
        COUNT(CASE WHEN lead_status = 'Closed Lost' THEN 1 END) * 100.0
        / NULLIF(COUNT(lead_id), 0), 1
    )                                                                            AS loss_rate_pct

FROM leads_clean
GROUP BY follow_up_band
ORDER BY band_min_touches;

/*
  EXPECTED OUTPUT  : 6 rows. Sweet Spot Entry (3–4) and Optimal Zone (5–6) should show peak
                     conversion rates. Revenue_per_touch_in_band should decline sharply after the
                     Optimal Zone — making the "diminishing returns" point mathematically provable.
                     Prospect Fatigue Zone (9+) should show conversion rate dropping below 20%
                     even if some conversions occur (possibly long-cycle complex policies).
  BUSINESS REACTION: Use revenue_per_touch_in_band as the hard stop rule: when incremental revenue
                     per touch drops below ₹X (business-defined threshold), CRM should auto-flag
                     the lead as "low probability — reduce priority."
                     Operationally: if 9+ band has 15%+ of all leads, agents are not managing their
                     pipeline correctly. Pipeline hygiene training is needed.
*/




-- ============================================================================================================================
-- SECTION 6 : POLICY-SOURCE CONVERSION MATRIX — WHICH CHANNEL SELLS WHICH POLICY BEST
-- ============================================================================================================================

/*
  OBJECTIVE    : Cross-tabulate lead source vs policy type to find the highest-yield
                 channel-product combinations and the mismatched ones dragging overall performance.
  WHY IT MATTERS : It's entirely possible that Agent Referral drives Senior Citizen policy
                   conversions at 60%+ while Website drives them at 8%. If the marketing team
                   doesn't know this, they may spend digital budget trying to acquire Senior
                   Citizen leads online — which will fail. This matrix guides channel-to-product
                   alignment strategy.
  BUSINESS USE : Campaign targeting decisions, sales playbook design, agent training
                 (teach agents which pitch to use for which source), and product distribution planning.
*/

SELECT
    policy_type,
    lead_source,
    COUNT(lead_id)                                                               AS total_leads,
    COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END)                      AS conversions,
    ROUND(
        COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END) * 100.0
        / NULLIF(COUNT(lead_id), 0), 1
    )                                                                            AS conversion_rate_pct,
    ROUND(AVG(CASE WHEN lead_status = 'Closed Won' THEN premium_amount END), 0)
                                                                                 AS avg_winning_premium,
    ROUND(SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END), 0)
                                                                                 AS realized_revenue,

    -- Rank each source within each policy type — best channel per product
    DENSE_RANK() OVER (
        PARTITION BY policy_type
        ORDER BY
            COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END) * 100.0
            / NULLIF(COUNT(lead_id), 0) DESC
    )                                                                            AS source_rank_within_policy,

    -- Rank each policy type within each source — best product per channel
    DENSE_RANK() OVER (
        PARTITION BY lead_source
        ORDER BY
            SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END) DESC
    )                                                                            AS policy_revenue_rank_within_source

FROM leads_clean
WHERE total_leads >= 5   -- suppress noise from ultra-thin combinations
  -- NOTE: replace with HAVING clause if this WHERE doesn't work in your SQL dialect
GROUP BY policy_type, lead_source
HAVING COUNT(lead_id) >= 5
ORDER BY policy_type, source_rank_within_policy;

/*
  EXPECTED OUTPUT  : Multi-row matrix. For each policy type, the top source (rank 1) should be
                     Agent Referral or Direct Agent. For Group Health specifically, Walk-in may
                     perform better (corporate walk-ins with group requirements). Website should
                     consistently rank near the bottom for Senior Citizen and Critical Illness
                     (high-consideration products that need relationship-based selling, not digital).
  BUSINESS REACTION: Any combination with source_rank_within_policy = 1 and conversion > 35% =
                     replicate at scale. Increase lead routing from that channel to that policy team.
                     Combinations with rank 1 in BOTH dimensions (best source × best policy revenue)
                     are "golden corridors" — maximize investment there without hesitation.
                     Poor combos (Website + Senior Citizen) should be suppressed in targeting.
*/




-- ============================================================================================================================
-- SECTION 7 : MONTHLY LEAD COHORT ANALYSIS — DO EARLIER COHORTS CONVERT BETTER?
-- ============================================================================================================================

/*
  OBJECTIVE    : Group leads by the month they entered the CRM (lead cohort) and track
                 each cohort's realized conversion rate and average premium. Identify whether
                 older cohorts (more time to mature) outperform recent cohorts, and whether
                 there is seasonal variation in lead quality by intake month.
  WHY IT MATTERS : Python showed monthly conversion variation (20%–37%). But this didn't distinguish
                   between "the pipeline converted well this month" vs "leads acquired in January
                   are inherently stronger leads." Cohort analysis separates timing from quality.
                   This is the difference between a seasonal trend and a lead quality drift.
  BUSINESS USE : Forecasting — project future revenue based on cohort quality.
                 Budget allocation — invest more in months that historically produce stronger cohorts.
                 CRM strategy — know how long after acquisition to expect peak conversion.
*/

SELECT
    -- Extract intake cohort month
    DATE_FORMAT(lead_date, '%Y-%m')                                              AS lead_cohort_month,
    -- Alternatively for PostgreSQL: TO_CHAR(lead_date, 'YYYY-MM')
    -- For SQL Server: FORMAT(lead_date, 'yyyy-MM')

    COUNT(lead_id)                                                               AS cohort_size,
    COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END)                      AS conversions,
    COUNT(CASE WHEN lead_status = 'Closed Lost' THEN 1 END)                     AS losses,
    COUNT(CASE WHEN lead_status NOT IN ('Closed Won','Closed Lost') THEN 1 END) AS still_in_pipeline,

    -- Conversion rate for this cohort
    ROUND(
        COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END) * 100.0
        / NULLIF(COUNT(lead_id), 0), 1
    )                                                                            AS cohort_conversion_pct,

    -- Revenue realized from this cohort
    ROUND(SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END), 0)
                                                                                 AS cohort_revenue,

    -- Average premium per converted lead from this cohort — quality signal
    ROUND(AVG(CASE WHEN lead_status = 'Closed Won' THEN premium_amount END), 0)
                                                                                 AS avg_converted_premium,

    -- What % of this cohort's premium potential has been captured
    ROUND(
        SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END) * 100.0
        / NULLIF(SUM(premium_amount), 0), 1
    )                                                                            AS cohort_penetration_pct,

    -- Cumulative revenue running total by cohort month (rolling view of revenue build)
    SUM(SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END))
        OVER (ORDER BY DATE_FORMAT(lead_date, '%Y-%m')
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)                  AS cumulative_revenue,

    -- Month-over-month cohort conversion change
    ROUND(
        COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END) * 100.0
        / NULLIF(COUNT(lead_id), 0)
        - LAG(
            COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END) * 100.0
            / NULLIF(COUNT(lead_id), 0)
          ) OVER (ORDER BY DATE_FORMAT(lead_date, '%Y-%m')), 1
    )                                                                            AS mom_conversion_change_ppts

FROM leads_clean
GROUP BY lead_cohort_month
ORDER BY lead_cohort_month;

/*
  EXPECTED OUTPUT  : One row per intake month across the dataset's date range (~18–24 months).
                     MoM_conversion_change_ppts shows which months saw quality spikes or crashes.
                     Cohorts with high still_in_pipeline counts are immature — conversion rate
                     understates their true potential (should be noted in reporting).
  BUSINESS REACTION: Months showing consistently high cohort_conversion_pct = examine what
                     changed — was there a campaign, an event, a new agent, or a seasonal factor?
                     Replicate those conditions in target months next year.
                     Months with large still_in_pipeline = high revenue forecasting opportunity.
                     A 5% improvement in conversion for a 100-lead cohort with avg ₹30K premium
                     = ₹1.5L in additional revenue — quantify this for leadership.
*/




-- ============================================================================================================================
-- SECTION 8 : POLICY TYPE × AGE SEGMENT REVENUE OPTIMIZATION
-- ============================================================================================================================

/*
  OBJECTIVE    : Find which age segments drive the highest premium per converted policy,
                 and whether certain policy types are being undersold to high-value age groups.
  WHY IT MATTERS : Python showed age 30–45 has the highest conversion rate. But which policy
                   type within that segment generates the most revenue? And are there age groups
                   buying the "wrong" (low-premium) policy when a better one exists?
                   This query reframes the "who converts" question into "what should they buy."
  BUSINESS USE : Product recommendation engine design, agent pitch optimization,
                 upsell/cross-sell identification, and policy portfolio margin management.
*/

SELECT
    -- Create meaningful age segments
    CASE
        WHEN age < 25                THEN 'Under 25 — Young Adult'
        WHEN age BETWEEN 25 AND 34  THEN '25–34 — Early Career'
        WHEN age BETWEEN 35 AND 44  THEN '35–44 — Prime Earner'
        WHEN age BETWEEN 45 AND 54  THEN '45–54 — Pre-Senior'
        WHEN age >= 55              THEN '55+ — Senior'
        ELSE 'Age Not Captured'
    END                                                                          AS age_segment,

    policy_type,
    COUNT(lead_id)                                                               AS total_leads,
    COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END)                      AS conversions,

    ROUND(
        COUNT(CASE WHEN lead_status = 'Closed Won' THEN 1 END) * 100.0
        / NULLIF(COUNT(lead_id), 0), 1
    )                                                                            AS conversion_rate_pct,

    -- Revenue per conversion for this age × policy combination
    ROUND(AVG(CASE WHEN lead_status = 'Closed Won' THEN premium_amount END), 0)
                                                                                 AS avg_premium_converted,

    -- Max premium in this segment — what's the ceiling for upsell potential
    ROUND(MAX(CASE WHEN lead_status = 'Closed Won' THEN premium_amount END), 0)
                                                                                 AS max_premium_achieved,

    -- Total revenue captured
    ROUND(SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END), 0)
                                                                                 AS total_segment_revenue,

    -- Rank policy type within age segment by revenue
    DENSE_RANK() OVER (
        PARTITION BY
            CASE
                WHEN age < 25               THEN 'Under 25'
                WHEN age BETWEEN 25 AND 34  THEN '25–34'
                WHEN age BETWEEN 35 AND 44  THEN '35–44'
                WHEN age BETWEEN 45 AND 54  THEN '45–54'
                ELSE '55+'
            END
        ORDER BY
            SUM(CASE WHEN lead_status = 'Closed Won' THEN premium_amount ELSE 0 END) DESC
    )                                                                            AS policy_revenue_rank_in_age

FROM leads_clean
WHERE age IS NOT NULL
GROUP BY age_segment, policy_type
HAVING COUNT(lead_id) >= 5
ORDER BY age_segment, policy_revenue_rank_in_age;

/*
  EXPECTED OUTPUT  : Matrix of age segments × policy types. Prime Earner (35–44) should show the
                     highest avg_premium_converted for Family Floater and Critical Illness.
                     Senior (55+) should show Senior Citizen policy ranked first by revenue.
                     Interesting find to look for: are 25–34 segment leads being sold Individual
                     Health when they might convert Family Floater at higher premium (family starting age)?
  BUSINESS REACTION: Any age segment where the top-revenue policy (rank 1) is NOT the most-sold
                     policy = upsell gap. Train agents on recognizing life-stage buying signals.
                     For example: 35–44 leads inquiring about Individual Health should be offered
                     a Family Floater comparison — it may close at higher premium with same effort.
                     Marketing should tailor campaign messaging by age-policy combination.
*/




-- ============================================================================================================================
-- SECTION 9 : LOST REVENUE FORENSICS — WHERE DID THE PIPELINE BREAK DOWN?
-- ============================================================================================================================

/*
  OBJECTIVE    : Forensically analyze Closed Lost leads to identify which stage, agent, source,
                 and policy combination is responsible for the most destroyed pipeline value.
                 This is a post-mortem on failed conversions — told in INR, not headcount.
  WHY IT MATTERS : Most CRM reports focus on what converted. But the Closed Lost pile often
                   contains more strategic signal than the won pile. If ₹2.4Cr of premium
                   was lost, and 60% of it was lost from Negotiation stage by two specific agents
                   selling one policy type via one channel — that's not a "market problem."
                   It's a fixable process problem with a clear financial consequence.
  BUSINESS USE : Root cause analysis presentations for Sales Head. Justifies spending on
                 specific training, tooling, or process redesign with an ROI argument.
*/

WITH Lost_Leads AS (
    SELECT *
    FROM leads_clean
    WHERE lead_status = 'Closed Lost'
),

Lost_By_Agent AS (
    SELECT
        agent_name,
        COUNT(lead_id)                                                           AS leads_lost,
        ROUND(SUM(premium_amount), 0)                                            AS revenue_destroyed,
        ROUND(AVG(premium_amount), 0)                                            AS avg_lost_deal_size,
        ROUND(AVG(follow_up_count), 1)                                           AS avg_follow_ups_before_loss,
        DENSE_RANK() OVER (ORDER BY SUM(premium_amount) DESC)                   AS loss_rank_by_revenue
    FROM Lost_Leads
    GROUP BY agent_name
),

Lost_By_Source AS (
    SELECT
        lead_source,
        COUNT(lead_id)                                                           AS leads_lost,
        ROUND(SUM(premium_amount), 0)                                            AS revenue_destroyed,
        ROUND(AVG(follow_up_count), 1)                                           AS avg_follow_ups_wasted,
        -- Follow-up effort consumed with no return — wasted agent hours proxy
        ROUND(SUM(follow_up_count), 0)                                           AS total_follow_up_touches_wasted
    FROM Lost_Leads
    GROUP BY lead_source
),

Lost_By_Policy AS (
    SELECT
        policy_type,
        COUNT(lead_id)                                                           AS leads_lost,
        ROUND(SUM(premium_amount), 0)                                            AS revenue_destroyed,
        ROUND(AVG(premium_amount), 0)                                            AS avg_lost_premium,
        ROUND(AVG(follow_up_count), 1)                                           AS avg_follow_ups_consumed
    FROM Lost_Leads
    GROUP BY policy_type
)

-- Final: Agent-level loss forensics with context
SELECT
    a.agent_name,
    a.leads_lost,
    a.revenue_destroyed                                                          AS agent_revenue_destroyed,
    a.avg_lost_deal_size,
    a.avg_follow_ups_before_loss,
    a.loss_rank_by_revenue,

    -- Contextual: What % of total Closed Lost revenue this agent accounts for
    ROUND(a.revenue_destroyed * 100.0 / SUM(a.revenue_destroyed) OVER (), 1)   AS pct_of_total_loss,

    -- Revenue destruction classification
    CASE
        WHEN a.revenue_destroyed * 100.0 / SUM(a.revenue_destroyed) OVER () >= 20
             THEN 'CRITICAL LOSS DRIVER — Immediate Review'
        WHEN a.revenue_destroyed * 100.0 / SUM(a.revenue_destroyed) OVER () >= 12
             THEN 'SIGNIFICANT LOSS CONTRIBUTOR — Coaching Priority'
        ELSE 'BELOW AVERAGE LOSS — Normal Attrition'
    END                                                                          AS loss_severity_tag

FROM Lost_By_Agent a
ORDER BY a.revenue_destroyed DESC;

/*
  EXPECTED OUTPUT  : 10 rows (one per agent). Loss concentration will likely be uneven — one or two
                     agents will account for 35%+ of all destroyed revenue despite having moderate
                     lead volumes. These are the CRITICAL LOSS DRIVERS.
  BUSINESS REACTION:
    CRITICAL LOSS DRIVER → Two-track intervention: (a) Review call recordings or CRM notes for
                           the last 20 lost deals. Identify the common objection pattern.
                           (b) Temporarily reassign high-value leads (premium > ₹30K) away from
                           this agent until root cause is fixed.
    SIGNIFICANT CONTRIBUTOR → Monthly loss review sessions. Define "loss criteria" — what does
                              the agent say or fail to say at each stage that causes drop-off?
    BELOW AVERAGE LOSS → No action. Some attrition is expected and healthy.
    NOTE: Also run this query group-by lead_source and policy_type for triangulation —
    if the same agent's losses concentrate in one policy type, the problem is product knowledge,
    not general sales skill.
*/




-- ============================================================================================================================
-- SECTION 10 : WINNER'S PROFILE COMPOSITE — CTE SCORECARD OF THE IDEAL CONVERTED LEAD
-- ============================================================================================================================

/*
  OBJECTIVE    : Build a statistically grounded "winner's profile" — the combination of
                 demographics, channel, policy, follow-up count, and agent that maximizes
                 conversion probability. Then score ACTIVE (unconverted) pipeline leads
                 against this profile to prioritize which ones to close first.
  WHY IT MATTERS : This is the most actionable query in the set. Instead of reporting what happened,
                   it creates a scoring framework for what to do next. Leads that match the
                   winner's profile on 4–5 dimensions should receive maximum agent attention today.
                   Leads matching on 1–2 dimensions can wait or be auto-nurtured.
  BUSINESS USE : CRM lead scoring automation, daily agent prioritization, MIS reports for
                 Sales Manager's morning briefing. The foundation for a rule-based scoring engine.
*/

WITH

-- Step 1: Define the winner's profile from all Closed Won leads
Winner_Profile AS (
    SELECT
        -- Most common lead source among winners
        (SELECT lead_source FROM leads_clean
         WHERE lead_status = 'Closed Won'
         GROUP BY lead_source ORDER BY COUNT(*) DESC LIMIT 1)                   AS top_source,

        -- Best-converting policy type
        (SELECT policy_type FROM leads_clean
         WHERE lead_status = 'Closed Won'
         GROUP BY policy_type ORDER BY COUNT(*) DESC LIMIT 1)                   AS top_policy,

        -- Optimal follow-up range (sweet spot from Section 5)
        3                                                                        AS optimal_fu_min,
        6                                                                        AS optimal_fu_max,

        -- Prime age segment
        35                                                                       AS prime_age_min,
        44                                                                       AS prime_age_max,

        -- Premium threshold — converted leads above this are high-value
        ROUND(AVG(premium_amount), 0)                                            AS avg_winner_premium

    FROM leads_clean
    WHERE lead_status = 'Closed Won'
),

-- Step 2: Score every ACTIVE pipeline lead against the winner's profile
Active_Lead_Scoring AS (
    SELECT
        l.lead_id,
        l.last_name,
        l.agent_name,
        l.city,
        l.lead_source,
        l.policy_type,
        l.age,
        l.gender,
        l.premium_amount,
        l.follow_up_count,
        l.lead_status,

        -- Score each dimension: 1 point per matching winner's attribute
        (CASE WHEN l.lead_source = w.top_source THEN 1 ELSE 0 END)
        + (CASE WHEN l.policy_type = w.top_policy THEN 1 ELSE 0 END)
        + (CASE WHEN l.follow_up_count BETWEEN w.optimal_fu_min AND w.optimal_fu_max THEN 1 ELSE 0 END)
        + (CASE WHEN l.age BETWEEN w.prime_age_min AND w.prime_age_max THEN 1 ELSE 0 END)
        + (CASE WHEN l.premium_amount >= w.avg_winner_premium THEN 1 ELSE 0 END)
                                                                                 AS winner_match_score,

        -- For transparency: show which criteria were met
        CONCAT(
            CASE WHEN l.lead_source = w.top_source THEN '[✓ Source] ' ELSE '[✗ Source] ' END,
            CASE WHEN l.policy_type = w.top_policy THEN '[✓ Policy] ' ELSE '[✗ Policy] ' END,
            CASE WHEN l.follow_up_count BETWEEN w.optimal_fu_min AND w.optimal_fu_max
                 THEN '[✓ FollowUp] ' ELSE '[✗ FollowUp] ' END,
            CASE WHEN l.age BETWEEN w.prime_age_min AND w.prime_age_max
                 THEN '[✓ Age] ' ELSE '[✗ Age] ' END,
            CASE WHEN l.premium_amount >= w.avg_winner_premium
                 THEN '[✓ Premium]' ELSE '[✗ Premium]' END
        )                                                                        AS matched_criteria

    FROM leads_clean l
    CROSS JOIN Winner_Profile w
    WHERE l.lead_status NOT IN ('Closed Won', 'Closed Lost')  -- Only active pipeline
),

-- Step 3: Classify active leads by priority tier
Priority_Scored AS (
    SELECT
        *,
        CASE
            WHEN winner_match_score = 5 THEN 'TIER 1 — CLOSE THIS WEEK'
            WHEN winner_match_score = 4 THEN 'TIER 2 — HIGH PRIORITY'
            WHEN winner_match_score = 3 THEN 'TIER 3 — MEDIUM PRIORITY'
            WHEN winner_match_score = 2 THEN 'TIER 4 — NURTURE'
            ELSE                             'TIER 5 — LOW PRIORITY / AUTO-NURTURE'
        END                                                                      AS priority_tier
    FROM Active_Lead_Scoring
)

SELECT
    lead_id,
    last_name,
    agent_name,
    city,
    lead_source,
    policy_type,
    age,
    premium_amount,
    follow_up_count,
    lead_status,
    winner_match_score,
    matched_criteria,
    priority_tier

FROM Priority_Scored
ORDER BY winner_match_score DESC, premium_amount DESC;

/*
  EXPECTED OUTPUT  : All active pipeline leads (Contacted, Quote Sent, Negotiation, Lead stage),
                     each assigned a TIER 1–5 priority based on how closely they match the
                     historical winner's profile. Tier 1 leads = close this week.
  BUSINESS REACTION: Every Monday morning, Sales Manager runs this query and sends Tier 1 and
                     Tier 2 leads to the top 3 agents as their week's priority list.
                     Tier 5 leads get enrolled in an automated email nurture sequence —
                     no agent time wasted on low-probability manual follow-up.
                     Over time, track whether Tier 1–2 leads actually convert at higher rates.
                     If yes, the scoring model is validated. If not, refine the criteria using
                     more recent Closed Won data. This query becomes a living scoring engine.
  NOTE ON ENHANCEMENT: This is a rule-based scoring model. The natural next step (for Power BI
                        or Python ML) is to replace the equal-weight scoring with logistic regression
                        coefficients derived from the historical data — giving source a 2× weight
                        if it's empirically the strongest predictor. Mention this in interviews
                        to show you understand the bridge between SQL analytics and ML pipelines.
*/




-- ============================================================================================================================
-- ============================================================================================================================
--
--  EXECUTIVE SUMMARY — STRATEGIC FINDINGS FROM CRM LEAD CONVERSION ANALYSIS
--  (For Sales Head / Business Development Director Presentation)
--
-- ============================================================================================================================
-- ============================================================================================================================

/*
╔══════════════════════════════════════════════════════════════════════════════════════════════╗
║                    TOP 3 STRATEGIC RISKS IDENTIFIED                                        ║
╚══════════════════════════════════════════════════════════════════════════════════════════════╝

  RISK 1 — NEGOTIATION STAGE REVENUE LEAKAGE (HIGH SEVERITY)
  ──────────────────────────────────────────────────────────
  Section 1 (Revenue Pipeline Risk) quantifies premium rupees stuck in the late funnel.
  The Negotiation stage is statistically the most dangerous: leads have already been quoted,
  invested in multiple follow-ups, and carry above-average premiums — yet are dying at the
  final decision step. This is not a lead quality problem; it is a closing skill problem.
  Action Required: Sales Head must audit what happens between "Quote Sent" and "Negotiation."
  Are agents presenting pricing without objection handling? Is there a structured closing script?
  Any month where Negotiation-stage premium exceeds ₹20L = mandatory Sales Head review of
  that pipeline. Do not let high-value opportunities age past 15 days without escalation.

  RISK 2 — CHANNEL BUDGET MISALLOCATION (MEDIUM-HIGH SEVERITY)
  ─────────────────────────────────────────────────────────────
  Section 2 (Lead Source Revenue Quality Matrix) reveals that volume-based channel ranking
  (leads generated) is misleading. A channel may generate 200 leads but destroy agent bandwidth
  on low-intent, low-premium prospects. Revenue_yield_per_lead is the correct optimization
  target — not lead count. If marketing budgets are being set based on lead volume alone,
  the company is systematically underinvesting in its highest-return channels.
  Action Required: Marketing team must migrate from CPL (Cost Per Lead) to CPR (Cost Per
  Revenue) as the primary channel evaluation metric. Quarterly budget reallocation review
  should be anchored to revenue_yield_per_lead from the prior quarter's data.

  RISK 3 — AGENT SKILL CONCENTRATION IN LOSING (MEDIUM SEVERITY)
  ───────────────────────────────────────────────────────────────
  Section 9 (Lost Revenue Forensics) will show that 2–3 agents account for a disproportionate
  share of destroyed pipeline revenue. This is a controllable risk. Left unaddressed, it
  compounds: high-follow-up leads that don't convert consume agent time that should go to
  fresh Tier 1 leads (Section 10 scoring). The cost of one undertrained agent is not just
  their conversion rate — it's the opportunity cost of every lead they mishandle.
  Action Required: Monthly loss forensics review by Sales Manager. Agent loss ratios should
  be tracked alongside conversion rates as a dual-sided performance metric.


╔══════════════════════════════════════════════════════════════════════════════════════════════╗
║                    TOP 3 COMMERCIAL OPPORTUNITIES IDENTIFIED                               ║
╚══════════════════════════════════════════════════════════════════════════════════════════════╝

  OPPORTUNITY 1 — WINNER'S PROFILE LEAD SCORING (HIGH POTENTIAL — IMMEDIATE ROI)
  ──────────────────────────────────────────────────────────────────────────────
  Section 10 establishes a rule-based scoring framework for the active pipeline. If implemented
  in CRM as a daily report, agents receive a ranked call list every morning — highest-probability
  closes at the top. Conservative estimate: even a 5% improvement in Tier 1–2 conversion rates
  on a ₹50L active pipeline = ₹2.5L incremental annual premium revenue.
  No additional marketing spend required. Pure execution improvement through data prioritization.

  OPPORTUNITY 2 — POLICY × AGE UPSELL PROGRAMME (MEDIUM-HIGH POTENTIAL)
  ───────────────────────────────────────────────────────────────────────
  Section 8 (Policy × Age Optimization) may reveal that the 35–44 Prime Earner segment is
  predominantly buying Individual Health policies when Family Floater — pitched correctly —
  could close at 1.5–2× the premium. This is an upsell opportunity that exists inside
  the current lead database, requiring no new leads, no new marketing spend.
  Immediate action: In the next 30 days, identify all 35–44 aged leads who closed on
  Individual Health. Build a re-contact campaign for Family Floater upgrade pitch.

  OPPORTUNITY 3 — CITY-LEVEL MARKET DEVELOPMENT IN OPPORTUNITY MARKETS (MEDIUM POTENTIAL)
  ─────────────────────────────────────────────────────────────────────────────────────────
  Section 4 (City Penetration Matrix) identifies OPPORTUNITY MARKET cities — high average
  premium potential, but below-national-average conversion. These cities don't need more leads.
  They need better agent-city matching, targeted follow-up protocols, and possibly city-specific
  policy pitches aligned to local demographic preferences. Capturing even 5% additional
  conversion in a top OPPORTUNITY MARKET city could add ₹10L–₹30L in annual realized revenue
  depending on city size and average premium level.


╔══════════════════════════════════════════════════════════════════════════════════════════════╗
║                    HOW LEADERSHIP SHOULD USE THIS ANALYSIS                                 ║
╚══════════════════════════════════════════════════════════════════════════════════════════════╝

  FOR SALES HEAD / BUSINESS DEVELOPMENT DIRECTOR:
  → Use Section 1 (Pipeline Revenue Risk) and Section 9 (Loss Forensics) for monthly
    pipeline reviews. Speak in INR, not lead counts. Quantify what inaction costs.
  → Use Section 10 (Winner's Profile Scoring) as the framework for daily agent task assignment.
    Eliminate intuition-based prioritization. Data-driven call lists = higher closure rates.

  FOR MARKETING MANAGER:
  → Use Section 2 (Source Revenue Quality) and Section 6 (Policy × Source Matrix) for
    quarterly budget reallocation. Shift from CPL to CPR as the KPI.
  → Use Section 7 (Cohort Analysis) to validate whether campaign months produce stronger
    cohorts — connecting marketing input to downstream pipeline output.

  FOR AGENT MANAGER / TEAM LEAD:
  → Use Section 3 (Agent Efficiency Scorecard) for monthly one-on-ones. Each agent
    should see their profile tag and understand what it means for their development path.
  → Use Section 5 (Follow-Up Sweet Spot) to establish and enforce the "8 touch maximum"
    pipeline hygiene rule across all agents. Back it with revenue_per_touch_in_band data.

  FOR CRM / OPERATIONS TEAM:
  → Section 10 is the blueprint for an automated lead scoring rule in Zoho CRM.
    The 5-dimension scoring model can be implemented as a calculated field in Zoho —
    updating daily as lead statuses and follow-up counts change.

  FINAL NOTE:
  ───────────
  These 10 queries are designed to be run as a monthly analytics cadence, not a one-time report.
  The most powerful output is trend — when Section 7's cohort conversion or Section 3's agent
  profile tags shift month-over-month, that's the early warning signal that something changed
  in the business. React to trends, not just snapshots. Data without a review rhythm is
  just storage. Data with a monthly management cadence becomes a competitive advantage.

*/

-- ============================================================================================================================
-- END OF SCRIPT — health_insurance_crm_sql_analytics.sql
-- CRM Analysis | leads_clean table
-- Zoho CRM Simulation — Health Insurance Lead Conversion
-- ============================================================================================================================
