-- =============================================================================
-- dw.usp_load_dim_field_name
-- =============================================================================
-- Loads field name dimension from stg.student_history (row_type 7).
-- Insert-only — no updates.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_dim_field_name
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @ri      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_dim_field_name', 'Load dim_field_name', @step_id OUTPUT;
    BEGIN TRY
        INSERT INTO dw.dim_field_name (field_name, description)
        SELECT DISTINCT field_name, NULL
        FROM stg.student_history
        WHERE row_type = 7 AND field_name IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM dw.dim_field_name d WHERE d.field_name = field_name);
        SET @ri = @@ROWCOUNT;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, @ri;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        THROW;
    END CATCH;
END;
GO