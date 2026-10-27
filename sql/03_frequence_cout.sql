-- =====================================================================
-- 03_frequence_cout.sql
-- Fréquence, coût moyen et prime pure par segment.
--
-- Définitions utilisées partout dans ce dépôt :
--   fréquence      = nombre de sinistres / exposition (en années-contrat)
--   coût moyen     = somme des montants plafonnés / nombre de sinistres chiffrés
--   prime pure     = fréquence x coût moyen (coût attendu par année-contrat)
--   indice         = prime pure du segment / prime pure globale x 100
-- On ne calcule JAMAIS une moyenne de moyennes : on additionne d'abord
-- (sinistres, exposition, coûts) puis on divise.
-- Prérequis : avoir exécuté 02_nettoyage.sql.
-- =====================================================================

DROP TABLE IF EXISTS contrats_cout;

-- Une ligne par contrat, avec le coût et le nombre de sinistres chiffrés.
-- Cette table évite de joindre les sinistres à chaque requête et, surtout,
-- évite de multiplier les lignes de contrats lors de la jointure.
CREATE TABLE contrats_cout AS
SELECT
    v.*,
    COALESCE(s.nb_chiffres, 0)   AS nb_sinistres_chiffres,
    COALESCE(s.cout_plafonne, 0) AS cout_plafonne
FROM v_contrats AS v
LEFT JOIN (
    SELECT id_contrat, COUNT(*) AS nb_chiffres, SUM(montant_plafonne) AS cout_plafonne
    FROM sinistres
    GROUP BY id_contrat
) AS s ON s.id_contrat = v.id_contrat;

CREATE INDEX idx_contrats_cout_id ON contrats_cout(id_contrat);

-- Q1. Indicateurs globaux du portefeuille
SELECT
    COUNT(*)                                              AS nb_contrats,
    ROUND(SUM(exposition), 0)                             AS exposition_annees,
    SUM(nb_sinistres)                                     AS nb_sinistres,
    ROUND(100.0 * SUM(nb_sinistres) / SUM(exposition), 2) AS frequence_pour_100_annees,
    SUM(nb_sinistres_chiffres)                            AS sinistres_chiffres,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres), 0) AS cout_moyen,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres)
          * SUM(nb_sinistres) / SUM(exposition), 1)       AS prime_pure
FROM contrats_cout;

-- Q2. Par tranche d'âge du conducteur
SELECT
    tranche_age,
    COUNT(*)                                              AS nb_contrats,
    ROUND(SUM(exposition), 0)                             AS exposition,
    ROUND(100.0 * SUM(nb_sinistres) / SUM(exposition), 2) AS frequence_pour_100,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres), 0) AS cout_moyen,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres)
          * SUM(nb_sinistres) / SUM(exposition), 1)       AS prime_pure
FROM contrats_cout
GROUP BY tranche_age
ORDER BY tranche_age;

-- Q3. Par niveau de bonus-malus
SELECT
    tranche_bonus_malus,
    COUNT(*)                                              AS nb_contrats,
    ROUND(SUM(exposition), 0)                             AS exposition,
    ROUND(100.0 * SUM(nb_sinistres) / SUM(exposition), 2) AS frequence_pour_100,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres), 0) AS cout_moyen,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres)
          * SUM(nb_sinistres) / SUM(exposition), 1)       AS prime_pure
FROM contrats_cout
GROUP BY tranche_bonus_malus
ORDER BY tranche_bonus_malus;

-- Q4. Par âge du véhicule
SELECT
    tranche_age_vehicule,
    COUNT(*)                                              AS nb_contrats,
    ROUND(SUM(exposition), 0)                             AS exposition,
    ROUND(100.0 * SUM(nb_sinistres) / SUM(exposition), 2) AS frequence_pour_100,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres), 0) AS cout_moyen,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres)
          * SUM(nb_sinistres) / SUM(exposition), 1)       AS prime_pure
FROM contrats_cout
GROUP BY tranche_age_vehicule
ORDER BY tranche_age_vehicule;

-- Q5. Par zone de densité (A = rural ... F = centre urbain)
SELECT
    zone,
    COUNT(*)                                              AS nb_contrats,
    ROUND(SUM(exposition), 0)                             AS exposition,
    ROUND(100.0 * SUM(nb_sinistres) / SUM(exposition), 2) AS frequence_pour_100,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres), 0) AS cout_moyen,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres)
          * SUM(nb_sinistres) / SUM(exposition), 1)       AS prime_pure
FROM contrats_cout
GROUP BY zone
ORDER BY zone;

-- Q6. Par carburant
SELECT
    carburant,
    COUNT(*)                                              AS nb_contrats,
    ROUND(SUM(exposition), 0)                             AS exposition,
    ROUND(100.0 * SUM(nb_sinistres) / SUM(exposition), 2) AS frequence_pour_100,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres), 0) AS cout_moyen,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres)
          * SUM(nb_sinistres) / SUM(exposition), 1)       AS prime_pure
FROM contrats_cout
GROUP BY carburant
ORDER BY carburant;

-- Q7. Par puissance du véhicule
SELECT
    puissance,
    COUNT(*)                                              AS nb_contrats,
    ROUND(SUM(exposition), 0)                             AS exposition,
    ROUND(100.0 * SUM(nb_sinistres) / SUM(exposition), 2) AS frequence_pour_100,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres), 0) AS cout_moyen,
    ROUND(SUM(cout_plafonne) / SUM(nb_sinistres_chiffres)
          * SUM(nb_sinistres) / SUM(exposition), 1)       AS prime_pure
FROM contrats_cout
GROUP BY puissance
ORDER BY puissance;

-- Q8. Effet du plafonnement : coût moyen avec et sans plafond à 100 000
SELECT
    ROUND(SUM(montant) / COUNT(*), 0)            AS cout_moyen_brut,
    ROUND(SUM(montant_plafonne) / COUNT(*), 0)   AS cout_moyen_plafonne,
    ROUND(100.0 * (SUM(montant) - SUM(montant_plafonne)) / SUM(montant), 1)
                                                 AS part_du_cout_total_retiree_pct
FROM sinistres;
