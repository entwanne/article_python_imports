# Découverte et chargement des modules

Allons maintenant un cran plus loin afin de comprendre comment Python découvre les modules à partir du `sys.path`.  
Ce mécanisme s'appuie principalement sur deux types de composants : les _finders_ et les _loaders_.

Un _finder_ est un objet chargé de localiser un module à partir de son nom.  
Python possède donc une liste de _finders_ connus qu'il interroge lorsque l'on cherche à importer un nouveau module (un module non présent dans le cache), pour savoir si l'un d'eux sait à quel module est associé ce nom.

Le _loader_ intervient ensuite, associé au _finder_, pour charger le module ainsi trouvé (charger un fichier source depuis un répertoire, depuis une archive zip, etc.).

## `sys.path_hooks`

On a vu que le `sys.path` permettait de configurer une liste de chemins de découverte modules, mais cette liste ne fonctionne pas seule.
Afin de savoir comment exploiter un chemin pour y trouver les modules, Python a besoin de lui associer un _finder_.  
C'est là qu'entre en jeu `sys.path_hooks`.

`sys.path_hooks` est une liste de fonctions[^callables] qui renvoient un _finder_ lorsqu'elles sont appelées avec un chemin en argument.
Ce chemin est une entrée du `sys.path`.

[^callables]: Ou objets assimilés, voir l'article [Devenir incollable sur les callables]() pour en savoir plus.

Ainsi, pour chaque élément du `sys.path`, on appellera les fonctions de la liste `sys.path_hooks` jusqu'à ce que l'une d'entre-elles renvoie un _finder_ associé au chemin (indiquant donc qu'elle sait gérer ce type de chemin).

On voit que par défaut le `path_hooks` est composé de deux entrées, l'une traitant les archives zip et l'autre plus cryptique qui s'occupe des répertoires.  
Le _hook_ traitant les zip est donc considéré en priorité par rapport à celui traitant les répertoires.

```pycon
>>> sys.path_hooks
[<class 'zipimport.zipimporter'>, <function FileFinder.path_hook.<locals>.path_hook_for_FileFinder at 0xdeadbeef>]
```

Les _hooks_ sont donc appelables en leur donnant en argument un chemin, et ceux-ci renvoie un _finder_.

```pycon
>>> zip_hook, dir_hook = sys.path_hooks
>>> zip_hook('packages.zip')
<zipimporter object "packages.zip/">
>>> dir_hook('subdirectory')
FileFinder('/tmp/subdirectory')
```

On peut aussi constater que l'un et et l'autre lèvent bien des erreurs si on leur demande un _finder_ pour un chemin qu'ils ne gèrent pas.

```pycon
>>> dir_hook('packages.zip')
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
  File "<frozen importlib._bootstrap_external>", line 1699, in path_hook_for_FileFinder
ImportError: only directories are supported
>>> zip_hook('subdirectory')
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
  File "<frozen zipimport>", line 88, in __init__
zipimport.ZipImportError: not a Zip file
```

On en déduit que le comportement de Python pour obtenir la liste des _finders_ est approximativement le suivant :

```python
path_finders = []

for path in sys.path:
    for hook in sys.path_hooks:
        try:
            path_finders.append(hook(path))
            continue
        except ImportError:
            pass
```

## Objet _finder_

Intéressons-nous maintenant de plus près à l'objet _finder_.
Le _finder_ possède une méthode `find_spec` qui reçoit un nom de module et renvoie une « spécification de module » si celui-ci est trouvé (et `None` sinon).

```pycon
>>> finder.find_spec('dir_example')
ModuleSpec(name='dir_example', loader=<_frozen_importlib_external.SourceFileLoader object at 0xbadc0ffee>, origin='/tmp/subdirectory/dir_example.py')
>>> finder.find_spec('zip_example')
>>> finder.find_spec('random')
>>> finder.find_spec('unknown')
```

Les 3 derniers appels renvoient `None` parce que le `finder` n'est pas en mesure de trouver de module correspondant dans le répertoire qui lui est associé.

La spécification renvoyée dans le cas où le module est trouvé contient des attributs (`name`, `origin`) décrivant le module.
Elle contient aussi un attribut `loader` renvoyant le _loader_ qui saura charger un module à partir de ce fichier.  
Il s'agit ici d'un _source file loader_, soit un _loader_ gérant les fichiers de code source Python.

```pycon
>>> spec = finder.find_spec('dir_example')
>>> spec.name
'dir_example'
>>> spec.origin
'/tmp/subdirectory/dir_example.py'
>>> spec.loader
<_frozen_importlib_external.SourceFileLoader object at 0xbadc0ffee>
```

## Objet _loader_

Ce _loader_ renvoyé contient lui aussi de nombreux attributs et méthodes, mais intéressons-nous premièrement à deux d'entre-elles :

- `create_module` prend la spécification en paramètre et initialise un nouveau module (vide), c'est l'étape de chargement.
- `exec_module` reçoit le module nouvellement créé et le remplit en exécutant le code du fichier, c'est l'étape d'exécution.

