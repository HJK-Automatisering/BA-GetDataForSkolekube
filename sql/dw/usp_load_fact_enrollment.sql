-- =============================================================================
-- dw.usp_load_fact_enrollment
-- =============================================================================
-- Loads enrollment history from stg.student_history (row_type 4).
-- MERGE on (student_id, school_code, from_date_id).
-- Updates to_date_id and class details if changed.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_fact_enrollment
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
        @run_id, 'dw.usp_load_fact_enrollment', 'Load fact_enrollment', @step_id OUTPUT;
    BEGIN TRY
        SELECT @rr = COUNT(*) FROM stg.student_history WHERE row_type = 4;
        DECLARE @o TABLE (a NVARCHAR(10));
        ;MERGE dw.fact_enrollment AS t
        USING (
            SELECT s.student_id,
                COALESCE(ds.school_code,       -1) AS sc,
                h.school_name,
                COALESCE(dst.school_type_code, -1) AS stc,
                h.class_label,
                COALESCE(dct.class_type_code,  -1) AS ctc,
                h.student_level AS sgl,
                h.class_level   AS hgl,
                h.class_track   AS trk,
                CAST(h.valid_from AS INT)          AS fd,
                TRY_CAST(h.valid_to AS INT)        AS td
            FROM stg.student_history h
            JOIN dw.dim_student_sensitive s  ON s.cpr_nr              = h.cpr_nr
            LEFT JOIN dw.dim_school      ds  ON ds.school_code        = h.school_code
            LEFT JOIN dw.dim_school_type dst ON dst.school_type_code  = h.school_type_code
            LEFT JOIN dw.dim_class_type  dct ON dct.class_type_code   = h.class_type_code
            WHERE h.row_type = 4 AND h.valid_from IS NOT NULL
        ) AS src ON (t.student_id = src.student_id AND t.school_code = src.sc AND t.from_date_id = src.fd)
        WHEN MATCHED AND (
            ISNULL(t.to_date_id,            -1) <> ISNULL(src.td,         -1)
            OR ISNULL(t.school_name,        '') <> ISNULL(src.school_name, '')
            OR t.school_type_code                <> src.stc
            OR ISNULL(t.class_name,         '') <> ISNULL(src.class_label, '')
            OR t.class_type_code                 <> src.ctc
            OR ISNULL(t.student_grade_level,-1) <> ISNULL(src.sgl,        -1)
            OR ISNULL(t.home_grade_level,   -1) <> ISNULL(src.hgl,        -1)
            OR ISNULL(t.track,              '') <> ISNULL(src.trk,         '')
        ) THEN UPDATE SET
            t.to_date_id          = src.td,
            t.school_name         = src.school_name,
            t.school_type_code    = src.stc,
            t.class_name          = src.class_label,
            t.class_type_code     = src.ctc,
            t.student_grade_level = src.sgl,
            t.home_grade_level    = src.hgl,
            t.track               = src.trk
        WHEN NOT MATCHED THEN INSERT (
            student_id, school_code, school_name, school_type_code, class_name,
            class_type_code, student_grade_level, home_grade_level, track, from_date_id, to_date_id
        ) VALUES (
            src.student_id, src.sc, src.school_name, src.stc, src.class_label,
            src.ctc, src.sgl, src.hgl, src.trk, src.fd, src.td
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