-- =============================================================================
-- meta.usp_meta_finish_step
-- =============================================================================
-- Marks an ETL step as finished in meta.meta_run_step.
-- Sets finished_at, status, row counts and optional error_message.
-- =============================================================================

CREATE OR ALTER PROCEDURE meta.usp_meta_finish_step
    @step_id       INT,
    @status        NVARCHAR(10),
    @rows_read     INT            = NULL,
    @rows_inserted INT            = NULL,
    @rows_updated  INT            = NULL,
    @rows_deleted  INT            = NULL,
    @error_message NVARCHAR(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE meta.meta_run_step
    SET finished_at   = SYSUTCDATETIME(),
        status        = @status,
        rows_read     = @rows_read,
        rows_inserted = @rows_inserted,
        rows_updated  = @rows_updated,
        rows_deleted  = @rows_deleted,
        error_message = @error_message
    WHERE step_id = @step_id;
END;
GO