Un détail cependant concernant `create_module` : elle peut aussi ne pas être implémentée ou renvoyer `None`, pour déléguer à Python la création du module en utilisant le mécanisme par défaut.  
Cette méthode n'est alors utile que si l'on souhaite implémenter un comportement particulier pour nos modules (utilisation d'un autre type de module, création d'attributs par défaut, etc.).

Afin de gérer correctement ce cas, nous utiliserons donc plutôt la fonction `module_from_spec` du module `importlib.util` qui a la même signature, appelle `create_module` et s'occupe de créer le module avec le comportement par défaut si besoin.

```pycon
>>> import importlib.util
>>> mod = importlib.util.module_from_spec(spec)
>>> mod
<module 'dir_example' from '/tmp/subdirectory/dir_example.py'>
>>> dir(mod)
['__cached__', '__doc__', '__file__', '__loader__', '__name__', '__package__', '__spec__']
>>> spec.loader.exec_module(mod)
>>> dir(mod)
['__builtins__', '__cached__', '__doc__', '__file__', '__loader__', '__name__', '__package__', '__spec__', 'hello']
>>> mod.hello
<function hello at 0xe11ae11e1a>
>>> mod.hello('all!')
DIR: Hello all!
```

Dans le cas présent nous avons affaire à un _source file loader_, et celui-ci présente d'autres attributs et méthodes qui peuvent nous intéresser.

```pycon
>>> spec.loader.name
'dir_example'
>>> spec.loader.path
'/tmp/subdirectory/dir_example.py'
>>> spec.loader.get_filename(spec.loader.name)
'/tmp/subdirectory/dir_example.py'
>>> spec.loader.get_source(spec.loader.name)
"def hello(name):\n    print('DIR:', 'Hello', name)\n"
>>> spec.loader.get_data(spec.loader.path)
b"def hello(name):\n    print('DIR:', 'Hello', name)\n"
```

On remarque aussi une méthode `get_code` renvoyant l'objet-code (Python compilé) du module qui est utilisé par `exec_module` et qu'on peut exécuter à la main avec `eval`.

```pycon
>>> code = spec.loader.get_code(spec.loader.name)
>>> code
<code object <module> at 0xc0dec0dac, file "/tmp/subdirectory/dir_example.py", line 1>
>>> namespace = {}
>>> eval(code, namespace)
>>> namespace.keys()
dict_keys(['__builtins__', 'hello'])
>>> namespace['hello']('eval')
DIR: Hello eval
```

## Étapes de l'import

Concernant les _path hooks_, on en était resté à comment Python les utilisait pour créer une liste de _finders_.  
On peut maintenant aller plus loin et mieux comprendre les étapes de l'import.

- On construit les _finders_ à l'aide des listes `sys.path` et `sys.path_hooks` (la liste `path_finders` que l'on a construite plus tôt dans ce chapitre).
- On itère sur ces _finders_ jusqu'à trouver celui qui peut importer notre module (celui renvoie une spécification).
- On crée/exécute le module grâce au _loader_ associé à la spécification.

```python
def my_import(name):
    spec = None
    for finder in path_finders:
        spec = finder.find_spec(name)
        if spec is not None:
            break
    if spec is None:
        raise ModuleNotFoundError(name)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod
```

```pycon
>>> my_import('random')
<module 'random' from '/usr/lib/python3.12/random.py'>
```

## Ajouter notre propre _hook_

Et cela nous amène à construire notre propre entrée à ajouter au `sys.path_hooks`, sur le modèle de celui dédié aux archives zip.  
En effet, Python est capable d'importer des fichiers `.zip` mais il ne sait pas traiter les archives `.tar.gz`.

On va d'abord créer une telle archive contenant un fichier `tar_example.py`

```python
def hello(name):
    print('TAR:', 'Hello', name)
```
Code: `packages.tar.gz/tar_example.py`

[[i]]
| Pour créer l'archive vous pouvez utiliser la commande `tar czf packages.tar.gz --remove-files tar_example.py` après avoir créé un fichier `tar_example.py` dans le répertoire courant contenant le code ci-dessus.

Si on ajoute `'packages.tar.gz'` au `sys.path` on constate bien que ça ne suffit pas à rendre notre module `tar_example` accessible : il manque toujours le _path hook_ pour gérer ce type d'archive.

```pycon
>>> sys.path.append('packages.tar.gz')
>>> import tar_example
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
ModuleNotFoundError: No module named 'tar_example'
```

Avant de construire nos _finder_ et _loader_ et de mettre en place le _hook_, on va s'intéresser au traitement de l'archive `.tar.gz`.

[Le module `tarfile` de Python]() nous permet de manipuler les archives tar (et `.tar.gz` par extension).  
La fonction `open` du module prend un chemin et nous renvoie un objet pour interagir avec l'archive.

