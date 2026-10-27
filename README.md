# Assurance auto : fréquence, coût et prime pure en SQL (freMTPL2)

Projet SQL (SQLite) construit sur un portefeuille réel d'assurance automobile française : **678 013 contrats et 26 639 sinistres**. Question de départ : **qui coûte cher à assurer, et pourquoi ?** Le projet va du contrôle qualité des données brutes jusqu'à la prime pure par segment, en passant par un nettoyage documenté règle par règle.

## Résultats clés

| Constat | Chiffre |
|---|---|
| Fréquence de sinistres du portefeuille | **10,06 sinistres pour 100 années-contrat** (36 056 sinistres pour 358 360 années) |
| Coût moyen d'un sinistre | **1 864** (après plafonnement à 100 000 ; 2 266 sans plafond) |
| Prime pure moyenne (fréquence x coût moyen) | **187,6** par année-contrat |
| Jeunes conducteurs (18-24 ans) | fréquence **18,9 %** contre 9,3 % pour les 35-44 ans, soit une prime pure de **446** (2,4 fois la moyenne) |
| Bonus-malus | fréquence de **8,0 %** au bonus maximal (50) contre **44,0 %** au-delà de 125 : prime pure de 143 contre 1 185 |
| Cumul jeune conducteur et bonus-malus de 100 ou plus | **1,4 %** des contrats, **5,7 %** du coût total, fréquence de 37,3 % |
| Zone | fréquence de **8,2 %** en zone rurale (A) contre **13,9 %** en centre urbain (F) |
| Concentration du coût | les **10 % de sinistres les plus chers** font **51 %** du coût (60 % sans plafonnement) |
| Marque | la marque B12 (166 024 contrats) a une fréquence de **13,7 %**, contre environ 9 % pour B1 et B2 |

Les chiffres détaillés de chaque script sont dans le dossier [resultats/](resultats/).

## Contenu du dépôt

```
sql/
  01_controles_qualite.sql    11 contrôles en lecture seule sur les données brutes
  02_nettoyage.sql            tables propres, vue des segments, journal des règles
  03_frequence_cout.sql       fréquence, coût moyen et prime pure par segment
  04_requetes_avancees.sql    fonctions de fenêtre, tableau croisé, pièges d'interprétation
scripts/
  charger_donnees.py          charge les deux CSV dans SQLite
  executer_sql.py             exécute un fichier .sql et affiche chaque résultat
  lancer_tout.py              enchaîne tout et écrit les résultats
resultats/                    sortie de chaque script (texte)
donnees/LISEZ-MOI.md          où télécharger les données, dictionnaire des colonnes
```

## Reproduire

Il faut Python 3 (SQLite est inclus dans Python) et les deux fichiers CSV (voir [donnees/LISEZ-MOI.md](donnees/LISEZ-MOI.md)).

```
python scripts/lancer_tout.py chemin/vers/les/csv
```

La base `fremtpl2.db` est créée et les quatre scripts s'exécutent. On peut aussi ouvrir la base avec DB Browser for SQLite et lancer les scripts un par un.

## Méthode

**Deux tables sources.** `contrats_brut` (un contrat par ligne, avec son exposition et le nombre de sinistres déclarés) et `sinistres_brut` (un sinistre par ligne, avec son montant), reliées par `IDpol`. Les tables brutes ne sont jamais modifiées : le nettoyage produit de nouvelles tables.

**Définitions** (identiques dans tous les scripts) :

- **Exposition** : durée pendant laquelle le contrat a été en vigueur, en années. Un contrat de six mois vaut 0,5.
- **Fréquence** = nombre de sinistres / somme des expositions.
- **Coût moyen** = somme des montants plafonnés / nombre de sinistres chiffrés.
- **Prime pure** = fréquence x coût moyen : le coût attendu par année-contrat, avant frais et marge.

On additionne toujours les sinistres, les expositions et les coûts avant de diviser. Moyenner des moyennes donnerait le même poids à un segment de 200 contrats et à un segment de 200 000.

## Contrôles qualité et règles de nettoyage

Le script `01` ne touche à rien : Il ne trouve ni doublon de contrat, ni valeur manquante, mais plusieurs points qui demandent une décision.

