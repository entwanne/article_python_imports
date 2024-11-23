# Système de cache des modules

2. Cache
    - Ne pas recharger / ré-exécuter le module à chaque import
    - Cache `sys.modules` pour stocker les modules chargés
    - Ce cache court-circuite le mécanisme d'import
    - `importlib.reload` pour recharger un module
    - Permet de vérifier si un module a déjà été importé (si présent dans `sys.modules`)
    - Permet de nettoyer / falsifier le cache en ajoutant des modules à la volée dans `sys.modules`

Ces étapes de l'import, si elles étaient répétées à chaque fois, représenteraient à force un coût non négligeable.
Pour l'éviter, Python met en place un mécanisme de cache afin de se souvenir des modules précédemment importés.  
Ainsi, l'import d'un module déjà importé court-circuite les étapes vues précédemment, et c'est assez facile à constater.

```pycon
>>> import my_module
```

On voit que cette fois-ci importer `my_module` ne provoque pas d'effet de bord (la première fois il était affiché « Coucou »), c'est que le code du module n'a pas été réexécuté.

Ce cache est partagé par les différents mécanismes d'import de Python, telle que la fonction `import_module`.

On peut accéder à ce cache via l'attribut `modules` du module `sys`.

```pycon
>>> import sys
>>> sys.modules
{'sys': <module 'sys' (built-in)>, 'builtins': <module 'builtins' (built-in)>, ..., 'my_module': <module 'my_module' from 'my_module.py'>}
```

Il est toutefois possible de recharger un module si le besoin se fait sentir.
On serait tenté de simplement supprimer la clé correspondante dans `sys.modules` pour retirer le module du cache puis le réimporter mais on préférera utiliser `importlib.reload` qui a l'avantage de modifier le module en place plutôt que d'en créer un nouveau.

Cette fonction prend directement l'objet module en argument, et le renvoie après l'avoir rechargé.

```pycon
>>> importlib.reload(my_module)
Coucou
<module 'my_module' from 'my_module.py'>
```

Les cas où le besoin de réimporter un module sont toutefois rares et se rencontrent surtout quand le code d'un module est amené à changer au cours du temps (pendant que le programme tourne) : il est alors nécessaire de le réimporter pour utilisr la dernière version.
