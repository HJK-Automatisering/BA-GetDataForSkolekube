-- =============================================================================
-- dw.usp_load_fact_absence_daily
-- =============================================================================
-- Loads daily absence fact. One row per student per day.
-- IF row (absence_value=0.0, lesson=NULL) inserted for yesterday
-- only if yesterday is a valid school day (not weekend/vacation).
-- row_type 5 (full day) takes priority over row_type 7 (half day).
-- absence_value is capped at 1.0. Priority: U > S > L > F.
-- Rows no longer in stg are reset to IF within current school year.
-- Future-dated registrations (> yesterday) are filtered out.
-- Half day registrations (row_type 7) for grade 0-6 are treated as
-- full day (absence_value=1.0, lesson='Hele dagen').
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_fact_absence_daily
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id      INT;
    DECLARE @rr           INT  = 0;
    DECLARE @ri           INT  = 0;
    DECLARE @ru           INT  = 0;
    DECLARE @err          NVARCHAR(2000);
    DECLARE @yesterday    DATE = DATEADD(DAY, -1, CAST(GETDATE() AS DATE));
    DECLARE @yesterday_id INT  = CAST(FORMAT(@yesterday, 'yyyyMMdd') AS INT);
    DECLARE @sy_start_id  INT  = CAST(FORMAT(
        CASE
            WHEN MONTH(GETDATE()) >= 8
                THEN DATEFROMPARTS(YEAR(GETDATE()),     8, 1)
            ELSE DATEFROMPARTS(YEAR(GETDATE()) - 1, 8, 1)
        END, 'yyyyMMdd') AS INT);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_fact_absence_daily', 'Load fact_absence_daily', @step_id OUTPUT;
    BEGIN TRY
        SELECT @rr = COUNT(*) FROM stg.student_absence
        WHERE row_type IN (5, 7) AND absence_reason IN ('S', 'L', 'U', 'F');

        CREATE TABLE #absence_students (student_id INT NOT NULL PRIMARY KEY);
        INSERT INTO #absence_students (student_id)
        SELECT ds.student_id
        FROM dw.dim_student     ds
        JOIN dw.dim_school      dsc ON dsc.school_code     = ds.school_code
        JOIN dw.dim_main_school dm  ON dm.main_school_code = dsc.main_school_code
        WHERE ds.student_id    <> -1
          AND dm.include_absence = 1;

        -- IF rows for yesterday — only if yesterday is a valid school day
        INSERT INTO dw.fact_absence_daily (
            student_id, absence_reason_code, date_id, school_code,
            grade_level, track, absence_value, lesson
        )
        SELECT ds.student_id, 'IF', @yesterday_id, COALESCE(ds.school_code, -1),
               ds.grade_level, ds.class_track, 0.0, NULL
        FROM dw.dim_student ds
        JOIN #absence_students ab ON ab.student_id = ds.student_id
        JOIN dw.dim_date       dd ON dd.date_id         = @yesterday_id
                                 AND dd.is_weekend      = 0
                                 AND dd.is_vacation_day = 0
        WHERE NOT EXISTS (
            SELECT 1 FROM dw.fact_absence_daily f
            WHERE f.student_id  = ds.student_id
              AND f.date_id     = @yesterday_id
              AND f.school_code = COALESCE(ds.school_code, -1)
        );
        SET @ri = @@ROWCOUNT;

        DECLARE @o TABLE (a NVARCHAR(10));
        ;MERGE dw.fact_absence_daily AS t
        USING (
            SELECT
                s.student_id,
                CAST(a.absence_date AS INT)    AS date_id,
                COALESCE(dsch.school_code, -1) AS school_code,
                MAX(a.class_level)             AS grade_level,
                MAX(a.class_track)             AS track,
                -- Priority: U > S > L > F across all rows
                CASE
                    WHEN MAX(CASE WHEN a.absence_reason = 'U' THEN 1 ELSE 0 END) = 1 THEN 'U'
                    WHEN MAX(CASE WHEN a.absence_reason = 'S' THEN 1 ELSE 0 END) = 1 THEN 'S'
                    WHEN MAX(CASE WHEN a.absence_reason = 'L' THEN 1 ELSE 0 END) = 1 THEN 'L'
                    ELSE 'F'
                END                            AS absence_reason_code,
                -- row_type 5 always wins — no cross-type summation.
                -- row_type 7 on grade 0-6 is treated as full day (1.0).
                -- NULL class_level keeps original half day logic.
                CASE
                    WHEN MAX(CASE WHEN a.row_type = 5 THEN 1 ELSE 0 END) = 1
                        THEN 1.0
                    WHEN MAX(CASE WHEN a.row_type = 7 AND TRY_CAST(a.class_level AS INT) BETWEEN 0 AND 6 THEN 1 ELSE 0 END) = 1
                        THEN 1.0
                    WHEN SUM(CASE WHEN a.row_type = 7 THEN 0.5 ELSE 0.0 END) >= 1.0
                        THEN 1.0
                    ELSE SUM(CASE WHEN a.row_type = 7 THEN 0.5 ELSE 0.0 END)
                END                            AS absence_value,
                CASE
                    WHEN MAX(CASE WHEN a.row_type = 5 THEN 1 ELSE 0 END) = 1
                        THEN 'Hele dagen'
                    WHEN MAX(CASE WHEN a.row_type = 7 AND TRY_CAST(a.class_level AS INT) BETWEEN 0 AND 6 THEN 1 ELSE 0 END) = 1
                        THEN 'Hele dagen'
                    WHEN SUM(CASE WHEN a.row_type = 7 THEN 1 ELSE 0 END) >= 2
                        THEN 'Hele dagen'
                    WHEN MAX(CASE WHEN a.row_type = 7 AND a.half_day_part = 'første' THEN 1 ELSE 0 END) = 1
                        THEN 'Første lektion'
                    WHEN MAX(CASE WHEN a.row_type = 7 AND a.half_day_part = 'sidste' THEN 1 ELSE 0 END) = 1
                        THEN 'Sidste lektion'
                    ELSE NULL
                END                            AS lesson
            FROM stg.student_absence a
            JOIN dw.dim_student_sensitive s ON s.cpr_nr            = a.cpr_nr
            JOIN #absence_students        ab ON ab.student_id      = s.student_id
            JOIN dw.dim_date              dd ON dd.date_id         = CAST(a.absence_date AS INT)
                                            AND dd.is_weekend      = 0
                                            AND dd.is_vacation_day = 0
            LEFT JOIN dw.dim_school      dsch ON dsch.school_code  = a.school_code
            WHERE a.row_type IN (5, 7)
              AND a.absence_reason IN ('S', 'L', 'U', 'F')
              AND a.absence_date   <= @yesterday
            GROUP BY s.student_id, CAST(a.absence_date AS INT), COALESCE(dsch.school_code, -1)
        ) AS src ON (
            t.student_id  = src.student_id
            AND t.date_id     = src.date_id
            AND t.school_code = src.school_code
        )
        WHEN MATCHED AND (
            t.absence_reason_code        <> src.absence_reason_code
            OR t.absence_value           <> src.absence_value
            OR ISNULL(t.lesson,      '') <> ISNULL(src.lesson,      '')
            OR ISNULL(t.grade_level, -1) <> ISNULL(src.grade_level, -1)
            OR ISNULL(t.track,       '') <> ISNULL(src.track,       '')
        ) THEN UPDATE SET
            t.absence_reason_code = src.absence_reason_code,
            t.absence_value       = src.absence_value,
            t.lesson              = src.lesson,
            t.grade_level         = src.grade_level,
            t.track               = src.track
        WHEN NOT MATCHED BY TARGET THEN INSERT (
            student_id, absence_reason_code, date_id, school_code,
            grade_level, track, absence_value, lesson
        ) VALUES (
            src.student_id, src.absence_reason_code, src.date_id, src.school_code,
            src.grade_level, src.track, src.absence_value, src.lesson
        )
        WHEN NOT MATCHED BY SOURCE
            AND t.absence_reason_code <> 'IF'
            AND t.date_id >= @sy_start_id
            AND EXISTS (SELECT 1 FROM #absence_students ab WHERE ab.student_id = t.student_id)
        THEN UPDATE SET
            t.absence_reason_code = 'IF',
            t.absence_value       = 0.0,
            t.lesson              = NULL
        OUTPUT $action INTO @o;

        SELECT @ri = @ri + COUNT(CASE WHEN a = 'INSERT' THEN 1 END),
               @ru = COUNT(CASE WHEN a = 'UPDATE' THEN 1 END)
        FROM @o;

        DROP TABLE #absence_students;
        EXEC meta.usp_meta_finish_step @step_id, 'success', @rr, @ri, @ru;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#absence_students') IS NOT NULL DROP TABLE #absence_students;
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        THROW;
    END CATCH;
END;
GO