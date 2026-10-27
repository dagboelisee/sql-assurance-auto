# Assurance auto : fréquence, coût et prime pure en SQL (freMTPL2)

Projet SQL (SQLite) construit sur un portefeuille réel d'assurance automobile française : **678 013 contrats et 26 639 sinistres**. Question de départ : **qui coûte cher à assurer, et pourquoi ?** Le projet va du contrôle qualité des données brutes jusqu'à la prime pure par segment, en passant par un nettoyage documenté règle par règle.

## Résultats clés

| Constat | Chiffre |
|---|---|
| Fréquence de sinistres du portefeuille | **7,38 sinistres pour 100 années-contrat** (26 444 sinistres pour 358 360 années) |
| Coût moyen d'un sinistre | **1 864** (après plafonnement à 100 000 ; 2 266 sans plafond) |
| Prime pure moyenne (coût total / exposition) | **137,6** par année-contrat |
| Jeunes conducteurs (18-24 ans) | fréquence **16,1 %**, contre 5,8 à 7,7 % pour les 25 ans et plus ; prime pure de **380**, soit 2,8 fois la moyenne |
| Bonus-malus | fréquence de **5,2 %** au bonus maximal (50) contre **43,7 %** au-delà de 125 : prime pure de 92 contre 1 177 |
| Cumul jeune conducteur et bonus-malus de 100 ou plus | **1,4 %** des contrats, **5,7 %** du coût total, fréquence de 33,4 % |
| Zone | fréquence de **5,4 %** en zone rurale (A) contre **9,6 %** en zone E ; la zone F (centre urbain) est à 9,5 % |
| Concentration du coût | les **10 % de sinistres les plus chers** font **51 %** du coût (60 % sans plafonnement) |
| Défaut des données | la colonne `ClaimNb` surestime les sinistres : **36 102 déclarés contre 26 444** dans le détail (fréquence de 10,1 % au lieu de 7,4 %) |

Les chiffres détaillés de chaque script sont dans le dossier [resultats/](resultats/).

**Cohérence avec la littérature.** Wüthrich et Merz (*Statistical Foundations of Actuarial Learning and its Applications*, Springer, 2023, annexe B) utilisent le même jeu de données, comptent les sinistres à partir du fichier de détail et obtiennent une fréquence de 7,35 %. Mon résultat (7,38 %) est cohérent. Ils expliquent que les nombres de sinistres de la table des contrats ne correspondent pas au détail pour les contrats dont le numéro est inférieur ou égal à 24 500. Je l'ai confirmé sur les données (voir ci-dessous).

## Contenu du dépôt

