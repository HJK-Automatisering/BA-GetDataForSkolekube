-- =============================================================================
-- meta.usp_meta_finish_run
-- =============================================================================
-- Marks an ETL run as finished in meta.meta_run.
-- Sets finished_at, status and optional error_message.
-- =============================================================================

CREATE OR ALTER PROCEDURE meta.usp_meta_finish_run
    @run_id        INT,
    @status        NVARCHAR(10),
    @error_message NVARCHAR(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE meta.meta_run
    SET finished_at    = SYSUTCDATETIME(),
        status         = @status,
        error_message  = @error_message
    WHERE run_id = @run_id;
END;
GO