```pycon
>>> import tarfile
>>> archive = tarfile.open('packages.tar.gz')
>>> archive
<tarfile.TarFile object at 0xb1ab1ab1a>
```

On voit que l'objet possède des méthodes `getnames`, `getmember` et `extractfile` qui permettent respectivement de lister les noms de fichiers contenus dans l'archive, récupérer l'entrée de l'archive associée à un nom de fichier, extraire le contenu d'un fichier à partir de l'entrée.

```pycon
>>> archive.getnames()
['tar_example.py']
>>> member = archive.getmember('tar_example.py')
>>> file = archive.extractfile(member)
>>> file
<ExFileObject name='packages.tar.gz'>
>>> file.read()
b"def hello(name):\n    print('TAR:', 'Hello', name)\n"
```

[[a]]
| Attention, l'archive possède aussi une méthode `extract` mais celle-ci extrait directement le fichier dans le répertoire courant.
| On préférera donc `extractfile` qui nous renvoie un objet-fichier que l'on peut utiliser directement.

-----

Pour nos _finder_ et _loader_, nous allons nous appuyer sur le module `importlib.abc` (la classes abstraites liées à `importlib`) qui propose deux classes qui nous intéressent ici :

- `PathEntryFinder`, un type de _finder_ dédié aux entrées de `sys.path` (nous verrons par la suite qu'il existe un autre type de _finder).
- `SourceLoader`, un _loader_ similaire au `SourceFileLoader` que nous avons étudié précédemment.

Un `SourceLoader` a juste besoin d'implémenter les méthodes `get_filename` (obtenir le chemin du fichier associé au nom d'un module) et `get_data` (obtenir sous forme de _bytes_ le code source associé à un chemin de fichier), le reste des méthodes est déjà implémenté sur la classe.  
Pour faire simple, on va considérer que le _loader_ est instancié sur une archive précise (dont le chemin sera donné en argument au constructure) et que le chemin d'un fichier est le chemin à l'intérieur de cette archive.

Dans la méthode d'initialisation on s'occupe donc d'ouvrir l'archive et d'extraire les noms de fichiers présents pour créer une table d'association (dictionnaire) entre noms de modules et noms de fichiers.  
Ainsi dans `get_filename` on peut renvoyer le nom de fichier associé au nom de module dans cette table, et dans `get_data` utiliser le code vu plus haut pour extraire le contenu d'un fichier.

```python
import importlib.abc


class ArchiveLoader(importlib.abc.SourceLoader):
    def __init__(self, path):
        self.archive = tarfile.open(path, mode='r:gz')
        self.filenames = {
            name.removesuffix('.py'): name
            for name in self.archive.getnames()
            if name.endswith('.py')
        }

    def get_data(self, name):
        member = self.archive.getmember(name)
        fobj = self.archive.extractfile(member)
        return fobj.read().decode()

    def get_filename(self, name):
        return self.filenames[name]
```

Côté _finder_, notre classe recevra un chemin d'archive et créera directement l'unique _loader_ associé à cette archive.
La méthode `find_spec` n'aura alors qu'à tester si le nom de module existe dans le _loader_ et renvoyer la spécification associée (on dispose pour cela dans `importlib.util` d'une fonction `spec_from_loader` qui prend un nom et un _loader_).

```python
class ArchiveFinder(importlib.abc.PathEntryFinder):
    def __init__(self, path):
        self.loader = ArchiveLoader(path)

    def find_spec(self, fullname, path):
        if fullname in self.loader.filenames:
            return importlib.util.spec_from_loader(fullname, self.loader)
```

Il ne nous reste plus qu'à créer le _hook_ — une fonction qui reçoit un chemin et renvoie le _finder_ associé, ou lève une erreur `ImportError` si elle ne sait pas le gérer — et à l'ajouter au `sys.path_hooks`.

```python
def archive_path_hook(archive_path):
    if archive_path.endswith('.tar.gz'):
        return ArchiveFinder(archive_path)
    raise ImportError


sys.path_hooks.append(archive_path_hook)
```

Et l'on peut maintenant importer notre module…

```pycon
>>> import tar_example
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
ModuleNotFoundError: No module named 'tar_example'
```

… ou presque !  
Python a en fait un mécanisme de cache en place au niveau des _path hooks_ pour éviter d'avoir à les recalculer à chaque import.
Il faut donc nettoyer ce cache à l'aide de la fonction `sys.path_importer_cache.clear` pour rendre notre _hook_ disponible.

```pycon
>>> sys.path_importer_cache.clear()
>>> import tar_example
>>> tar_example
<module 'tar_example' from 'tar_example.py'>
>>> tar_example.hello('Zeste de Savoir')
TAR: Hello Zeste de Savoir
```

-----

On pourrait imaginer d'autres exemples de _path hooks_, depuis d'autres types d'archives ou tout ce qui peut prendre la forme d'une collection de fichiers.  
On pourrait même aller jusqu'à mettre en place un import par le réseau, mais on y reviendra plus tard avec d'autres mécanismes.
