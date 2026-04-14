-- =============================================================================
-- dw.usp_load_dim_school_type
-- =============================================================================
-- Loads school type dimension from stg.student_basis and stg.student_history.
-- Insert-only — no updates. Unknown types get a generated name.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_dim_school_type
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @ri      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_dim_school_type', 'Load dim_school_type', @step_id OUTPUT;
    BEGIN TRY
        ;WITH bs AS (
            SELECT DISTINCT school_type_code c, school_type_name n
            FROM stg.student_basis
            WHERE school_type_code IS NOT NULL AND school_type_name IS NOT NULL
        ),
        ho AS (
            SELECT DISTINCT school_type_code c
            FROM stg.student_history
            WHERE school_type_code IS NOT NULL AND school_type_code > 0
              AND NOT EXISTS (SELECT 1 FROM bs WHERE bs.c = school_type_code)
        ),
        src AS (
            SELECT c, n FROM bs
            UNION ALL
            SELECT c, 'Skoletype ' + CAST(c AS NVARCHAR(10)) FROM ho
        )
        INSERT INTO dw.dim_school_type (school_type_code, school_type_name)
        SELECT src.c, src.n FROM src
        WHERE NOT EXISTS (SELECT 1 FROM dw.dim_school_type d WHERE d.school_type_code = src.c);
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