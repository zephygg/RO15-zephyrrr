Greetings!
This DB is about a videogame and it's tournament circuit - VALORANT and Valorant Champions Tour (VCT).
The schema is called "vct" in the database.
Before running the file 02_final.sql, you must run the code below, whilst being connected to default "postgres" database, and it will create DB called vct_db.

DROP DATABASE IF EXISTS vct_db;
CREATE DATABASE vct_db;

Afterwards, you can connect to the DB by running " \c vct_db " in psql.
The database contains real data of:
- Teams;
- Players;
- Matches, their scores, and times;
- Player statistics for the latest tournament, including K/D calculated using formula.
The data has been taken from sources vlr.gg, liquipedia, and escharts.com and is true for the time of writing this file.