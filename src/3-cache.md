# Système de cache des modules

Jusqu'ici, on peut résumer ainsi les différentes étapes réalisées par Python lors de l'import d'un module :

1. Résolution du nom (afin de gérer les imports relatifs)
2. Imports récursifs des paquets parents (ce procédé étant répété pour chaque parent)
3. Chargement du module
4. Exécution du code du module

Mais ces étapes, si elles étaient répétées à chaque import, représenteraient à force un coût non négligeable.
Pour l'éviter, Python met en place un mécanisme de cache afin de se souvenir des modules précédemment importés.  
Ainsi, l'import d'un module déjà importé intervient au tout début et court-circuite ces étapes, ce qui est assez facile à constater.

```pycon
>>> import my_module
Coucou
>>> import my_module
```

On voit que la deuxième fois, importer `my_module` ne provoque pas d'effet de bord, c'est que le code du module n'a pas été réexécuté.  
Ce cache est partagé par les différents mécanismes d'import de Python, telle que la fonction `import_module`.

## Manipuler le cache

On peut accéder à ce cache via l'attribut `modules` du module `sys`.

```pycon
>>> import sys
>>> sys.modules
{'sys': <module 'sys' (built-in)>, 'builtins': <module 'builtins' (built-in)>, ..., 'my_module': <module 'my_module' from 'my_module.py'>}
```

Ce dictionnaire référence directement les modules, tels qu'ils sont rénvoyés lors de l'import.

```pycon
>>> sys.modules['my_module'] is my_module
True
```

Et permet de facilement vérifier, en y recherchant le nom d'un module, si celui-ci a déjà été importé ou non.

```pycon
>>> 'my_module' in sys.modules
True
```

## Recharger un module

Ce mécanisme de court-circuit a cependant un défaut : si le code du module cible est amené à changer au cours du temps (pendant que le programme tourne) et qu'il a déjà été importé, il ne permet pas d'en obtenir la dernière version.

Dans ce cas il est toutefois possible de forcer à recharger un module.
On serait tenté de simplement supprimer la clé correspondante dans `sys.modules` pour retirer le module du cache puis le réimporter mais on préférera utiliser `importlib.reload` qui a l'avantage de modifier le module en place plutôt que d'en créer un nouveau.

Cette fonction prend directement l'objet module en argument, et le renvoie après l'avoir rechargé.

```pycon
>>> import importlib
>>> importlib.reload(my_module)
Coucou
<module 'my_module' from 'my_module.py'>
```

Mais les cas où l'on a besoin de réimporter un module sont assez rares en réalité.

## Altérer le cache

Enfin ce cache nous permet aussi de falsifier le mécanisme d'import, en attribuant dynamiquement un objet-module à une clé du cache.  
On utilisera ici le type `ModuleType` (du module `types`) pour définir un objet qui soit un vrai module, mais n'importe quel type d'objet pourrait être stocké dans le cache.

```python
from types import ModuleType

class TestModule(ModuleType):
    def addition(self, a, b):
        return a + b
```

```pycon
>>> sys.modules['test'] = TestModule('test')
>>> import test
>>> test
<module 'test'>
>>> test.addition(3, 5)
8
>>> from test import addition
>>> addition(1, 2)
3
```

Ce mécanisme, bien que peu fréquent, est parfois utilisé pour agir directement sur le module courant en redéfinissant ou altérant `sys.modules[__name__]` (`__name__` contenant par définition le nom du module courant).  
On peut l'imaginer pour implémenter des opérateurs sur notre module (les opérateurs devant être implémentés sur le type de l'objet), comme dans l'exemple qui suit en permettant à un module `addition` d'être appelé comme une fonction.

```python
import sys
from types import ModuleType

class CallableModule(ModuleType):
    def __call__(self, a, b):
        return a + b

sys.modules[__name__].__class__ = CallableModule
```
Code: `addition.py`

```pycon
>>> import addition
>>> addition
<module 'addition' from 'addition.py'>
>>> addition(3, 5)
8
```

Avant l'introduction de la fonction `__getattr__` pour les modules dans la [PEP 562](https://peps.python.org/pep-0562/), on pouvait aussi utiliser ce mécanisme pour redéfinir manuellement `__getattr__` et lever un avertissement lors de l'accès à des attributs dépréciés par exemple.

[[i]]
| Plutôt que de truquer le cache, nous verrons par la suite comment nous pouvons interagir directement avec le mécanisme d'import pour altérer sur nos modules.
