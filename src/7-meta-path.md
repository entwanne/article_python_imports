# Découvrir des modules ailleurs

## Les deux types de _finders_

Jusqu'ici nous avons étudié uniquement des `PathEntryFinder` (`FileFinder` en est un cas particulier), les _finders_ invoqués par `sys.path_hooks` qui utilisent les entrées du `sys.path` pour localiser les modules.

Comme je vous l'indiquais plus tôt il existe un second type de _finders_, les `MetaPathFinder`.
Ceux-ci ne reposent pas sur `sys.path` et sont totalement libres d'aller trouver leurs modules ailleurs.

Les `MetaPathFinder` utilisés par Python sont référencés dans la liste `sys.meta_path`.

```pycon
>>> import sys
>>> sys.meta_path
[<_distutils_hack.DistutilsMetaFinder object at 0xfeedface>, <class '_frozen_importlib.BuiltinImporter'>, <class '_frozen_importlib.FrozenImporter'>, <class '_frozen_importlib_external.PathFinder'>]
```

On constate donc que plusieurs sont déjà présents au démarrage de Python :

- `DistutilsMetaFinder` est un peu spécial car lié à une spécificité de packaging avec `distutils`/`setuptools` et il ne nous intéressera pas ici.
- `BuiltinImporter` est dédié à l'import des modules _builtins_, modules directement implémentés dans le code de l'interpréteur Python (`sys.builtin_module_names`).
- `FrozenImporter` est quelque peu similaire pour d'autres modules écrits en Python mais compilés et embarqués dans l'interpréteur.
- `PathFinder` implémente le mécanisme que nous connaissons : c'est le _finder_ qui gère `sys.path_hooks` et les `PathEntryFinder`.

## Manipuler le _meta path_

Les éléments présents dans le _meta path_ (appelés des _meta finders_) sont donc considérés en premier lieu par Python lors d'un nouvel import (import d'un module non présent dans le cache).
Ils implémentent une interface `MetaPathFinder` très proche de `PathEntryFinder` que nous avons vue précédemment, à la différence près que sa méthode `find_spec` reçoit un chemin optionnel en plus du nom et de la cible, que nous pourrons simplement ignorer.

Il est ainsi possible sur cette base de créer nos propres _meta finders_, ajoutés à `sys.meta_path` pour permettre d'importer nos propres types de modules.

```python
import importlib.abc
import importlib.util


class TestLoader(importlib.abc.Loader):
    def exec_module(self, module):
        module.is_meta = True


class TestMetaFinder(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, path=None, target=None):
        if fullname == 'meta':
            return importlib.util.spec_from_loader(fullname, TestLoader())
        return None
```

```pycon
>>> sys.meta_path.append(TestMetaFinder())
>>> import meta
>>> meta
<module 'meta' (<__main__.TestLoader object at 0x7fdc57421e80>)>
>>> meta.is_meta
True
```

Maintenant que nous avons le principe, voyons quelques cas d'usages plus concrets.

## Modules auto-installables

