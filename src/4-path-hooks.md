# Découverte et chargement des modules

4. Path hooks
    - _Finders_ pour découvrir les modules et _loaders_ pour les charger
    - `sys.path_hooks` est une liste de callables créant un _finder_ pour chaque entrée de `sys.path`
    - Un _finder_ est un objet avec une méthode `find_spec`
        - Cette méthode prend en argument le nom complet du module
        - Elle renvoie une « spécification de module » (`ModuleSpec`), ou `None` si le module n'est pas trouvé
    - La spécification contient des attributs décrivant le module (`name`, `origin`)
        - et un attribut `loader` renvoyant le _loader_ associé à ce type de fichier
        - On peut initialiser un module vide à partir de la spec, via `importlib.util.module_from_spec` qui appelle `create_module` sur le _loader_ (si définie)
        - On charge le module via la méthode `exec_module` du _loader_
    - Python propose des utilitaires pour gérer différents types de _finders_ et _loaders_
        - `PathEntryFinder` est un _finder_ dédié pour les entrées de `sys.path`
        - `SourceLoader` est un _loader_ offrant de facilités pour importer un fichier source
            - Un _source loader_ a juste à implémenter des méthodes `get_filename` et `get_data` (qui renvoie le contenu du module sous forme de _bytes_)
    - On peut par exemple ajouter un _loader_ pour gérer les archives `.tar.gz`
        - fonctionnant sur le même principe que l'import d'archives `.zip`
        - Le _finder_ est un `PathEntryFinder` classique
        - Le _loader_ s'occupe d'ouvrir l'archive, de localiser le module et d'en renvoyer la source
        - Il suffit ensuite de le brancher aux `sys.path_hooks`
        - Python garde en cache les _hooks_ existants et il faut donc penser à nettoyer le cache
    - On peut imaginer d'autres exemples de _path hooks_
        - Import depuis tout type d'archive, ou tout ce qui prend la forme d'une collection de fichiers
        - Import depuis le réseau (on y reviendra plus tard)

```python
import importlib
import importlib.abc
import importlib.util
import sys
import tarfile


class ArchiveFinder(importlib.abc.PathEntryFinder):
    def __init__(self, path):
        self.loader = ArchiveLoader(path)

    def find_spec(self, fullname, path):
        if fullname in self.loader.filenames:
            return importlib.util.spec_from_loader(fullname, self.loader)


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


def archive_path_hook(archive_path):
    if archive_path.endswith('.tar.gz'):
        return ArchiveFinder(archive_path)
    raise ImportError


sys.path_hooks.append(archive_path_hook)
sys.path.append('packages.tar.gz')
sys.path_importer_cache.clear()


import tar_example
tar_example.hello('PyConFR')
```
Code: `targz_finder.py`
