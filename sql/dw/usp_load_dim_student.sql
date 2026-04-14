-- =============================================================================
-- dw.usp_load_dim_student
-- =============================================================================
-- Loads student dimension from stg.student_basis.
-- Joins dim_student_sensitive on cpr_nr for surrogate key.
-- Resolves student_type_code via LEFT JOIN on student_type_name.
-- Populates previous_main_school_code for school 280628 transfers.
-- Deletes students no longer in source (excludes sentinel -1).
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_dim_student
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @rr      INT = 0;
    DECLARE @ri      INT = 0;
    DECLARE @ru      INT = 0;
    DECLARE @rd      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_dim_student', 'Load dim_student', @step_id OUTPUT;
    BEGIN TRY
        SELECT @rr = COUNT(*) FROM stg.student_basis;

        CREATE TABLE #prev_school (
            student_id                INT NOT NULL PRIMARY KEY,
            previous_main_school_code INT NULL
        );

        INSERT INTO #prev_school (student_id, previous_main_school_code)
        SELECT e.student_id, dsc.main_school_code
        FROM dw.fact_enrollment e
        JOIN dw.dim_school dsc ON dsc.school_code = e.school_code
        WHERE e.school_code <> 280628
          AND e.to_date_id IS NOT NULL
          AND e.student_id IN (
              SELECT ds.student_id
              FROM dw.dim_student ds
              WHERE ds.school_code = 280628
          )
          AND e.to_date_id = (
              SELECT MAX(e2.to_date_id)
              FROM dw.fact_enrollment e2
              WHERE e2.student_id  = e.student_id
                AND e2.school_code <> 280628
                AND e2.to_date_id  IS NOT NULL
          );

        DECLARE @o TABLE (a NVARCHAR(10));
        MERGE dw.dim_student AS t
        USING (
            SELECT
                s.student_id,
                DATEDIFF(YEAR, TRY_CONVERT(DATE, sb.birth_date), CAST(GETDATE() AS DATE))
                - CASE WHEN DATEADD(YEAR,
                    DATEDIFF(YEAR, TRY_CONVERT(DATE, sb.birth_date), GETDATE()),
                    TRY_CONVERT(DATE, sb.birth_date)) > CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END AS age,
                sb.student_level,
                sb.class_level                                         AS grade_level,
                sb.class_track,
                sb.class_label,
                sb.school_district,
                sb.photo_permission,
                sb.transport_permission,
                CAST(ISNULL(sb.action_danish_second_lang, 0) AS BIT)  AS action_danish_second_lang,
                CAST(ISNULL(sb.action_reception_class,    0) AS BIT)  AS action_reception_class,
                CAST(ISNULL(sb.action_special_education,  0) AS BIT)  AS action_special_education,
                CAST(ISNULL(sb.action_supp_danish,        0) AS BIT)  AS action_supp_danish,
                CAST(ISNULL(sb.action_junior_master,      0) AS BIT)  AS action_junior_master,
                CAST(ISNULL(sb.action_intermediate,       0) AS BIT)  AS action_intermediate,
                COALESCE(sb.municipality_code,  -1)                    AS municipality_code,
                COALESCE(sb.paying_mun_code,    -1)                    AS paying_mun_code,
                COALESCE(sb.school_code,        -1)                    AS school_code,
                COALESCE(dst.student_type_code, -1)                    AS student_type_code,
                COALESCE(sb.nationality_code,   -1)                    AS citizenship_code,
                COALESCE(sb.birth_country_code, -1)                    AS country_code,
                COALESCE(sb.mother_tongue_code, -1)                    AS language_code,
                ps.previous_main_school_code
            FROM stg.student_basis sb
            JOIN  dw.dim_student_sensitive s  ON s.cpr_nr              = sb.cpr_nr
            LEFT JOIN dw.dim_student_type  dst ON dst.student_type_name = sb.student_type_name
            LEFT JOIN #prev_school         ps  ON ps.student_id         = s.student_id
        ) AS src ON t.student_id = src.student_id
        WHEN MATCHED THEN UPDATE SET
            t.age                       = src.age,
            t.student_level             = src.student_level,
            t.grade_level               = src.grade_level,
            t.class_track               = src.class_track,
            t.class_label               = src.class_label,
            t.school_district           = src.school_district,
            t.photo_permission          = src.photo_permission,
            t.transport_permission      = src.transport_permission,
            t.action_danish_second_lang = src.action_danish_second_lang,
            t.action_reception_class    = src.action_reception_class,
            t.action_special_education  = src.action_special_education,
            t.action_supp_danish        = src.action_supp_danish,
            t.action_junior_master      = src.action_junior_master,
            t.action_intermediate       = src.action_intermediate,
            t.municipality_code         = src.municipality_code,
            t.paying_mun_code           = src.paying_mun_code,
            t.school_code               = src.school_code,
            t.student_type_code         = src.student_type_code,
            t.citizenship_code          = src.citizenship_code,
            t.country_code              = src.country_code,
            t.language_code             = src.language_code,
            t.previous_main_school_code = src.previous_main_school_code
        WHEN NOT MATCHED BY TARGET THEN INSERT (
            student_id, age,
            student_level, grade_level, class_track, class_label, school_district,
            photo_permission, transport_permission,
            action_danish_second_lang, action_reception_class, action_special_education,
            action_supp_danish, action_junior_master, action_intermediate,
            municipality_code, paying_mun_code, school_code, student_type_code,
            citizenship_code, country_code, language_code,
            previous_main_school_code
        ) VALUES (
            src.student_id, src.age,
            src.student_level, src.grade_level, src.class_track, src.class_label, src.school_district,
            src.photo_permission, src.transport_permission,
            src.action_danish_second_lang, src.action_reception_class, src.action_special_education,
            src.action_supp_danish, src.action_junior_master, src.action_intermediate,
            src.municipality_code, src.paying_mun_code, src.school_code, src.student_type_code,
            src.citizenship_code, src.country_code, src.language_code,
            src.previous_main_school_code
        )
        WHEN NOT MATCHED BY SOURCE AND t.student_id <> -1
            THEN DELETE
        OUTPUT $action INTO @o;
        SELECT @ri = COUNT(CASE WHEN a = 'INSERT' THEN 1 END),
               @ru = COUNT(CASE WHEN a = 'UPDATE' THEN 1 END),
               @rd = COUNT(CASE WHEN a = 'DELETE' THEN 1 END)
        FROM @o;

        DROP TABLE #prev_school;
        EXEC meta.usp_meta_finish_step @step_id, 'success', @rr, @ri, @ru, @rd;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#prev_school') IS NOT NULL DROP TABLE #prev_school;
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        THROW;
    END CATCH;
END;
GO