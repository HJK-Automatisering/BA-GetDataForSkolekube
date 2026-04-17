-- =============================================================================
-- dw.usp_load_dim_school_district
-- =============================================================================
-- Loads school district dimension. Static table — insert-only.
-- Known district codes are mapped to Hjørring municipality schools.
-- All other codes resolve to sentinel -1 (Anden kommune).
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_dim_school_district
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @ri      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_dim_school_district', 'Load dim_school_district', @step_id OUTPUT;
    BEGIN TRY
        -- Table is static — no source to merge from.
        -- Sentinel and known districts are inserted once via migration script.
        SET @ri = 0;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, @ri;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        THROW;
    END CATCH;
END;
GO