"""Exécute un fichier .sql sur la base SQLite et affiche le résultat de chaque requête SELECT.

Usage : python scripts/executer_sql.py <base.db> <fichier.sql> [nb_lignes_max]
"""
import sqlite3
import sys

base, fichier = sys.argv[1], sys.argv[2]
maxi = int(sys.argv[3]) if len(sys.argv) > 3 else 40

con = sqlite3.connect(base)
texte = open(fichier, encoding="utf-8").read()


def afficher(titre, colonnes, lignes):
    print(f"\n=== {titre}")
    if not colonnes:
        return
    corps = [[("" if v is None else (f"{v:,.4f}".rstrip("0").rstrip(".").replace(",", " ") if isinstance(v, float) else str(v))) for v in l] for l in lignes[:maxi]]
    largeurs = [max(len(str(c)), *(len(r[i]) for r in corps)) if corps else len(str(c)) for i, c in enumerate(colonnes)]
    print(" | ".join(str(c).ljust(largeurs[i]) for i, c in enumerate(colonnes)))
    print("-+-".join("-" * w for w in largeurs))
    for r in corps:
        print(" | ".join(r[i].rjust(largeurs[i]) if r[i].replace(".", "").replace(" ", "").replace("-", "").isdigit() else r[i].ljust(largeurs[i]) for i in range(len(colonnes))))
    if len(lignes) > maxi:
        print(f"... ({len(lignes)} lignes au total)")


bloc, titre = "", ""
for ligne in texte.splitlines(keepends=True):
    s = ligne.strip()
    if not bloc and s.startswith("--"):
        titre = s.lstrip("- ").strip() if s.startswith("-- Q") or not titre else titre
        if s.startswith("-- Q"):
            titre = s[2:].strip()
        continue
    if not bloc and not s:
        continue
    bloc += ligne
    if sqlite3.complete_statement(bloc):
        curseur = con.execute(bloc)
        if curseur.description:
            afficher(titre or "requête", [d[0] for d in curseur.description], curseur.fetchall())
        bloc, titre = "", ""
con.commit()
print("\nTerminé.")
