-- =============================================================================
-- dw.usp_refresh_dim_date_school_year_label
-- =============================================================================
-- Updates school_year_label in dw.dim_date.
-- Labels the 5 most recent school years relative to today:
--   Indeværende, Indeværende-1 ... Indeværende-4.
-- All other dates get NULL. Only updates rows where the label
-- has actually changed — keeps @@ROWCOUNT meaningful in meta-log.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_refresh_dim_date_school_year_label
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id INT;
    DECLARE @ru      INT = 0;
    DECLARE @err     NVARCHAR(2000);
    DECLARE @cy      SMALLINT = CASE
        WHEN MONTH(GETDATE()) >= 8 THEN YEAR(GETDATE())
        ELSE YEAR(GETDATE()) - 1
    END;

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_refresh_dim_date_school_year_label', 'Refresh school_year_label', @step_id OUTPUT;
    BEGIN TRY
        ;WITH computed AS (
            SELECT
                date_id,
                school_year_label,
                CASE
                    WHEN MONTH(full_date) >= 8 THEN YEAR(full_date)
                    ELSE YEAR(full_date) - 1
                END AS sy_start
            FROM dw.dim_date
        ),
        labelled AS (
            SELECT
                date_id,
                school_year_label,
                CASE
                    WHEN sy_start = @cy     THEN 'Indeværende'
                    WHEN sy_start = @cy - 1 THEN 'Indeværende-1'
                    WHEN sy_start = @cy - 2 THEN 'Indeværende-2'
                    WHEN sy_start = @cy - 3 THEN 'Indeværende-3'
                    WHEN sy_start = @cy - 4 THEN 'Indeværende-4'
                    ELSE NULL
                END AS new_label
            FROM computed
        )
        UPDATE labelled
        SET school_year_label = new_label
        WHERE ISNULL(school_year_label, '') <> ISNULL(new_label, '');

        SET @ru = @@ROWCOUNT;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, NULL, @ru;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        THROW;
    END CATCH;
END;
GO