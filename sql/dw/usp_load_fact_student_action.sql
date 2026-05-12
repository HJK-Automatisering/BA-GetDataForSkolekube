-- =============================================================================
-- dw.usp_load_fact_student_action
-- =============================================================================
-- Loads student action/tiltag fact from stg.student_history (row_type 5).
-- Truncates and reloads from full daily extract — no MERGE needed.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_fact_student_action
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @rr      INT = 0;
    DECLARE @ri      INT = 0;
    DECLARE @rd      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_fact_student_action', 'Load fact_student_action', @step_id OUTPUT;
    BEGIN TRY
        SELECT @rr = COUNT(*) FROM stg.student_history WHERE row_type = 5;

        DELETE FROM dw.fact_student_action;
        SET @rd = @@ROWCOUNT;

        INSERT INTO dw.fact_student_action (
            student_id, action_type_code, referral_reason_code,
            from_date_id, to_date_id, hours, hours_outside_teaching
        )
        SELECT
            s.student_id,
            COALESCE(dat.action_type_code,     -1),
            COALESCE(drr.referral_reason_code, -1),
            CAST(h.valid_from AS INT),
            TRY_CAST(h.valid_to AS INT),
            h.hours,
            h.hours_outside
        FROM stg.student_history h
        JOIN dw.dim_student_sensitive s      ON s.cpr_nr                 = h.cpr_nr
        LEFT JOIN dw.dim_action_type     dat ON dat.action_type_code     = TRY_CAST(h.action_type_code    AS INT)
        LEFT JOIN dw.dim_referral_reason drr ON drr.referral_reason_code = TRY_CAST(h.referral_reason_code AS INT)
        WHERE h.row_type = 5 AND h.valid_from IS NOT NULL;

        SET @ri = @@ROWCOUNT;
        EXEC meta.usp_meta_finish_step @step_id, 'success', @rr, @ri, NULL, @rd;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        THROW;
    END CATCH;
END;
GO