Par exemple, on peut imaginer un système d'import avec une solution de repli lorsque le module n'est pas trouvé : tenter d'installer le paquet via `pip` et réessayer l'import.
Pour prévenir de tout problème de sécurité (exécution de code arbitraire via l'installation de paquets malicieux hébergés sur PyPI), on limitera la fonctionnalité à un ensemble prédéfini de paquets.

On met donc en place un _finder_ qui réalise un appel au programme `pip` (via la fonction `run` du module `subprocess` pour exécuter une commande sur le système) puis appelle à nouveau `find_spec`.
Le _finder_ sera initialisé avec la liste des modules autorisés, et nous penserons à mettre en place un mécanisme de nettoyage pour désinstaller les modules à la sortie du programme (en utilisant `atexit` qui permet d'enregistrer des fonctions à exécuter quand le programme se termine).

```python
import atexit
import subprocess


class PipFinder(importlib.abc.MetaPathFinder):
    def __init__(self, *allowed_modules):
        self.allowed_modules = set(allowed_modules)

    def find_spec(self, fullname, path=None, target=None):
        if fullname not in self.allowed_modules:
            return None

        subprocess.run(['pip', 'install', fullname])
        atexit.register(subprocess.run, ['pip', 'uninstall', fullname])

        return importlib.util.find_spec(fullname)
```

Et c'est aussi simple que cela.
Il ne nous reste qu'à ajouter une instance de `PipFinder` au `meta_path` pour tester notre nouvel import.

On le testera avec la bibliothèque `requests` permettant de réaliser des appels HTTP(S).

```pycon
>>> sys.meta_path.append(PipFinder('requests'))  # On autorise seulement requests pour cet exemple
>>> import requests
Collecting requests
...
Successfully installed ... requests-x.y.z ...
>>> print(requests.get('https://zestedesavoir.com'))
<Response [200]>
```

## Imports réseau

Dans la même veine, on va chercher à importer des modules depuis un serveur distant.
Il ne sera ici pas question d'installation de paquet mais simplement de télécharger le contenu des fichiers cibles afin de les exécuter localement.

[[i]]
| De façon générale on parle de [RPC — _Remote Procedure Call_ / Appel de Procédure à Distance](https://fr.wikipedia.org/wiki/Appel_de_proc%C3%A9dure_%C3%A0_distance) pour désigner le fait d'exécuter du code depuis des appels définis sur un ordinateur distant.

Notre projet se divisera alors en deux composants :

- Un serveur web mettant à disposition les fichiers Python à télécharger.
- Et un client qui fera appel à ce serveur en réalisant son import.

Pour plus de simplificté, nous ferons tourner ces deux composants dans un même programme à l'aide de _threads_ (fils d'exécution).

Commençons alors par mettre en place le serveur, en utilisant le module `http.server` de la bibliothèque standard.
Ce n'est pas le meilleur outil pour ça mais ça a l'avantage de ne pas demander d'installation ou de prise en main particulière, donc nous nous en contenterons ici.

Le serveur fonctionne à l'aide d'un gestionnaire de requête (_request handler_) basé sur la classe `BaseHTTPRequestHandler`.
Ce gestionnaire possède des méthodes qui seront appelées pour chaque action HTTP, en l'occurrence seulement `HEAD` et `GET` nous seront utiles ici.  
La première permet de savoir si un chemin existe et la deuxième de récupérer le contenu associé. Les deux renvoient le statut HTTP adapté (200 si la page est trouvée, 404 sinon) à la requête.

Pour simplifier les choses, nous utiliserons un dictionnaire en tant qu'attribut de classe associant les contenus des fichiers à leur chemin (nous n'aurons besoin que d'un fichier `remote.py`).

```python
import http.server


class ServerHandler(http.server.BaseHTTPRequestHandler):
    files = {
        'remote.py': b'def test():\n    print("Hello")'
    }

    def do_GET(self):
        filename = self.path[1:]
        content = self.files.get(filename)
        if content is None:
            self.send_error(404)
        else:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(content)

    def do_HEAD(self):
        filename = self.path[1:]
        if filename in self.files:
            self.send_response(200)
            self.end_headers()
        else:
            self.send_error(404)
```

On utilise ensuite la classe `HTTPServer` pour démarrer le serveur (dans un _thread_) en lui précisant l'adresse (`''` pour le lancer en local uniquement), le port et la classe gestionnaire de requêtes.

```python
import threading

server = http.server.HTTPServer(('', 8080), ServerHandler)
thr = threading.Thread(target=server.serve_forever)
thr.start()
```

Nous avons maintenant un serveur web qui tourne sur le port 8080, vous pouvez le constater en accédant à <http://localhost:8080/remote.py> depuis votre navigateur favori.

Côté client, on mettra en place un `SourceLoader` faisant ses requêtes au serveur à l'aide de la fonction `urlopen` du module `urllib.request` (prenant une URL en argument et renvoyant un fichier).
On ajoute une méthode `exists` à notre _loader_ qui nous sera utile pour la suite.

```python
import urllib.request


class NetworkLoader(importlib.abc.SourceLoader):
    def __init__(self, baseurl):
        self.baseurl = baseurl

    def get_url(self, fullname):
        return f'{self.baseurl}/{fullname}.py'

    def get_data(self, url):
        with urllib.request.urlopen(url) as f:
            return f.read()

    def get_filename(self, name):
        return f'{self.get_url(name)}'

    def exists(self, name):
        req = urllib.request.Request(self.get_url(name), method='HEAD')
        try:
            with urllib.request.urlopen(req) as f:
                pass
        except:
            return False
        return f.status == 200
```

On implémente ensuite un _meta path finder_ dédié.
Celui-ci utilisera un unique _loader_ qu'il initialisera avec une URL de serveur, et il fera appel à la méthode `exists` pour savoir quand un module peut être trouvé depuis ce _loader_.

```python
class NetworkFinder(importlib.abc.MetaPathFinder):
    def __init__(self, baseurl):
        self.loader = NetworkLoader(baseurl)

    def find_spec(self, fullname, path=None, target=None):
        if self.loader.exists(fullname):
            return importlib.util.spec_from_loader(fullname, self.loader)
```

Enfin on branche le tout au _meta path_ et on importe notre module distant.

```pycon
>>> sys.meta_path.append(NetworkFinder('http://localhost:8080'))
>>> import remote
127.0.0.1 - - [21/Jul/2025 12:34:56] "HEAD /remote.py HTTP/1.1" 200 -
127.0.0.1 - - [21/Jul/2025 12:34:56] "GET /remote.py HTTP/1.1" 200 -
>>> remote.test()
Hello
```

[[i]]
| On constate bien via les logs du serveur les appels HTTP qui sont réalisés lors de l'import.

Et on procède à un petit nettoyage pour la route en coupant le serveur et le _thread_.

```python
del sys.meta_path[-1]
server.shutdown()
thr.join()
```

## Imports dynamiques

Comme dernier exemple, je vous propose de construire des modules à la volée en fonction du nom demandé.

C'est un peu tiré par les cheveux, mais l'idée sera de reconnaître le module par le préfixe utilisé (`dynamic`) et d'interpréter la suite du nom comme des couples clé-valeur à définir dans le module.  
Par exemple `dynamic__title_Dynamic__author_Doe` sera un module définissant les variables `title = 'Dynamic'` et `author = 'Doe'`.

Le _loader_ est tout simple, il reçoit simplement les attributs à définir, et les ajoute au module au moment de l'exécution.

```python
class DynamicLoader(importlib.abc.Loader):
    def __init__(self, attributes):
        self.attributes = attributes

    def exec_module(self, module):
        module.__dict__.update(self.attributes)
```

Quant au _finder_, il s'occupe de découper le nom du module si celui-ci correspond au préfixe demandé, et d'évaluer les attributs pour les renseigner au _loader_.

```python
class DynamicFinder(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, path=None, target=None):
        if fullname.startswith('dynamic__'):
            parts = fullname.split('__')[1:]
            attributes = dict(part.split('_') for part in parts)
            return importlib.util.spec_from_loader(
                fullname,
                DynamicLoader(attributes)
            )
```

Le tout fonctionne ensuite comme annoncé.

```pycon
>>> sys.meta_path.append(DynamicFinder())
>>> import dynamic__title_Dynamic__author_Doe as mod
>>> mod
<module 'dynamic__title_Dynamic__author_Doe' (<__main__.DynamicLoader object at 0x7f556a3ada90>)>
>>> mod.title
'Dynamic'
>>> mod.author
'Doe'
```

## Autres exemples

On peut noter que les _meta finders_ sont le mécanisme le plus élémentaire impliqué dans le processus d'import, tout ce que nous avons vu jusqu'ici passant nécessairement par un tel _finder_.  
Ainsi, tous les exemples des sections précédentes peuvent être réécrits en utilisant des _meta finders_.
Mais il est à noter que chaque _finder_ serait alors en charge de gérer par lui même le mécanisme d'itération sur le `sys.path`.

Un autre exemple envisageable, si vous êtes joueur, consiste à utiliser un modèle de langage (intelligence artificielle) pour générer le code voulu en fonction du nom de la fonction et du module demandés, comme le fait le paquet [copilot-import](https://pypi.org/project/copilot-import/) dont vous pouvez aller regarder les sources.
