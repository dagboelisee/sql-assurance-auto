-- =====================================================================
-- 04_requetes_avancees.sql
-- Requêtes plus poussées : fonctions de fenêtre (RANK, NTILE, SUM OVER,
-- moyenne mobile), tableau croisé, CTE enchaînées, sous-requêtes.
-- Prérequis : avoir exécuté 02_nettoyage.sql puis 03_frequence_cout.sql.
-- =====================================================================

-- Q1. Concentration des coûts : les 10 % de sinistres les plus chers
--     représentent quelle part du coût total ? (NTILE + SUM OVER)
WITH deciles AS (
    SELECT montant_plafonne,
           NTILE(10) OVER (ORDER BY montant_plafonne DESC) AS decile   -- 1 = les plus chers
    FROM sinistres
),
par_decile AS (
    SELECT decile,
           COUNT(*)                AS nb_sinistres,
           MIN(montant_plafonne)   AS montant_min,
           MAX(montant_plafonne)   AS montant_max,
           SUM(montant_plafonne)   AS cout
    FROM deciles
    GROUP BY decile
)
SELECT
    decile,
    nb_sinistres,
    ROUND(montant_min, 0) AS montant_min,
    ROUND(montant_max, 0) AS montant_max,
    ROUND(100.0 * cout / SUM(cout) OVER (), 1)                              AS part_du_cout_pct,
    ROUND(100.0 * SUM(cout) OVER (ORDER BY decile) / SUM(cout) OVER (), 1) AS part_cumulee_pct
FROM par_decile
ORDER BY decile;

-- Q2. Classement des régions par prime pure, avec écart à la moyenne du portefeuille
WITH reg AS (
    SELECT region,
           COUNT(*)                                        AS nb_contrats,
           SUM(exposition)                                 AS exposition,
           SUM(nb_sinistres)                               AS nb_sinistres,
           SUM(nb_sinistres_chiffres)                      AS nb_chiffres,
           SUM(cout_plafonne)                              AS cout
    FROM contrats_cout
    GROUP BY region
),
indic AS (
    SELECT region, nb_contrats, exposition,
           1.0 * nb_sinistres / exposition                 AS frequence,
           cout / nb_chiffres                              AS cout_moyen,
           (1.0 * nb_sinistres / exposition) * (cout / nb_chiffres) AS prime_pure
    FROM reg
)
SELECT
    RANK() OVER (ORDER BY prime_pure DESC)                         AS rang,
    region,
    nb_contrats,
    ROUND(100 * frequence, 2)                                      AS frequence_pour_100,
    ROUND(cout_moyen, 0)                                           AS cout_moyen,
    ROUND(prime_pure, 1)                                           AS prime_pure,
    ROUND(100.0 * prime_pure / (SELECT 1.0 * SUM(cout_plafonne) / SUM(nb_sinistres_chiffres)
                                       * SUM(nb_sinistres) / SUM(exposition) FROM contrats_cout), 0)
                                                                   AS indice_base_100
FROM indic
ORDER BY rang;

-- Q3. Tableau croisé : fréquence (pour 100 années) par âge du conducteur x bonus-malus
--     (CASE WHEN pour faire pivoter les colonnes)
SELECT
    tranche_age,
    ROUND(100.0 * SUM(CASE WHEN bonus_malus = 50  THEN nb_sinistres END)
                / SUM(CASE WHEN bonus_malus = 50  THEN exposition  END), 1) AS bm_50,
    ROUND(100.0 * SUM(CASE WHEN bonus_malus BETWEEN 51 AND 99 THEN nb_sinistres END)
                / SUM(CASE WHEN bonus_malus BETWEEN 51 AND 99 THEN exposition  END), 1) AS bm_51_99,
    ROUND(100.0 * SUM(CASE WHEN bonus_malus >= 100 THEN nb_sinistres END)
                / SUM(CASE WHEN bonus_malus >= 100 THEN exposition  END), 1) AS bm_100_et_plus
FROM contrats_cout
GROUP BY tranche_age
ORDER BY tranche_age;

-- Q4. Fréquence par âge exact du conducteur, lissée par une moyenne mobile sur 5 ans d'âge
--     (on additionne sinistres et expositions sur la fenêtre, on ne moyenne pas des moyennes).
--     Le filtre sur les âges affichés est placé APRÈS le calcul de la fenêtre :
--     un WHERE placé avant retirerait les âges voisins du calcul.
WITH par_age AS (
    SELECT age_conducteur, SUM(nb_sinistres) AS sinistres, SUM(exposition) AS expo
    FROM contrats_cout
    WHERE age_conducteur BETWEEN 18 AND 80
    GROUP BY age_conducteur
),
lisse AS (
    SELECT
        age_conducteur,
        expo,
        100.0 * sinistres / expo                                              AS frequence_brute,
        100.0 * SUM(sinistres) OVER w / SUM(expo) OVER w                      AS frequence_lissee
    FROM par_age
    WINDOW w AS (ORDER BY age_conducteur ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING)
)
SELECT
    age_conducteur,
    ROUND(expo, 0)             AS exposition,
    ROUND(frequence_brute, 1)  AS frequence_brute,
    ROUND(frequence_lissee, 1) AS frequence_lissee
