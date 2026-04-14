-- =============================================================================
-- meta.usp_meta_start_step
-- =============================================================================
-- Inserts a new step record into meta.meta_run_step with status = running.
-- Returns the generated step_id via OUTPUT parameter.
-- =============================================================================

CREATE OR ALTER PROCEDURE meta.usp_meta_start_step
    @run_id         INT,
    @procedure_name NVARCHAR(200),
    @step_name      NVARCHAR(200),
    @step_id        INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO meta.meta_run_step (run_id, procedure_name, step_name, status)
    VALUES (@run_id, @procedure_name, @step_name, 'running');
    SET @step_id = SCOPE_IDENTITY();
END;
GO