| Règle | Constat | Décision | Lignes touchées |
|---|---|---|---|
| R1 | 1 224 contrats ont une exposition supérieure à 1 an (maximum 2,01), alors qu'une année complète vaut 1 | Exposition plafonnée à 1 an, valeur d'origine conservée dans `exposition_brute` | 1 224 (139 années retirées sur 358 499) |
| R2 | 9 contrats déclarent plus de 4 sinistres (jusqu'à 16) | Nombre plafonné à 4, valeur d'origine conservée | 9 |
| R3 | 195 sinistres pointent vers 6 contrats absents de la table des contrats | Exclus : impossible de leur attribuer un segment | 195 |
| R4 | 42 sinistres atteignent 100 000 ou plus, dont 3 dépassent 1 million (maximum 4,08 millions) | Montant plafonné à 100 000 dans une colonne à part (`montant_plafonne`) | 41 après exclusion des orphelins |
| R5 | 9 116 contrats déclarent un sinistre sans qu'aucun montant ne soit disponible | **Conservés** : ils comptent pour la fréquence, pas pour le coût moyen | 9 116 |

Le contrôle de cohérence final du script `02` montre que les 678 013 contrats sont tous conservés, que 26 444 sinistres sur 26 639 restent, et que le plafonnement retire 17,7 % du coût total des sinistres (59,9 millions avant, 49,3 millions après).

**Pourquoi plafonner à 100 000 ?** Quelques sinistres très rares peuvent à eux seuls faire bouger le coût moyen d'un segment entier. Le seuil de 100 000 est un choix d'analyse, pas une valeur de référence : en pratique, les assureurs traitent ces sinistres graves à part. Le montant d'origine est conservé, et la requête 8 du script `03` mesure l'effet du plafond.

## Ce que montrent les analyses

**L'âge et le bonus-malus dominent.** Les 18-24 ans ont une fréquence de 18,9 % (prime pure 446) alors que toutes les tranches de 25 à 74 ans se situent entre 9 et 10,6 %. Le coût moyen varie peu d'un segment à l'autre (de 1 500 à 2 700 environ) : la différence de prime vient surtout de la fréquence. Le bonus-malus classe les contrats de façon quasi monotone : 8,0 % au bonus maximal, 12,1 % entre 51 et 99, 27,6 % à 100, jusqu'à 44,0 % au-delà de 125. Le tableau croisé (script `04`, requête 3) montre que les deux effets se cumulent : 37,3 % de fréquence pour les moins de 25 ans avec un bonus-malus d'au moins 100.

**Deux fréquences paraissent anormalement élevées, et elles s'expliquent en partie.** Les véhicules neufs affichent 31,2 % et les contrats à bonus-malus 100 affichent 27,6 %. Ces contrats ont une exposition courte (0,29 an en moyenne pour les véhicules neufs, 0,32 pour le bonus-malus 100, contre 0,59 pour le bonus maximal). Or la fréquence annualisée explose quand l'exposition est courte : 45,3 % pour les contrats de moins de 0,1 an, 7,0 % pour ceux d'un an ou plus (script `04`, requête 6). En ne gardant que les contrats d'au moins six mois, la fréquence des véhicules neufs retombe à 16,1 %, mais reste le double de celle des véhicules de 1 à 4 ans (8,2 %). Une partie de l'écart reste donc inexpliquée par ces données.

**Le coût est concentré.** Les 10 % de sinistres les plus chers représentent 51,3 % du coût après plafonnement (59,9 % sans plafond). À l'autre bout, la moitié la moins chère des sinistres ne pèse que 18 % du coût.

**La géographie est contrastée mais bruitée.** La fréquence monte de 8,2 % en zone A à 13,9 % en zone F. Parmi les régions, l'Île-de-France (13,2 %) et la Provence-Alpes-Côte d'Azur (prime pure 237) sont au-dessus de la moyenne. La Corse (indice 205) et la Champagne-Ardenne (indice 195) arrivent en tête du classement, mais avec 4 516 et 3 026 contrats seulement : ces indices sont instables et ne doivent pas être lus comme des tarifs.

## Limites

- **Analyse univariée.** Chaque segment est étudié séparément. Les facteurs sont corrélés (les jeunes conducteurs ont plus souvent un bonus-malus de 100, les centres urbains ont des véhicules plus récents). Isoler l'effet propre de chaque variable demande un modèle, par exemple une régression pour la fréquence et une régression pour le coût. 
- **Le coût moyen repose sur 73 % des sinistres.** 9 116 contrats déclarent un sinistre sans montant (règle R5). Ce manque n'est pas réparti au hasard : il touche 77 % des sinistres déclarés des véhicules neufs, contre 15 à 20 % pour les autres âges (script `04`, requête 10). Le coût moyen des véhicules neufs est donc peu fiable.
- **Montants forfaitaires probables.** 4 792 sinistres (18 %) valent exactement 1 204, et quatre autres montants reviennent plus de 400 fois chacun. Je suppose qu'il s'agit de forfaits, mais la source ne le précise pas.
- **Plafond arbitraire.** Un seuil de 50 000 ou de 200 000 changerait les niveaux de coût moyen, pas le classement des segments.
- **Variables non nettoyées.** Quelques valeurs extrêmes subsistent (1 116 véhicules de plus de 30 ans, un âge de véhicule et de conducteur maximal de 100). Elles sont conservées et regroupées dans la tranche la plus haute.
- **Source.** La devise et la période d'observation ne sont pas précisées dans le jeu de données. Je suppose des euros, sans pouvoir le vérifier.

## Compétences mises en œuvre

Jointures (INNER, LEFT, anti-jointure), agrégations et HAVING, CTE enchaînées, sous-requêtes scalaires, fonctions de fenêtre (RANK, NTILE, LAG, SUM OVER, moyenne mobile avec cadre de lignes), tableau croisé avec CASE WHEN, création de tables et de vues, index, contrôle qualité et traçabilité du nettoyage (journal des règles), pièges classiques (moyenne de moyennes, multiplication des lignes après jointure, filtre placé avant une fonction de fenêtre), interprétation métier (fréquence, coût moyen, prime pure).

## Auteur

Élisée Dagbo – Master 2 Économétrie et Statistique (Économétrie Appliquée), IAE Nantes.
