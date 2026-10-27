"""Charge freMTPL2freq.csv et freMTPL2sev.csv dans une base SQLite.

Usage : python charger_donnees.py <dossier_des_csv> <fichier_sortie.db>
"""
import csv
import sqlite3
import sys
from pathlib import Path

dossier = Path(sys.argv[1])
sortie = Path(sys.argv[2])
if sortie.exists():
    sortie.unlink()

con = sqlite3.connect(sortie)
con.executescript(
    """
    CREATE TABLE contrats_brut (
        IDpol      INTEGER,
        ClaimNb    INTEGER,
        Exposure   REAL,
        VehPower   INTEGER,
        VehAge     INTEGER,
        DrivAge    INTEGER,
        BonusMalus INTEGER,
        VehBrand   TEXT,
        VehGas     TEXT,
        Area       TEXT,
        Density    INTEGER,
        Region     TEXT
    );
    CREATE TABLE sinistres_brut (
        IDpol       INTEGER,
        ClaimAmount REAL
    );
    """
)

def charger(nom_fichier, table, nb_colonnes):
    with open(dossier / nom_fichier, newline="", encoding="utf-8") as f:
        lecteur = csv.reader(f)
        next(lecteur)  # en-tête
        lignes = (ligne for ligne in lecteur if ligne)
        con.executemany(
            f"INSERT INTO {table} VALUES ({','.join('?' * nb_colonnes)})", lignes
        )

charger("freMTPL2freq.csv", "contrats_brut", 12)
charger("freMTPL2sev.csv", "sinistres_brut", 2)
# Index sur la clé de jointure : sans eux, les jointures sur 678 000 lignes sont très lentes
con.executescript(
    """
    CREATE INDEX idx_contrats_brut_idpol  ON contrats_brut(IDpol);
    CREATE INDEX idx_sinistres_brut_idpol ON sinistres_brut(IDpol);
    """
)
con.commit()

for table in ("contrats_brut", "sinistres_brut"):
    n = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    print(f"{table} : {n:,} lignes".replace(",", " "))
con.close()
