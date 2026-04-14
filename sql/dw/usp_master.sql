-- =============================================================================
-- dw.usp_master
-- =============================================================================
-- Master ETL orchestrator. Executes all steps in dependency order.
-- Called daily by the Python pipeline via EXEC dw.usp_master.
-- Uses SET ANSI_WARNINGS OFF to suppress SQL Server warnings
-- that would otherwise surface as errors through pyodbc.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_master
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_WARNINGS OFF;
    DECLARE @run_id INT;
    DECLARE @err    NVARCHAR(2000);
    EXEC meta.usp_meta_start_run @run_id = @run_id OUTPUT;
    BEGIN TRY
        EXEC dw.usp_cleanup                                    @run_id = @run_id;
        EXEC dw.usp_fill_absence_gaps                          @run_id = @run_id;
        EXEC dw.usp_refresh_dim_date_school_year_label         @run_id = @run_id;
        EXEC dw.usp_load_dim_municipality                      @run_id = @run_id;
        EXEC dw.usp_load_dim_school_type                       @run_id = @run_id;
        EXEC dw.usp_load_dim_main_school                       @run_id = @run_id;
        EXEC dw.usp_load_dim_school                            @run_id = @run_id;
        EXEC dw.usp_load_dim_student_type                      @run_id = @run_id;
        EXEC dw.usp_load_dim_citizenship                       @run_id = @run_id;
        EXEC dw.usp_load_dim_country                           @run_id = @run_id;
        EXEC dw.usp_load_dim_language                          @run_id = @run_id;
        EXEC dw.usp_load_dim_student_sensitive                 @run_id = @run_id;
        EXEC dw.usp_load_dim_student                           @run_id = @run_id;
        EXEC dw.usp_load_dim_field_name                        @run_id = @run_id;
        EXEC dw.usp_load_fact_enrollment                       @run_id = @run_id;
        EXEC dw.usp_load_fact_student_action                   @run_id = @run_id;
        EXEC dw.usp_load_fact_student_event                    @run_id = @run_id;
        EXEC dw.usp_load_fact_student_field                    @run_id = @run_id;
        EXEC dw.usp_load_fact_student_relocation               @run_id = @run_id;
        EXEC dw.usp_load_fact_absence_daily                    @run_id = @run_id;
        EXEC dw.usp_load_fact_absence_lesson                   @run_id = @run_id;
        EXEC dw.usp_load_fact_grade                            @run_id = @run_id;
        EXEC dw.usp_load_fact_student_snapshot                 @run_id = @run_id;
        EXEC meta.usp_meta_finish_run @run_id = @run_id, @status = 'success';
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_run @run_id = @run_id, @status = 'failed', @error_message = @err;
        THROW;
    END CATCH;
END;
GO