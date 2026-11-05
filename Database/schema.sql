-- SQLite schema v1. The iOS app creates this automatically.
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS toilets (
    id TEXT PRIMARY KEY NOT NULL,
    payload BLOB NOT NULL
);
CREATE TABLE IF NOT EXISTS reviews (
    id TEXT PRIMARY KEY NOT NULL,
    toilet_id TEXT NOT NULL UNIQUE REFERENCES toilets(id),
    payload BLOB NOT NULL
);
CREATE TABLE IF NOT EXISTS favorites (
    toilet_id TEXT PRIMARY KEY NOT NULL REFERENCES toilets(id)
);
CREATE TABLE IF NOT EXISTS reports (
    id TEXT PRIMARY KEY NOT NULL,
    toilet_id TEXT NOT NULL REFERENCES toilets(id),
    payload BLOB NOT NULL
);
CREATE INDEX IF NOT EXISTS reports_toilet_idx ON reports(toilet_id);
PRAGMA user_version = 1;
