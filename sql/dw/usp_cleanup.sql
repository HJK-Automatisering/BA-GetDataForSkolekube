-- =============================================================================
-- dw.usp_cleanup
-- =============================================================================
-- Removes all fact and dimension data for students not seen within the
-- last 5 school years, based on last_seen in dim_student_sensitive.
-- Iterates over all fact tables and both dim_student tables.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_cleanup
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id     INT;
    DECLARE @rd          INT;
    DECLARE @err         NVARCHAR(2000);
    DECLARE @cy          SMALLINT = CASE
        WHEN MONTH(GETDATE()) >= 8 THEN YEAR(GETDATE())
        ELSE YEAR(GETDATE()) - 1
    END;
    DECLARE @cutoff_year     SMALLINT     = @cy - 5;
    DECLARE @cutoff_skoleaar NVARCHAR(9)  =
        CAST(@cutoff_year AS NVARCHAR(4)) + '/' + CAST(@cutoff_year + 1 AS NVARCHAR(4));

    -- Students not seen since cutoff school year
    CREATE TABLE #udgaaede (student_id INT NOT NULL PRIMARY KEY);
    INSERT INTO #udgaaede (student_id)
    SELECT student_id FROM dw.dim_student_sensitive
    WHERE student_id <> -1
      AND (last_seen IS NULL OR last_seen < @cutoff_skoleaar);

    EXEC meta.usp_meta_start_step @run_id, 'dw.usp_cleanup', 'Cleanup fact_absence_daily', @step_id OUTPUT;
    BEGIN TRY
        DELETE f FROM dw.fact_absence_daily f JOIN #udgaaede u ON u.student_id = f.student_id;
        SET @rd = @@ROWCOUNT;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, NULL, NULL, @rd;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        DROP TABLE #udgaaede; THROW;
    END CATCH;

    EXEC meta.usp_meta_start_step @run_id, 'dw.usp_cleanup', 'Cleanup fact_absence_lesson', @step_id OUTPUT;
    BEGIN TRY
        DELETE f FROM dw.fact_absence_lesson f JOIN #udgaaede u ON u.student_id = f.student_id;
        SET @rd = @@ROWCOUNT;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, NULL, NULL, @rd;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        DROP TABLE #udgaaede; THROW;
    END CATCH;

    EXEC meta.usp_meta_start_step @run_id, 'dw.usp_cleanup', 'Cleanup fact_grade', @step_id OUTPUT;
    BEGIN TRY
        DELETE f FROM dw.fact_grade f JOIN #udgaaede u ON u.student_id = f.student_id;
        SET @rd = @@ROWCOUNT;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, NULL, NULL, @rd;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        DROP TABLE #udgaaede; THROW;
    END CATCH;

    EXEC meta.usp_meta_start_step @run_id, 'dw.usp_cleanup', 'Cleanup fact_enrollment', @step_id OUTPUT;
    BEGIN TRY
        DELETE f FROM dw.fact_enrollment f JOIN #udgaaede u ON u.student_id = f.student_id;
        SET @rd = @@ROWCOUNT;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, NULL, NULL, @rd;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        DROP TABLE #udgaaede; THROW;
    END CATCH;

    EXEC meta.usp_meta_start_step @run_id, 'dw.usp_cleanup', 'Cleanup fact_student_action', @step_id OUTPUT;
    BEGIN TRY
        DELETE f FROM dw.fact_student_action f JOIN #udgaaede u ON u.student_id = f.student_id;
        SET @rd = @@ROWCOUNT;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, NULL, NULL, @rd;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        DROP TABLE #udgaaede; THROW;
    END CATCH;

    EXEC meta.usp_meta_start_step @run_id, 'dw.usp_cleanup', 'Cleanup fact_student_event', @step_id OUTPUT;
    BEGIN TRY
        DELETE f FROM dw.fact_student_event f JOIN #udgaaede u ON u.student_id = f.student_id;
        SET @rd = @@ROWCOUNT;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, NULL, NULL, @rd;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        DROP TABLE #udgaaede; THROW;
    END CATCH;

    EXEC meta.usp_meta_start_step @run_id, 'dw.usp_cleanup', 'Cleanup fact_student_relocation', @step_id OUTPUT;
    BEGIN TRY
        DELETE f FROM dw.fact_student_relocation f JOIN #udgaaede u ON u.student_id = f.student_id;
        SET @rd = @@ROWCOUNT;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, NULL, NULL, @rd;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        DROP TABLE #udgaaede; THROW;
    END CATCH;

    EXEC meta.usp_meta_start_step @run_id, 'dw.usp_cleanup', 'Cleanup fact_student_field', @step_id OUTPUT;
    BEGIN TRY
        DELETE f FROM dw.fact_student_field f JOIN #udgaaede u ON u.student_id = f.student_id;
        SET @rd = @@ROWCOUNT;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, NULL, NULL, @rd;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        DROP TABLE #udgaaede; THROW;
    END CATCH;

    EXEC meta.usp_meta_start_step @run_id, 'dw.usp_cleanup', 'Cleanup fact_student_snapshot', @step_id OUTPUT;
    BEGIN TRY
        DELETE f FROM dw.fact_student_snapshot f JOIN #udgaaede u ON u.student_id = f.student_id;
        SET @rd = @@ROWCOUNT;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, NULL, NULL, @rd;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        DROP TABLE #udgaaede; THROW;
    END CATCH;

    EXEC meta.usp_meta_start_step @run_id, 'dw.usp_cleanup', 'Cleanup udgåede elever', @step_id OUTPUT;
    BEGIN TRY
        DELETE d FROM dw.dim_student           d JOIN #udgaaede u ON u.student_id = d.student_id;
        DELETE d FROM dw.dim_student_sensitive d JOIN #udgaaede u ON u.student_id = d.student_id;
        SET @rd = (SELECT COUNT(*) FROM #udgaaede);
        DROP TABLE #udgaaede;
        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, NULL, NULL, @rd;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#udgaaede') IS NOT NULL DROP TABLE #udgaaede;
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        THROW;
    END CATCH;
END;
GO