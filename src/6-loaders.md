# Chargement d'autres fichiers

Le _file finder_ par défaut de Python instancié dans les _path hooks_ gère l'import des fichiers `.py`, `.pyc` (fichiers Python compilés) et `.so`/`.dll` (bibliothèques dynamiques partagées).  
C'est en fait la classe `FileFinder` qui est instanciée en lui précisant les extensions de fichier supportées et le _loader_ à utiliser pour chaque extension.

On va donc essayer d'aller un cran plus loin en utisant `FileFinder` pour gérer de nouvelles extensions de fichiers, en nous appuyant sur un _loader_ dédié.

## Étendre la syntaxe de Python

Imaginons par exemple un langage Python++, un sur-ensemble de Python ajoutant un opérateur d'incrémentation (`++`).  
L'idée serait de pouvoir importer des fichiers `.pypp` écrits en Python++ et de transformer automatiquement les expressions de type `foo++` en `(foo := foo + 1)` au chargement du module.

Nous utiliserons un `FileLoader` (qui ressemble à `SourceLoader` en plus minimaliste) et surchargerons `get_source` plutôt que `get_data` pour transformer le code (`get_data` devant renvoyer le contenu brut du fichier).

Pour cette transformation on peut se pencher sur le module `tokenize` de Python qui permet de découper du code Python en une série de jetons lexicaux (mots, opérateurs, valeurs littérales).

Prenons le fichier d'entrée Python++ suivant :

```python
def test(x=0):
    for _ in range(10):
        print(x++)
```
Code: `increment.pypp`

Bien qu'il ne s'agisse pas d'un fichier Python valide, il est syntaxiquement composé de jetons valides en Python et peut donc être découpé ainsi.  
La fonction `tokenize` du module `tokenize` prend en argument une fonction de type _readline_ (renvoyant une nouvelle ligne de code à chaque appel) sur un fichier binaire et produit des jetons en retour.

```pycon
>>> with open('increment.pypp', 'rb') as f:
...     for token in tokenize.tokenize(f.readline):
...         print(token)
... 
TokenInfo(type=63 (ENCODING), string='utf-8', start=(0, 0), end=(0, 0), line='')
TokenInfo(type=1 (NAME), string='def', start=(1, 0), end=(1, 3), line='def test(x=0):\n')
TokenInfo(type=1 (NAME), string='test', start=(1, 4), end=(1, 8), line='def test(x=0):\n')
TokenInfo(type=54 (OP), string='(', start=(1, 8), end=(1, 9), line='def test(x=0):\n')
[...]
TokenInfo(type=1 (NAME), string='x', start=(3, 14), end=(3, 15), line='        print(x++)\n')
TokenInfo(type=54 (OP), string='+', start=(3, 15), end=(3, 16), line='        print(x++)\n')
TokenInfo(type=54 (OP), string='+', start=(3, 16), end=(3, 17), line='        print(x++)\n')
[...]
TokenInfo(type=6 (DEDENT), string='', start=(4, 0), end=(4, 0), line='')
TokenInfo(type=6 (DEDENT), string='', start=(4, 0), end=(4, 0), line='')
TokenInfo(type=0 (ENDMARKER), string='', start=(4, 0), end=(4, 0), line='')
```

Notre fonction de transformation prendra un itérable de _tokens_ en entrée et produira les _tokens_ de sortie à la volée.  
Le mécanisme sera relativement simple et utilisera une pile pour détecter quand un jeton `NAME` est suivi de deux jetons `OP:+`.
Dans ce cas nous produirons les jetons correspondant à l'expression `(foo := foo +1)` via une fonction `increment_token` implémentée plus bas.  
Dans le cas contraire, nous penserons à relayer les jetons de la pile avant de la vider et à transmettre directement le jeton reçu.

```pycon
>>> def transform(tokens):
...     stack = []
...     for token in tokens:
...         match token.type:
...             case tokenize.NAME if not stack:
...                 stack.append(token)
...             case tokenize.OP if stack and token.string == '+':
...                 if len(stack) < 2:
...                     stack.append(token)
...                 else:
...                     yield from increment_token(token, stack)
...             case _:
...                 yield from stack
...                 stack.clear()
...                 yield token
...
>>> def increment_token(token, stack):
...     name_token = stack.pop(0)
...     stack.clear()
...     
...     start = name_token.start
...     end = token.end
...     line = name_token.line
...     
...     yield tokenize.TokenInfo(type=tokenize.OP, string='(', start=start, end=start, line=line)
...     yield tokenize.TokenInfo(type=tokenize.NAME, string=name_token.string, start=start, end=start, line=line)
...     yield tokenize.TokenInfo(type=tokenize.OP, string=':=', start=start, end=start, line=line)
...     yield tokenize.TokenInfo(type=tokenize.NAME, string=name_token.string, start=start, end=start, line=line)
...     yield tokenize.TokenInfo(type=tokenize.OP, string='+', start=start, end=start, line=line)
...     yield tokenize.TokenInfo(type=tokenize.NUMBER, string='1', start=start, end=start, line=line)
...     yield tokenize.TokenInfo(type=tokenize.OP, string=')', start=start, end=end, line=line)
...
```

Et ça fonctionne bien à l'usage.

```pycon
>>> with open('increment.pypp', 'rb') as f:
...     for token in transform(tokenize.tokenize(f.readline)):
...         print(token)
...
[...]
TokenInfo(type=54 (OP), string='(', start=(3, 14), end=(3, 14), line='        print(x++)\n')
TokenInfo(type=1 (NAME), string='x', start=(3, 14), end=(3, 14), line='        print(x++)\n')
TokenInfo(type=54 (OP), string=':=', start=(3, 14), end=(3, 14), line='        print(x++)\n')
TokenInfo(type=1 (NAME), string='x', start=(3, 14), end=(3, 14), line='        print(x++)\n')
TokenInfo(type=54 (OP), string='+', start=(3, 14), end=(3, 14), line='        print(x++)\n')
TokenInfo(type=2 (NUMBER), string='1', start=(3, 14), end=(3, 14), line='        print(x++)\n')
TokenInfo(type=54 (OP), string=')', start=(3, 14), end=(3, 17), line='        print(x++)\n')
[...]
```

