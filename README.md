# daas_db

## Project

Refrence of DaaS Project - https://github.com/nealrout/daas_docs
## Description

This project contains the liquibase scripts to build and underlying PostgreSQL daas database.  This database stores facility, asset, etc. information for DaaS that will be fetched through Django apis.  We are adding functions and procedures so we can control the CRUD operations at the DBMS level.


## Table of Contents

- [Requirements](#requirements)
- [Miscellaneous](#miscellaneous)
- [Usage](#usage)
- [Features](#features)
- [Contact](#contact)

## Requirements
PostgreSQL - https://www.postgresql.org/download/

Liquibase CLI (open source)- https://www.liquibase.com/download
## Miscellaneous
For postgresql anonymous blocks to work we have to make the following substitutions in the .sql files

- From
  - '
- To
  - ''
- From
  - \$$
- To
  - '

## Usage
If the DaaS database does not exist yet, you must create it with a password that you must update. 

    CREATE ROLE daas WITH login PASSWORD 'UPDATEME';
    CREATE DATABASE us_dev_daas OWNER daas;
    CREATE DATABASE us_int_daas OWNER daas;

    GRANT ALL PRIVILEGES ON
    DATABASE us_dev_daas TO daas;
    GRANT ALL PRIVILEGES ON
    DATABASE us_int_daas TO daas;
    
    CREATE SCHEMA daas;
    ALTER SCHEMA daas OWNER TO daas;

    -- Turn on feature citext for index friendly case-insensitive joins (things like status_code)
    CREATE EXTENSION IF NOT EXISTS citext;

#
    Initialization
        liquibase update --url=jdbc:postgresql://localhost:5432/us_dev_daas --contexts=init --username=UPDATEME --password=UPDATEME
        liquibase update --url=jdbc:postgresql://localhost:5432/us_int_daas --contexts=init --username=UPDATEME --password=UPDATEME

    Migration
        liquibase update --contexts=update --username=UPDATEME --password=UPDATEME


## Features
- Facility table
- Asset table and functions to allow DBMS control over CRUD operations.

## Contact
Neal Routson  
nroutson@gmail.com
