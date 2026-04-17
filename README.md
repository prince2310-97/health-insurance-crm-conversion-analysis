# 🏥 Health Insurance CRM — Lead Conversion Analytics

A full-cycle CRM analytics project simulating a real-world health insurance sales pipeline using **Zoho CRM** exported data. It combines Python-based exploratory analysis with advanced SQL business intelligence to surface conversion insights, agent performance gaps, and revenue opportunities.

---

## 📁 Project Structure

```
crm-lead-conversion-analytics/
│
├── leads.csv                      # Raw Zoho CRM export (993 records, 67 columns)
├── leads_clean.csv                # Cleaned & feature-engineered dataset (12 columns)
├── lead_conversion_analysis.ipynb # Python EDA & visualization notebook
└── crm_business_queries.sql       # 10-section SQL analytics script
```

---

## 🎯 Business Problem

A health insurance company generates a significant number of leads through multiple channels but struggles with inconsistent policy conversions. The company lacked visibility into:

- Which leads convert and why
- Where drop-offs occur in the sales funnel
- How follow-up frequency impacts conversion
- Which agents, cities, and lead sources deliver the most revenue

---

## 📊 Dataset Overview

### Raw Data (`leads.csv`)
- **Source:** Zoho CRM export simulation
- **Records:** 993 leads, 67 columns
- **Intentional data quality issues introduced:** missing values, duplicates, inconsistent categoricals, and outliers — to simulate real-world CRM data challenges

### Cleaned Data (`leads_clean.csv`)
After preprocessing, 12 business-relevant columns are retained:

| Column | Description |
|---|---|
| `Lead ID` | Unique lead identifier |
| `Last Name` | Lead surname |
| `Lead Source` | Acquisition channel (Agent Referral, Website, Walk-in, etc.) |
| `Lead Status` | Funnel stage (Lead → Contacted → Quote Sent → Negotiation → Closed Won/Lost) |
| `Address - City` | City of residence (17 cities) |
| `Age` | Lead age in years |
| `Gender` | Male / Female |
| `Policy Type` | Individual Health / Family Floater / Senior Citizen / Critical Illness / Group Health |
| `Premium Amount` | Annual premium in INR (₹) |
| `Follow Up Count` | Total agent follow-up touches |
| `Agent Name` | Assigned agent (10 agents) |
| `Lead Date` | CRM entry date |

> **Conversion Definition:** `Lead Status = 'Closed Won'` — Overall rate ≈ **27%**

---

## 🐍 Python Analysis (`lead_conversion_analysis.ipynb`)

The notebook follows a structured 10-step analytical workflow:

### Step-by-Step Workflow

| Step | Description |
|---|---|
| 1 | Business problem definition & dataset overview |
| 2 | Data loading from Zoho CRM export |
| 3 | Data structure exploration (shape, dtypes, nulls) |
| 4 | Column selection — retaining 12 business-relevant fields |
| 5 | Data cleaning (duplicates, missing values, categorical standardization) |
| 6 | Conversion rate analysis & lead source comparison |
| 7 | Sales funnel distribution analysis |
| 8 | Follow-up impact analysis & root cause identification |
| 9 | Agent performance analysis (absolute & normalized) |
| 10 | Time-series (monthly) conversion trend analysis |

### Key Python Findings

- **Overall Conversion Rate:** ~27%
- **Best Lead Sources:** Agent Referral (~44%), Direct Agent (~40%), Walk-in (~33%)
- **Weakest Sources:** Website (~14%), Social Media (~19%), Google Ads (~19%)
- **Top Age Segment:** 30–45 years (~32% conversion)
- **Optimal Follow-up Range:** 3–6 interactions
- **Monthly Conversion Range:** 20% – 37% (seasonality detected)
- **Top Agents:** Rajesh Sharma, Amit Verma (>33% conversion rate)
- **Lowest Performers:** Suresh Pillai, Sneha Reddy (~13–21%)

---

## 🗄️ SQL Analytics (`crm_business_queries.sql`)

10 production-grade SQL sections targeting different business stakeholders. All queries run on the `leads_clean` table inside the `insurance_crm` database.

### Section Overview

| # | Section | Business Audience |
|---|---|---|
| 1 | Revenue Pipeline Risk — Premium ₹ stuck at each funnel stage | CFO / Sales Head |
| 2 | Lead Source Revenue Quality Matrix — Volume vs Value vs Conversion | Marketing Manager |
| 3 | Agent Efficiency Scorecard — CTE-based multi-KPI ranking | Agent Manager |
| 4 | City-Level Market Penetration — Potential vs Actual Conversion | Regional Sales Head |
| 5 | Follow-Up Sweet Spot Analysis — Diminishing returns quantification | Operations / CRM Team |
| 6 | Policy × Source Conversion Matrix — Channel-product alignment | Product & Marketing |
| 7 | Monthly Lead Cohort Analysis — Cohort quality vs timing | Forecasting / Finance |
| 8 | Policy Type × Age Segment Revenue Optimization | Product / Upsell Teams |
| 9 | Lost Revenue Forensics — Closed Lost post-mortem by agent | Sales Head |
| 10 | Winner's Profile Scoring — Active pipeline lead prioritization | Sales Manager (Daily) |

