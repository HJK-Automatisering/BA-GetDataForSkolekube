-- =============================================================================
-- dw.usp_load_dim_student_sensitive
-- =============================================================================
-- Loads sensitive student data from stg.student_basis.
-- Includes: name, uni_login, birth_date, gender, address,
-- parent CPR, parent names, nationalities and custody.
-- MERGE on cpr_nr. Updates last_seen every run for GDPR tracking.
-- =============================================================================

CREATE OR ALTER PROCEDURE dw.usp_load_dim_student_sensitive
    @run_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_id  INT;
    DECLARE @rr       INT = 0;
    DECLARE @ri       INT = 0;
    DECLARE @ru       INT = 0;
    DECLARE @err      NVARCHAR(2000);
    DECLARE @skoleaar NVARCHAR(9) = CASE
        WHEN MONTH(GETDATE()) >= 8
            THEN CAST(YEAR(GETDATE()) AS NVARCHAR(4)) + '/' + CAST(YEAR(GETDATE()) + 1 AS NVARCHAR(4))
        ELSE
            CAST(YEAR(GETDATE()) - 1 AS NVARCHAR(4)) + '/' + CAST(YEAR(GETDATE()) AS NVARCHAR(4))
    END;

    EXEC meta.usp_meta_start_step
        @run_id, 'dw.usp_load_dim_student_sensitive', 'Load dim_student_sensitive', @step_id OUTPUT;
    BEGIN TRY
        SELECT @rr = COUNT(*) FROM stg.student_basis;
        DECLARE @o TABLE (a NVARCHAR(10));
        MERGE dw.dim_student_sensitive AS t
        USING (
            SELECT
                cpr_nr,
                first_name,
                last_name,
                uni_login,
                TRY_CONVERT(DATE, birth_date) AS birth_date,
                gender,
                father_cpr,
                mother_cpr,
                address_line1,
                address_line2,
                postal_code,
                city_name,
                secret_address,
                father_first_name,
                father_last_name,
                mother_first_name,
                mother_last_name,
                father_nationality,
                father_birth_country,
                father_custody,
                mother_nationality,
                mother_birth_country,
                mother_custody
            FROM stg.student_basis
            WHERE cpr_nr IS NOT NULL
        ) AS src ON t.cpr_nr = src.cpr_nr
        WHEN MATCHED AND (
            ISNULL(t.first_name,          '') <> ISNULL(src.first_name,          '')
            OR ISNULL(t.last_name,           '') <> ISNULL(src.last_name,           '')
            OR ISNULL(t.uni_login,           '') <> ISNULL(src.uni_login,           '')
            OR ISNULL(t.birth_date, '19000101') <> ISNULL(src.birth_date, '19000101')
            OR ISNULL(t.gender,              '') <> ISNULL(src.gender,              '')
            OR ISNULL(t.father_cpr,          '') <> ISNULL(src.father_cpr,          '')
            OR ISNULL(t.mother_cpr,          '') <> ISNULL(src.mother_cpr,          '')
            OR ISNULL(t.address_line1,       '') <> ISNULL(src.address_line1,       '')
            OR ISNULL(t.address_line2,       '') <> ISNULL(src.address_line2,       '')
            OR ISNULL(t.postal_code,         '') <> ISNULL(src.postal_code,         '')
            OR ISNULL(t.city_name,           '') <> ISNULL(src.city_name,           '')
            OR ISNULL(t.secret_address,      '') <> ISNULL(src.secret_address,      '')
            OR ISNULL(t.father_first_name,   '') <> ISNULL(src.father_first_name,   '')
            OR ISNULL(t.father_last_name,    '') <> ISNULL(src.father_last_name,    '')
            OR ISNULL(t.mother_first_name,   '') <> ISNULL(src.mother_first_name,   '')
            OR ISNULL(t.mother_last_name,    '') <> ISNULL(src.mother_last_name,    '')
            OR ISNULL(t.father_nationality,  '') <> ISNULL(src.father_nationality,  '')
            OR ISNULL(t.father_birth_country,'') <> ISNULL(src.father_birth_country,'')
            OR ISNULL(t.father_custody,      '') <> ISNULL(src.father_custody,      '')
            OR ISNULL(t.mother_nationality,  '') <> ISNULL(src.mother_nationality,  '')
            OR ISNULL(t.mother_birth_country,'') <> ISNULL(src.mother_birth_country,'')
            OR ISNULL(t.mother_custody,      '') <> ISNULL(src.mother_custody,      '')
            OR t.last_seen <> @skoleaar
        ) THEN UPDATE SET
            t.first_name           = src.first_name,
            t.last_name            = src.last_name,
            t.uni_login            = src.uni_login,
            t.birth_date           = src.birth_date,
            t.gender               = src.gender,
            t.father_cpr           = src.father_cpr,
            t.mother_cpr           = src.mother_cpr,
            t.address_line1        = src.address_line1,
            t.address_line2        = src.address_line2,
            t.postal_code          = src.postal_code,
            t.city_name            = src.city_name,
            t.secret_address       = src.secret_address,
            t.father_first_name    = src.father_first_name,
            t.father_last_name     = src.father_last_name,
            t.mother_first_name    = src.mother_first_name,
            t.mother_last_name     = src.mother_last_name,
            t.father_nationality   = src.father_nationality,
            t.father_birth_country = src.father_birth_country,
            t.father_custody       = src.father_custody,
            t.mother_nationality   = src.mother_nationality,
            t.mother_birth_country = src.mother_birth_country,
            t.mother_custody       = src.mother_custody,
            t.last_seen            = @skoleaar
        WHEN NOT MATCHED THEN INSERT (
            cpr_nr, first_name, last_name, uni_login,
            birth_date, gender,
            father_cpr, mother_cpr,
            address_line1, address_line2, postal_code, city_name, secret_address,
            father_first_name, father_last_name, mother_first_name, mother_last_name,
            father_nationality, father_birth_country, father_custody,
            mother_nationality, mother_birth_country, mother_custody,
            last_seen
        ) VALUES (
            src.cpr_nr, src.first_name, src.last_name, src.uni_login,
            src.birth_date, src.gender,
            src.father_cpr, src.mother_cpr,
            src.address_line1, src.address_line2, src.postal_code, src.city_name, src.secret_address,
            src.father_first_name, src.father_last_name, src.mother_first_name, src.mother_last_name,
            src.father_nationality, src.father_birth_country, src.father_custody,
            src.mother_nationality, src.mother_birth_country, src.mother_custody,
            @skoleaar
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