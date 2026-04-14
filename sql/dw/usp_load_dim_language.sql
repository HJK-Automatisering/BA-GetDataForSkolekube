-- =============================================================================
-- dw.usp_load_dim_language
-- =============================================================================
-- Loads language/mother tongue dimension from stg.student_basis.
-- MERGE on language_code — inserts new, updates changed name.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_dim_language
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @ri      INT = 0;
    DECLARE @ru      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_dim_language', 'Load dim_language', @step_id OUTPUT;
    BEGIN TRY
        DECLARE @o TABLE (a NVARCHAR(10));
        ;WITH src AS (
            SELECT DISTINCT mother_tongue_code c, mother_tongue_name n
            FROM stg.student_basis
            WHERE mother_tongue_code IS NOT NULL AND mother_tongue_name IS NOT NULL
        )
        MERGE dw.dim_language AS t USING src ON t.language_code = src.c
        WHEN MATCHED AND t.language_name <> src.n
            THEN UPDATE SET t.language_name = src.n
        WHEN NOT MATCHED
            THEN INSERT (language_code, language_name) VALUES (src.c, src.n)
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