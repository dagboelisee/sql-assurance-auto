-- =====================================================================
-- 02_nettoyage.sql
-- Construit les tables propres (contrats, sinistres), une vue de segments
-- (v_contrats) et un journal des règles de nettoyage appliquées.
-- Les tables brutes (contrats_brut, sinistres_brut) ne sont jamais modifiées.
--
-- Règles appliquées (chacune est justifiée dans le README) :
--   R1. Exposition plafonnée à 1 an (1 224 contrats > 1 an).
--   R2. Le nombre de sinistres est compté à partir du détail des sinistres
--       (table sinistres_brut), et non à partir de la colonne ClaimNb. Pour
--       9 116 contrats, ClaimNb annonce des sinistres sans qu'aucun montant
--       n'existe : leur nombre est incohérent avec le détail. Le nombre déclaré
--       est conservé dans nb_sinistres_declare.
--   R3. Sinistres sans contrat correspondant exclus (195 lignes).
--   R4. Montants des sinistres plafonnés à 100 000 dans une colonne à part
--       (le montant d'origine est conservé).
-- Aucun contrat n'est supprimé. Les contrats qui comptent plus de 4 sinistres
-- (une poignée) sont conservés tels quels.
-- =====================================================================

DROP VIEW  IF EXISTS v_contrats;
DROP TABLE IF EXISTS sinistres;
DROP TABLE IF EXISTS contrats;
DROP TABLE IF EXISTS journal_nettoyage;

-- ---------------------------------------------------------------------
-- Table des contrats : noms de colonnes en français, règles R1 et R2
-- ---------------------------------------------------------------------
CREATE TABLE contrats (
    id_contrat          INTEGER PRIMARY KEY,
    nb_sinistres        INTEGER NOT NULL,   -- nombre de sinistres chiffrés dans la table des sinistres (R2)
    nb_sinistres_declare INTEGER NOT NULL,  -- valeur d'origine de ClaimNb
    exposition          REAL    NOT NULL,   -- en années, plafonnée à 1 (R1)
    exposition_brute    REAL    NOT NULL,
    puissance           INTEGER NOT NULL,
    age_vehicule        INTEGER NOT NULL,
    age_conducteur      INTEGER NOT NULL,
    bonus_malus         INTEGER NOT NULL,
    marque              TEXT    NOT NULL,
    carburant           TEXT    NOT NULL,
    zone                TEXT    NOT NULL,   -- A = rural ... F = centre urbain
    densite             INTEGER NOT NULL,
    region              TEXT    NOT NULL,
    detail_disponible   INTEGER NOT NULL    -- 1 si au moins un sinistre chiffré
);

INSERT INTO contrats
SELECT
    c.IDpol,
    COALESCE(d.nb_detail, 0),          -- R2 : nombre de sinistres d'après le détail
    c.ClaimNb,
    MIN(c.Exposure, 1.0),
    c.Exposure,
    c.VehPower,
    c.VehAge,
    c.DrivAge,
    c.BonusMalus,
    c.VehBrand,
    c.VehGas,
    c.Area,
    c.Density,
    c.Region,
    CASE WHEN d.nb_detail IS NULL THEN 0 ELSE 1 END
FROM contrats_brut AS c
LEFT JOIN (SELECT IDpol, COUNT(*) AS nb_detail FROM sinistres_brut GROUP BY IDpol) AS d ON d.IDpol = c.IDpol;

-- ---------------------------------------------------------------------
-- Table des sinistres : règles R3 et R4
-- ---------------------------------------------------------------------
CREATE TABLE sinistres (
    id_sinistre         INTEGER PRIMARY KEY AUTOINCREMENT,
    id_contrat          INTEGER NOT NULL REFERENCES contrats(id_contrat),
    montant             REAL    NOT NULL,   -- montant d'origine
    montant_plafonne    REAL    NOT NULL    -- plafonné à 100 000 (R4)
);

INSERT INTO sinistres (id_contrat, montant, montant_plafonne)
SELECT s.IDpol, s.ClaimAmount, MIN(s.ClaimAmount, 100000.0)
FROM sinistres_brut AS s
INNER JOIN contrats AS c ON c.id_contrat = s.IDpol;   -- R3 : écarte les sinistres orphelins

CREATE INDEX idx_sinistres_contrat ON sinistres(id_contrat);

-- ---------------------------------------------------------------------
-- Vue des segments : tranches utilisées dans toutes les analyses
-- ---------------------------------------------------------------------
CREATE VIEW v_contrats AS
SELECT
    c.*,
    CASE
        WHEN age_conducteur < 25 THEN '1. 18-24 ans'
        WHEN age_conducteur < 35 THEN '2. 25-34 ans'
        WHEN age_conducteur < 45 THEN '3. 35-44 ans'
        WHEN age_conducteur < 55 THEN '4. 45-54 ans'
        WHEN age_conducteur < 65 THEN '5. 55-64 ans'
        WHEN age_conducteur < 75 THEN '6. 65-74 ans'
        ELSE '7. 75 ans et plus'
    END AS tranche_age,
    CASE
        WHEN bonus_malus = 50  THEN '1. 50 (bonus maximal)'
        WHEN bonus_malus < 100 THEN '2. 51 à 99 (bonus)'
        WHEN bonus_malus = 100 THEN '3. 100 (neutre)'
        WHEN bonus_malus <= 125 THEN '4. 101 à 125 (malus léger)'
        ELSE '5. Plus de 125 (malus fort)'
    END AS tranche_bonus_malus,
    CASE
        WHEN age_vehicule = 0  THEN '1. Neuf (0 an)'
        WHEN age_vehicule <= 4 THEN '2. 1 à 4 ans'
        WHEN age_vehicule <= 9 THEN '3. 5 à 9 ans'
        WHEN age_vehicule <= 14 THEN '4. 10 à 14 ans'
        ELSE '5. 15 ans et plus'
    END AS tranche_age_vehicule
FROM contrats AS c;

-- ---------------------------------------------------------------------
-- Journal du nettoyage : combien de lignes chaque règle touche
-- ---------------------------------------------------------------------
CREATE TABLE journal_nettoyage (
    regle        TEXT,
    description  TEXT,
    lignes_touchees INTEGER
);

INSERT INTO journal_nettoyage VALUES
 ('R1', 'Exposition plafonnée à 1 an (contrats touchés)',
        (SELECT COUNT(*) FROM contrats WHERE exposition_brute > 1)),
 ('R2a', 'Contrats dont ClaimNb annonce des sinistres sans aucun montant (sinistres comptés à 0)',
        (SELECT COUNT(*) FROM contrats WHERE nb_sinistres_declare > 0 AND detail_disponible = 0)),
 ('R2b', 'Sinistres déclarés dans ClaimNb mais absents du détail (ignorés)',
        (SELECT SUM(nb_sinistres_declare) FROM contrats WHERE detail_disponible = 0)),
 ('R2c', 'Contrats dont le nombre déclaré diffère du détail (autres cas)',
        (SELECT COUNT(*) FROM contrats WHERE detail_disponible = 1 AND nb_sinistres_declare <> nb_sinistres)),
 ('R3', 'Sinistres sans contrat exclus',
        (SELECT COUNT(*) FROM sinistres_brut) - (SELECT COUNT(*) FROM sinistres)),
 ('R4', 'Montants de sinistres plafonnés à 100 000',
        (SELECT COUNT(*) FROM sinistres WHERE montant > 100000));

-- Q1. Journal du nettoyage
SELECT * FROM journal_nettoyage;

-- Q2. Contrôle : aucun contrat perdu, exposition totale et coûts avant et après
SELECT
    (SELECT COUNT(*) FROM contrats_brut)               AS contrats_avant,
    (SELECT COUNT(*) FROM contrats)                    AS contrats_apres,
    (SELECT COUNT(*) FROM sinistres_brut)              AS sinistres_avant,
    (SELECT COUNT(*) FROM sinistres)                   AS sinistres_apres,
    ROUND((SELECT SUM(Exposure) FROM contrats_brut), 0)  AS exposition_avant,
    ROUND((SELECT SUM(exposition) FROM contrats), 0)     AS exposition_apres,
    ROUND((SELECT SUM(ClaimAmount) FROM sinistres_brut), 0)     AS cout_avant,
    ROUND((SELECT SUM(montant) FROM sinistres), 0)              AS cout_apres,
    ROUND((SELECT SUM(montant_plafonne) FROM sinistres), 0)     AS cout_plafonne;

-- Q3. Nombre total de sinistres : déclaré dans ClaimNb contre compté dans le détail
SELECT
    SUM(nb_sinistres_declare) AS sinistres_declares_claimnb,
    SUM(nb_sinistres)         AS sinistres_dans_le_detail
FROM contrats;