Le _loader_ n'a alors qu'à reproduire ce comportement dans sa méthode `get_source`.
La méthode devant retourner du code Python (valide) sous forme de texte, on utilisera la fonction `untokenize` pour transformer les jetons produits en texte.

```pycon
>>> class PythonPPLoader(importlib.abc.FileLoader):
...     def get_source(self, fullname):
...         path = self.get_filename(fullname)
...         with open(path, 'rb') as f:
...             tokens = tokenize.tokenize(f.readline)
...             tokens = transform(tokens)
...             return tokenize.untokenize(tokens)
...
```

Pour ce qui est du _path hook_, on reprend donc `FileLoader` présent dans `importlib.machinery` dont on crée un _hook_ pour les fichiers `.py` et `.pypp`.  
Le _loader_ pour les fichiers `.py` est nécessaire car notre nouveau _hook_ sera utilisé en priorité par rapport à l'existant (nous le placerons en première position dans la liste) et renverra un _finder_ valide pour tout chemin de répertoire.
Les fichiers d'extensions non gérées par ce _loader_ (`.pyc`, `.so` et `.dll` par exemple) ne seront donc plus importables, mais ils ne nous intéressent pas ici[^prod].

[^prod]: Dans un code destiné à de la production, il faudrait mettre en place le code gérant ces extensions comme le fait Python par défaut.

```pycon
>>> import importlib.machinery
>>> path_hook = importlib.machinery.FileFinder.path_hook(
...     (importlib.machinery.SourceFileLoader, ['.py']),
...     (PythonPPLoader, ['.pypp']),
... )
>>> sys.path_hooks.insert(0, path_hook)
>>> sys.path_importer_cache.clear()
```

Et ce nouveau _hook_ nous permet bien d'importer le module `increment`.

```pycon
>>> import increment
>>> increment.test(10)
11
12
13
14
15
16
17
18
19
20
```

## Importer un module chiffré

## Importer un module écrit dans un autre langage

----------

5. File loaders
    - On peut aussi imaginer vouloir lire (et décoder) des fichiers Python chiffrés
        - On pourra là encore faire appel à un `FileLoader`
        - Idem, le _loader_ transforme la source et est branché à un _finder_
    - Enfin on peut étendre le mécanisme d'imports pour gérer d'autres langages que Python
        - Par exemple un interpréteur brainfuck sous forme de _loader_
        - On fournit un _loader_ basique qui implémente juste `exec_module`

```python
import codecs
import importlib.abc
import sys
from importlib.machinery import FileFinder, SourceFileLoader


class Rot13Loader(importlib.abc.FileLoader):
    def get_source(self, fullname):
        data = self.get_data(self.get_filename(fullname))
        return codecs.encode(data.decode(), 'rot_13')


path_hook = FileFinder.path_hook(
    (SourceFileLoader, ['.py']),
    (Rot13Loader, ['.pyr']),
)
sys.path_hooks.insert(0, path_hook)
sys.path_importer_cache.clear()

import secret
print(secret.toto())
import secret2
print(secret2.toto())

sys.path_hooks.remove(path_hook)
sys.path_importer_cache.clear()
```
Code: `rot13_loader.py`

```python
import ast
import importlib
import importlib.abc
import importlib.machinery
import pathlib
import sys


class BrainfuckLoader(importlib.abc.Loader):
    OPS = {
        '>': ast.parse('cur += 1').body,
        '<': ast.parse('cur -= 1').body,
        '+': ast.parse('mem[cur] = mem.get(cur, 0) + 1').body,
        '-': ast.parse('mem[cur] = mem.get(cur, 0) - 1').body,
        '.': ast.parse('print(chr(mem.get(cur, 0)), end="")').body,
        'init': ast.parse('mem, cur = {}, 0').body,
        'test': ast.parse('mem.get(cur, 0)').body[0].value,
    }

    def __init__(self, fullname, path):
        self.path = pathlib.Path(path)

    def exec_module(self, module):
        content = self.path.read_text()
        body = [*self.OPS['init']]
        stack = [body]

        for char in content:
            current = stack[-1]
            match char:
                case '[':
                    loop = ast.While(
                        test=self.OPS['test'],
                        body=[ast.Pass()],
                        orelse=[],
                    )
                    current.append(loop)
                    stack.append(loop.body)
                case ']':
                    stack.pop()
                case c if c in self.OPS:
                    current.extend(self.OPS[c])
                case _:
                    raise SyntaxError

        tree = ast.Module(
            body=[
                ast.FunctionDef(
                    name='run',
                    args=ast.arguments(posonlyargs=[], args=[], kwonlyargs=[], kw_defaults=[], defaults=[]),
                    decorator_list=[],
                    body=body,
                ),
            ],
            type_ignores=[],
        )

        ast.fix_missing_locations(tree)
        code = compile(tree, self.path, 'exec')
        exec(code, module.__dict__)


path_hook = importlib.machinery.FileFinder.path_hook(
    (importlib.machinery.SourceFileLoader, ['.py']),
    (BrainfuckLoader, ['.bf']),
)
sys.path_hooks.insert(0, path_hook)
sys.path_importer_cache.clear()

import hello
hello.run()

sys.path_hooks.remove(path_hook)
sys.path_importer_cache.clear()
```
Code: `brainfuck_loader.py`