FROM lisse
WHERE age_conducteur IN (18, 20, 22, 25, 30, 40, 50, 60, 70, 80)
ORDER BY age_conducteur;

-- Q5. Variation de la fréquence d'un âge de véhicule à l'autre (LAG)
WITH par_age AS (
    SELECT age_vehicule, SUM(nb_sinistres) AS sinistres, SUM(exposition) AS expo
    FROM contrats_cout
    WHERE age_vehicule <= 12
    GROUP BY age_vehicule
)
SELECT
    age_vehicule,
    ROUND(expo, 0)                                   AS exposition,
    ROUND(100.0 * sinistres / expo, 2)               AS frequence_pour_100,
    ROUND(100.0 * sinistres / expo
          - LAG(100.0 * sinistres / expo) OVER (ORDER BY age_vehicule), 2) AS variation_vs_annee_precedente
FROM par_age
ORDER BY age_vehicule;

-- Q6. Piège de l'exposition courte : la fréquence annualisée explose quand l'exposition est courte
--     (explique en partie les fréquences élevées des véhicules neufs et du bonus-malus 100)
SELECT
    CASE
        WHEN exposition_brute < 0.1  THEN '1. moins de 0,1 an'
        WHEN exposition_brute < 0.25 THEN '2. 0,1 à 0,25 an'
        WHEN exposition_brute < 0.5  THEN '3. 0,25 à 0,5 an'
        WHEN exposition_brute < 1    THEN '4. 0,5 à 1 an'
        ELSE                              '5. 1 an ou plus'
    END                                                   AS duree_exposition,
    COUNT(*)                                              AS nb_contrats,
    ROUND(SUM(exposition), 0)                             AS exposition,
    ROUND(100.0 * SUM(nb_sinistres) / SUM(exposition), 1) AS frequence_pour_100,
    ROUND(100.0 * SUM(nb_sinistres > 0) / COUNT(*), 2)    AS contrats_avec_sinistre_pct
FROM contrats_cout
GROUP BY duree_exposition
ORDER BY duree_exposition;

-- Q7. Même analyse en ne gardant que les contrats d'au moins 6 mois :
--     la fréquence des véhicules neufs retombe-t-elle ?
SELECT
    tranche_age_vehicule,
    COUNT(*)                                              AS nb_contrats,
    ROUND(100.0 * SUM(nb_sinistres) / SUM(exposition), 2) AS frequence_pour_100
FROM contrats_cout
WHERE exposition_brute >= 0.5
GROUP BY tranche_age_vehicule
ORDER BY tranche_age_vehicule;

-- Q8. Les marques : classement avec un seuil d'exposition minimal (HAVING)
--     pour ne pas comparer des marques trop rares
SELECT
    marque,
    COUNT(*)                                              AS nb_contrats,
    ROUND(SUM(exposition), 0)                             AS exposition,
    ROUND(100.0 * SUM(nb_sinistres) / SUM(exposition), 2) AS frequence_pour_100,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres), 0) AS cout_moyen,
    RANK() OVER (ORDER BY SUM(nb_sinistres) / SUM(exposition) DESC) AS rang_frequence
FROM contrats_cout
GROUP BY marque
HAVING SUM(exposition) >= 5000
ORDER BY rang_frequence;

-- Q9. Contrats à risque : conducteurs de moins de 25 ans avec malus ou bonus-malus neutre,
--     comparés au reste du portefeuille (sous-requête scalaire)
SELECT
    CASE WHEN age_conducteur < 25 AND bonus_malus >= 100 THEN 'Moins de 25 ans, BM >= 100'
         ELSE 'Reste du portefeuille' END                 AS groupe,
    COUNT(*)                                              AS nb_contrats,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM contrats_cout), 1) AS part_contrats_pct,
    ROUND(100.0 * SUM(nb_sinistres) / SUM(exposition), 1) AS frequence_pour_100,
    ROUND(100.0 * SUM(cout_plafonne) / (SELECT SUM(cout_plafonne) FROM contrats_cout), 1) AS part_du_cout_pct
FROM contrats_cout
GROUP BY groupe;

-- Q10. Contrats déclarant des sinistres mais sans montant (règle R5) :
--      sont-ils répartis comme les autres ? (comparaison par tranche d'âge de véhicule)
SELECT
    tranche_age_vehicule,
    SUM(nb_sinistres)                                          AS sinistres_declares,
    SUM(CASE WHEN detail_disponible = 0 THEN nb_sinistres END) AS sans_montant,
    ROUND(100.0 * SUM(CASE WHEN detail_disponible = 0 THEN nb_sinistres END)
                / SUM(nb_sinistres), 1)                        AS part_sans_montant_pct
FROM contrats_cout
GROUP BY tranche_age_vehicule
ORDER BY tranche_age_vehicule;
