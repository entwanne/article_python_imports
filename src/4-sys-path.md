# Chemins de recherche

3. Path
    - `sys.path` pour ajouter des répertoires de découverte de modules
        - Mais n'est pas nécessaire généralement : laisser Python gérer les répertoires d'installation et rendre les paquets installables
    - `sys.path` comprend aussi les archives zip
    - Python peut aussi exécuter directement un fichier zip (exécute le module `__main__`) de l'archive

---

Mais comment Python trouve-t-il les modules à importer ?  
Vous avez peut-être pour cela déjà entendu parler du `sys.path`.

Le module `sys` (système) de Python possède en effet un attribut `path` qui est une liste de chemins de répertoires.

```pycon
>>> import sys
>>> sys.path
['', '/usr/lib/python312.zip', '/usr/lib/python3.12', '/usr/lib/python3.12/lib-dynload', '/usr/lib/python3.12/site-packages']
```

Ce sont les répertoires que Python utilise pour trouver les fichiers correspondant aux modules.
Le premier (chaîne vide) correspond au répertoire courant et les autres sont les répertoires d'installation des modules systèmes.

Si vous êtes au sein d'un environnement virtuel (_virtualenv_), les répertoires de ce dernier apparaîtra aussi dans cette liste.

```pycon
>>> sys.path
['', '/usr/lib/python312.zip', '/usr/lib/python3.12', '/usr/lib/python3.12/lib-dynload', '/tmp/venv/lib/python3.12/site-packages']
```

- répertoires par ordre de priorité
- ajout de répertoire au sys.path
- préférer pip install plutôt que d'ajouter des répertoires (casse-gueule)

...

## Import d'archives zip

Vous avez peut-être remarqué que notre `sys.path` ne contenait pas que des répertoires, un fichier `.zip` y était aussi présent.
