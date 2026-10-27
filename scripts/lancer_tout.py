"""Reconstruit la base SQLite et exécute les quatre scripts SQL dans l'ordre.

Usage : python scripts/lancer_tout.py <dossier_des_csv> [fremtpl2.db]

Les résultats de chaque script sont écrits dans le dossier resultats/.
"""
import subprocess
import sys
from pathlib import Path

racine = Path(__file__).resolve().parent.parent
dossier_csv = Path(sys.argv[1])
base = Path(sys.argv[2]) if len(sys.argv) > 2 else racine / "fremtpl2.db"

subprocess.run([sys.executable, str(racine / "scripts" / "charger_donnees.py"), str(dossier_csv), str(base)], check=True)

(racine / "resultats").mkdir(exist_ok=True)
for script in sorted((racine / "sql").glob("*.sql")):
    sortie = racine / "resultats" / (script.stem + ".txt")
    resultat = subprocess.run(
        [sys.executable, str(racine / "scripts" / "executer_sql.py"), str(base), str(script), "60"],
        check=True, capture_output=True, text=True, encoding="utf-8",
    )
    sortie.write_text(resultat.stdout, encoding="utf-8")
    print(f"{script.name} exécuté -> {sortie.relative_to(racine)}")
