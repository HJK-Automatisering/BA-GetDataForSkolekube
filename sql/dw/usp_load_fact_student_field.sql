-- =============================================================================
-- dw.usp_load_fact_student_field
-- =============================================================================
-- Loads student field/value fact from stg.student_history (row_type 7).
-- MERGE on (student_id, field_name) — updates field_value if changed.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_fact_student_field
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
        @run_id, 'dw.usp_load_fact_student_field', 'Load fact_student_field', @step_id OUTPUT;
    BEGIN TRY
        SELECT @rr = COUNT(*) FROM stg.student_history WHERE row_type = 7;
        DECLARE @o TABLE (a NVARCHAR(10));
        MERGE dw.fact_student_field AS t
        USING (
            SELECT s.student_id, dfn.field_name, h.field_value
            FROM stg.student_history h
            JOIN dw.dim_student_sensitive s  ON s.cpr_nr       = h.cpr_nr
            JOIN dw.dim_field_name       dfn ON dfn.field_name = h.field_name
            WHERE h.row_type = 7 AND h.field_name IS NOT NULL
        ) AS src ON (t.student_id = src.student_id AND t.field_name = src.field_name)
        WHEN MATCHED AND ISNULL(t.field_value, '') <> ISNULL(src.field_value, '')
            THEN UPDATE SET t.field_value = src.field_value
        WHEN NOT MATCHED
            THEN INSERT (student_id, field_name, field_value)
                 VALUES (src.student_id, src.field_name, src.field_value)
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