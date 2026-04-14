-- =============================================================================
-- dw.usp_fill_absence_gaps
-- =============================================================================
-- Fills missing absence days by inserting IF rows (absence_value=0.0,
-- lesson=NULL) for dates with zero registrations in fact_absence_daily.
-- Looks back 10 school days including yesterday.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_fill_absence_gaps
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id   INT;
    DECLARE @ri        INT = 0;
    DECLARE @err       NVARCHAR(2000);
    DECLARE @today     DATE = CAST(GETDATE() AS DATE);
    DECLARE @yesterday DATE = DATEADD(DAY, -1, @today);

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_fill_absence_gaps', 'Fill absence gaps', @step_id OUTPUT;
    BEGIN TRY

        CREATE TABLE #school_days (
            school_date DATE NOT NULL PRIMARY KEY,
            date_id     INT  NOT NULL
        );

        INSERT INTO #school_days (school_date, date_id)
        SELECT TOP 10 full_date, date_id
        FROM dw.dim_date
        WHERE full_date <= @yesterday
          AND is_weekend      = 0
          AND is_vacation_day = 0
        ORDER BY full_date DESC;

        CREATE TABLE #missing_days (
            school_date DATE NOT NULL PRIMARY KEY,
            date_id     INT  NOT NULL
        );

        INSERT INTO #missing_days (school_date, date_id)
        SELECT sd.school_date, sd.date_id
        FROM #school_days sd
        WHERE NOT EXISTS (
            SELECT 1 FROM dw.fact_absence_daily f
            WHERE f.date_id = sd.date_id
        );

        CREATE TABLE #to_insert (
            date_id     INT         NOT NULL,
            student_id  INT         NOT NULL,
            school_code INT         NOT NULL,
            grade_level SMALLINT    NULL,
            track       NVARCHAR(2) NULL
        );

        DECLARE @missing_date DATE;
        DECLARE @missing_id   INT;
        DECLARE @source_id    INT;

        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT school_date, date_id FROM #missing_days ORDER BY school_date;

        OPEN cur;
        FETCH NEXT FROM cur INTO @missing_date, @missing_id;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @source_id = NULL;

            SELECT TOP 1 @source_id = sd.date_id
            FROM #school_days sd
            WHERE sd.school_date < @missing_date
              AND EXISTS (
                  SELECT 1 FROM dw.fact_absence_daily f
                  WHERE f.date_id = sd.date_id
              )
            ORDER BY sd.school_date DESC;

            IF @source_id IS NOT NULL
            BEGIN
                INSERT INTO #to_insert (date_id, student_id, school_code, grade_level, track)
                SELECT DISTINCT @missing_id, f.student_id, f.school_code, f.grade_level, f.track
                FROM dw.fact_absence_daily f
                WHERE f.date_id = @source_id;
            END
            ELSE
            BEGIN
                INSERT INTO #to_insert (date_id, student_id, school_code, grade_level, track)
                SELECT @missing_id, ds.student_id, COALESCE(ds.school_code, -1),
                       ds.grade_level, ds.class_track
                FROM dw.dim_student     ds
                JOIN dw.dim_school      dsc ON dsc.school_code     = ds.school_code
                JOIN dw.dim_main_school dm  ON dm.main_school_code = dsc.main_school_code
                WHERE ds.student_id    <> -1
                  AND dm.include_absence = 1;
            END;

            FETCH NEXT FROM cur INTO @missing_date, @missing_id;
        END;

        CLOSE cur;
        DEALLOCATE cur;

        INSERT INTO dw.fact_absence_daily (
            student_id, absence_reason_code, date_id, school_code,
            grade_level, track, absence_value, lesson
        )
        SELECT t.student_id, 'IF', t.date_id, t.school_code,
               t.grade_level, t.track, 0.0, NULL
        FROM #to_insert t
        WHERE NOT EXISTS (
            SELECT 1 FROM dw.fact_absence_daily f
            WHERE f.student_id  = t.student_id
              AND f.date_id     = t.date_id
              AND f.school_code = t.school_code
        );

        SET @ri = @@ROWCOUNT;

        DROP TABLE #to_insert;
        DROP TABLE #missing_days;
        DROP TABLE #school_days;

        EXEC meta.usp_meta_finish_step @step_id, 'success', NULL, @ri;

    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#to_insert')    IS NOT NULL DROP TABLE #to_insert;
        IF OBJECT_ID('tempdb..#missing_days') IS NOT NULL DROP TABLE #missing_days;
        IF OBJECT_ID('tempdb..#school_days')  IS NOT NULL DROP TABLE #school_days;
        SET @err = ERROR_MESSAGE();
        EXEC meta.usp_meta_finish_step @step_id, 'failed', NULL, NULL, NULL, NULL, @err;
        THROW;
    END CATCH;
END;
GO