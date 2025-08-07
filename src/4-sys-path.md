# Chemins de recherche

Mais comment Python trouve-t-il les modules à importer ?  
Vous avez peut-être pour cela déjà entendu parler du `sys.path`.

Le module `sys` (système) de Python possède en effet un attribut `path` qui est une liste de chemins de répertoires.

```pycon
>>> import sys
>>> sys.path
['', '/usr/lib/python313.zip', '/usr/lib/python3.13', '/usr/lib/python3.13/lib-dynload', '/usr/lib/python3.13/site-packages']
```

Ce sont les répertoires que Python utilise pour trouver les fichiers correspondant aux modules.
Le premier (chaîne vide) correspond au répertoire courant et les autres sont les répertoires d'installation des modules systèmes.

Si vous êtes au sein d'un environnement virtuel (_virtualenv_), les répertoires de ce dernier apparaîtront aussi dans cette liste.

```pycon
>>> sys.path
['', '/usr/lib/python313.zip', '/usr/lib/python3.13', '/usr/lib/python3.13/lib-dynload', '/tmp/venv/lib/python3.13/site-packages']
```

Les répertoires sont classés dans la liste par ordre de priorité : quand on cherche à importer un module (`random` par exemple), Python les parcourt de la gauche vers la droite jusqu'à trouver un fichier `random.py` dans l'un d'eux[^package].

[^package]: Ou un répertoire `random` contenant un fichier `__init__.py` dans le cas d'un package.

```pycon
>>> import random
>>> random
<module 'random' from '/usr/lib/python3.13/random.py'>
```

Ici le module est trouvé dans le 3ème répertoire de la liste.
Si par contre je disposais d'un fichier `random.py` (un fichier vide par exemple) dans mon répertoire courant (`/tmp` dans mon cas), celui-ci serait trouvé en priorité.

```pycon
>>> import importlib
>>> importlib.reload(random)
<module 'random' from '/tmp/random.py'>
```

[[a]]
| Cela explique certains problèmes que l'on peut parfois rencontrer avec des conflits de nom : le répertoire courant étant en première place de la liste il faut faire attention à ne pas nommer nos fichiers de la même manière que certains modules de la bibliothèque standard, ce qui les rendrait sinon introuvables.  
| L'import fonctionnerait correctement (un fichier correspondant au nom serait trouvé) mais le module ne contiendrait pas ce qu'on y attend.
|
| Si vous renconrez un tel problème de module de la bibliothèque standard qui semble incohérent, pensez à afficher le module comme nous l'avons fait dans les exemples précédents pour vérifier que le chemin correspond bien à celui attendu.

## Modifier les répertoires de recherche

Cette liste de chemins est modifiable, il est donc possible d'y ajouter/retirer des répertoires.
Au début, au milieu, comme à la fin.

Imaginons que nous disposons d'un sous-répertoire `subdirectory` dans le répertoire courant, ce sous-répertoire contenant un fichier `dir_example.py`.

```python
def hello(name):
    print('DIR:', 'Hello', name)
```
Code: `subdirectory/dir_example.py`

Par défaut ce module n'est pas atteignable par Python.

```pycon
>>> import dir_example
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
ModuleNotFoundError: No module named 'dir_example'
```

Mais il le devient si nous lui indiquons qu'il faut explorer le répertoire `subdirectory`.

```pycon
>>> sys.path.append('subdirectory')
>>> import dir_example
>>> dir_example
<module 'dir_example' from '/tmp/subdirectory/dir_example.py'>
>>> dir_example.hello('Zeste de Savoir')
DIR: Hello Zeste de Savoir
```

[[i]]
| Le module `dir_example` n'existant nulle part ailleurs que dans ce répertoire, la place de `'subdirectory'` dans le `sys.path` n'a pas d'importance.

-----

La suppression fonctionne de la même manière mais demande à recharger le module ensuite (un simple réimport ne fonctionne pas en raison du cache évoqué plus tôt).  
En reprenant l'exemple du conflit sur le module `random` :

```pycon
>>> import random
>>> random
<module 'random' from '/tmp/random.py'>
>>> sys.path.remove('')
>>> importlib.reload(random)
<module 'random' from '/usr/lib/python3.11/random.py'>
```

[[a]]
| Pensez à quitter/relancer l'interpréteur Python après cet exemple ou à rajouter manuellement `''` au `sys.path` afin que le répertoire courant devienne à nouveau disponible.
|
| Vous pouvez aussi supprimer le fichier `random.py` du répertoire courant pour éviter tout problème ultérieur.

## Import d'archives zip

Vous avez peut-être remarqué que notre `sys.path` ne contenait pas que des chemins de répertoires, un fichier `.zip` y était aussi présent.
Python est en effet capable de les gérer nativement comme des répertoires.

Créons par exemple une archive `packages.zip` contenant un unique fichier `zip_example.py`.

```python
def hello(name):
    print('ZIP:', 'Hello', name)
```
Code: `packages.zip/zip_example.py`

