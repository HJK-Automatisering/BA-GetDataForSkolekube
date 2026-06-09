# ba-skolekube

ETL-pipeline til daglig indlæsning af elevdata fra Tabulex til Skolekubes data warehouse.

## Indhold

- [Beskrivelse](#beskrivelse)
- [Forudsætninger](#forudsætninger)
- [Opsætning](#opsætning)
- [Kørsel](#kørsel)
- [Docker](#docker)
- [Miljøvariabler](#miljøvariabler)
- [Projektstruktur](#projektstruktur)

## Beskrivelse

Projektet henter daglige udtræk fra Tabulex (elever, fravær, historik og karakterer), indlæser dem i staging-tabeller og eksekverer en master stored procedure i SQL Server-dabasen Skolekube.

Pipelinen kører som en Docker-container og afvikles dagligt på et konfigureret tidspunkt via en indbygget scheduler.

## Forudsætninger

- Python 3.12+
- Docker Desktop
- Adgang til SQL Server (Skolekube)
- Adgang til IstSkole360-filshare

## Opsætning

Klon repositoriet:

```bash
git clone https://github.com/dit-repo/ba-skolekube.git
cd ba-skolekube
```

Opret virtuelt miljø og installér afhængigheder:

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

Kopiér `.env.example` til `.env` og udfyld værdierne:

```bash
cp .env.example .env
```

## Kørsel

Kør direkte med Python:

```bash
python main.py
```

Sæt `RUN_NOW=true` i `.env` for at eksekvere med det samme uden at afvente scheduleren.

Deploy alle stored procedures til databasen:

```bash
python deploy_procedures.py
```

## Docker

Opret eksternt volume (kun første gang):

```bash
docker volume create \
  --driver local \
  --opt type=cifs \
  --opt device="//DIN-SERVER/dit-share" \
  --opt o="addr=DIN-IP,username=BRUGER,password=ADGANGSKODE,domain=DOMÆNE,vers=3.0" \
  filer-istskole360
```

Byg og start container:

```bash
docker compose up --build
```

Stop container:

```bash
docker compose stop
```

## Miljøvariabler

| Variabel | Beskrivelse | Eksempel |
|---|---|---|
| `DB_DRIVER` | ODBC-driver til SQL Server | `ODBC Driver 18 for SQL Server` |
| `DB_SERVER` | Server og port | `0.0.0.0:0000` |
| `DB_NAME` | Databasenavn | `Skolekube` |
| `DB_USERNAME` | Databasebruger | `etl_user` |
| `DB_PASSWORD` | Adgangskode | — |
| `FILE_PATH` | Sti til Tabulex-filer | `/shr/ISTSkole360` |
| `RUN_AT` | Kørselstidspunkt (scheduler) | `04:00` |
| `RUN_NOW` | Kør straks uden scheduler | `false` |

## Projektstruktur

```
BA-Skolekube/
├── sql/
│   ├── dw/
│   │   ├── usp_cleanup.sql
│   │   ├── usp_fill_absence_gaps.sql
│   │   ├── usp_load_dim_citizenship.sql
│   │   ├── usp_load_dim_country.sql
│   │   ├── usp_load_dim_field_name.sql
│   │   ├── usp_load_dim_language.sql
│   │   ├── usp_load_dim_main_school.sql
│   │   ├── usp_load_dim_municipality.sql
│   │   ├── usp_load_dim_school.sql
│   │   ├── usp_load_dim_school_district
│   │   ├── usp_load_dim_school_type.sql
│   │   ├── usp_load_dim_student.sql
│   │   ├── usp_load_dim_student_sensitive.sql
│   │   ├── usp_load_dim_student_type.sql
│   │   ├── usp_load_fact_absence_daily.sql
│   │   ├── usp_load_fact_absence_lesson.sql
│   │   ├── usp_load_fact_enrollment.sql
│   │   ├── usp_load_fact_grade.sql
│   │   ├── usp_load_fact_student_action.sql
│   │   ├── usp_load_fact_student_event.sql
│   │   ├── usp_load_fact_student_field.sql
│   │   ├── usp_load_fact_student_relocation.sql
│   │   ├── usp_load_fact_student_snapshot.sql
│   │   ├── usp_master.sql
│   │   └── usp_refresh_dim_date_school_year_label.sql
│   └── meta/
│       ├── usp_meta_finish_run.sql
│       ├── usp_meta_finish_step.sql
│       ├── usp_meta_start_run.sql
│       └── usp_meta_start_step.sql
├── utils/
│   ├── get_engine.py       # SQLAlchemy engine-opsætning
│   ├── load_stg.py         # Indlæsning af staging-tabeller
│   ├── run_etl.py          # Eksekvering af master stored procedure
│   └── setup_logging.py    # Logkonfiguration
├── constants.py            # Kolonnemapping og filkonstanter
├── main.py                 # Entry point og scheduler
├── deploy_procedures.py    # Deploy alle stored procedures
├── Dockerfile
├── docker-compose.yaml
├── requirements.txt
└── .env.example
```
