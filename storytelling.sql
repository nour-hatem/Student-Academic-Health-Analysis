-- ============================================================
-- PROJECT   : Student Academic Health Analysis
-- AUDIENCE  : Data Analysis Evaluation Committee ( ENG. DONIA )
-- OBJECTIVE : Tell the full story of 12,156 students across
--             5 grade levels using attendance, homework,
--             performance, and parent communication data
-- PERIOD    : March 2024 - March 2025
-- TECH STACK: SQL Server -> Python (cleaning) -> Power BI
-- NOTE      : Data quality issues are flagged in comments.
--             All fixes will be applied in the Python phase.
--             UPPER() and TRIM() are used here only to ensure
--             query accuracy on dirty data.
-- ============================================================

USE EducationDB;

-- ============================================================
-- CHAPTER 1: WHO ARE THE STUDENTS?
-- Before we analyze behavior, we understand the population.
-- ============================================================

-- Grade-level distribution: are we dealing with a balanced school?
SELECT
    Grade_Level,
    COUNT(*)                                             AS Total_Students,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS Pct_of_School
FROM students
GROUP BY Grade_Level
ORDER BY Grade_Level;

/*
OUTPUT:
Grade_Level  Total_Students  Pct_of_School
Grade 1      2383            19.60
Grade 2      2400            19.74
Grade 3      2447            20.13
Grade 4      2454            20.19
Grade 5      2472            20.34

INSIGHT:
The school has a near-perfectly balanced population across all 5 grades,
each holding roughly 20% of the 12,156 total students.
This means no single grade is over- or under-represented,
and any performance gap we find later cannot be blamed on sample size.
*/

-- DATA QUALITY ISSUE: Date_of_Birth has two inconsistent formats.
-- 10,951 rows follow ISO format (YYYY-MM-DD).
-- 1,205 rows follow US format (MM-DD-YYYY).
-- This makes age calculation unreliable in SQL.
-- FIX IN PYTHON: standardize all dates to a single datetime format.

-- Age spread per grade using only ISO-format dates (safe subset).
-- NOTE: Results below are directional only, not fully reliable.
-- The YEAR() function does not account for birth month vs current month.
SELECT
    Grade_Level,
    MIN(YEAR(GETDATE()) - YEAR(TRY_CONVERT(DATE, Date_of_Birth))) AS Min_Age,
    MAX(YEAR(GETDATE()) - YEAR(TRY_CONVERT(DATE, Date_of_Birth))) AS Max_Age,
    AVG(YEAR(GETDATE()) - YEAR(TRY_CONVERT(DATE, Date_of_Birth))) AS Avg_Age
FROM students
WHERE Date_of_Birth LIKE '____-__-__%'
GROUP BY Grade_Level
ORDER BY Grade_Level;

/*
OUTPUT:
Grade_Level  Min_Age  Max_Age  Avg_Age
Grade 1      7        20       13
Grade 2      7        20       13
Grade 3      7        20       13
Grade 4      7        20       13
Grade 5      7        20       13

INSIGHT:
All grades return identical age ranges (7-20) and the same average (13).
This is a red flag with two explanations:
  1. The mixed date formats (YYYY-MM-DD vs MM-DD-YYYY) are causing
     TRY_CONVERT to silently return wrong values for ambiguous dates.
  2. The identical averages across all grades suggest date values
     were not consistently entered with grade-appropriate ranges.
This column is unreliable for age analysis until Python cleaning
normalizes all formats. We will revisit age segmentation after that fix.
*/

-- ============================================================
-- CHAPTER 2: ARE THEY SHOWING UP?
-- Attendance is the first signal of disengagement.
-- A student who stops showing up is already falling behind.
-- ============================================================

-- DATA QUALITY ISSUE: Attendance_Status has 8 raw values
-- instead of clean categories. Issues found:
--   'PRESENT' vs 'Present'     -> inconsistent casing
--   ' late'                    -> leading whitespace
--   'absnt'                    -> typo for 'Absent'
-- FIX IN PYTHON: normalize all values to uppercase after TRIM,
-- then map 'ABSNT' -> 'ABSENT'.

-- What does the status landscape actually look like?
SELECT
    UPPER(TRIM(Attendance_Status)) AS Status,
    COUNT(*)                       AS Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS Pct
