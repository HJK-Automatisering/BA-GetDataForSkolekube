-- =============================================================================
-- dw.usp_load_fact_student_action
-- =============================================================================
-- Loads student action/tiltag fact from stg.student_history (row_type 5).
-- MERGE on (student_id, action_type_code, from_date_id).
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_fact_student_action
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @rr      INT = 0;
    DECLARE @ri      INT = 0;
    DECLARE @ru      INT = 0;
    DECLARE @err     NVARCHAR(2000);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_fact_student_action', 'Load fact_student_action', @step_id OUTPUT;
    BEGIN TRY
        SELECT @rr = COUNT(*) FROM stg.student_history WHERE row_type = 5;
        DECLARE @o TABLE (a NVARCHAR(10));
        MERGE dw.fact_student_action AS t
        USING (
            SELECT s.student_id,
                COALESCE(dat.action_type_code,     -1) AS atc,
                COALESCE(drr.referral_reason_code, -1) AS rrc,
                CAST(h.valid_from AS INT)              AS fd,
                TRY_CAST(h.valid_to AS INT)            AS td,
                h.hours,
                h.hours_outside
            FROM stg.student_history h
            JOIN dw.dim_student_sensitive s      ON s.cpr_nr                 = h.cpr_nr
            LEFT JOIN dw.dim_action_type     dat ON dat.action_type_code     = TRY_CAST(h.action_type_code    AS INT)
            LEFT JOIN dw.dim_referral_reason drr ON drr.referral_reason_code = TRY_CAST(h.referral_reason_code AS INT)
            WHERE h.row_type = 5 AND h.valid_from IS NOT NULL
        ) AS src ON (t.student_id = src.student_id AND t.action_type_code = src.atc AND t.from_date_id = src.fd)
        WHEN MATCHED AND (
            t.referral_reason_code                <> src.rrc
            OR ISNULL(t.to_date_id,             -1) <> ISNULL(src.td,           -1)
            OR ISNULL(t.hours,                 0.0) <> ISNULL(src.hours,        0.0)
            OR ISNULL(t.hours_outside_teaching,0.0) <> ISNULL(src.hours_outside,0.0)
        ) THEN UPDATE SET
            t.referral_reason_code   = src.rrc,
            t.to_date_id             = src.td,
            t.hours                  = src.hours,
            t.hours_outside_teaching = src.hours_outside
        WHEN NOT MATCHED THEN INSERT (
            student_id, action_type_code, referral_reason_code,
            from_date_id, to_date_id, hours, hours_outside_teaching
        ) VALUES (
            src.student_id, src.atc, src.rrc, src.fd, src.td, src.hours, src.hours_outside
        )
        OUTPUT $action INTO @o;
        SELECT @ri = COUNT(CASE WHEN a = 'INSERT' THEN 1 END),
               @ru = COUNT(CASE WHEN a = 'UPDATE' THEN 1 END)
        FROM @o;
        EXEC meta.usp_meta_finish_step @step_id, 'success', @rr, @ri, @ru;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        THROW;
    END CATCH;
END;
GO