[[i]]
| Pour créer cette archive sous Linux, vous pouvez commencer par créer un fichier `zip_example.py` puis lancer la commande `zip -m packages.zip zip_example.py` qui déplacera le fichier dans l'archive `packages.zip` nouvellement créée.

Et comme précédemment, nous pouvons ajouter le chemin `packages.zip` au `sys.path` pour rendre atteignable le module `zip_example`.

```pycon
>>> import sys
>>> sys.path.append('packages.zip')
>>> import zip_example
>>> zip_example
<module 'zip_example' from 'packages.zip/zip_example.py'>
>>> zip_example.hello('Zeste de Savoir')
ZIP: Hello Zeste de Savoir
```

-----

Ce mécanisme permet aussi de lancer Python avec un fichier `.zip` en argument plutôt qu'un `.py`.
Dans ce cas l'archive sera automatiquement ajoutée au `sys.path` et c'est le fichier `__main__.py` qu'elle contient qui sera exécuté.

Créons alors une nouvelle archive `program.zip` contenant le même fichier `zip_example.py` que précédemment et le fichier `__main__.py` suivant.

```python
import sys
print(sys.path)
from zip_example import hello
hello('zip exec')
```
Code: `program.zip/__main__.py`

Que nous pouvons ensuite exécuter directement avec Python.

```sh
% python program.zip
['/tmp/program.zip', '/usr/lib/python313.zip', '/usr/lib/python3.13', '/usr/lib/python3.13/lib-dynload', '/usr/lib/python3.13/site-packages']
ZIP: Hello zip exec
```

-----

On remarque cependant que l'archive ne crée pas de paquet Python en tant que tel : tous les modules qu'elle contient sont exposés dans l'espace de nom global des modules (augmentant les chances de conflits avec des modules de la bibliothèque standard).

Si on veut aller plus loin, on peut alors créer nous-même un paquet (répertoire) à l'intérieur de l'archive qui contiendrait tout ce que l'on souhaite exposer, et on ajouterait un fichier `__main__.py` à la racine qui serait exécuté par Python et importerait ce que l'on veut depuis le paquet.

On crée alors une archive `calc_program.zip` de la structure suivante :

```
calc_program.zip
├── calc
│   ├── __init__.py
│   └── multiplication.py
└── __main__.py
```
Code: `calc_program.zip`

```python
from .multiplication import multiplication
```
Code: `calc_program.zip/calc/__init__.py`

```python
def multiplication(x, y):
    return x * y
```
Code: `calc_program.zip/calc/multiplication.py`

```python
from calc import multiplication

def main():
    x = int(input('x> '))
    y = int(input('y> '))
    result = multiplication(x, y)
    print(f'{x} * {y} = {result}')

if __name__ == '__main__':
    main()
```
Code: `calc_program.zip/__main__.py`

Que l'on exécute comme précédemment.

```sh
% python calc_program.zip
x> 5
y> 3
5 * 3 = 15
```

[[i]]
| On notera que cela fonctionne aussi avec un répertoire donné en argument à Python, mais l'archive zip est plus convenable pour distribuer rapidement un projet.

## Installation de modules

[[a]]
| Attention cependant, les manipulations de `sys.path` sont souvent hasardeuses : ça demande à ce que la modification soit toujours faite avant le premier import des modules cibles, de faire attention à l'ordre de priorité et de ne pas se mélanger entre chemins relatifs et absolus (le chemin `subdirectory` que nous avons ajouté ne serait plus atteignable si nous changions de répertoire courant).

Pour toutes ces raisons il est préférable de laisser Python gérer cela par lui-même et de se reposer uniquement sur les répertoires d'installation pour rendre nos modules accessibles, en utilisant `pip` afin de les installer.

Il suffit d'un `pyproject.toml` rudimentaire (voire vide) pour forger un paquet Python minimal et le rendre installable via `pip`

Par exemple pour notre répertoire `subdirectory` que nous allons transformer en paquet :

```toml
[project]
name = "dir-example"
```
Code: `subdirectory/pyproject.toml`

Nous l'installons ensuite dans l'environnement virtuel courant.

```sh
(venv) % pip install ./subdirectory
...
```

Et il devient directement disponible dans Python sans avoir à manipuler le `sys.path`.

```pycon
>>> import dir_example
>>> dir_example
...
>>> dir_example.hello('venv')
DIR: Hello venv
```

[[i]]
| On notera aussi l'option `-e` du `pip install` pour installer un module en mode éditable.
|
| Dans notre installation précédente, le fichier `subdirectory/dir_example.py` a été copié dans le répertoire de l'environnement virtuel : les modifications apportées au fichier n'auront alors aucun impact sur le module installé.  
| En revanche si nous avions utilisé `pip install -e ./subdirectory`, pip aurait créé un lien symbolique vers notre fichier plutôt qu'une copie. Les modifications apportées seraient alors directement visibles depuis Python sans avoir à réinstaller le module.
