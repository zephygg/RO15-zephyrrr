-- ============================================================
-- VALORANT VCT DATABASE
-- PostgreSQL Script
-- 02_final.sql — schema + data, fully merged and re-runnable
-- Read README.md before using the DB for correct results
-- ============================================================

-- (run this block manually in psql or pgAdmin connected to the default 'postgres' db, NOT inside a transaction)
-- DROP DATABASE IF EXISTS vct_db;
-- CREATE DATABASE vct_db;
DROP SCHEMA IF EXISTS vct CASCADE;
CREATE SCHEMA IF NOT EXISTS vct;
SET search_path TO vct;
-- ============================================================
-- PART 2.1: DROP (reverse FK order)
-- ============================================================

DROP TABLE IF EXISTS player_stats        CASCADE;
DROP TABLE IF EXISTS match_maps          CASCADE;
DROP TABLE IF EXISTS matches             CASCADE;
DROP TABLE IF EXISTS tournament_teams    CASCADE;
DROP TABLE IF EXISTS tournaments         CASCADE;
DROP TABLE IF EXISTS tournament_types    CASCADE;
DROP TABLE IF EXISTS team_players        CASCADE;
DROP TABLE IF EXISTS team_coaches        CASCADE;
DROP TABLE IF EXISTS coaches             CASCADE;
DROP TABLE IF EXISTS players             CASCADE;
DROP TABLE IF EXISTS teams               CASCADE;
DROP TABLE IF EXISTS organisers          CASCADE;
DROP TABLE IF EXISTS maps                CASCADE;
DROP TABLE IF EXISTS agents              CASCADE;

-- ============================================================
-- PART 2.2: CREATE & CONSTRAINTS
-- ============================================================

-- independent tables

CREATE TABLE IF NOT EXISTS tournament_types (
    tournament_type_id  SERIAL          PRIMARY KEY,
    tournament_type     VARCHAR(50)     NOT NULL
);

