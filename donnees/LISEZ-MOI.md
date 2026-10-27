# Données

Les fichiers de données ne sont pas inclus dans ce dépôt (ils sont volumineux et se téléchargent librement).

## Ce qu'il faut récupérer

Deux fichiers CSV, issus du jeu de données **freMTPL2** (French Motor Third-Party Liability, assurance responsabilité civile automobile en France) :

| Fichier | Contenu | Lignes |
|---|---|---|
| `freMTPL2freq.csv` | un contrat par ligne : exposition, nombre de sinistres, caractéristiques du conducteur, du véhicule et de la zone | 678 013 |
| `freMTPL2sev.csv` | un sinistre par ligne : identifiant du contrat et montant | 26 639 |

## Où les télécharger

- Copie sur Hugging Face utilisée pour ce projet : https://huggingface.co/datasets/mabilton/fremtpl2
- Source d'origine : le paquet R **CASdatasets** (Arthur Charpentier et Christophe Dutang), qui contient `freMTPL2freq` et `freMTPL2sev`.

## Où les ranger

Place les deux fichiers dans un même dossier (par exemple `donnees/`), puis lance :

```
python scripts/lancer_tout.py donnees
```

## Dictionnaire des colonnes

`freMTPL2freq.csv` : `IDpol` (identifiant du contrat), `ClaimNb` (nombre de sinistres), `Exposure` (durée d'exposition en années), `VehPower` (puissance du véhicule), `VehAge` (âge du véhicule), `DrivAge` (âge du conducteur), `BonusMalus` (coefficient bonus-malus : 50 = meilleur bonus, 100 = neutre, au-dessus de 100 = malus), `VehBrand` (marque, anonymisée B1 à B14), `VehGas` (carburant), `Area` (zone de densité, A = rural à F = centre urbain), `Density` (habitants au km² de la commune), `Region` (région).

`freMTPL2sev.csv` : `IDpol`, `ClaimAmount` (montant du sinistre ; la devise n'est pas précisée dans la source, probablement des euros).

## Défaut connu du jeu de données

La colonne `ClaimNb` du fichier des contrats annonce plus de sinistres (36 102) que le fichier de détail n'en contient (26 444). L'écart se concentre sur les contrats dont le numéro `IDpol` est inférieur ou égal à 24 500. Les analyses de ce dépôt comptent les sinistres dans le fichier de détail (voir le README).

## Licence

Les données appartiennent à leurs auteurs d'origine. Le paquet CASdatasets est publié sous licence GPL-2 ; vérifie les conditions avant toute réutilisation ou redistribution. Ce dépôt ne contient que mon code SQL et Python, pas les données.
