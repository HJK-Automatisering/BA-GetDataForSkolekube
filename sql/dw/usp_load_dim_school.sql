-- =============================================================================
-- dw.usp_load_dim_school
-- =============================================================================
-- Loads school dimension from stg.student_basis and stg.student_history.
-- MERGE on school_code. Hardcodes main_school_code = school_code
-- for schools 280628 (Hjørringskolen) and 821019 (Hjørring Ny 10.)
-- and 821006 (Tårs Skole) to prevent ETL overwrites.
-- All other schools with unknown main_school_code resolve to -1.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_dim_school
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @ri      INT = 0;
    DECLARE @ru      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_dim_school', 'Load dim_school', @step_id OUTPUT;
    BEGIN TRY
        DECLARE @o TABLE (a NVARCHAR(10));
        ;WITH bs AS (
            SELECT school_code,
                   MIN(school_name)                    AS school_name,
                   MIN(school_owner_type)              AS school_owner_type,
                   MIN(COALESCE(school_type_code, -1)) AS stc,
                   MIN(COALESCE(main_school_code, -1)) AS msc
            FROM stg.student_basis
            WHERE school_code IS NOT NULL
            GROUP BY school_code
        ),
        ho AS (
            SELECT school_code,
                   MIN(school_name)                    AS school_name,
                   CAST(NULL AS NVARCHAR(100))         AS school_owner_type,
                   MIN(COALESCE(school_type_code, -1)) AS stc,
                   CAST(-1 AS INT)                     AS msc
            FROM stg.student_history
            WHERE school_code IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM bs b WHERE b.school_code = school_code)
            GROUP BY school_code
        ),
        src AS (
            SELECT school_code, school_name, school_owner_type, stc,
                   CASE
                       -- Hardcoded self-referencing main schools
                       WHEN school_code IN (280628, 821019, 821006) THEN school_code
                       -- Known main schools map to themselves
                       WHEN msc IN (280093, 280094, 280096, 280626, 280627, 280628, 821019, 821006) THEN msc
                       -- All others resolve to -1
                       ELSE -1
                   END AS msc
            FROM bs
            UNION ALL
            SELECT school_code, school_name, school_owner_type, stc,
                   CASE
                       WHEN school_code IN (280628, 821019, 821006) THEN school_code
                       WHEN msc IN (280093, 280094, 280096, 280626, 280627, 280628, 821019, 821006) THEN msc
                       ELSE -1
                   END AS msc
            FROM ho
        )
        MERGE dw.dim_school AS t USING src ON t.school_code = src.school_code
        WHEN MATCHED AND (
            t.school_name      <> src.school_name
            OR ISNULL(t.school_owner, '') <> ISNULL(src.school_owner_type, '')
            OR t.school_type_code         <> src.stc
            OR t.main_school_code         <> src.msc
        ) THEN UPDATE SET
            t.school_name      = src.school_name,
            t.school_owner     = src.school_owner_type,
            t.school_type_code = src.stc,
            t.main_school_code = src.msc
        WHEN NOT MATCHED THEN INSERT (school_code, school_name, school_owner, school_type_code, main_school_code)
            VALUES (src.school_code, src.school_name, src.school_owner_type, src.stc, src.msc)
        OUTPUT $action INTO @o;
        SELECT @ri = COUNT(CASE WHEN a = 'INSERT' THEN 1 END),
               @ru = COUNT(CASE WHEN a = 'UPDATE' THEN 1 END)
        FROM @o;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, @ri, @ru;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        THROW;
    END CATCH;
END;
GO