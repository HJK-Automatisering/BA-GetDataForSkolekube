-- =============================================================================
-- dw.usp_load_fact_student_event
-- =============================================================================
-- Loads student event fact from stg.student_history (row_type 6).
-- Insert-only — no updates.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_fact_student_event
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @rr      INT = 0;
    DECLARE @ri      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_fact_student_event', 'Load fact_student_event', @step_id OUTPUT;
    BEGIN TRY
        SELECT @rr = COUNT(*) FROM stg.student_history WHERE row_type = 6;
        INSERT INTO dw.fact_student_event (student_id, event_type_code, date_id)
        SELECT s.student_id, COALESCE(det.event_type_code, -1), CAST(h.event_date AS INT)
        FROM stg.student_history h
        JOIN dw.dim_student_sensitive s   ON s.cpr_nr            = h.cpr_nr
        LEFT JOIN dw.dim_event_type   det ON det.event_type_code = h.event_type_code
        WHERE h.row_type = 6 AND h.event_date IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM dw.fact_student_event e
              WHERE e.student_id      = s.student_id
                AND e.event_type_code = COALESCE(det.event_type_code, -1)
                AND e.date_id         = CAST(h.event_date AS INT)
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