CREATE TABLE IF NOT EXISTS organisers (
    organiser_id    SERIAL          PRIMARY KEY,
    organiser_name  VARCHAR(100)    NOT NULL,
    country         VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS maps (
    map_id      SERIAL          PRIMARY KEY,
    map_name    VARCHAR(50)     NOT NULL,
    date_added  DATE			CHECK (date_added > '2020-06-01') --  VALORANT release date
);

CREATE TABLE IF NOT EXISTS agents (
    agent_id    SERIAL          PRIMARY KEY,
    agent_name  VARCHAR(50)     UNIQUE NOT NULL,
    agent_added DATE,
    role        VARCHAR(50)     NOT NULL CHECK (role IN ('Duelist', 'Controller', 'Sentinel', 'Initiator')),-- e.g. Duelist, Controller, Sentinel, Initiator
	is_available BOOL NOT NULL
);

CREATE TABLE IF NOT EXISTS teams (
    team_id     SERIAL          PRIMARY KEY,
    team_name   VARCHAR(100)    NOT NULL,
    country     VARCHAR(50),
    region      VARCHAR(50),
    date_joined DATE			CHECK (date_joined > '2020-06-01') -- Valorant Release date
);

CREATE TABLE IF NOT EXISTS players (
    player_id       SERIAL          PRIMARY KEY,
    first_name      VARCHAR(50)     NOT NULL,
    last_name       VARCHAR(50)     NOT NULL,
    nickname        VARCHAR(50),
    country         VARCHAR(50),
    date_of_birth   DATE,
    role            VARCHAR(50),    -- e.g. IGL, Entry, Support
    is_active       BOOLEAN         DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS coaches (
    coach_id        SERIAL          PRIMARY KEY,
    first_name      VARCHAR(50)     NOT NULL,
    last_name       VARCHAR(50)     NOT NULL,
    nickname        VARCHAR(50),
    country         VARCHAR(50),
    date_of_birth   DATE,
    is_active       BOOLEAN         DEFAULT TRUE
);

-- junction / dependent tables

CREATE TABLE IF NOT EXISTS team_players (
    team_id     INT     NOT NULL REFERENCES teams(team_id)   ON DELETE CASCADE,
    player_id   INT     NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
    date_joined DATE,
    date_left   DATE,           -- NULL = currently active
    PRIMARY KEY (team_id, player_id)
);

CREATE TABLE IF NOT EXISTS team_coaches (
    team_id     INT     NOT NULL REFERENCES teams(team_id)   ON DELETE CASCADE,
    coach_id    INT     NOT NULL REFERENCES coaches(coach_id) ON DELETE CASCADE,
    date_joined DATE,
    date_left   DATE,           -- NULL = currently active
    PRIMARY KEY (team_id, coach_id)
);

CREATE TABLE IF NOT EXISTS tournaments (
	tournament_name VARCHAR(50) NOT NULL,
    tournament_id   SERIAL  	PRIMARY KEY,
    organiser_id    INT     	NOT NULL REFERENCES organisers(organiser_id) ON DELETE RESTRICT,
    tournament_type INT     	NOT NULL REFERENCES tournament_types(tournament_type_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS tournament_teams (
    tournament_id   INT             NOT NULL REFERENCES tournaments(tournament_id) ON DELETE CASCADE,
    team_id         INT             NOT NULL REFERENCES teams(team_id)             ON DELETE CASCADE,
    placement       NUMERIC  		CHECK (placement > 0),  -- team cant be 0'th place
    prize_won       NUMERIC,
    PRIMARY KEY (tournament_id, team_id)
);

CREATE TABLE IF NOT EXISTS matches (
    match_id        SERIAL      PRIMARY KEY,
    tournament_id   INT         NOT NULL REFERENCES tournaments(tournament_id) ON DELETE CASCADE,
    team_1_id       INT         NOT NULL REFERENCES teams(team_id)             ON DELETE RESTRICT,
    team_2_id       INT         NOT NULL REFERENCES teams(team_id)             ON DELETE RESTRICT,
    best_of         NUMERIC     NOT NULL,
    match_winner_id INT         REFERENCES teams(team_id)                      ON DELETE SET NULL,
    match_type      VARCHAR(50),    -- e.g. 'Group Stage', 'Playoff', 'Grand Final' (no check due to non-standart match types)
    match_start     TIMESTAMP   CHECK (match_start > '2026-01-01'),
    match_ended     TIMESTAMP,
    CHECK (team_1_id <> team_2_id)
);

CREATE TABLE IF NOT EXISTS match_maps (
    match_map_id        SERIAL  PRIMARY KEY,
    match_id            INT     NOT NULL REFERENCES matches(match_id) ON DELETE CASCADE,
    map_id              INT     NOT NULL REFERENCES maps(map_id)      ON DELETE RESTRICT,
    picked_by_team_id   INT     REFERENCES teams(team_id)             ON DELETE SET NULL,
    map_number          NUMERIC NOT NULL,
    team_1_score        NUMERIC,
    team_2_score        NUMERIC,
    map_winner_id       INT     REFERENCES teams(team_id)             ON DELETE SET NULL,
    map_started         TIMESTAMP,
    map_ended           TIMESTAMP
);

CREATE TABLE IF NOT EXISTS player_stats (
    player_id           INT             NOT NULL REFERENCES players(player_id)         ON DELETE CASCADE,
    tournament_id       INT             NOT NULL REFERENCES tournaments(tournament_id)  ON DELETE CASCADE,
    kills               INT             NOT NULL DEFAULT 0,
    deaths              INT             NOT NULL DEFAULT 0,
    assists             INT             NOT NULL DEFAULT 0,
    kd_ratio            NUMERIC(5)    GENERATED ALWAYS AS
                            (kills::NUMERIC / NULLIF(deaths, 0)) STORED,
    tournament_mvp      BOOLEAN         DEFAULT FALSE,
    most_picked_agent   INT             REFERENCES agents(agent_id) ON DELETE SET NULL,
    PRIMARY KEY (player_id, tournament_id)
);

-- ============================================================
-- INDEXES (faster code)
-- ============================================================

CREATE INDEX idx_matches_tournament     ON matches(tournament_id);
CREATE INDEX idx_matches_team1          ON matches(team_1_id);
CREATE INDEX idx_matches_team2          ON matches(team_2_id);
CREATE INDEX idx_match_maps_match       ON match_maps(match_id);
CREATE INDEX idx_player_stats_player    ON player_stats(player_id);
CREATE INDEX idx_player_stats_tournament ON player_stats(tournament_id);
CREATE INDEX idx_team_players_team      ON team_players(team_id);
CREATE INDEX idx_team_coaches_team      ON team_coaches(team_id);

-- ============================================================
-- PART 3 ALTER TABLES
-- ============================================================

ALTER TABLE tournaments ADD COLUMN total_prize_pool numeric DEFAULT NULL; -- Total prize pool for clarity
ALTER TABLE matches ADD CONSTRAINT time_must_be_positive CHECK (match_start < match_ended); -- time must be positive
ALTER TABLE agents DROP COLUMN is_available; -- irrelevant info
ALTER TABLE player_stats ALTER COLUMN kd_ratio TYPE numeric(5,2); -- added more precision
ALTER TABLE tournament_teams ALTER COLUMN prize_won SET DEFAULT 0; -- the prize is not always money - can also be championship points for the league


-- ============================================================
-- PART 4: INSERT DATA
-- VCT Masters Santiago 2026 — playoff bracket
-- Source: vlr.gg / liquipedia / escharts.com
-- ============================================================

-- TRUNCATE in FK-safe order
TRUNCATE player_stats, match_maps, matches,
         tournament_teams, tournaments, tournament_types,
         team_players, team_coaches, coaches, players,
         teams, organisers, maps, agents
RESTART IDENTITY CASCADE;

-- ── organisers ───────────────────────────────────────────────

INSERT INTO organisers (organiser_name, country) VALUES
    ('Riot Games', 'United States'),
	('Red Bull',   'Austria'),
	('EWC', 	   'UAE'),
	('AfreekaTV',  'South Korea'),
	('BLAST',      'Denmark');

-- ── tournament types ─────────────────────────────────────────

INSERT INTO tournament_types (tournament_type) VALUES
	('Ascension'),
	('Challengers'),
    ('Masters'),
	('Champions'),
	('Offseason'),
	('Regional'),
	('Other');

-- ── tournaments ──────────────────────────────────────────────

INSERT INTO tournaments (tournament_name, organiser_id, tournament_type, total_prize_pool) VALUES
    (	
		'VCT Masters London 2026 // KICKOFF',
        (SELECT organiser_id FROM organisers WHERE organiser_name = 'Riot Games'),
        (SELECT tournament_type_id FROM tournament_types WHERE tournament_type = 'Masters'),
		1000000
    ),
    (	
		'VCT Masters Santiago 2026 // STAGE 1',
        (SELECT organiser_id FROM organisers WHERE organiser_name = 'Riot Games'),
        (SELECT tournament_type_id FROM tournament_types WHERE tournament_type = 'Masters'),
		1000000
    ),
    (	
		'VCT EMEA 2026 // STAGE 2',
        (SELECT organiser_id FROM organisers WHERE organiser_name = 'Riot Games'),
        (SELECT tournament_type_id FROM tournament_types WHERE tournament_type = 'Regional'),
		0
    ),
    (	
		'ESports World Cup 2026',
        (SELECT organiser_id FROM organisers WHERE organiser_name = 'EWC'),
        (SELECT tournament_type_id FROM tournament_types WHERE tournament_type = 'Other'),
		2000000
    ),
    (	
		'VCT Champions Shanghai 2026',
        (SELECT organiser_id FROM organisers WHERE organiser_name = 'Riot Games'),
        (SELECT tournament_type_id FROM tournament_types WHERE tournament_type = 'Champions'),
		NULL
    ),
	(
		'Challengers Oceania League 2026 // STAGE 2',
        (SELECT organiser_id FROM organisers WHERE organiser_name = 'Riot Games'),
        (SELECT tournament_type_id FROM tournament_types WHERE tournament_type = 'Challengers'),
		NULL
	)
	;

-- ── teams (8 playoff teams + 1 league team) ──────────────────

INSERT INTO teams (team_name, country, region, date_joined) VALUES
    ('Nongshim RedForce', 'South Korea',   'Pacific',  '2024-01-01'),
    ('Paper Rex',         'Singapore',     'Pacific',  '2021-06-01'),
    ('NRG',               'United States', 'Americas', '2022-01-01'),
    ('G2 Esports',        'United States', 'Americas', '2023-01-01'),
    ('All Gamers',        'China',         'China',    '2023-06-01'),
    ('BBL Esports',       'Turkey',        'EMEA',     '2021-01-01'),
    ('Gentle Mates',      'France',        'EMEA',     '2024-01-01'),
    ('FURIA',             'Brazil',        'Americas', '2022-06-01'),
	('TALON eSports',	  'Hong Kong',     'Pacific',  '2022-09-22');

-- ── agents ───────────────────────────────────────────────────
-- IDs explicit to keep most_picked_agent references stable

INSERT INTO agents (agent_id, agent_name, agent_added, role) VALUES
    (1,  'Brimstone', '2020-06-02', 'Controller'),
    (2,  'Viper',     '2020-06-02', 'Controller'),
    (3,  'Omen',      '2020-06-02', 'Controller'),
    (4,  'Killjoy',   '2020-08-04', 'Sentinel'),
    (5,  'Cypher',    '2020-06-02', 'Sentinel'),
    (6,  'Sova',      '2020-06-02', 'Initiator'),
    (7,  'Sage',      '2020-06-02', 'Sentinel'),

    (9,  'Phoenix',   '2020-06-02', 'Duelist'),
    (10, 'Jett',      '2020-06-02', 'Duelist'),
    (13, 'Breach',    '2020-06-02', 'Initiator'),
    (12,  'Raze',      '2020-06-02', 'Duelist'),
    (11, 'Reyna',     '2020-06-02', 'Duelist'),
    (14, 'Skye',      '2020-10-27', 'Initiator'),
    (15, 'Yoru',      '2021-01-12', 'Duelist'),
    (16, 'Astra',     '2021-03-02', 'Controller'),
    (17, 'KAY/O',     '2021-06-22', 'Initiator'),
    (18, 'Chamber',   '2021-11-16', 'Sentinel'),
    (19, 'Neon',      '2022-01-11', 'Duelist'),
    (20, 'Fade',      '2022-04-27', 'Initiator'),
    (21, 'Harbor',    '2022-10-18', 'Controller'),
    (22, 'Gekko',     '2023-03-07', 'Initiator'),
    (23, 'Deadlock',  '2023-06-27', 'Sentinel'),
    (24, 'Iso',       '2023-10-31', 'Duelist'),
    (25, 'Clove',     '2024-03-26', 'Controller'),
    (26, 'Vyse',      '2024-08-28', 'Sentinel'),
    (27, 'Tejo',      '2025-01-08', 'Initiator'),
    (28, 'Waylay',    '2025-03-05', 'Duelist');

-- ── players (5 per team = 40 total + 5) ──────────────────────────

INSERT INTO players (first_name, last_name, nickname, country, role, is_active) VALUES

-- Nongshim RedForce
('Sung-hyeon',  'Park',       'Ivy',         'South Korea',   'Flex',       TRUE),
('Sang-min',    'Goo',        'Rb',           'South Korea',   'IGL',        TRUE),
('Jeonghwan',   'Unknown',    'Xross',        'South Korea',   'Initiator',  TRUE),
('Hyuk-kyu',    'Lee',        'Dambi',        'South Korea',   'Duelist',    TRUE),
('Mu-bin',      'Kim',        'Francis',      'South Korea',   'Duelist',    TRUE),

-- Paper Rex
('Jing Jie',    'Wang',       'jinggg',       'Singapore',     'Duelist',    TRUE),
('Jiggs',       'Reyes',      'invy',         'Philippines',   'Initiator',  TRUE),
('Jason',       'Susanto',    'f0rsakeN',     'Indonesia',     'Flex',       TRUE),
('Khalish',     'Rusyaidee',  'd4v41',        'Malaysia',      'Sentinel',   TRUE),
('Ilya',        'Petrov',     'something',    'Russia',        'Duelist',    TRUE),

-- NRG
('Ethan',       'Arnold',      'Ethan',       'United States', 'Duelist',    TRUE),
('Georgio',     'Sanassy',     'keiko',       'United States', 'Sentinel',   TRUE),
('Brock',       'Somerhalder', 'brawk',       'United States', 'Duelist',    TRUE),
('Adam',        'Pampuch',     'mada',        'United States', 'Controller', TRUE),
('Logan',       'Jenkins',     'skuba',       'United States', 'Initiator',  TRUE),

-- G2 Esports
('Jacob',       'Batio',       'valyn',       'United States', 'IGL',        TRUE),
('Alexander',   'Mor',         'jawgemo',     'United States', 'Duelist',    TRUE),
('Andrej',      'Francisty',   'BABYBAY',     'United States', 'Duelist',    TRUE),
('Trent',       'Cairns',      'trent',       'United States', 'Flex',       TRUE),
('Nathan',      'Orf',         'leaf',        'United States', 'Sentinel',   TRUE),

-- All Gamers
('Yang',        'Yong',        'Shr1mp',      'China',         'Duelist',    TRUE),
('Huang',       'Zhihao',      'K1ra',        'China',         'Duelist',    TRUE),
('Zhu',         'Yihao',       'Au1',         'China',         'Controller', TRUE),
('Roman',       'Smirnov',     'f4ngeer',     'Russia',        'Initiator',  TRUE),
('Gao',         'Ruiqi',       'iamgrq',      'China',         'Sentinel',   TRUE),

-- BBL Esports
('Ali Eren',    'Sargin',      'Crewen',      'Turkey',        'IGL',        TRUE),
('Yusuf Kaan',  'Kanber',      'Lar0k',       'Turkey',        'Duelist',    TRUE),
('Utku',        'Kart',        'Loita',       'Turkey',        'Flex',       TRUE),
('Eren',        'Erzan',       'Rose',        'Turkey',        'Initiator',  TRUE),
('Umut',        'Pekdogan',    'lovers rock', 'Turkey',        'Sentinel',   TRUE),

-- Gentle Mates
('Patryk',      'Kopczynski',  'starxo',      'Poland',          'Initiator', TRUE),
('Taranvir',    'Singh',       'bipo',        'United Kingdom',  'Controller',TRUE),
('Martin',      'Patek',       'marteen',     'Czech Republic',  'Duelist',   TRUE),
('Conner',      'Garcia',      'GLYPH',       'United States',   'Controller',TRUE),
('Patrik',      'Husek',       'Minny',       'Czech Republic',  'Sentinel',  TRUE),

-- FURIA
('Michael',     'Yerrow',      'nerve',       'United States', 'Duelist',    TRUE),
('Arthur',      'Araujo',      'artzin',      'Brazil',        'Duelist',    TRUE),
('Daniel',      'Vucenovic',   'eeiu',        'Canada',        'IGL',        TRUE),
('Gianfranco',  'Potestio',    'koalanoob',   'Venezuela',     'Initiator',  TRUE),
('Torogul',     'Baidyldaev',  'alym',        'Kyrgyzstan',    'Controller', TRUE),

-- TALON (VCT Pacific 2026)
('Anupong',    'Preamsak',      'thyy',      'Thailand', 'Flex',       TRUE),
('Papaphat',   'Sriprapha',     'primmie',   'Thailand', 'Duelist',    TRUE),
('Tanate',     'Teerasawad',    'Killua',    'Thailand', 'Initiator',  TRUE),
('Jittana',    'Nokngam',       'JitBoyS',   'Thailand', 'Controller', TRUE),
('Thanyathon', 'Nakmee',        'Leviathan', 'Thailand', 'Sentinel',   TRUE);

-- ── coaches ──────────────────────────────────────────────────

INSERT INTO coaches (first_name, last_name, nickname, country, is_active) VALUES

-- Nongshim RedForce
('Gyeong-min',  'Kim',     'SilKanoN',   'South Korea',   TRUE),  -- head coach
('Young-moon',  'Chae',    'yoman',      'South Korea',   TRUE),  -- coach
('Seong-min',   'So',      'Sungmin',    'South Korea',   TRUE),  -- coach

-- Paper Rex
('Alexandre',   'Salle',   'alecks',     'France',        TRUE),  -- head coach

-- NRG
('Malkolm',     'Rench',   'bonkar',     'Sweden',        TRUE),  -- head coach
('Mitch',       'Semago',  'mitch',      'United States', TRUE),  -- assistant coach

-- G2 Esports
('Josh',        'Lee',     'JoshRT',     'United States', TRUE),  -- head coach
('Peter',       'Belej',   'shhhack',    'United States', TRUE),  -- assistant coach

-- All Gamers
('Zihan',       'Cheng',   'Master',     'China',         TRUE),  -- head coach

-- BBL Esports
('Mert',        'Celebi',  'KEY',        'Turkey',        TRUE),  -- head coach
('Goktug Alp',  'Cebi',    'Viento',     'Turkey',        TRUE),  -- assistant coach

-- Gentle Mates
('Unknown',     'Unknown', 'pakko',      'Unknown',       TRUE),  -- head coach (real name not public)
('Unknown',     'Unknown', 'KUNDIKUNDI', 'Unknown',       TRUE),  -- assistant coach

-- FURIA
('Unknown',     'Unknown', 'shaW',       'Brazil',        TRUE),  -- head coach
('Unknown',     'Unknown', 'Kamino',     'Brazil',        TRUE),  -- assistant coach

-- FULL SENSE Coaches (VCT Pacific 2026)
('Thanamethk', 'Mahatthananuyut', 'CRWS',            'Thailand', TRUE),
('Thanaphat',  'Limpaphan',       'THEELOVEFAMILY',  'Thailand', TRUE);

-- ── team-player links ────────────────────────────────────────

INSERT INTO team_players (team_id, player_id, date_joined)
SELECT t.team_id, p.player_id, '2026-01-01'
FROM teams t, players p
WHERE t.team_name = 'Nongshim RedForce'
  AND p.nickname IN ('Ivy','Rb','Xross','Dambi','Francis');

INSERT INTO team_players (team_id, player_id, date_joined)
SELECT t.team_id, p.player_id, '2024-01-01'
FROM teams t, players p
WHERE t.team_name = 'Paper Rex'
  AND p.nickname IN ('jinggg','invy','f0rsakeN','d4v41','something');

INSERT INTO team_players (team_id, player_id, date_joined)
SELECT t.team_id, p.player_id, '2025-11-01'
FROM teams t, players p
WHERE t.team_name = 'NRG'
  AND p.nickname IN ('Ethan','keiko','brawk','mada','skuba');

INSERT INTO team_players (team_id, player_id, date_joined)
SELECT t.team_id, p.player_id, '2025-11-01'
FROM teams t, players p
WHERE t.team_name = 'G2 Esports'
  AND p.nickname IN ('valyn','jawgemo','BABYBAY','trent','leaf');

INSERT INTO team_players (team_id, player_id, date_joined)
SELECT t.team_id, p.player_id, '2025-10-01'
FROM teams t, players p
WHERE t.team_name = 'All Gamers'
  AND p.nickname IN ('Shr1mp','K1ra','Au1','f4ngeer','iamgrq');

INSERT INTO team_players (team_id, player_id, date_joined)
SELECT t.team_id, p.player_id, '2025-11-01'
FROM teams t, players p
WHERE t.team_name = 'BBL Esports'
  AND p.nickname IN ('Crewen','Lar0k','Loita','Rose','lovers rock');

INSERT INTO team_players (team_id, player_id, date_joined)
SELECT t.team_id, p.player_id, '2025-10-01'
FROM teams t, players p
WHERE t.team_name = 'Gentle Mates'
  AND p.nickname IN ('starxo','bipo','marteen','GLYPH','Minny');

INSERT INTO team_players (team_id, player_id, date_joined)
SELECT t.team_id, p.player_id, '2025-11-01'
FROM teams t, players p
WHERE t.team_name = 'FURIA'
  AND p.nickname IN ('nerve','artzin','eeiu','koalanoob','alym');

INSERT INTO team_players (team_id, player_id, date_joined)
SELECT t.team_id, p.player_id, '2022-09-22'
FROM teams t, players p
WHERE t.team_name = 'TALON eSports'
  AND p.nickname IN ('thyy', 'primmie', 'Killua', 'JitBoyS', 'Leviathan');

-- ── team-coach links ─────────────────────────────────────────

INSERT INTO team_coaches (team_id, coach_id, date_joined)
SELECT t.team_id, c.coach_id, '2026-01-01'
FROM teams t, coaches c
WHERE t.team_name = 'Nongshim RedForce'
  AND c.nickname IN ('SilKanoN','yoman','Sungmin');

INSERT INTO team_coaches (team_id, coach_id, date_joined)
SELECT t.team_id, c.coach_id, '2022-01-01'
FROM teams t, coaches c
WHERE t.team_name = 'Paper Rex'
  AND c.nickname IN ('alecks');

INSERT INTO team_coaches (team_id, coach_id, date_joined)
SELECT t.team_id, c.coach_id, '2025-11-01'
FROM teams t, coaches c
WHERE t.team_name = 'NRG'
  AND c.nickname IN ('bonkar','mitch');

INSERT INTO team_coaches (team_id, coach_id, date_joined)
SELECT t.team_id, c.coach_id, '2025-11-01'
FROM teams t, coaches c
WHERE t.team_name = 'G2 Esports'
  AND c.nickname IN ('JoshRT','shhhack');

INSERT INTO team_coaches (team_id, coach_id, date_joined)
SELECT t.team_id, c.coach_id, '2025-10-01'
FROM teams t, coaches c
WHERE t.team_name = 'All Gamers'
  AND c.nickname IN ('Master');

INSERT INTO team_coaches (team_id, coach_id, date_joined)
SELECT t.team_id, c.coach_id, '2025-11-01'
FROM teams t, coaches c
WHERE t.team_name = 'BBL Esports'
  AND c.nickname IN ('KEY','Viento');

INSERT INTO team_coaches (team_id, coach_id, date_joined)
SELECT t.team_id, c.coach_id, '2025-10-01'
FROM teams t, coaches c
WHERE t.team_name = 'Gentle Mates'
  AND c.nickname IN ('pakko','KUNDIKUNDI');

INSERT INTO team_coaches (team_id, coach_id, date_joined)
SELECT t.team_id, c.coach_id, '2025-11-01'
FROM teams t, coaches c
WHERE t.team_name = 'FURIA'
  AND c.nickname IN ('shaW','Kamino');

INSERT INTO team_coaches (team_id, coach_id, date_joined)
SELECT t.team_id, c.coach_id, '2022-09-22'
FROM teams t, coaches c
WHERE t.team_name = 'TALON eSports'
  AND c.nickname IN ('CRWS', 'THEELOVEFAMILY');

-- ── tournament teams (placements + prize money) ──────────────

INSERT INTO tournament_teams (tournament_id, team_id, placement, prize_won) VALUES
    ((SELECT tournament_id FROM tournaments LIMIT 1), (SELECT team_id FROM teams WHERE team_name = 'Nongshim RedForce'), 1, 350000),
    ((SELECT tournament_id FROM tournaments LIMIT 1), (SELECT team_id FROM teams WHERE team_name = 'Paper Rex'),         2, 200000),
    ((SELECT tournament_id FROM tournaments LIMIT 1), (SELECT team_id FROM teams WHERE team_name = 'NRG'),               3, 125000),
    ((SELECT tournament_id FROM tournaments LIMIT 1), (SELECT team_id FROM teams WHERE team_name = 'G2 Esports'),        4,  75000),
    ((SELECT tournament_id FROM tournaments LIMIT 1), (SELECT team_id FROM teams WHERE team_name = 'All Gamers'),        5,  50000),
    ((SELECT tournament_id FROM tournaments LIMIT 1), (SELECT team_id FROM teams WHERE team_name = 'BBL Esports'),       5,  50000),
    ((SELECT tournament_id FROM tournaments LIMIT 1), (SELECT team_id FROM teams WHERE team_name = 'Gentle Mates'),      7,  35000),
    ((SELECT tournament_id FROM tournaments LIMIT 1), (SELECT team_id FROM teams WHERE team_name = 'FURIA'),             7,  35000);

-- ── maps (active pool at Masters Santiago) ───────────────────

INSERT INTO maps (map_name, date_added) VALUES
    ('Bind',    '2020-06-02'),
    ('Haven',   '2020-06-02'),
    ('Split',   '2020-06-02'),
    ('Ascent',  '2020-06-02'),
    ('Icebox',  '2020-10-13'),
    ('Fracture','2021-09-08'),
    ('Breeze',  '2021-01-12'),
    ('Pearl',   '2022-06-22'),
    ('Lotus',   '2023-01-10'),
    ('Sunset',  '2023-08-29'),
    ('Abyss',   '2024-06-11'),
	('Corrode', '2025-06-25');
    -- NOTE: 'Corrode' (~2026) not in pool data yet — add manually when confirmed DONE

-- ── matches — playoff bracket ────────────────────────────────
-- all BO3 except lower final (BO5) and grand final (BO5)

INSERT INTO matches (tournament_id, team_1_id, team_2_id, best_of, match_winner_id, match_type, match_start, match_ended) VALUES

-- upper bracket quarterfinals
(
    (SELECT tournament_id FROM tournaments LIMIT 1),
    (SELECT team_id FROM teams WHERE team_name = 'Nongshim RedForce'),
    (SELECT team_id FROM teams WHERE team_name = 'Gentle Mates'),
    3, (SELECT team_id FROM teams WHERE team_name = 'Nongshim RedForce'),
    'Upper Bracket Quarterfinal', '2026-03-06 21:00:00+00', '2026-03-06 23:10:00+00'
),
(
    (SELECT tournament_id FROM tournaments LIMIT 1),
    (SELECT team_id FROM teams WHERE team_name = 'All Gamers'),
    (SELECT team_id FROM teams WHERE team_name = 'G2 Esports'),
    3, (SELECT team_id FROM teams WHERE team_name = 'G2 Esports'),
    'Upper Bracket Quarterfinal', '2026-03-07 20:30:00+00', '2026-03-07 22:40:00+00'
),
(
    (SELECT tournament_id FROM tournaments LIMIT 1),
    (SELECT team_id FROM teams WHERE team_name = 'FURIA'),
    (SELECT team_id FROM teams WHERE team_name = 'Paper Rex'),
    3, (SELECT team_id FROM teams WHERE team_name = 'Paper Rex'),
    'Upper Bracket Quarterfinal', '2026-03-06 18:00:00+00', '2026-03-06 20:30:00+00'
),
(
    (SELECT tournament_id FROM tournaments LIMIT 1),
    (SELECT team_id FROM teams WHERE team_name = 'BBL Esports'),
    (SELECT team_id FROM teams WHERE team_name = 'NRG'),
    3, (SELECT team_id FROM teams WHERE team_name = 'NRG'),
    'Upper Bracket Quarterfinal', '2026-03-07 17:00:00+00', '2026-03-07 19:30:00+00'
),

-- upper bracket semifinals
(
    (SELECT tournament_id FROM tournaments LIMIT 1),
    (SELECT team_id FROM teams WHERE team_name = 'Nongshim RedForce'),
    (SELECT team_id FROM teams WHERE team_name = 'G2 Esports'),
    3, (SELECT team_id FROM teams WHERE team_name = 'Nongshim RedForce'),
    'Upper Bracket Semifinal', '2026-03-09 19:00:00+00', '2026-03-09 21:45:00+00'
),
(
    (SELECT tournament_id FROM tournaments LIMIT 1),
    (SELECT team_id FROM teams WHERE team_name = 'Paper Rex'),
    (SELECT team_id FROM teams WHERE team_name = 'NRG'),
    3, (SELECT team_id FROM teams WHERE team_name = 'NRG'),
    'Upper Bracket Semifinal', '2026-03-09 22:20:00+00', '2026-03-10 00:30:00+00'
),

-- upper bracket final
(
    (SELECT tournament_id FROM tournaments LIMIT 1),
    (SELECT team_id FROM teams WHERE team_name = 'Nongshim RedForce'),
    (SELECT team_id FROM teams WHERE team_name = 'NRG'),
    3, (SELECT team_id FROM teams WHERE team_name = 'Nongshim RedForce'),
    'Upper Bracket Final', '2026-03-13 18:00:00+00', '2026-03-13 20:10:00+00'
),

-- lower round 1
(
    (SELECT tournament_id FROM tournaments LIMIT 1),
    (SELECT team_id FROM teams WHERE team_name = 'Gentle Mates'),
    (SELECT team_id FROM teams WHERE team_name = 'All Gamers'),
    3, (SELECT team_id FROM teams WHERE team_name = 'All Gamers'),
    'Lower Bracket Round 1', '2026-03-08 21:30:00+00', '2026-03-08 23:50:00+00'
),
(
    (SELECT tournament_id FROM tournaments LIMIT 1),
    (SELECT team_id FROM teams WHERE team_name = 'FURIA'),
    (SELECT team_id FROM teams WHERE team_name = 'BBL Esports'),
    3, (SELECT team_id FROM teams WHERE team_name = 'BBL Esports'),
    'Lower Bracket Round 1', '2026-03-08 18:00:00+00', '2026-03-08 20:20:00+00'
),

-- lower round 2
(
    (SELECT tournament_id FROM tournaments LIMIT 1),
    (SELECT team_id FROM teams WHERE team_name = 'Paper Rex'),
    (SELECT team_id FROM teams WHERE team_name = 'All Gamers'),
    3, (SELECT team_id FROM teams WHERE team_name = 'Paper Rex'),
    'Lower Bracket Round 2', '2026-03-10 21:10:00+00', '2026-03-10 23:40:00+00'
),
(
    (SELECT tournament_id FROM tournaments LIMIT 1),
    (SELECT team_id FROM teams WHERE team_name = 'G2 Esports'),
    (SELECT team_id FROM teams WHERE team_name = 'BBL Esports'),
    3, (SELECT team_id FROM teams WHERE team_name = 'G2 Esports'),
    'Lower Bracket Round 2', '2026-03-10 19:00:00+00', '2026-03-10 21:00:00+00'
),

-- lower round 3
(
    (SELECT tournament_id FROM tournaments LIMIT 1),
    (SELECT team_id FROM teams WHERE team_name = 'Paper Rex'),
    (SELECT team_id FROM teams WHERE team_name = 'G2 Esports'),
    3, (SELECT team_id FROM teams WHERE team_name = 'Paper Rex'),
    'Lower Bracket Round 3', '2026-03-13 20:25:00+00', '2026-03-13 23:10:00+00'
),

-- lower bracket final (BO5)
(
    (SELECT tournament_id FROM tournaments LIMIT 1),
    (SELECT team_id FROM teams WHERE team_name = 'NRG'),
    (SELECT team_id FROM teams WHERE team_name = 'Paper Rex'),
    5, (SELECT team_id FROM teams WHERE team_name = 'Paper Rex'),
    'Lower Bracket Final', '2026-03-14 18:00:00+00', '2026-03-14 22:30:00+00'
),

-- grand final (BO5, NS swept PRX 3-0)
(
    (SELECT tournament_id FROM tournaments LIMIT 1),
    (SELECT team_id FROM teams WHERE team_name = 'Nongshim RedForce'),
    (SELECT team_id FROM teams WHERE team_name = 'Paper Rex'),
    5, (SELECT team_id FROM teams WHERE team_name = 'Nongshim RedForce'),
    'Grand Final', '2026-03-15 18:00:00+00', '2026-03-15 23:00:00+00'
);

-- ── match maps ───────────────────────────────────────────────
-- picked_by_team_id = NULL where pick/ban data not confirmed
-- remaining matches left for manual addition

-- Grand Final: NS 3-0 PRX
INSERT INTO match_maps (match_id, map_id, picked_by_team_id, map_number, team_1_score, team_2_score, map_winner_id, map_started, map_ended) VALUES
(
    (SELECT match_id FROM matches WHERE match_type = 'Grand Final' LIMIT 1),
    (SELECT map_id FROM maps WHERE map_name = 'Bind'),
    NULL, 1, 13, 5,
    (SELECT team_id FROM teams WHERE team_name = 'Nongshim RedForce'),
    '2026-03-15 18:00:00+00', '2026-03-15 19:05:00+00'
),
(
    (SELECT match_id FROM matches WHERE match_type = 'Grand Final' LIMIT 1),
    (SELECT map_id FROM maps WHERE map_name = 'Abyss'),
    NULL, 2, 13, 9,
    (SELECT team_id FROM teams WHERE team_name = 'Nongshim RedForce'),
    '2026-03-15 19:20:00+00', '2026-03-15 20:35:00+00'
),
(
    (SELECT match_id FROM matches WHERE match_type = 'Grand Final' LIMIT 1),
    (SELECT map_id FROM maps WHERE map_name = 'Haven'),
    NULL, 3, 13, 9,
    (SELECT team_id FROM teams WHERE team_name = 'Nongshim RedForce'),
    '2026-03-15 20:50:00+00', '2026-03-15 22:10:00+00'
);

-- Upper Bracket Final: NS 2-0 NRG
INSERT INTO match_maps (match_id, map_id, picked_by_team_id, map_number, team_1_score, team_2_score, map_winner_id, map_started, map_ended) VALUES
(
    (SELECT match_id FROM matches WHERE match_type = 'Upper Bracket Final' LIMIT 1),
    (SELECT map_id FROM maps WHERE map_name = 'Bind'),
    NULL, 1, 13, 7,
    (SELECT team_id FROM teams WHERE team_name = 'Nongshim RedForce'),
    '2026-03-13 18:00:00+00', '2026-03-13 19:05:00+00'
),
(
    (SELECT match_id FROM matches WHERE match_type = 'Upper Bracket Final' LIMIT 1),
    (SELECT map_id FROM maps WHERE map_name = 'Haven'),
    NULL, 2, 13, 8,
    (SELECT team_id FROM teams WHERE team_name = 'Nongshim RedForce'),
    '2026-03-13 19:20:00+00', '2026-03-13 20:10:00+00'
);

-- Lower Bracket Final: PRX 3-2 NRG
INSERT INTO match_maps (match_id, map_id, picked_by_team_id, map_number, team_1_score, team_2_score, map_winner_id, map_started, map_ended) VALUES
(
    (SELECT match_id FROM matches WHERE match_type = 'Lower Bracket Final' LIMIT 1),
    (SELECT map_id FROM maps WHERE map_name = 'Abyss'),
    NULL, 1, 7, 13,
    (SELECT team_id FROM teams WHERE team_name = 'NRG'),
    '2026-03-14 18:00:00+00', '2026-03-14 19:10:00+00'
),
(
    (SELECT match_id FROM matches WHERE match_type = 'Lower Bracket Final' LIMIT 1),
    (SELECT map_id FROM maps WHERE map_name = 'Bind'),
    NULL, 2, 9, 13,
    (SELECT team_id FROM teams WHERE team_name = 'Paper Rex'),
    '2026-03-14 19:25:00+00', '2026-03-14 20:35:00+00'
),
(
    (SELECT match_id FROM matches WHERE match_type = 'Lower Bracket Final' LIMIT 1),
    (SELECT map_id FROM maps WHERE map_name = 'Haven'),
    NULL, 3, 11, 13,
    (SELECT team_id FROM teams WHERE team_name = 'Paper Rex'),
    '2026-03-14 20:50:00+00', '2026-03-14 22:05:00+00'
),
(
    (SELECT match_id FROM matches WHERE match_type = 'Lower Bracket Final' LIMIT 1),
    (SELECT map_id FROM maps WHERE map_name = 'Breeze'),
    NULL, 4, 13, 8,
    (SELECT team_id FROM teams WHERE team_name = 'NRG'),
    '2026-03-14 22:20:00+00', '2026-03-14 23:20:00+00'
),
(
    (SELECT match_id FROM matches WHERE match_type = 'Lower Bracket Final' LIMIT 1),
    (SELECT map_id FROM maps WHERE map_name = 'Pearl'),
    NULL, 5, 11, 13,
    (SELECT team_id FROM teams WHERE team_name = 'Paper Rex'),
    '2026-03-14 23:35:00+00', '2026-03-15 00:55:00+00'
);

-- remaining playoff matches (UBQFx4, UBSFx2, LBR1x2, LBR2x2, LBR3x1):
-- add map data manually using the same pattern above

-- ── player stats ─────────────────────────────────────────────
-- tournament totals (kills/deaths/assists) from vlr.gg/event/stats/2760
-- most_picked_agent = most-played agent across the event per vlr.gg
-- kd_ratio is GENERATED — do not insert it

INSERT INTO player_stats (player_id, tournament_id, kills, deaths, assists, tournament_mvp, most_picked_agent) VALUES

-- Nongshim RedForce
((SELECT player_id FROM players WHERE nickname = 'Ivy'),     (SELECT tournament_id FROM tournaments LIMIT 1), 165, 131,  47, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Killjoy')),
((SELECT player_id FROM players WHERE nickname = 'Rb'),      (SELECT tournament_id FROM tournaments LIMIT 1), 126, 132, 100, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Omen')),
((SELECT player_id FROM players WHERE nickname = 'Xross'),   (SELECT tournament_id FROM tournaments LIMIT 1), 158, 133,  63, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Sova')),
((SELECT player_id FROM players WHERE nickname = 'Dambi'),   (SELECT tournament_id FROM tournaments LIMIT 1), 183, 154,  46,  TRUE, (SELECT agent_id FROM agents WHERE agent_name = 'Neon')),
((SELECT player_id FROM players WHERE nickname = 'Francis'), (SELECT tournament_id FROM tournaments LIMIT 1), 167, 153,  54, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Yoru')),

-- Paper Rex
((SELECT player_id FROM players WHERE nickname = 'jinggg'),    (SELECT tournament_id FROM tournaments LIMIT 1), 358, 331, 128, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Raze')),
((SELECT player_id FROM players WHERE nickname = 'invy'),      (SELECT tournament_id FROM tournaments LIMIT 1), 335, 302, 130, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Fade')),
((SELECT player_id FROM players WHERE nickname = 'f0rsakeN'),  (SELECT tournament_id FROM tournaments LIMIT 1), 342, 344, 149, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Omen')),
((SELECT player_id FROM players WHERE nickname = 'd4v41'),     (SELECT tournament_id FROM tournaments LIMIT 1), 371, 310,  88, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Viper')),
((SELECT player_id FROM players WHERE nickname = 'something'), (SELECT tournament_id FROM tournaments LIMIT 1), 340, 312,  94, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Yoru')),

-- NRG
((SELECT player_id FROM players WHERE nickname = 'Ethan'), (SELECT tournament_id FROM tournaments LIMIT 1), 231, 270, 114, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Omen')),
((SELECT player_id FROM players WHERE nickname = 'keiko'), (SELECT tournament_id FROM tournaments LIMIT 1), 313, 270,  84, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Viper')),
((SELECT player_id FROM players WHERE nickname = 'brawk'), (SELECT tournament_id FROM tournaments LIMIT 1), 231, 269, 118, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Sova')),
((SELECT player_id FROM players WHERE nickname = 'mada'),  (SELECT tournament_id FROM tournaments LIMIT 1), 292, 289,  82, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Neon')),
((SELECT player_id FROM players WHERE nickname = 'skuba'), (SELECT tournament_id FROM tournaments LIMIT 1), 300, 263,  99, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Killjoy')),

-- G2 Esports
((SELECT player_id FROM players WHERE nickname = 'valyn'),   (SELECT tournament_id FROM tournaments LIMIT 1), 217, 216, 117, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Astra')),
((SELECT player_id FROM players WHERE nickname = 'jawgemo'), (SELECT tournament_id FROM tournaments LIMIT 1), 278, 255,  52, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Neon')),
((SELECT player_id FROM players WHERE nickname = 'BABYBAY'), (SELECT tournament_id FROM tournaments LIMIT 1), 200, 225,  59, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Waylay')),
((SELECT player_id FROM players WHERE nickname = 'trent'),   (SELECT tournament_id FROM tournaments LIMIT 1), 229, 207, 111, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Fade')),
((SELECT player_id FROM players WHERE nickname = 'leaf'),    (SELECT tournament_id FROM tournaments LIMIT 1), 238, 235,  95, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Viper')),

-- All Gamers
((SELECT player_id FROM players WHERE nickname = 'Shr1mp'), (SELECT tournament_id FROM tournaments LIMIT 1),  86, 104,  41, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Skye')),
((SELECT player_id FROM players WHERE nickname = 'K1ra'),   (SELECT tournament_id FROM tournaments LIMIT 1), 105, 107,  25, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Raze')),
((SELECT player_id FROM players WHERE nickname = 'Au1'),    (SELECT tournament_id FROM tournaments LIMIT 1),  97, 115,  34, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Viper')),
((SELECT player_id FROM players WHERE nickname = 'f4ngeer'),(SELECT tournament_id FROM tournaments LIMIT 1), 114, 112,  18, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Waylay')),
((SELECT player_id FROM players WHERE nickname = 'iamgrq'), (SELECT tournament_id FROM tournaments LIMIT 1),  90, 109,  49, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Omen')),

-- BBL Esports
((SELECT player_id FROM players WHERE nickname = 'Crewen'),      (SELECT tournament_id FROM tournaments LIMIT 1), 119, 124, 31, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Cypher')),
((SELECT player_id FROM players WHERE nickname = 'Lar0k'),       (SELECT tournament_id FROM tournaments LIMIT 1), 137, 126, 34, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Neon')),
((SELECT player_id FROM players WHERE nickname = 'Loita'),       (SELECT tournament_id FROM tournaments LIMIT 1), 123, 123, 74, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Astra')),
((SELECT player_id FROM players WHERE nickname = 'Rose'),        (SELECT tournament_id FROM tournaments LIMIT 1),  91, 128, 47, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Sova')),
((SELECT player_id FROM players WHERE nickname = 'lovers rock'), (SELECT tournament_id FROM tournaments LIMIT 1), 119, 131, 32, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Yoru')),

-- Gentle Mates
((SELECT player_id FROM players WHERE nickname = 'starxo'),  (SELECT tournament_id FROM tournaments LIMIT 1), 117, 119,  66, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Sova')),
((SELECT player_id FROM players WHERE nickname = 'bipo'),    (SELECT tournament_id FROM tournaments LIMIT 1), 112, 139,  41, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Neon')),
((SELECT player_id FROM players WHERE nickname = 'marteen'), (SELECT tournament_id FROM tournaments LIMIT 1), 176, 123,  57, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Yoru')),
((SELECT player_id FROM players WHERE nickname = 'GLYPH'),   (SELECT tournament_id FROM tournaments LIMIT 1), 106, 127,  76, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Astra')),
((SELECT player_id FROM players WHERE nickname = 'Minny'),   (SELECT tournament_id FROM tournaments LIMIT 1), 118, 128,  46, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Cypher')),

-- FURIA
((SELECT player_id FROM players WHERE nickname = 'nerve'),     (SELECT tournament_id FROM tournaments LIMIT 1),  70,  93, 32, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Viper')),
((SELECT player_id FROM players WHERE nickname = 'artzin'),    (SELECT tournament_id FROM tournaments LIMIT 1),  82,  96, 37, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Killjoy')),
((SELECT player_id FROM players WHERE nickname = 'eeiu'),      (SELECT tournament_id FROM tournaments LIMIT 1), 111,  83, 29, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Sova')),
((SELECT player_id FROM players WHERE nickname = 'koalanoob'), (SELECT tournament_id FROM tournaments LIMIT 1),  86,  95, 33, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Omen')),
((SELECT player_id FROM players WHERE nickname = 'alym'),      (SELECT tournament_id FROM tournaments LIMIT 1),  78,  98, 26, FALSE, (SELECT agent_id FROM agents WHERE agent_name = 'Neon'));


-- ==============================
-- PART 5.1 - UPDATES
-- ==============================

-- TALON has been terminated from the league, giving spot to FULL SENSE while retaining TALON's roster
UPDATE teams SET team_name = 'FULL SENSE' WHERE team_name = 'TALON eSports';
UPDATE teams SET date_joined = '2025-11-8' WHERE team_name = 'FULL SENSE';

-- checking if update worked (should change team name TALON => FULL SENSE)
-- SELECT  t.team_name,
-- 		p.nickname
-- FROM teams t
-- JOIN team_players tp ON tp.team_id  = t.team_id
-- JOIN players p ON p.player_id = tp.player_id

-- since FULL SENSE is a new team, all dates should be updated on players and coaches's fields
UPDATE team_players tp
SET date_joined = '2025-11-08'
FROM teams t
WHERE tp.team_id = t.team_id
  AND t.team_name = 'FULL SENSE';

-- same for coaches

UPDATE team_coaches tc
SET date_joined = '2025-11-08'
FROM teams t
WHERE tc.team_id = t.team_id
  AND t.team_name = 'FULL SENSE';

-- checking (shall be 2025-11-08 - date when FULL SENSE took over TALON)
SELECT  t.team_name,
		p.nickname,
		tp.date_joined
FROM teams t
JOIN team_players tp ON tp.team_id  = t.team_id
JOIN players p ON p.player_id = tp.player_id
WHERE team_name = 'FULL SENSE';

-- ==================================
-- PART 5.2 - DELETE
-- ==================================

-- after FULL SENSE came, they removed CRWS as the head coach

BEGIN;
DELETE FROM coaches
WHERE nickname = 'CRWS'
RETURNING coach_id;
ROLLBACK;

-- -- ==================================
-- -- PART 6 - ROLES (GRANT/REVOKE)
-- -- ==================================

-- DROP ROLE IF EXISTS vct_db_readonly;
-- DROP ROLE IF EXISTS vct_db_writer;

-- -- read-only role: analysts and observers who need to query match/roster data but must not modify it
-- CREATE ROLE vct_db_readonly;

-- -- writer role: data entry staff who manage rosters and match results
-- CREATE ROLE vct_db_writer;

-- -- grant read access to all tables
-- GRANT SELECT ON ALL TABLES IN SCHEMA vct TO vct_db_readonly;

-- -- grant insert + update on core roster/match tables
-- GRANT INSERT, UPDATE ON teams TO vct_db_writer;
-- GRANT INSERT, UPDATE ON players TO vct_db_writer;
-- GRANT INSERT, UPDATE ON coaches TO vct_db_writer;
-- GRANT INSERT, UPDATE ON team_players TO vct_db_writer;
-- GRANT INSERT, UPDATE ON team_coaches TO vct_db_writer;

-- -- revoke UPDATE on junction tables: roster history must be append-only to preserve
-- -- accurate join/leave records — editing past entries would corrupt transfer history
-- REVOKE UPDATE ON team_players FROM vct_db_writer;
-- REVOKE UPDATE ON team_coaches FROM vct_db_writer;