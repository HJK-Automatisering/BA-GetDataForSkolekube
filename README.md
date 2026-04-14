# BA-GetDataForSkolekube

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

Projektet henter daglige udtræk fra Tabulex (elever, fravær, historik og karakterer), indlæser dem i staging-tabeller og eksekverer en master stored procedure i SQL Server-datawarehouseét Skolekube.

Pipelinen kører som en Docker-container og afvikles dagligt på et konfigureret tidspunkt via en indbygget scheduler.

## Forudsætninger

- Python 3.12+
- Docker Desktop
- Adgang til SQL Server (Skolekube)
- Adgang til IstSkole360-filshare

## Opsætning

Klon repositoriet:

```bash
git clone https://github.com/dit-repo/BA-GetDataForSkolekube.git
cd BA-GetDataForSkolekube
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
| `DB_SERVER` | Server og port | `0:0:0:0:0000` |
| `DB_NAME` | Databasenavn | `Skolekube` |
| `DB_USERNAME` | Databasebruger | `etl_user` |
| `DB_PASSWORD` | Adgangskode | — |
| `FILE_PATH` | Sti til Tabulex-filer | `/shr/ISTSkole360` |
| `RUN_AT` | Kørselstidspunkt (scheduler) | `04:00` |
| `RUN_NOW` | Kør straks uden scheduler | `false` |

## Projektstruktur

```
BA-GetDataForSkolekube/
├── utils/
│   ├── get_engine.py       # SQLAlchemy engine-opsætning
│   ├── load_stg.py         # Indlæsning af staging-tabeller
│   ├── run_etl.py          # Eksekvering af master stored procedure
│   ├── setup_logging.py    # Logkonfiguration
│   └── should_run.py       # Skoledagstjek mod dim_date
├── constants.py            # Kolonnemapping og filkonstanter
├── main.py                 # Entry point og scheduler
├── Dockerfile
├── docker-compose.yaml
├── requirements.txt
└── .env.example
```
