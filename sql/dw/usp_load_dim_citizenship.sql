-- =============================================================================
-- dw.usp_load_dim_citizenship
-- =============================================================================
-- Loads citizenship dimension from stg.student_basis.
-- MERGE on citizenship_code — inserts new, updates changed name.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_dim_citizenship
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @ri      INT = 0;
    DECLARE @ru      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_dim_citizenship', 'Load dim_citizenship', @step_id OUTPUT;
    BEGIN TRY
        DECLARE @o TABLE (a NVARCHAR(10));
        ;WITH src AS (
            SELECT DISTINCT nationality_code c, nationality_name n
            FROM stg.student_basis
            WHERE nationality_code IS NOT NULL AND nationality_name IS NOT NULL
        )
        MERGE dw.dim_citizenship AS t USING src ON t.citizenship_code = src.c
        WHEN MATCHED AND t.citizenship_name <> src.n
            THEN UPDATE SET t.citizenship_name = src.n
        WHEN NOT MATCHED
            THEN INSERT (citizenship_code, citizenship_name) VALUES (src.c, src.n)
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