```
sql/
  01_controles_qualite.sql    12 contrôles en lecture seule sur les données brutes
  02_nettoyage.sql            tables propres, vue des segments, journal des règles
  03_frequence_cout.sql       fréquence, coût moyen et prime pure par segment
  04_requetes_avancees.sql    fonctions de fenêtre, tableau croisé, tests de robustesse
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

La base `fremtpl2.db` est créée et les quatre scripts s'exécutent en une dizaine de secondes. On peut aussi ouvrir la base avec DB Browser for SQLite et lancer les scripts un par un.

## Méthode

**Deux tables sources.** `contrats_brut` (un contrat par ligne, avec son exposition et un nombre de sinistres déclaré) et `sinistres_brut` (un sinistre par ligne, avec son montant), reliées par `IDpol`. Les tables brutes ne sont jamais modifiées : le nettoyage produit de nouvelles tables.

**Définitions** (identiques dans tous les scripts) :

- **Exposition** : durée pendant laquelle le contrat a été en vigueur, en années. Un contrat de six mois vaut 0,5.
- **Fréquence** = nombre de sinistres / somme des expositions.
- **Coût moyen** = somme des montants plafonnés / nombre de sinistres.
- **Prime pure** = fréquence x coût moyen = coût total / exposition : le coût attendu par année-contrat, avant frais et marge.

On additionne toujours les sinistres, les expositions et les coûts avant de diviser. Moyenner des moyennes donnerait le même poids à un segment de 200 contrats et à un segment de 200 000.

## Contrôles qualité et règles de nettoyage

Le script `01` ne touche à rien : il mesure. Il ne trouve ni doublon de contrat, ni valeur manquante, mais plusieurs points qui demandent une décision.

| Règle | Constat | Décision | Lignes touchées |
|---|---|---|---|
| R1 | 1 224 contrats ont une exposition supérieure à 1 an (maximum 2,01), alors qu'une année complète vaut 1 | Exposition plafonnée à 1 an, valeur d'origine conservée dans `exposition_brute` | 1 224 (139 années retirées sur 358 499) |
| R2 | 9 116 contrats annoncent des sinistres dans `ClaimNb` sans qu'aucun montant n'existe dans la table des sinistres (9 657 sinistres déclarés au total). 8 851 d'entre eux ont un `IDpol` inférieur ou égal à 24 500 | Le nombre de sinistres est **compté dans le détail**, pas dans `ClaimNb`. Le nombre déclaré est conservé dans `nb_sinistres_declare` | 9 116 contrats |
| R3 | 195 sinistres pointent vers 6 contrats absents de la table des contrats | Exclus : impossible de leur attribuer un segment | 195 |
| R4 | 42 sinistres atteignent 100 000 ou plus, dont 3 dépassent 1 million (maximum 4,08 millions) | Montant plafonné à 100 000 dans une colonne à part (`montant_plafonne`) | 41 après exclusion des orphelins |

Aucun contrat n'est supprimé : les 678 013 contrats sont tous conservés. Le plafonnement retire 17,7 % du coût total des sinistres (59,9 millions avant, 49,3 millions après). Une poignée de contrats comptent plus de 4 sinistres dans le détail (jusqu'à 16) : ils sont conservés tels quels, leur effet est négligeable.

**Pourquoi compter dans le détail (R2) ?** Le contrôle 12 montre que **tous** les 9 139 contrats dont le numéro est inférieur ou égal à 24 500 déclarent au moins un sinistre, contre 3,7 % pour les autres. Ce n'est pas un hasard : pour ces contrats, la table des contrats annonce des sinistres que le détail ne contient pas (8 851 sur 9 139). Si on fait confiance à `ClaimNb`, on compte 36 102 sinistres et une fréquence de 10,1 %, contre 26 444 sinistres et 7,4 % dans le détail. La requête 11 du script `04` montre que ce défaut crée de fausses anomalies : la fréquence des véhicules neufs passe de 31,2 % (avec `ClaimNb`) à 7,1 % (avec le détail), et celle de la marque B12 de 13,7 % à 6,5 %.

**Pourquoi plafonner à 100 000 (R4) ?** Quelques sinistres très rares peuvent à eux seuls faire bouger le coût moyen d'un segment entier. Le seuil de 100 000 est un choix d'analyse, pas une valeur de référence : en pratique, les assureurs traitent ces sinistres graves à part. Le montant d'origine est conservé, et la requête 8 du script `03` mesure l'effet du plafond.

## Ce que montrent les analyses

**L'âge et le bonus-malus dominent.** Les 18-24 ans ont une fréquence de 16,1 % (prime pure 380) alors que toutes les autres tranches se situent entre 5,8 et 7,7 %. Le coût moyen varie peu d'un segment à l'autre (de 1 500 à 2 700 environ) : la différence de prime vient surtout de la fréquence. Le bonus-malus classe les contrats de façon monotone : 5,2 % au bonus maximal, 10,0 % entre 51 et 99, 21,2 % à 100, 34,2 % entre 101 et 125 et 43,7 % au-delà. Le tableau croisé (script `04`, requête 3) montre que les deux effets se cumulent : 33,4 % de fréquence pour les moins de 25 ans avec un bonus-malus d'au moins 100, soit 1,4 % des contrats mais 5,7 % du coût.

**La zone joue, jusqu'à un certain point.** La fréquence monte de 5,4 % en zone A (rural) à 9,6 % en zone E, puis reste à 9,5 % en zone F. Les accidents du centre urbain coûtent moins cher (1 505 contre 1 800 à 2 000 dans les autres zones), ce qui donne à la zone F une prime pure (143) inférieure à celle de la zone E (184).

**La durée du contrat fausse les fréquences annualisées.** Les contrats à bonus-malus 100 ont une exposition moyenne de 0,32 an, contre 0,59 pour le bonus maximal. Or la fréquence annualisée augmente quand l'exposition est courte : 16,8 % pour les contrats de moins de 0,1 an, 5,5 % pour ceux d'un an ou plus (script `04`, requête 6). Une partie de la fréquence élevée du bonus-malus 100 (21,2 %) vient donc de cet effet.

**Le coût est concentré.** Les 10 % de sinistres les plus chers représentent 51,3 % du coût après plafonnement (59,9 % sans plafond). La moitié la moins chère des sinistres ne pèse que 18 % du coût.

**La géographie est bruitée.** La Corse (prime pure 206, indice 150) et la Champagne-Ardenne (176, indice 128) arrivent en tête avec seulement 4 516 et 3 026 contrats : ces indices sont instables. Parmi les grosses régions, Provence-Alpes-Côte d'Azur (181) et Rhône-Alpes (171) sont au-dessus de la moyenne, le Centre (121) en dessous.

## Limites

- **Analyse univariée.** Chaque segment est étudié séparément. Les facteurs sont corrélés (les jeunes conducteurs ont plus souvent un bonus-malus de 100, les centres urbains ont des véhicules plus récents). Isoler l'effet propre de chaque variable demande un modèle, par exemple une régression de Poisson pour la fréquence et une régression Gamma pour le coût. C'est le prolongement naturel de ce projet.
- **Les sinistres déclarés mais absents du détail sont ignorés (R2).** 9 657 sinistres déclarés ne sont pas comptés. Les contrats concernés restent dans l'exposition : cela peut sous-estimer légèrement la fréquence des segments où ils sont nombreux. La littérature procède de la même façon.
- **Effet de la durée.** Les contrats courts gonflent les fréquences annualisées. Je ne les ai pas corrigés ni pondérés : la comparaison entre segments à durées moyennes différentes (bonus-malus 100 notamment) est donc à lire avec prudence.
- **Montants forfaitaires probables.** 4 792 sinistres (18 %) valent exactement 1 204, et quatre autres montants reviennent plus de 400 fois chacun. Je suppose qu'il s'agit de forfaits, mais la source ne le précise pas.
- **Plafond arbitraire.** Un seuil de 50 000 ou de 200 000 changerait les niveaux de coût moyen. Je n'ai pas testé si le classement des segments reste identique.
- **Variables non nettoyées.** Quelques valeurs extrêmes subsistent (1 116 véhicules de plus de 30 ans, un âge de véhicule et de conducteur maximal de 100). Elles sont conservées et regroupées dans la tranche la plus haute.
- **Source.** La devise et la période d'observation ne sont pas précisées dans le jeu de données. Je suppose des euros, sans pouvoir le vérifier.

## Compétences mises en œuvre

Jointures (INNER, LEFT, anti-jointure), agrégations et HAVING, CTE enchaînées, sous-requêtes scalaires, fonctions de fenêtre (RANK, NTILE, LAG, SUM OVER, moyenne mobile avec cadre de lignes), tableau croisé avec CASE WHEN, création de tables et de vues, index, contrôle qualité et traçabilité du nettoyage (journal des règles), test de robustesse (comparaison de deux définitions de la fréquence), pièges classiques (moyenne de moyennes, multiplication des lignes après jointure, filtre placé avant une fonction de fenêtre), interprétation métier (fréquence, coût moyen, prime pure).

## Auteure

Élisée Dagbo – Master 2 Économétrie et Statistique (Économétrie Appliquée), IAE Nantes.
