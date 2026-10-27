-- =====================================================================
-- 01_controles_qualite.sql
-- Contrôles de qualité sur les données brutes (tables contrats_brut et
-- sinistres_brut, chargées par scripts/charger_donnees.py).
-- Aucune donnée n'est modifiée ici : ce script ne fait que lire.
-- Les décisions de nettoyage sont dans 02_nettoyage.sql.
-- =====================================================================

-- Q1. Volumétrie des deux tables
SELECT 'contrats_brut' AS table_source, COUNT(*) AS nb_lignes FROM contrats_brut
UNION ALL
SELECT 'sinistres_brut', COUNT(*) FROM sinistres_brut;

-- Q2. Clé unique : un contrat ne doit apparaître qu'une fois dans contrats_brut
SELECT COUNT(*) - COUNT(DISTINCT IDpol) AS contrats_en_double
FROM contrats_brut;

-- Q3. Valeurs manquantes dans chaque colonne de contrats_brut
SELECT
    SUM(IDpol IS NULL)      AS idpol_null,
    SUM(ClaimNb IS NULL)    AS claimnb_null,
    SUM(Exposure IS NULL)   AS exposure_null,
    SUM(VehPower IS NULL)   AS vehpower_null,
    SUM(VehAge IS NULL)     AS vehage_null,
    SUM(DrivAge IS NULL)    AS drivage_null,
    SUM(BonusMalus IS NULL) AS bonusmalus_null,
    SUM(VehBrand IS NULL)   AS vehbrand_null,
    SUM(VehGas IS NULL)     AS vehgas_null,
    SUM(Area IS NULL)       AS area_null,
    SUM(Density IS NULL)    AS density_null,
    SUM(Region IS NULL)     AS region_null
FROM contrats_brut;

-- Q4. Exposition : une année complète vaut 1, donc toute valeur supérieure est suspecte
SELECT
    MIN(Exposure)                    AS exposition_min,
    MAX(Exposure)                    AS exposition_max,
    SUM(Exposure > 1)                AS contrats_exposition_sup_1,
    ROUND(SUM(Exposure), 0)          AS exposition_totale_annees
FROM contrats_brut;

-- Q5. Nombre de sinistres déclarés par contrat (distribution)
SELECT ClaimNb AS nb_sinistres, COUNT(*) AS nb_contrats,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM contrats_brut), 3) AS pourcentage
FROM contrats_brut
GROUP BY ClaimNb
ORDER BY ClaimNb;

-- Q6. Bornes des variables explicatives (âge du véhicule, du conducteur, bonus-malus)
SELECT
    MIN(VehAge) AS age_vehicule_min,    MAX(VehAge) AS age_vehicule_max,
    SUM(VehAge > 30) AS vehicules_plus_30_ans,
    MIN(DrivAge) AS age_conducteur_min, MAX(DrivAge) AS age_conducteur_max,
    MIN(BonusMalus) AS bonus_malus_min, MAX(BonusMalus) AS bonus_malus_max,
    MIN(VehPower) AS puissance_min,     MAX(VehPower) AS puissance_max,
    MIN(Density) AS densite_min,        MAX(Density) AS densite_max
FROM contrats_brut;

-- Q7. Sinistres : montants (minimum, maximum, grands sinistres)
SELECT
    COUNT(*)                         AS nb_sinistres,
    MIN(ClaimAmount)                 AS montant_min,
    MAX(ClaimAmount)                 AS montant_max,
    SUM(ClaimAmount >= 100000)       AS sinistres_100k_et_plus,
    SUM(ClaimAmount >= 1000000)      AS sinistres_1m_et_plus,
    ROUND(SUM(ClaimAmount), 0)       AS montant_total
FROM sinistres_brut;

-- Q8. Sinistres sans contrat correspondant (anti-jointure)
SELECT COUNT(*)              AS sinistres_orphelins,
       COUNT(DISTINCT s.IDpol) AS contrats_inconnus_distincts
FROM sinistres_brut AS s
LEFT JOIN contrats_brut AS c ON c.IDpol = s.IDpol
WHERE c.IDpol IS NULL;

-- Q9. Cohérence entre le nombre de sinistres déclaré (ClaimNb) et le détail disponible
WITH detail AS (
    SELECT IDpol, COUNT(*) AS nb_detail
    FROM sinistres_brut
    GROUP BY IDpol
)
SELECT
    SUM(c.ClaimNb > 0 AND d.IDpol IS NULL)                      AS declare_sans_detail,
    SUM(c.ClaimNb = 0 AND d.IDpol IS NOT NULL)                  AS detail_sans_declaration,
    SUM(d.IDpol IS NOT NULL AND c.ClaimNb <> d.nb_detail)       AS nombre_different,
    SUM(d.IDpol IS NOT NULL AND c.ClaimNb = d.nb_detail)        AS coherents,
    SUM(c.ClaimNb > 0)                                          AS contrats_avec_sinistre
FROM contrats_brut AS c
LEFT JOIN detail AS d ON d.IDpol = c.IDpol;

-- Q10. Sinistres de même contrat et même montant (doublons possibles ou montants forfaitaires)
SELECT COUNT(*) AS groupes_idpol_montant_repetes,
       SUM(nb) AS lignes_concernees
FROM (
    SELECT IDpol, ClaimAmount, COUNT(*) AS nb
    FROM sinistres_brut
    GROUP BY IDpol, ClaimAmount
    HAVING COUNT(*) > 1
);

-- Q11. Montants les plus répétés dans les sinistres (forfaits ?)
SELECT ClaimAmount AS montant, COUNT(*) AS nb_sinistres
FROM sinistres_brut
GROUP BY ClaimAmount
ORDER BY nb_sinistres DESC
LIMIT 5;

-- Q12. Où sont les contrats qui annoncent des sinistres sans aucun montant ? (selon le numéro IDpol)
SELECT
    CASE WHEN c.IDpol <= 24500 THEN '1. IDpol de 24 500 ou moins' ELSE '2. IDpol au-dessus de 24 500' END AS plage_idpol,
    COUNT(*)                                                           AS nb_contrats,
    SUM(c.ClaimNb > 0)                                                 AS contrats_declarant_un_sinistre,
    SUM(c.ClaimNb > 0 AND NOT EXISTS (SELECT 1 FROM sinistres_brut s WHERE s.IDpol = c.IDpol)) AS declares_sans_montant
FROM contrats_brut AS c
GROUP BY plage_idpol
ORDER BY plage_idpol;
