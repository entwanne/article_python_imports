# Chargement d'autres fichiers

5. File loaders
    - Le _file finder_ par défaut de Python gère l'import de fichiers `.py`, `.pyc` et `.so`/`.dll`
        - La classe `FileFinder` est pour cela instanciée en lui précisant les extensions supportées et les _loaders_ associés
        - `FileFinder` permet ainsi de gérer d'autres extensions de fichiers avec d'autres _loaders_
    - On peut utiliser le mécanisme des _loaders_ pour étendre la syntaxe de Python
        - Par exemple en ajoutant un opérateur d'incrémentation (`++`)
        - L'idée serait que `foo++` soit transformé en `(foo := foo + 1)` au chargement du module
        - `FileLoader` pourra être utilisé avec une transformation de l'entrée
            - Il ressemble à `SourceLoader` en plus minimaliste
            - On surchargera `get_source` plutôt que `get_data` (qui renvoie le contenu brut)
        - Le _loader_ s'occupe de lire la source et transformer les _tokens_
        - La transformation consiste à détecter les `+` enchaînés après un nom et à les remplacer par une expression d'incrémentation, et produit les _tokens_ correspondant à cette expression
    - On peut aussi imaginer vouloir lire (et décoder) des fichiers Python chiffrés
        - On pourra là encore faire appel à un `FileLoader`
        - Idem, le _loader_ transforme la source et est branché à un _finder_
    - Enfin on peut étendre le mécanisme d'imports pour gérer d'autres langages que Python
        - Par exemple un interpréteur brainfuck sous forme de _loader_
        - On fournit un _loader_ basique qui implémente juste `exec_module`

```python
import importlib.abc
import importlib.machinery
import sys
import tokenize


def transform(tokens):
    stack = []
    for token in tokens:
        match token.type:
            case tokenize.NAME if not stack:
                stack.append(token)
            case tokenize.OP if stack and token.string == '+':
                if len(stack) < 2:
                    stack.append(token)
                else:
                    yield from increment_token(token, stack)
            case _:
                yield from stack
                stack.clear()
                yield token


def increment_token(token, stack):
    name_token = stack.pop(0)
    stack.clear()

    start = name_token.start
    end = token.end
    line = name_token.line

    yield tokenize.TokenInfo(type=tokenize.OP, string='(', start=start, end=start, line=line)
    yield tokenize.TokenInfo(type=tokenize.NAME, string=name_token.string, start=start, end=start, line=line)
    yield tokenize.TokenInfo(type=tokenize.OP, string=':=', start=start, end=start, line=line)
    yield tokenize.TokenInfo(type=tokenize.NAME, string=name_token.string, start=start, end=start, line=line)
    yield tokenize.TokenInfo(type=tokenize.OP, string='+', start=start, end=start, line=line)
    yield tokenize.TokenInfo(type=tokenize.NUMBER, string='1', start=start, end=start, line=line)
    yield tokenize.TokenInfo(type=tokenize.OP, string=')', start=start, end=end, line=line)


class BetterPythonLoader(importlib.abc.FileLoader):
    def get_source(self, fullname):
        path = self.get_filename(fullname)
        with open(path, 'rb') as f:
            tokens = list(tokenize.tokenize(f.readline))
        tokens = transform(tokens)
        return tokenize.untokenize(tokens)


path_hook = importlib.machinery.FileFinder.path_hook(
    (importlib.machinery.SourceFileLoader, ['.py']),
    (BetterPythonLoader, ['.bpy']),
)
sys.path_hooks.insert(0, path_hook)
sys.path_importer_cache.clear()

import increment
increment.test(4)

sys.path_hooks.remove(path_hook)
sys.path_importer_cache.clear()
```
Code: `bpython_loader.py`

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
