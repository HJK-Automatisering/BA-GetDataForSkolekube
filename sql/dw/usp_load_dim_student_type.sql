-- =============================================================================
-- dw.usp_load_dim_student_type
-- =============================================================================
-- Loads student type dimension. student_type_code is IDENTITY.
-- Insert-only on new student_type_name values from stg.student_basis.
-- NULL/blank names are handled by sentinel -1 and never inserted.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_dim_student_type
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @ri      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_dim_student_type', 'Load dim_student_type', @step_id OUTPUT;
    BEGIN TRY
        INSERT INTO dw.dim_student_type (student_type_name)
        SELECT DISTINCT student_type_name
        FROM stg.student_basis
        WHERE student_type_name IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM dw.dim_student_type d
              WHERE d.student_type_name = student_type_name
          );
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