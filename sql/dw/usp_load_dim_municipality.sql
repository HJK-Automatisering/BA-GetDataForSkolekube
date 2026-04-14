-- =============================================================================
-- dw.usp_load_dim_municipality
-- =============================================================================
-- Loads municipality dimension from stg.student_basis.
-- Combines municipality_code and paying_mun_code into one dimension.
-- MERGE on municipality_code — inserts new, updates changed name.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_dim_municipality
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @ri      INT = 0;
    DECLARE @ru      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_dim_municipality', 'Load dim_municipality', @step_id OUTPUT;
    BEGIN TRY
        DECLARE @o TABLE (a NVARCHAR(10));
        ;WITH src AS (
            SELECT DISTINCT municipality_code AS c, municipality_name AS n
            FROM stg.student_basis
            WHERE municipality_code IS NOT NULL AND municipality_name IS NOT NULL
            UNION
            SELECT DISTINCT paying_mun_code, paying_mun_name
            FROM stg.student_basis
            WHERE paying_mun_code IS NOT NULL AND paying_mun_name IS NOT NULL
        )
        MERGE dw.dim_municipality AS t USING src ON t.municipality_code = src.c
        WHEN MATCHED AND t.municipality_name <> src.n
            THEN UPDATE SET t.municipality_name = src.n
        WHEN NOT MATCHED
            THEN INSERT (municipality_code, municipality_name) VALUES (src.c, src.n)
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