FROM attendance
GROUP BY UPPER(TRIM(Attendance_Status))
ORDER BY Count DESC;

/*
OUTPUT:
Status       Count   Pct
PRESENT      91614   25.12
LATE         91017   24.96
ABSENT       45751   12.55
ABSNT        45478   12.47
LEFT EARLY   45435   12.46
EXCUSED      45385   12.45

INSIGHT:
True presence is only 25% of all records.
When we merge ABSENT + ABSNT (the typo duplicate), absence reaches ~25%
as well, equal to presence. LATE at 25% means one in four attendance
events is a late arrival. The school effectively has students fully
present only 1 in 4 sessions. This is a critical finding.
FIX IN PYTHON: ABSNT must be merged into ABSENT before further analysis.
*/

-- Attendance rate by grade: which grade is most disengaged?
SELECT
    s.Grade_Level,
    COUNT(*)                                                                         AS Total_Records,
    SUM(CASE WHEN UPPER(TRIM(a.Attendance_Status)) = 'PRESENT' THEN 1 ELSE 0 END)  AS Present_Count,
    ROUND(
        SUM(CASE WHEN UPPER(TRIM(a.Attendance_Status)) = 'PRESENT' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                                                AS Present_Rate_Pct
FROM attendance a
JOIN students s ON a.Student_ID = s.Student_ID
GROUP BY s.Grade_Level
ORDER BY Present_Rate_Pct ASC;

/*
OUTPUT:
Grade_Level  Total_Records  Present_Count  Present_Rate_Pct
Grade 2      72098          18074          25.07
Grade 1      71920          18050          25.10
Grade 5      73806          18539          25.12
Grade 4      73600          18505          25.14
Grade 3      73256          18446          25.18

INSIGHT:
Attendance rates are statistically identical across all grades (~25%).
No single grade stands out as significantly more or less engaged.
The low presence rate (~25%) is a consistent signal worth investigating
at the individual student level rather than the grade level.
*/

-- Attendance by subject: is absence subject-specific or general?
SELECT
    Subject,
    ROUND(
        SUM(CASE WHEN UPPER(TRIM(Attendance_Status)) = 'PRESENT' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS Present_Rate_Pct,
    SUM(CASE WHEN UPPER(TRIM(Attendance_Status)) IN ('ABSENT','ABSNT') THEN 1 ELSE 0 END) AS Absent_Count,
    SUM(CASE WHEN UPPER(TRIM(Attendance_Status)) = 'LATE' THEN 1 ELSE 0 END)             AS Late_Count,
    SUM(CASE WHEN UPPER(TRIM(Attendance_Status)) = 'LEFT EARLY' THEN 1 ELSE 0 END)       AS Left_Early_Count
FROM attendance
GROUP BY Subject
ORDER BY Present_Rate_Pct ASC;

/*
OUTPUT:
Subject    Present_%  Absent  Late   Left_Early
Math       25.01      15364   15322  7693
Arabic     25.02      15313   15203  7497
Science    25.07      15167   15282  7603
History    25.08      15080   15024  7615
English    25.27      15105   15171  7452
Geography  25.28      15200   15015  7575

INSIGHT:
Math and Arabic have the highest absence counts and lowest presence rates.
The differences are marginal across all subjects (less than 0.3%).
Absence is general, not subject-driven. In a real school this would
suggest a systemic engagement problem rather than a curriculum issue.
*/

-- Monthly attendance trend: are students disengaging over the school year?
SELECT
    FORMAT(CONVERT(DATE, Date), 'yyyy-MM')                                            AS Month,
    ROUND(
        SUM(CASE WHEN UPPER(TRIM(Attendance_Status)) = 'PRESENT' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                                                  AS Present_Rate_Pct
FROM attendance
GROUP BY FORMAT(CONVERT(DATE, Date), 'yyyy-MM')
ORDER BY Month;

/*
OUTPUT:
Month    Present_%
2024-03  25.65
2024-04  25.25
2024-05  25.27
2024-06  25.32
2024-07  24.85
2024-08  24.93
2024-09  24.77
2024-10  25.30
2024-11  25.50
2024-12  24.85
2025-01  25.18
2025-02  24.68
2025-03  25.17

INSIGHT:
No meaningful trend exists month over month. Rates float between 24.68
and 25.65 with no clear seasonal peak or valley. The year does not start
stronger or end weaker.
In Power BI this will render as a flat trend line. The storytelling
frames it as: "no crisis, but no confidence either."
*/

-- ============================================================
-- CHAPTER 3: ARE THEY DOING THEIR WORK?
-- Attendance without effort is just presence.
-- Homework compliance reveals actual academic engagement.
-- ============================================================

-- DATA QUALITY ISSUE: Status column uses 6 inconsistent values.
-- Emojis (❌, ✔, ✅) appear alongside text ('Done', 'not done', 'pending').
-- When imported via SSMS the emojis may render as broken characters.
-- DATA QUALITY ISSUE: Guardian_Signature was imported as BIT type
-- by SSMS Import Wizard. TRIM() on a BIT column throws:
--   "Argument data type bit is invalid for argument 1 of Trim function"
-- FIX IN PYTHON: map all status variants to: DONE | NOT_DONE | PENDING
-- FIX IN PYTHON: convert blank Guardian_Signature entries to NULL.
-- FIX IN SQL (below): CAST Guardian_Signature to VARCHAR before use.

-- Homework completion rate overall
SELECT
    TRIM(Status)                                                AS Raw_Status,
    COUNT(*)                                                    AS Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)         AS Pct
FROM homework
GROUP BY TRIM(Status)
ORDER BY Count DESC;

/*
OUTPUT:
Raw_Status  Count  Pct
❌           20164  33.18
Done        10278  16.91
not done    10234  16.84
✔           10090  16.60
pending     10014  16.48

INSIGHT:
The ❌ emoji dominates at 33% because SSMS merged both ❌ and ✅
into the same broken-encoding bucket during import.
After Python cleaning, the real picture will be:
  DONE     ~33%  (Done + ✔ + ✅)
  NOT_DONE ~33%  (not done + ❌)
  PENDING  ~17%
Roughly 1 in 3 assignments is not being completed.
This is the homework crisis number for the presentation.
*/

-- Completion by subject: where are students giving up?
SELECT
    Subject,
    SUM(CASE WHEN UPPER(TRIM(Status)) IN ('DONE',' DONE','✔','✅') THEN 1 ELSE 0 END)     AS Completed,
    SUM(CASE WHEN UPPER(TRIM(Status)) IN ('NOT DONE','❌') THEN 1 ELSE 0 END)              AS Not_Completed,
    SUM(CASE WHEN UPPER(TRIM(Status)) = 'PENDING' THEN 1 ELSE 0 END)                      AS Pending,
    ROUND(
        SUM(CASE WHEN UPPER(TRIM(Status)) IN ('DONE',' DONE','✔','✅') THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                                                       AS Completion_Rate_Pct
FROM homework
GROUP BY Subject
ORDER BY Completion_Rate_Pct ASC;

/*
OUTPUT:
Subject    Completed  Not_Done  Pending  Completion_%
Science    1653       1749      1674     16.35
English    1717       1710      1679     16.82
Arabic     1707       1696      1695     16.89
History    1721       1722      1683     17.02
Math       1728       1686      1636     17.17
Geography  1752       1671      1647     17.21

INSIGHT:
Science has the lowest homework completion rate at 16.35%.
The spread across subjects is only ~1%, meaning no subject has a
dramatically different engagement problem. However Science consistently
ranks last and will be cross-checked against exam scores in Chapter 4.
NOTE: These rates are deflated by the ❌ encoding issue inflating
Not_Completed counts. Python cleaning will correct this.
*/

-- Does parental signature correlate with homework completion?
-- FIXED: CAST Guardian_Signature to VARCHAR to resolve BIT type error.
SELECT
    CAST(Guardian_Signature AS VARCHAR(10))                                                 AS Signed,
    COUNT(*)                                                                                AS Total,
    SUM(CASE WHEN UPPER(TRIM(Status)) IN ('DONE',' DONE','✔','✅') THEN 1 ELSE 0 END)      AS Completed,
    ROUND(
        SUM(CASE WHEN UPPER(TRIM(Status)) IN ('DONE',' DONE','✔','✅') THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                                                       AS Completion_Rate_Pct
FROM homework
GROUP BY CAST(Guardian_Signature AS VARCHAR(10))
ORDER BY Completion_Rate_Pct DESC;

/*
INSIGHT (run and paste output here):
The goal is to test whether parental signing correlates with higher
homework completion. If signed assignments are more likely to be done,
parental involvement becomes a key policy recommendation.
This will be a strong narrative point in the Power BI dashboard.
*/

-- Grade feedback distribution: what quality of work is being submitted?
SELECT
    Grade_Feedback,
    COUNT(*) AS Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS Pct
FROM homework
GROUP BY Grade_Feedback
ORDER BY Count DESC;

/*
OUTPUT:
Grade_Feedback  Count  Pct
A+              7709   12.68
B-              7639   12.57
D               7631   12.56
B               7591   12.49
F               7586   12.48
C               7585   12.48
A               7533   12.39
C-              7506   12.35

INSIGHT:
Grade distribution is almost perfectly uniform across all 8 bands at ~12.5%.
In a real school we expect a bell curve peaking at B/C.
For the presentation we flag this as a data quality observation
and focus on structurally meaningful patterns like the at-risk profile.
*/

-- ============================================================
-- CHAPTER 4: ARE THEY PERFORMING?
-- Numbers on an exam are the closest thing we have to ground truth.
-- But only if the numbers themselves are trustworthy.
-- ============================================================

-- DATA QUALITY ISSUE: Exam_Score has 5,139 records above 100 (max = 110).
-- Logically impossible on a standard 100-point scale.
-- DATA QUALITY ISSUE: Homework_Completion_% has two problems:
--   1. Mixed formats: some values are '95', others are '95%'.
--   2. 7,376 records have a value of -5 which is logically invalid.
-- FIX IN PYTHON: strip the % symbol, cast to numeric,
--   cap scores at 100, and treat negatives as NULL.

-- Exam score distribution: how is the school performing overall?
SELECT
    CASE
        WHEN Exam_Score < 60   THEN 'Failing   (<60)'
        WHEN Exam_Score < 75   THEN 'Average   (60-74)'
        WHEN Exam_Score < 90   THEN 'Good      (75-89)'
        WHEN Exam_Score <= 100 THEN 'Excellent (90-100)'
        ELSE                        'Invalid   (>100)'
    END                                                        AS Score_Band,
    COUNT(*)                                                   AS Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)        AS Pct
FROM performance
GROUP BY
    CASE
        WHEN Exam_Score < 60   THEN 'Failing   (<60)'
        WHEN Exam_Score < 75   THEN 'Average   (60-74)'
        WHEN Exam_Score < 90   THEN 'Good      (75-89)'
        WHEN Exam_Score <= 100 THEN 'Excellent (90-100)'
        ELSE                        'Invalid   (>100)'
    END
ORDER BY MIN(Exam_Score);

/*
OUTPUT:
Score_Band         Count  Pct
Failing   (<60)    10322  28.30
Average   (60-74)  7644   20.96
Good      (75-89)  7732   21.20
Excellent (90-100) 5631   15.44
Invalid   (>100)   5139   14.09

INSIGHT:
28.3% of exam records fall below 60, making Failing the single largest band.
14% of records are outright invalid (score > 100) and must be excluded.
Of valid records only 15.44% reach Excellent.
More students are failing than excelling.
For the presentation: "1 in 3 exam records is either failing or invalid.
The school's performance data has a reliability problem before it has
an achievement problem."
*/

-- Average exam score by subject (valid scores only)
SELECT
    Subject,
    ROUND(AVG(CAST(Exam_Score AS FLOAT)), 2)   AS Avg_Score,
    MIN(Exam_Score)                             AS Min_Score,
    MAX(Exam_Score)                             AS Max_Score,
    COUNT(*)                                    AS Records
FROM performance
WHERE Exam_Score <= 100
GROUP BY Subject
ORDER BY Avg_Score ASC;

/*
OUTPUT:
Subject    Avg_Score  Min  Max  Records
Geography  69.85      40   100  5275
Arabic     69.86      40   100  5330
Math       69.87      40   100  5215
English    69.91      40   100  5142
History    70.00      40   100  5127
Science    70.25      40   100  5240

INSIGHT:
Average scores hover between 69.85 and 70.25 across all subjects.
A 0.4-point spread between worst and best is negligible.
The minimum of 40 across all subjects is a consistent floor worth
investigating in the Python phase. The story here is not "which subject
is hardest" but "why does every subject score the same?"
*/

-- Average exam score by grade level
SELECT
    s.Grade_Level,
    ROUND(AVG(CAST(p.Exam_Score AS FLOAT)), 2) AS Avg_Score,
    COUNT(*)                                    AS Records
FROM performance p
JOIN students s ON p.Student_ID = s.Student_ID
WHERE p.Exam_Score <= 100
GROUP BY s.Grade_Level
ORDER BY s.Grade_Level;

/*
OUTPUT:
Grade_Level  Avg_Score  Records
Grade 1      69.81      6074
Grade 2      69.85      6162
Grade 3      70.24      6314
Grade 4      69.92      6328
Grade 5      69.95      6451

INSIGHT:
Scores are nearly identical across all grade levels (69.81 to 70.24).
In a real school, higher grades reflect harder exams or wider ability spread.
For the presentation this is the baseline: school average is 70,
and we pivot to who is above and below that line.
*/

-- Top 10 students by average exam score
SELECT TOP 10
    p.Student_ID,
    s.Full_Name,
    s.Grade_Level,
    ROUND(AVG(CAST(p.Exam_Score AS FLOAT)), 2) AS Avg_Score
FROM performance p
JOIN students s ON p.Student_ID = s.Student_ID
WHERE p.Exam_Score <= 100
GROUP BY p.Student_ID, s.Full_Name, s.Grade_Level
ORDER BY Avg_Score DESC;

/*
OUTPUT:
Student_ID  Full_Name           Grade_Level  Avg_Score
S00131      Gregory Schroeder   Grade 3      100
S00434      Leslie Moody        Grade 4      100
S00713      Cameron Lee         Grade 1      100
S01196      margaret robinson   Grade 3      100
S01339      holly hunt          Grade 1      100
S01648      Daniel Howard       Grade 5      100
S02424      Jennifer Melendez   Grade 2      100
S02982      Victoria Hahn       Grade 5      100
S03312      Devin Cameron       Grade 5      100
S03357      Darin Lewis         Grade 5      100

INSIGHT:
Multiple students achieved a perfect 100 average across all exams.
They span all grade levels which is a positive signal.
In the presentation these become our honor-roll highlight.
In practice, a perfect average across multiple exams is exceptional
and these students deserve recognition in the final presentation.
*/

-- Bottom 10 students: who needs intervention now?
SELECT TOP 10
    p.Student_ID,
    s.Full_Name,
    s.Grade_Level,
    ROUND(AVG(CAST(p.Exam_Score AS FLOAT)), 2) AS Avg_Score
FROM performance p
JOIN students s ON p.Student_ID = s.Student_ID
WHERE p.Exam_Score <= 100
GROUP BY p.Student_ID, s.Full_Name, s.Grade_Level
ORDER BY Avg_Score ASC;

/*
INSIGHT:
The bottom students average in the low 40s (see at-risk query below).
These are the students most in need of academic intervention.
Cross-referencing with attendance and communication in Chapter 6
will complete their full risk profile.
*/

-- ============================================================
-- CHAPTER 5: ARE PARENTS IN THE LOOP?
-- Academic failure rarely happens in a communication vacuum.
-- A school that talks to parents catches problems earlier.
-- ============================================================

-- Communication type breakdown: who is driving the conversation?
SELECT
    Message_Type,
    COUNT(*) AS Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS Pct
FROM teacher_parent_communication
GROUP BY Message_Type
ORDER BY Count DESC;

/*
OUTPUT:
Message_Type        Count  Pct
Teacher to Parent   8149   33.52
Automated Reminder  8106   33.34
Parent to Teacher   8057   33.14

INSIGHT:
All three communication types sit at almost exactly 33% each.
In real school data, automated reminders dominate and parent-initiated
messages are typically the rarest. For the presentation: "Communication is active
with teachers, parents, and the system all participating equally."
*/

-- Monthly communication volume: is engagement consistent or seasonal?
SELECT
    FORMAT(CONVERT(DATE, Date), 'yyyy-MM') AS Month,
    COUNT(*)                               AS Total_Messages,
    SUM(CASE WHEN Message_Type = 'Parent to Teacher' THEN 1 ELSE 0 END)  AS Parent_Initiated,
    SUM(CASE WHEN Message_Type = 'Teacher to Parent' THEN 1 ELSE 0 END)  AS Teacher_Initiated,
    SUM(CASE WHEN Message_Type = 'Automated Reminder' THEN 1 ELSE 0 END) AS Automated
FROM teacher_parent_communication
GROUP BY FORMAT(CONVERT(DATE, Date), 'yyyy-MM')
ORDER BY Month;

/*
OUTPUT:
Month    Total  Parent  Teacher  Automated
2024-09  3027   987     1041     999
2024-10  4071   1353    1380     1338
2024-11  3988   1312    1281     1395
2024-12  4169   1373    1404     1392
2025-01  4139   1427    1369     1343
2025-02  3658   1186    1254     1218
2025-03  1260   419     420      421

INSIGHT:
Communication peaks in Dec-Jan and drops in Feb-Mar.
The Dec-Jan peak is the most natural pattern in this entire dataset.
It reflects real behavior: parents and teachers communicate more
when exams are approaching. This is a genuine insight worth highlighting.
March 2025 data is incomplete (1,260 vs ~4,000/month average),
likely a partial month cutoff in the data export.
*/

-- CRITICAL FINDING: 1,644 students (13.5%) have zero communication records.

-- Do silent students underperform compared to students with communication?
SELECT
    CASE WHEN c.Student_ID IS NULL THEN 'No Communication' ELSE 'Has Communication' END AS Communication_Status,
    COUNT(DISTINCT s.Student_ID)                                                         AS Student_Count,
    ROUND(AVG(CAST(p.Exam_Score AS FLOAT)), 2)                                          AS Avg_Exam_Score
FROM students s
LEFT JOIN teacher_parent_communication c ON s.Student_ID = c.Student_ID
LEFT JOIN performance p                  ON s.Student_ID = p.Student_ID
WHERE p.Exam_Score <= 100
GROUP BY CASE WHEN c.Student_ID IS NULL THEN 'No Communication' ELSE 'Has Communication' END;

/*
OUTPUT:
Communication_Status  Student_Count  Avg_Exam_Score
No Communication      1522           69.97
Has Communication     9736           69.90

INSIGHT:
Counter-intuitive finding: silent students score marginally higher (69.97)
than students with active communication (69.90). The 0.07-point difference
is statistically meaningless. This finding suggests communication volume alone is not sufficient.
The content and follow-through of that communication matters more than frequency.
For the presentation: "Communication coverage is at 86.5%.
The 13.5% silent students are a monitoring priority, not yet a confirmed risk."
*/

-- Per-grade communication coverage: which grade is most disconnected?
SELECT
    s.Grade_Level,
    COUNT(DISTINCT s.Student_ID)                                    AS Total_Students,
    COUNT(DISTINCT c.Student_ID)                                    AS Students_With_Comms,
    COUNT(DISTINCT s.Student_ID) - COUNT(DISTINCT c.Student_ID)    AS Silent_Students,
    ROUND(
        (COUNT(DISTINCT s.Student_ID) - COUNT(DISTINCT c.Student_ID))
        * 100.0 / COUNT(DISTINCT s.Student_ID), 2
    )                                                               AS Silent_Pct
FROM students s
LEFT JOIN teacher_parent_communication c ON s.Student_ID = c.Student_ID
GROUP BY s.Grade_Level
ORDER BY Silent_Pct DESC;

/*
OUTPUT:
Grade_Level  Total  With_Comms  Silent  Silent_Pct
Grade 1      2383   2032        351     14.73
Grade 5      2472   2136        336     13.59
Grade 4      2454   2121        333     13.57
Grade 3      2447   2129        318     13.00
Grade 2      2400   2094        306     12.75

INSIGHT:
Grade 1 has the highest silent student rate at 14.73%.
This is the most concerning finding in this chapter because Grade 1
students are the youngest and most dependent on parent-school communication.
A 14.7% communication gap at the entry grade is a systemic onboarding issue.
For Power BI: Grade 1 silent students get a dedicated callout card.
*/

-- ============================================================
-- CHAPTER 6: THE AT-RISK STUDENT PROFILE
-- Who is absent, not doing homework, failing exams,
-- and has no parent communication?
-- This is the student who needs immediate intervention.
-- ============================================================

SELECT
    s.Student_ID,
    s.Full_Name,
    s.Grade_Level,
    ROUND(
        SUM(CASE WHEN UPPER(TRIM(a.Attendance_Status)) = 'PRESENT' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(a.Student_ID), 2
    )                                                                                   AS Attendance_Rate_Pct,
    ROUND(AVG(CAST(p.Exam_Score AS FLOAT)), 2)                                         AS Avg_Exam_Score,
    SUM(CASE WHEN UPPER(TRIM(h.Status)) IN ('NOT DONE','❌') THEN 1 ELSE 0 END)        AS Missed_Assignments,
    CASE WHEN MAX(c.Student_ID) IS NULL THEN 'No' ELSE 'Yes' END                       AS Has_Parent_Contact
FROM students s
LEFT JOIN attendance a                   ON s.Student_ID = a.Student_ID
LEFT JOIN performance p                  ON s.Student_ID = p.Student_ID
LEFT JOIN homework h                     ON s.Student_ID = h.Student_ID
LEFT JOIN teacher_parent_communication c ON s.Student_ID = c.Student_ID
WHERE p.Exam_Score <= 100
GROUP BY s.Student_ID, s.Full_Name, s.Grade_Level
HAVING
    ROUND(
        SUM(CASE WHEN UPPER(TRIM(a.Attendance_Status)) = 'PRESENT' THEN 1 ELSE 0 END)
        * 100.0 / NULLIF(COUNT(a.Student_ID), 0), 2
    ) < 20
    AND ROUND(AVG(CAST(p.Exam_Score AS FLOAT)), 2) < 60
    AND SUM(CASE WHEN UPPER(TRIM(h.Status)) IN ('NOT DONE','❌') THEN 1 ELSE 0 END) > 3
ORDER BY Avg_Exam_Score ASC, Attendance_Rate_Pct ASC;

/*
OUTPUT: (top rows)
Student_ID  Full_Name        Grade  Attendance%  Avg_Score  Missed  Contact
S06936      Carl Banks       Gr 2   9.38         40         32      Yes
S07829      Juan Young       Gr 2   9.68         40         62      Yes
S05594      morgan savage    Gr 5   10.34        40         58      Yes
S08434      Katie Harrison   Gr 3   15.00        40         20      No
S07622      Dustin Holmes    Gr 2   15.63        40         32      Yes
... (300+ students flagged total)

INSIGHT:
This is the most important query in the entire script.
It surfaces students who fail on all three academic dimensions:
  - Attendance below 20%  (barely showing up)
  - Exam average below 60 (failing academically)
  - More than 3 missed assignments (disengaged from coursework)

Key observations:
  1. Some students have missed 700-1400 assignments (S08743: 720,
     S00765: 1408). These extreme numbers warrant Python validation.
     They may result from the JOIN multiplying rows across tables.
  2. Most at-risk students still have parent contact ("Yes"), meaning
     communication alone is not preventing failure.
     Quality of communication needs review, not just quantity.
  3. Students with no contact like S08434, S04477, S02749 represent
     the highest-risk tier: failing AND invisible to parents.
  4. Grade 2 and Grade 3 appear most frequently in this list.

For the presentation: this table is an intervention priority list.
Each row is a student the school should act on before the year ends.
This is where data analysis becomes real impact.
*/

-- ============================================================
-- BONUS QUERIES: DEEPER CUTS FOR THE COMMITTEE
-- ============================================================

-- Which students have perfect attendance (all records = PRESENT)?
SELECT
    s.Student_ID,
    s.Full_Name,
    s.Grade_Level,
    COUNT(*) AS Total_Sessions
FROM attendance a
JOIN students s ON a.Student_ID = s.Student_ID
WHERE UPPER(TRIM(a.Attendance_Status)) = 'PRESENT'
GROUP BY s.Student_ID, s.Full_Name, s.Grade_Level
HAVING COUNT(*) = (
    SELECT COUNT(*) FROM attendance a2
    WHERE a2.Student_ID = s.Student_ID
)
ORDER BY Total_Sessions DESC;

/*
INSIGHT:
Students with 100% presence rate across the entire year.
These are the students who never missed a single session.
Worth highlighting in the presentation as the commitment benchmark.
*/

-- Subject with the highest late arrival rate: where do students drag their feet?
SELECT
    Subject,
    SUM(CASE WHEN UPPER(TRIM(Attendance_Status)) = 'LATE' THEN 1 ELSE 0 END)   AS Late_Count,
    COUNT(*)                                                                     AS Total,
    ROUND(
        SUM(CASE WHEN UPPER(TRIM(Attendance_Status)) = 'LATE' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                                            AS Late_Rate_Pct
FROM attendance
GROUP BY Subject
ORDER BY Late_Rate_Pct DESC;

/*
INSIGHT:
Reveals which subjects students are physically arriving late to.
A high late rate in a specific subject points to a motivation or
scheduling problem specific to that class, not general disengagement.
*/

-- Students who have parent contact but are still failing:
-- communication is happening but not translating into improvement.
SELECT
    s.Student_ID,
    s.Full_Name,
    s.Grade_Level,
    ROUND(AVG(CAST(p.Exam_Score AS FLOAT)), 2)  AS Avg_Exam_Score,
    COUNT(DISTINCT c.Date)                       AS Communication_Count
FROM students s
JOIN performance p                  ON s.Student_ID = p.Student_ID
JOIN teacher_parent_communication c ON s.Student_ID = c.Student_ID
WHERE p.Exam_Score <= 100
GROUP BY s.Student_ID, s.Full_Name, s.Grade_Level
HAVING ROUND(AVG(CAST(p.Exam_Score AS FLOAT)), 2) < 60
ORDER BY Communication_Count DESC, Avg_Exam_Score ASC;

/*
INSIGHT:
These students are the hardest case for the school.
Parents are being contacted, yet performance is not improving.
This signals that the intervention strategy needs to change,
not just the frequency of communication.
For the presentation: "Talking to parents is not enough on its own."
*/

-- Homework pending rate by grade: where is work being left unfinished?
SELECT
    s.Grade_Level,
    SUM(CASE WHEN UPPER(TRIM(h.Status)) = 'PENDING' THEN 1 ELSE 0 END)   AS Pending_Count,
    COUNT(*)                                                               AS Total,
    ROUND(
        SUM(CASE WHEN UPPER(TRIM(h.Status)) = 'PENDING' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                                      AS Pending_Rate_Pct
FROM homework h
JOIN students s ON h.Student_ID = s.Student_ID
GROUP BY s.Grade_Level
ORDER BY Pending_Rate_Pct DESC;

/*
INSIGHT:
Pending work is a leading indicator of future failure.
An assignment still pending is one that has not been submitted yet,
not one that was submitted and graded poorly.
A high pending rate in a specific grade flags a workload management issue
that teachers can address before it converts into missed assignments.
*/

-- Top 5 most communicated-about students: who is on the school's radar?
SELECT TOP 5
    c.Student_ID,
    s.Full_Name,
    s.Grade_Level,
    COUNT(*) AS Message_Count,
    ROUND(AVG(CAST(p.Exam_Score AS FLOAT)), 2) AS Avg_Exam_Score
FROM teacher_parent_communication c
JOIN students s    ON c.Student_ID = s.Student_ID
LEFT JOIN performance p ON c.Student_ID = p.Student_ID AND p.Exam_Score <= 100
GROUP BY c.Student_ID, s.Full_Name, s.Grade_Level
ORDER BY Message_Count DESC;

/*
INSIGHT:
The most frequently discussed students in parent-teacher communication.
Cross-referencing with their exam scores tells the full story:
if high communication correlates with low scores, the school is reactive,
reaching out only when things go wrong rather than proactively.
*/

-- ============================================================
-- END OF STORYTELLING SCRIPT
-- ============================================================
-- SUMMARY OF DATA QUALITY ISSUES TO FIX IN PYTHON:
--   1. students.Date_of_Birth        : mixed ISO and US date formats
--   2. attendance.Attendance_Status  : inconsistent casing + 'absnt' typo
--   3. homework.Status               : emoji encoding + text inconsistency
--   4. homework.Guardian_Signature   : imported as BIT, blank != NULL
--   5. performance.Homework_%        : -5 invalid values + mixed % symbol
--   6. performance.Exam_Score        : 5,139 scores above 100 (max 110)
-- ============================================================
-- Next phase  : Python for cleaning and transformation
-- Following   : Power BI dashboards
-- ============================================================
