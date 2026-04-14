-- =============================================================================
-- dw.usp_load_dim_main_school
-- =============================================================================
-- Loads main school dimension from stg.student_basis.
-- MERGE on main_school_code — inserts new, updates changed name.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_dim_main_school
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @ri      INT = 0;
    DECLARE @ru      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_dim_main_school', 'Load dim_main_school', @step_id OUTPUT;
    BEGIN TRY
        DECLARE @o TABLE (a NVARCHAR(10));
        ;WITH src AS (
            SELECT DISTINCT main_school_code c, main_school_name n
            FROM stg.student_basis
            WHERE main_school_code IS NOT NULL AND main_school_name IS NOT NULL
        )
        MERGE dw.dim_main_school AS t USING src ON t.main_school_code = src.c
        WHEN MATCHED AND t.main_school_name <> src.n
            THEN UPDATE SET t.main_school_name = src.n
        WHEN NOT MATCHED
            THEN INSERT (main_school_code, main_school_name) VALUES (src.c, src.n)
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