### SQL Techniques Used

- Window functions: `DENSE_RANK()`, `LAG()`, `SUM() OVER()`, `AVG() OVER()`
- Common Table Expressions (CTEs) with 3-layer agent scorecard
- `CROSS JOIN` for profile scoring
- Conditional aggregation with `CASE WHEN`
- `NULLIF()` for division safety
- `DATE_FORMAT()` for cohort bucketing
- `HAVING` clause filtering on thin combinations
- Revenue-per-touch diminishing returns quantification

---

## 🔍 Key Business Insights

### Revenue & Funnel
- Negotiation-stage leads carry **above-average premium** but die at the final step — a **closing skill problem**, not a lead quality problem
- Closed Lost leads represent permanently destroyed pipeline revenue — quantified in INR, not just headcount

### Channels
- **Revenue Yield per Lead** (not lead volume) is the correct channel evaluation metric
- Agent Referral and Direct Agent consistently outperform digital channels on revenue quality
- Senior Citizen and Critical Illness policies require relationship-based selling — digital channels underperform for these products

### Agents
- Top agents achieve nearly **2× the conversion rate** of low performers
- A multi-dimensional scorecard classifies agents as: `ELITE`, `VOLUME CLOSER`, `QUALITY HUNTER`, or `CRITICAL`
- 2–3 agents typically account for a disproportionate share of destroyed pipeline revenue

### Geography
- Cities are classified into: **STAR MARKET**, **VOLUME MARKET**, **OPPORTUNITY MARKET**, or **CHALLENGED MARKET**
- Opportunity Markets (high premium potential, low conversion) signal execution gaps, not poor lead quality

### Lead Scoring
- A 5-dimension winner's profile scores every active pipeline lead (Tier 1–5)
- Tier 1 leads match: top source + top policy + optimal follow-up + prime age + above-average premium

---

## 💡 Business Recommendations

| Area | Recommendation | Expected Impact |
|---|---|---|
| Follow-up Strategy | Enforce 3–6 follow-up rule; auto-flag leads at 9+ touches | +5–8% conversion |
| Closing Process | Structured closing script for Negotiation stage | +4–6% conversion |
| Channel Budget | Shift from CPL to CPR (Cost Per Revenue) as the KPI | Higher ROI per ₹ spent |
| Lead Scoring | Deploy Section 10 winner's profile as daily CRM prioritization report | Reduced agent time waste |
| Agent Coaching | Monthly loss forensics review; replicate top-agent best practices | Reduced revenue destruction |
| Upsell | Re-contact 35–44 Individual Health buyers with Family Floater pitch | +1.5–2× premium per deal |
| City Strategy | Prioritize Opportunity Market cities with targeted agent reassignment | +₹10L–₹30L per city |

---

## 🚀 Skills Demonstrated

**Python / Data Analysis**
- Pandas data cleaning pipeline (nulls, duplicates, type standardization)
- Exploratory Data Analysis (EDA)
- Customer segmentation & cohort analysis
- Matplotlib visualizations

**SQL / Business Intelligence**
- Advanced SQL with CTEs and window functions
- Revenue pipeline modeling
- Multi-dimensional agent scorecards
- Cohort retention analysis
- Rule-based lead scoring engine

**Business Acumen**
- CRM funnel interpretation (Zoho CRM simulation)
- Sales performance diagnostics
- Revenue forensics & opportunity gap analysis
- Stakeholder-specific output framing (CFO vs. Sales Head vs. Marketing)

---

## 🛠️ Tech Stack

| Tool | Usage |
|---|---|
| Python 3.x | EDA, data cleaning, visualization |
| Pandas | Data manipulation |
| Matplotlib | Charts & graphs |
| MySQL | SQL analytics (DATE_FORMAT compatible) |
| Zoho CRM | Source system simulation |
| Jupyter Notebook | Interactive analysis environment |

---

## 🗂️ How to Run

### Python Notebook
```bash
pip install pandas matplotlib jupyter
jupyter notebook lead_conversion_analysis.ipynb
```

### SQL Queries
```sql
-- Set up the database
CREATE DATABASE insurance_crm;
USE insurance_crm;

-- Import leads_clean.csv into the leads_clean table
-- Then run crm_business_queries.sql section by section
SOURCE crm_business_queries.sql;
```

> The SQL script is written for **MySQL**. For PostgreSQL, replace `DATE_FORMAT(date, '%Y-%m')` with `TO_CHAR(date, 'YYYY-MM')`. For SQL Server, use `FORMAT(date, 'yyyy-MM')`.

---

## 📌 Notes

- The dataset is **synthetically generated** but designed to mirror real Zoho CRM data challenges
- Intentional data quality issues (missing values, duplicates, outliers) were introduced to simulate a realistic preprocessing scenario
- All monetary values are in **Indian Rupees (₹)**
- The SQL scoring model in Section 10 is designed to be implemented as a **calculated field in Zoho CRM** for daily automated lead prioritization

---

### Project Status
This project is **in progress**. Additional visualizations and insights will be added shortly.


*CRM & Sales Analytics Project | Health Insurance Lead Conversion | FY 2023–24*
