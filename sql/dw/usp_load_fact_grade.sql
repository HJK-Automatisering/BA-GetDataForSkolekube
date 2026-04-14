-- =============================================================================
-- dw.usp_load_fact_grade
-- =============================================================================
-- Loads grade fact from stg.student_grades.
-- MERGE on (student_id, subject_code, discipline_code,
-- grade_level, school_year, exam_type_code).
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_fact_grade
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
        @run_id, 'dw.usp_load_fact_grade', 'Load fact_grade', @step_id OUTPUT;
    BEGIN TRY
        SELECT @rr = COUNT(*) FROM stg.student_grades;
        DECLARE @o TABLE (a NVARCHAR(10));
        ;MERGE dw.fact_grade AS t
        USING (
            SELECT s.student_id,
                COALESCE(dsub.subject_code,    -1)   AS suc,
                COALESCE(ddis.discipline_code, -1)   AS dic,
                g.class_level AS cl, g.school_year_int AS sy, g.is_fs10 AS fs,
                g.grade_sp1, g.grade_sp2, g.grade_sp_final,
                g.grade_work1, g.grade_work2, g.grade_work_final, g.grade_exam,
                COALESCE(dsch.school_code,      -1)  AS skc,
                COALESCE(dext.exam_type_code,  '-1') AS etc
            FROM stg.student_grades g
            JOIN dw.dim_student_sensitive s   ON s.cpr_nr             = g.cpr_nr
            LEFT JOIN dw.dim_subject     dsub ON dsub.subject_code    = TRY_CAST(g.subject_code    AS INT)
            LEFT JOIN dw.dim_discipline  ddis ON ddis.discipline_code = TRY_CAST(g.discipline_code AS INT)
            LEFT JOIN dw.dim_school      dsch ON dsch.school_code     = g.school_code
            LEFT JOIN dw.dim_exam_type   dext ON dext.exam_type_code  = g.exam_type_code
        ) AS src ON (
            t.student_id      = src.student_id
            AND t.subject_code    = src.suc
            AND t.discipline_code = src.dic
            AND t.grade_level     = src.cl
            AND t.school_year     = src.sy
            AND t.exam_type_code  = src.etc
        )
        WHEN MATCHED AND (
            ISNULL(t.sp1_grade,  '') <> ISNULL(src.grade_sp1,       '')
            OR ISNULL(t.sp2_grade,  '') <> ISNULL(src.grade_sp2,       '')
            OR ISNULL(t.sps_grade,  '') <> ISNULL(src.grade_sp_final,  '')
            OR ISNULL(t.arb1_grade, '') <> ISNULL(src.grade_work1,     '')
            OR ISNULL(t.arb2_grade, '') <> ISNULL(src.grade_work2,     '')
            OR ISNULL(t.arbs_grade, '') <> ISNULL(src.grade_work_final,'')
            OR ISNULL(t.prv_grade,  '') <> ISNULL(src.grade_exam,      '')
            OR t.fs10 <> src.fs OR t.school_code <> src.skc
        ) THEN UPDATE SET
            t.fs10        = src.fs,
            t.sp1_grade   = src.grade_sp1,   t.sp2_grade   = src.grade_sp2,
            t.sps_grade   = src.grade_sp_final,
            t.arb1_grade  = src.grade_work1,  t.arb2_grade  = src.grade_work2,
            t.arbs_grade  = src.grade_work_final,
            t.prv_grade   = src.grade_exam,
            t.school_code = src.skc
        WHEN NOT MATCHED THEN INSERT (
            student_id, subject_code, discipline_code, grade_level, school_year, fs10,
            sp1_grade, sp2_grade, sps_grade, arb1_grade, arb2_grade, arbs_grade, prv_grade,
            school_code, exam_type_code
        ) VALUES (
            src.student_id, src.suc, src.dic, src.cl, src.sy, src.fs,
            src.grade_sp1, src.grade_sp2, src.grade_sp_final,
            src.grade_work1, src.grade_work2, src.grade_work_final, src.grade_exam,
            src.skc, src.etc
        )
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