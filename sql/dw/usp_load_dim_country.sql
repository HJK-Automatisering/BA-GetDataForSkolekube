-- =============================================================================
-- dw.usp_load_dim_country
-- =============================================================================
-- Loads country/birth country dimension from stg.student_basis.
-- MERGE on country_code — inserts new, updates changed name.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_dim_country
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @ri      INT = 0;
    DECLARE @ru      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_dim_country', 'Load dim_country', @step_id OUTPUT;
    BEGIN TRY
        DECLARE @o TABLE (a NVARCHAR(10));
        ;WITH src AS (
            SELECT DISTINCT birth_country_code c, birth_country_name n
            FROM stg.student_basis
            WHERE birth_country_code IS NOT NULL AND birth_country_name IS NOT NULL
        )
        MERGE dw.dim_country AS t USING src ON t.country_code = src.c
        WHEN MATCHED AND t.country_name <> src.n
            THEN UPDATE SET t.country_name = src.n
        WHEN NOT MATCHED
            THEN INSERT (country_code, country_name) VALUES (src.c, src.n)
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