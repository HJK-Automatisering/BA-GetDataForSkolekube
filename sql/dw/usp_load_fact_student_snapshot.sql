-- =============================================================================
-- dw.usp_load_fact_student_snapshot
-- =============================================================================
-- Truncates and reloads a daily snapshot of all current students
-- from dim_student joined with dim_student_sensitive (for gender).
-- One row per student per day. Excludes sentinel student_id = -1.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_fact_student_snapshot
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id  INT;
    DECLARE @ri       INT = 0;
    DECLARE @rd       INT = 0;
    DECLARE @today_id INT = CAST(FORMAT(CAST(GETDATE() AS DATE), 'yyyyMMdd') AS INT);
    DECLARE @err      NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_fact_student_snapshot', 'Load fact_student_snapshot', @step_id OUTPUT;
    BEGIN TRY
        DELETE FROM dw.fact_student_snapshot;
        SET @rd = @@ROWCOUNT;

        INSERT INTO dw.fact_student_snapshot (
            date_id, student_id,
            school_code, municipality_code, paying_mun_code,
            student_type_code, citizenship_code, country_code, language_code,
            grade_level, class_track, student_level, gender, age,
            action_danish_second_lang, action_reception_class, action_special_education,
            action_supp_danish, action_junior_master, action_intermediate
        )
        SELECT
            @today_id,
            ds.student_id,
            ds.school_code,
            ds.municipality_code,
            ds.paying_mun_code,
            ds.student_type_code,
            ds.citizenship_code,
            ds.country_code,
            ds.language_code,
            ds.grade_level,
            ds.class_track,
            ds.student_level,
            dss.gender,
            ds.age,
            CAST(ds.action_danish_second_lang AS TINYINT),
            CAST(ds.action_reception_class    AS TINYINT),
            CAST(ds.action_special_education  AS TINYINT),
            CAST(ds.action_supp_danish        AS TINYINT),
            CAST(ds.action_junior_master      AS TINYINT),
            CAST(ds.action_intermediate       AS TINYINT)
        FROM dw.dim_student           ds
        JOIN dw.dim_student_sensitive dss ON dss.student_id = ds.student_id
        WHERE ds.student_id <> -1;

        SET @ri = @@ROWCOUNT;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, @ri, NULL, @rd;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        THROW;
    END CATCH;
END;
GO