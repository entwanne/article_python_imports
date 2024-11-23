# Comprendre les imports

## Qu'est-ce qu'un import ?

En Python [il est d'usage de découper son code en modules](https://zestedesavoir.com/tutoriels/2514/un-zeste-de-python/6-entrees-sorties/1-modules/), chaque module étant une « unité de code » contenant variables, fonctions et classes.
L'idée d'un module est alors de fournir des fonctionnalités particulières, afin de les utiliser dans notre code.
Les bibliothèques (comprenant la bibliothèque standard) ne sont qu'une collection de modules.

Pour utiliser les fonctionnalités d'un module, il est nécessaire de l'importer.
Importer un module c'est charger le fichier de code correspondant, l'exécuter et en exposer le contenu.

L'import simple se réalise à l'aide du mot-clé `import` suivi du nom du module.
Python crée alors une variable du même nom référençant le module en tant qu'objet et permettant d'accéder à ses attributs.

```pycon
>>> import pathlib
>>> pathlib
<module 'pathlib' from '/usr/lib/python3.12/pathlib.py'>
>>> pathlib.Path
<class 'pathlib.Path'>
```

Derrière ce mot-clé, Python réalise un appel à la fonction `__import__` qui reçoit le nom du module, et l'assigne à la variable.  
Le code précédent est alors équivalent à :

```pycon
>>> pathlib = __import__('pathlib')
>>> pathlib
<module 'pathlib' from '/usr/lib/python3.12/pathlib.py'>
```

Cela permet donc de réaliser des imports dynamiques / programmatiques : importer un module dont le nom n'est pas connu avant le lancement du programme (ca dépendant d'une entrée utilisateur, d'une configuration, d'un échange réseau ou autre).
Mais on évitera d'utiliser directement la fonction `__import__` car [son usage est découragé](https://docs.python.org/fr/3.13/library/functions.html#import__) en raison de son interface « austère » et de la manière dont elle traite les modules imbriqués (paquets).  
On lui préférera alors [la fonction `import_module` du module `importlib`](https://docs.python.org/fr/3.13/library/importlib.html#importlib.import_module) (qui utilise les mêmes mécanismes en interne).

Là encore, celle-ci se comporte comme attendu.

```pycon
>>> import importlib
>>> pathlib = importlib.import_module('pathlib')
>>> pathlib
<module 'pathlib' from '/usr/lib/python3.12/pathlib.py'>
```

## Chargement et exécution

Comme je l'expliquais plus tôt l'import ne se contente pas seulement de charger les modules, il en exécute aussi le code directement.

Charger un module, c'est identifier le fichier correspondant et créer un module vide (le contenant).
Exécuter ce module, c'est exécuter le code du fichier et remplir le contenant à l'aide des objets qui y sont définis.

Cela se constate facilement si l'on place des actions avec des effets de bord à la racine du code du module (hors de toute fonction), comme des appels à `print`.

On va par exemple créer un fichier `my_module.py` dans le répertoire courant.

```python
print('Coucou')
```
Code: `my_module.py`

Et l'importer depuis l'interpréteur interactif.

```pycon
>>> import my_module
Coucou
```

C'est par cette exécution que sont rendues disponibles les fonctions et classes définies dans le module.
C'est elle aussi qui permet que le module ait des traitements conditionnels (définir une fonction sous certaines conditions, par exemple la plate-forme utilisée).

La conséquence c'est qu'un import peut être coûteux s'il charge beaucoup de choses ou effectue des traitements lours, et que c'est à vous de faire attention lorsque vous codez vos modules et que vous avez des traitements à réaliser, afin de ne placer à la racine des modules que ce qui leur est essentiel.

----------

Puisque l'exécution est une étape systématique, on pourrait alors se demander pourquoi on a besoin de la distinguer du chargement, pourquoi ce ne sont pas une seule et même étape.  
La réponse peut se trouver du côté des imports circulaires (deux modules qui s'importent l'un l'autre par exemple).

En effet, le module existe pour Python dès lors qu'il est chargé, même s'il n'est pas encore exécuté ou pas entièrement.
Si un tel module (appelons-le `even` pour coller à l'exemple qui suivra) importe un autre module (`odd`), ce second module est chargé et exécuté avant que l'exécution du premier ne soit terminé.  
Et donc si ce module `odd` importe à son tour `even`, bien que l'exécution d'`even` ne soit pas terminée, Python sait déjà qu'un tel module existe (il est vide pour le moment) et la commande d'import fonctionne correctement.

```python
import odd

def is_even(n):
    "Teste si un nombre est pair"
    if n == 0:
        return True
    return not odd.is_odd(abs(n) - 1)
```
Code: `even.py`

```python
import even

def is_odd(n):
    "Teste si un nombre est impair"
    if n == 0:
        return False
    return not even.is_even(abs(n) - 1)
```
Code: `odd.py`

```pycon
>>> from even import is_even
>>> is_even(42)
True
```

Cette implémentation — un peu absurde j'en conviens — du test de parité montre que l'interdépendances entre modules est possible.
On notera cependant que je n'utilise pas de `from ... import ...` dans mes modules, justement à cause de l'exécution incomplète.

Écrire `from even import is_even`, cela revient à écrire le code suivant.

```python
import even
is_even = even.is_even
del even
```

Juste après l'import, on cherche donc à accéder à son contenu (ici la fonction `is_even`) : celui-ci n'existe qu'après l'exécution du module.
Ainsi, utiliser `from even import is_even` dans le module `odd` lèverait une erreur d'import parce que l'import survient dans `odd` alors que l'exécution du module `even` ne soit terminée.

```pycon
ImportError: cannot import name 'is_even' from partially initialized module 'even' (most likely due to a circular import) (even.py)
```

## Gestion des paquets et résolution des noms

Afin de trouver le module à importer, Python doit en comprendre la structure :
il doit identifier s'il s'agit d'importer un module isolé, ou d'un module au sein d'un paquet (modules imbriqués).
Cela se détermine à l'aide des points utilisés dans le nom du module.

Ainsi `collections.abc` n'est pas simplement un module portant ce nom, c'est un sous-module `abc` imbriqué dans le module (paquet) `collections`.
Lorsqu'on demande à Python d'importer `collections.abc`, il doit alors premièrement importer `collections` avant d'importer `abc` dans ce paquet.

```pycon
>>> import collections.abc
>>> collections
<module 'collections' from '/usr/lib/python3.12/collections/__init__.py'>
>>> collections.abc
<module 'collections.abc' from '/usr/lib/python3.12/collections/abc.py'>
```

Là-dessus le comportement de la fonction `import_module` diffère un peu (et c'est l'une de ses principales différences avec `__import__`) : celui-ci renvoie directement le module cible (`collections.abc`) et non le module parent (`collections`), puisqu'il n'a pas vocation à être stocké dans une variable nommée `collections`.

```pycon
>>> importlib.import_module('collections.abc')
<module 'collections.abc' from '/usr/lib/python3.12/collections/abc.py'>
>>> __import__('collections.abc')
<module 'collections' from '/usr/lib/python3.12/collections/__init__.py'>
```

Aussi comme je le disais, cet import implique donc d'exécuter le code de chacun des modules de la hiérarchie.  
Dans le cas d'un paquet (qui prend la forme d'un répertoire sur le système de fichiers), on le voit dans les exemples qui précèdent, le code à exécuter est stocké dans le fichier `__init__.py` du paquet.

Pour bien comprendre ce qu'il se passe, on peut prendre la structure de paquet suivante :

```python
print('Import foo')
```
Code: `foo/__init__.py`

```python
print('Import foo.spam')
```
Code: `foo/spam/__init__.py`

```python
print('Import foo.spam.eggs')
```
Code: `foo/spam/eggs.py`

Lors de l'import du module `foo.spam.eggs`, on constate la chaîne d'exécution de tous les modules.

```pycon
>>> import foo.spam.eggs
Import foo
Import foo.spam
Import foo.spam.eggs
```

----------

Cette identification du module à importer s'occupe aussi de résoudre les noms relatifs.  
Il est en effet possible au sein d'un paquet d'importer d'autres modules via leurs chemins relatifs.

Depuis un module `foo.spam.relative` (donc dans le paquet `foo.spam`), le module `.increment` correspond ainsi au module `foo.spam.increment`.

```python
def increment(x):
    return x + 1
```
Code: `foo/spam/increment.py`

```python
from .increment import increment

print(increment(5))
```
Code: `foo/spam/relative.py`

```pycon
>>> import foo.spam.relative
6
```

Ce sont les points utilisés en préfixe du nom qui indiquent qu'il s'agit d'un import relatif.
Je parle bien de points au pluriel car il est possible d'en utiliser plusieurs pour remonter les différents niveaux du paquet : `..bar` depuis le paquet `foo.spam` correspond à `foo.bar`.

La fonction `resolve_name` d'`importlib.util` prend deux chaînes de caractères en arguments, la première est le nom du module à résoudre et la seconde celui du paquet à partir duquel faire la résolution.  
On constate que pour un import absolu (né debutant pas par un point) le paquet courant est ignoré, mais qu'il est bien considéré pour les imports relatifs.

```pycon
>>> from importlib.util import resolve_name
>>> resolve_name('math', 'foo.spam')
'math'
>>> resolve_name('.increment', 'foo.spam')
'foo.spam.increment'
>>> resolve_name('..bar', 'foo.spam')
'foo.bar'
```

## Étapes de l'import

Pour conclure cette première section, on peut résumer ainsi les différentes étapes réalisées par Python lors de l'import d'un module :

1. Résolution du nom (afin de gérer les imports relatifs)
2. Imports récursifs des paquets parents (ce procédé étant répété pour chaque parent)
3. Chargement du module
4. Exécution du code du module
