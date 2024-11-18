# Système de cache des modules

2. Cache
    - Ne pas recharger / ré-exécuter le module à chaque import
    - Cache `sys.modules` pour stocker les modules chargés
    - Ce cache court-circuite le mécanisme d'import
    - `importlib.reload` pour recharger un module
    - Permet de vérifier si un module a déjà été importé (si présent dans `sys.modules`)
    - Permet de nettoyer / falsifier le cache en ajoutant des modules à la volée dans `sys.modules`
