# Découvrir des modules ailleurs

## Les deux types de _finders_

Jusqu'ici nous avons étudié uniquement des `PathEntryFinder` (`FileFinder` en est un cas particulier), les _finders_ invoqués par `sys.path_hooks` qui utilisent les entrées du `sys.path` pour localiser les modules.

Comme je vous l'indiquais plus tôt il existe un second type de _finders_, celui  des `MetaPathFinder`.
Ceux-ci ne reposent pas sur `sys.path` et sont totalement libres d'aller trouver des modules ailleurs.  
On verra qu'ils n'ont pas exactement la même signature car leur méthode `findspec` reçoit un argument `xxx` supplémentaire.

Les `MetaPathFinder` utilisés par Python sont référencés dans la liste `sys.meta_path`.

```pycon
>>> import sys
>>> sys.meta_path
[<_distutils_hack.DistutilsMetaFinder object at 0xfeedface>, <class '_frozen_importlib.BuiltinImporter'>, <class '_frozen_importlib.FrozenImporter'>, <class '_frozen_importlib_external.PathFinder'>]
```

On constate donc que plusieurs sont déjà présents au démarrage de Python :

- `DistutilsMetaFinder` est un peu spécial et
- `BuiltinImporter` est dédié à l'import des modules _builtins_, modules directement implémentés dans le code de l'interpréteur Python (`sys.builtin_module_names`).
- `FrozenImporter` est quelque peu similaire pour d'autres modules écrits en Python mais compilés et embarqués dans l'interpréteur.
- `PathFinder` implémente le mécanisme que nous connaissons : c'est le _finder_ qui gère `sys.path_hooks` et les `PathEntryFinder`.

- PathEntryFinder
    - utilise des répertoires (ou assimilés, sys.path) sur le système de fichiers pour localiser les modules
- MetaPathFinder
    - totalement libres de trouver des modules où bon leur semble
    - `find_spec` reçoit un argument supplémentaire
    - `PathFinder` est un `MetaPathFinder` qui opère la gestion du `sys.path`/`sys.path_hooks` (et donc gère les `PathEntryFinder`)

## Manipuler le _meta path_

## Modules auto-installables

## Imports réseau

## Imports dynamiques

6. Meta path
    - `FileFinder` s'appuie sur des répertoires (ou apparentés) via des `PathEntryFinder`
    - `sys.meta_path` liste les _meta finders_ utilisés par Python pour rechercher un module
        - Ceux-ci implémentent l'interface de `MetaPathFinder`
        - Très proche de `PathEntryFinder`, elle demande une méthode `find_spec` recevant le nom du module et son chemin
        - On remarque que `PathFinder` (et donc les mécanismes liés à `sys.path` et `sys.meta_path`) est lui aussi une entrée _meta path_
    - Finder qui se charge d'installer les paquets manquants, à ajouter en dernière position du meta path (appelé seulement si aucun finder n'a traité l'import avant)
    - Finder HTTP auprès d'un serveur exposant des modules pour de la programmation RPC
    - Imports dynamiques : module dont le contenu est généré à la volée en fonction du nom
    - les exemples des sections précédentes pourraient être réécrits avec des meta path finders
        - mais chaque finder devrait gérer lui-même le mécanisme d'itération sur le sys.path
    - exemple possible : import qui fait générer le contenu du module par IA

```python
import atexit
import importlib
import importlib.abc
import importlib.util
import subprocess
import sys


class PipFinder(importlib.abc.MetaPathFinder):
    def __init__(self, *allowed_modules):
        self.allowed_modules = set(allowed_modules)

    def find_spec(self, fullname, path, target=None):
        if fullname not in self.allowed_modules:
            return None

        subprocess.run(['pip', 'install', fullname])
        atexit.register(subprocess.run, ['pip', 'uninstall', fullname])

        return importlib.util.find_spec(fullname)


sys.meta_path.append(PipFinder('requests'))

import requests
print(requests.get('https://pycon.fr'))
```
Code: `pip_finder.py`

```python
import codecs
import http.client
import http.server
import importlib
import importlib.abc
import importlib.util
import sys
import threading
import urllib.request


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


server = http.server.HTTPServer(('', 8080), ServerHandler)
thr = threading.Thread(target=server.serve_forever)
thr.start()


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


class NetworkFinder(importlib.abc.MetaPathFinder):
    def __init__(self, baseurl):
        self.loader = NetworkLoader(baseurl)

    def find_spec(self, fullname, path, target=None):
        if self.loader.exists(fullname):
            return importlib.util.spec_from_loader(fullname, self.loader)


sys.meta_path.append(NetworkFinder('http://localhost:8080'))

import remote
remote.test()

server.shutdown()
thr.join()
```
Code: `network_finder.py`

```python
import importlib
import importlib.abc
import importlib.util
import sys


class DynamicLoader(importlib.abc.Loader):
    def __init__(self, attributes):
        self.attributes = attributes

    def exec_module(self, module):
        module.__dict__.update(self.attributes)


class DynamicFinder(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, path, target=None):
        if fullname.startswith('dynamic__'):
            parts = fullname.split('__')[1:]
            attributes = dict(part.split('_') for part in parts)
            return importlib.util.spec_from_loader(
                fullname,
                DynamicLoader(attributes)
            )

sys.meta_path.append(DynamicFinder())

import dynamic__foo_bar__toto_tata as mod
print(mod)
print(mod.foo)
print(mod.toto)
```
Code: `dynamic_import.py`
