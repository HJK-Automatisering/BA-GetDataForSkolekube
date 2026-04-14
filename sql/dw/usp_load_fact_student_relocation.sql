-- =============================================================================
-- dw.usp_load_fact_student_relocation
-- =============================================================================
-- Loads student relocation fact from stg.student_history (row_type 8).
-- Insert-only — no updates.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_fact_student_relocation
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @rr      INT = 0;
    DECLARE @ri      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_fact_student_relocation', 'Load fact_student_relocation', @step_id OUTPUT;
    BEGIN TRY
        SELECT @rr = COUNT(*) FROM stg.student_history WHERE row_type = 8;
        INSERT INTO dw.fact_student_relocation (student_id, municipality_code, relocation_date_id)
        SELECT s.student_id, COALESCE(dm.municipality_code, -1), CAST(h.moved_date AS INT)
        FROM stg.student_history h
        JOIN dw.dim_student_sensitive s  ON s.cpr_nr             = h.cpr_nr
        LEFT JOIN dw.dim_municipality dm ON dm.municipality_code = h.moved_to_mun_code
        WHERE h.row_type = 8 AND h.moved_date IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM dw.fact_student_relocation r
              WHERE r.student_id         = s.student_id
                AND r.relocation_date_id = CAST(h.moved_date AS INT)
          );
        SET @ri = @@ROWCOUNT;
        EXEC meta.usp_meta_finish_step @step_id, 'success', @rr, @ri;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        THROW;
    END CATCH;
END;
GO