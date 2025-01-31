# Gestion des paquets

## Résolution des noms de modules

Afin de trouver le module à importer, Python doit en comprendre la structure :
il doit identifier s'il s'agit d'importer un module isolé, ou d'un module au sein d'un paquet (modules imbriqués).
Cela se détermine à l'aide des points utilisés dans le nom du module.

Ainsi `collections.abc` n'est pas simplement un module portant ce nom, c'est un sous-module `abc` imbriqué dans le module (paquet) `collections`.
Lorsqu'on demande à Python d'importer `collections.abc`, il doit alors premièrement importer `collections` avant d'importer `abc` dans ce paquet.

```pycon
>>> import collections.abc
>>> collections
<module 'collections' from '/usr/lib/python3.13/collections/__init__.py'>
>>> collections.abc
<module 'collections.abc' from '/usr/lib/python3.13/collections/abc.py'>
```

Là-dessus le comportement de la fonction `import_module` diffère un peu (et c'est l'une de ses principales différences avec `__import__`) : celui-ci renvoie directement le module cible (`collections.abc`) et non le module parent (`collections`), puisqu'il n'a pas vocation à être stocké dans une variable nommée `collections`.

```pycon
>>> import importlib
>>> importlib.import_module('collections.abc')
<module 'collections.abc' from '/usr/lib/python3.13/collections/abc.py'>
>>> __import__('collections.abc')
<module 'collections' from '/usr/lib/python3.13/collections/__init__.py'>
```

Aussi comme je le disais, cet import implique donc d'exécuter le code de chacun des modules de la hiérarchie.  
Dans le cas d'un paquet (qui prend la forme d'un répertoire sur le système de fichiers), on le voit dans les résultats des exemples qui précèdent, le code à exécuter est stocké dans le fichier `__init__.py` du répertoire.

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

## Imports relatifs

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
On constate que pour un import absolu (ne débutant pas par un point) le paquet courant est ignoré, mais qu'il est bien considéré pour les imports relatifs.

```pycon
>>> from importlib.util import resolve_name
>>> resolve_name('math', 'foo.spam')
'math'
>>> resolve_name('.increment', 'foo.spam')
'foo.spam.increment'
>>> resolve_name('..bar', 'foo.spam')
'foo.bar'
```
