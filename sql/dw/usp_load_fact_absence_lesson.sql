-- =============================================================================
-- dw.usp_load_fact_absence_lesson
-- =============================================================================
-- Loads lesson-level absence fact from stg.student_absence (row_type 6).
-- MERGE on (student_id, date_id, lesson_number, school_code, subject_code).
-- NOTE: Pending rollout.
-- When fixed: add dim_date filter (is_weekend/is_vacation_day)
-- and filter absence_date <= yesterday.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_fact_absence_lesson
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @rr      INT = 0;
    DECLARE @ri      INT = 0;
    DECLARE @ru      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_fact_absence_lesson', 'Load fact_absence_lesson', @step_id OUTPUT;
    BEGIN TRY
        SELECT @rr = COUNT(*) FROM stg.student_absence
        WHERE row_type = 6 AND absence_reason IN ('S', 'L', 'U', 'F');
        DECLARE @o TABLE (a NVARCHAR(10));
        ;MERGE dw.fact_absence_lesson AS t
        USING (
            SELECT s.student_id, a.absence_reason AS ar, CAST(a.absence_date AS INT) AS di,
                   a.lesson_number AS ln,
                   COALESCE(dsub.subject_code, -1) AS sc,
                   COALESCE(dsch.school_code,  -1) AS skc,
                   a.class_level AS gl, a.class_track AS tr
            FROM stg.student_absence a
            JOIN dw.dim_student_sensitive s ON s.cpr_nr             = a.cpr_nr
            JOIN dw.dim_student           ds ON ds.student_id       = s.student_id
            JOIN dw.dim_school           dsc ON dsc.school_code     = ds.school_code
            JOIN dw.dim_main_school       dm ON dm.main_school_code = dsc.main_school_code
            LEFT JOIN dw.dim_subject  dsub   ON dsub.subject_code   = a.subject_code
            LEFT JOIN dw.dim_school   dsch   ON dsch.school_code    = a.school_code
            WHERE a.row_type = 6
              AND a.absence_reason IN ('S', 'L', 'U', 'F')
              AND dm.include_absence = 1
        ) AS src ON (
            t.student_id    = src.student_id
            AND t.date_id       = src.di
            AND t.lesson_number = src.ln
            AND t.school_code   = src.skc
            AND t.subject_code  = src.sc
        )
        WHEN MATCHED AND t.absence_reason_code <> src.ar
            THEN UPDATE SET
                t.absence_reason_code = src.ar, t.grade_level = src.gl, t.track = src.tr
        WHEN NOT MATCHED THEN INSERT (
            student_id, absence_reason_code, date_id, lesson_number,
            subject_code, school_code, grade_level, track, absence_value
        ) VALUES (src.student_id, src.ar, src.di, src.ln, src.sc, src.skc, src.gl, src.tr, 1)
        OUTPUT $action INTO @o;
        SELECT @ri = COUNT(CASE WHEN a = 'INSERT' THEN 1 END),
               @ru = COUNT(CASE WHEN a = 'UPDATE' THEN 1 END)
        FROM @o;
        EXEC meta.usp_meta_finish_step @step_id, 'success', @rr, @ri, @ru;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        THROW;
    END CATCH;
END;
GO