-- =============================================================================
-- meta.usp_meta_start_run
-- =============================================================================
-- Inserts a new run record into meta.meta_run with status = running.
-- Returns the generated run_id via OUTPUT parameter.
-- =============================================================================

CREATE OR ALTER PROCEDURE meta.usp_meta_start_run
    @run_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO meta.meta_run (status) VALUES ('running');
    SET @run_id = SCOPE_IDENTITY();
END;
GO