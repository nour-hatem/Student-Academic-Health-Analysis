<div align="center">

<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&size=28&duration=3000&pause=1000&color=00D9FF&center=true&vCenter=true&width=700&lines=NTI+Academic+Success+%26+Intervention;Student+Academic+Health+Analysis;SQL+%E2%86%92+Python+%E2%86%92+Power+BI" alt="Typing SVG" />

<br/>

![Python](https://img.shields.io/badge/Python-3.12-00D9FF?style=for-the-badge&logo=python&logoColor=white&labelColor=0D1117)
![SQL Server](https://img.shields.io/badge/SQL_Server-2025-7B2FBE?style=for-the-badge&logo=microsoftsqlserver&logoColor=white&labelColor=0D1117)
![Power BI](https://img.shields.io/badge/Power_BI-Dashboard-00D9FF?style=for-the-badge&logo=powerbi&logoColor=white&labelColor=0D1117)
![Jupyter](https://img.shields.io/badge/Jupyter-Notebook-7B2FBE?style=for-the-badge&logo=jupyter&logoColor=white&labelColor=0D1117)

<br/>

> **Graduation Project — DEPI x NTI Data Analysis Track**  
> A full end-to-end data analysis pipeline covering 12,156 students across 5 grade levels.  
> From raw CSV files to a 6-page interactive Power BI dashboard.

</div>

---

## Pipeline

```
Raw CSVs  ──▶  SQL Server (Storytelling)  ──▶  Python (Cleaning)  ──▶  Power BI (Dashboard)
   5 files          storytelling.sql             education_cleaning.ipynb     Final Education.pbix
```

---

## Dataset Overview

| Table | Rows | Description |
|---|---|---|
| `students.csv` | 12,156 | Student profiles across Grade 1–5 |
| `attendance.csv` | 364,680 | Daily attendance per subject |
| `homework.csv` | 60,780 | Assignment status and guardian signatures |
| `performance.csv` | 36,468 | Exam scores and homework completion rates |
| `teacher_parent_communication.csv` | 24,312 | Message logs between school and parents |

**Period:** March 2024 – March 2025  
**Audience:** ENG. DONIA — Data Analysis Evaluation Committee

---

## Phase 1 — SQL Storytelling

**File:** `storytelling.sql`

Six analytical chapters written as a narrative, not just queries. Each chapter answers a business question and documents every data quality issue found.

```
Chapter 1 │ Who are the students?          →  population & grade distribution
Chapter 2 │ Are they showing up?           →  attendance patterns & trends
Chapter 3 │ Are they doing their work?     →  homework compliance & guardian impact
Chapter 4 │ Are they performing?           →  exam scores & subject breakdown
Chapter 5 │ Are parents in the loop?       →  communication volume & silent students
Chapter 6 │ Who needs intervention now?    →  at-risk student profile (cross-table)
```

**Data quality issues flagged in SQL (fixed in Python):**

| Column | Issue |
|---|---|
| `students.Date_of_Birth` | Mixed ISO and US date formats |
| `attendance.Attendance_Status` | Inconsistent casing + `absnt` typo |
| `homework.Status` | Emoji encoding mixed with text values |
| `homework.Guardian_Signature` | Imported as BIT — blank ≠ NULL |
| `performance.Homework_Completion_%` | `-5` invalid values + mixed `%` suffix |

---

## Phase 2 — Python Cleaning

**File:** `education_cleaning.ipynb`

```
01  Setup
02  Load Data
03  Clean — students        date format unification, Age feature, Grade_Num ordinal
04  Clean — attendance      status normalization, ABSNT → ABSENT merge
05  Clean — homework        emoji/text mapping → Done | Not Done | Pending
06  Clean — performance     % suffix strip, -5 → NaN, subject-level median imputation
07  Clean — communication   date parsing, Month extraction
08  Validation              referential integrity check across all tables
09  Near-Duplicate Flags    column-level audit per dataframe
10  Feature Engineering     Attendance_Rate_%, HW_Completion_%, Avg_Exam_Score,
                            Missed_Assignments, Comm_Count, Is_At_Risk, Score_Band
11  Drop Unused Columns     Emergency_Contact, Date_of_Birth, Year, Assignment_Name,
                            Teacher_Comments, Message_Content
12  Final Checks            shape, dtypes, null counts per table
13  Export                  5 clean CSVs → data/clean/
```

**Key engineering decisions:**

- `Homework_Completion_%` nulls → subject-level median (not global — avoids cross-subject bias)
- `Guardian_Signature` nulls → `False` (no evidence of sign-off = treat as unsigned)
- `Is_At_Risk` flag = Attendance < 20% AND Avg Score < 60 AND Missed Assignments > 3

---

## Phase 3 — Power BI Dashboard

**File:** `Final Education.pbix`  
**Pages:** 6

<table>
<tr>
<td width="50%">

**Page 1 — Executive Summary**
- Total Enrollment, Avg Score, At-Risk Count
- Attendance Rate, HW Completion Rate
- Score Band donut + At-Risk by Grade
- Monthly Attendance Trend

</td>
<td width="50%">

**Page 2 — Attendance Analysis**
- Attendance / Absence / Late / Left Early KPIs
- Absence & Tardiness by Subject
- Status Distribution by Subject
- Avg Attendance Rate by Grade

</td>
</tr>
<tr>
<td>

**Page 3 — Homework & Engagement**
- Pending Rate, Missed Rate, Completion Rate
- Completion Status donut (Done / Not Done / Pending)
- Completion Rate per Subject
- Grade Feedback distribution

</td>
<td>

**Page 4 — Academic Performance**
- Score Range 40–110, Failing Rate, High Achievers
- Student Count by Performance Band
- Avg Score by Subject and Grade Level
- Score distribution histogram

</td>
</tr>
<tr>
<td>

**Page 5 — Parent Communication**
- Communication Volume, Silent Students count
- Message Type split (Teacher / Parent / Automated)
- Silent Students by Grade
- Communication Volume Trend

</td>
<td>

**Page 6 — At-Risk Intervention**
- Avg Score, Avg Attendance, At-Risk % for flagged cohort
- Scatter: Attendance vs Score (At-Risk vs Safe)
- Full at-risk student table with all risk dimensions

</td>
</tr>
</table>

---

## Key Findings

```
12,156   total students across 5 balanced grade levels (~20% each)

 2,000   at-risk students flagged (12.41% of school)
         criteria: attendance < 20% AND exam avg < 60 AND missed assignments > 3

 1,644   students with zero parent communication records (13.5%)
         Grade 1 has the highest silent rate at 14.73%

25.12%   true presence rate — students are physically present only 1 in 4 sessions
         ABSENT + ABSNT combined equals the same rate as PRESENT

  ~33%   homework not completed — 1 in 3 assignments never submitted
         Science has the lowest completion rate across all subjects

 74.96   school average exam score across all subjects and grades
         score range: 40 – 110 (full valid range, no invalid entries)
```

---

## Repo Structure

```
Education/
│
├── data/
│   ├── raw/                   original CSV files
│   └── clean/                 cleaned outputs from Python phase
│
├── storytelling.sql           SQL Server — Phase 1
├── education_cleaning.ipynb   Python — Phase 2
└── Final Education.pbix       Power BI — Phase 3
```

---

<div align="center">
  
[![Portfolio](https://img.shields.io/badge/Portfolio-nourhatem.wep.app-00D9FF?style=flat-square&labelColor=0D1117)](https://nourhatem.web.app)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-nour--hatem---7B2FBE?style=flat-square&logo=linkedin&logoColor=white&labelColor=0D1117)](https://linkedin.com/in/nour-hatem-)

</div>
