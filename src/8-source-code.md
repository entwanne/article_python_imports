# Codes sources des exemples

## Import d'archives `.tar.gz`

[[s]]
| ```python
| def hello(name):
|     print('TAR:', 'Hello', name)
| ```
| Code: `packages.tar.gz/tar_example.py`
| 
| ```python
| import importlib.abc
| import importlib.util
| import sys
| import tarfile
| 
| 
| class ArchiveLoader(importlib.abc.SourceLoader):
|     def __init__(self, path):
|         self.archive = tarfile.open(path, mode='r:gz')
|         self.filenames = {
|             name.removesuffix('.py'): name
|             for name in self.archive.getnames()
|             if name.endswith('.py')
|         }
| 
|     def get_data(self, name):
|         member = self.archive.getmember(name)
|         fobj = self.archive.extractfile(member)
|         return fobj.read().decode()
| 
|     def get_filename(self, name):
|         return self.filenames[name]
| 
| 
| class ArchiveFinder(importlib.abc.PathEntryFinder):
|     def __init__(self, path):
|         self.loader = ArchiveLoader(path)
| 
|     def find_spec(self, fullname, path):
|         if fullname in self.loader.filenames:
|             return importlib.util.spec_from_loader(fullname, self.loader)
| 
| 
| def archive_path_hook(archive_path):
|     if archive_path.endswith('.tar.gz'):
|         return ArchiveFinder(archive_path)
|     raise ImportError
| 
| 
| sys.path_hooks.append(archive_path_hook)
| sys.path_importer_cache.clear()
| sys.path.append('packages.tar.gz')
| 
| import tar_example
| tar_example.hello('Zeste de Savoir')
| ```

## Import de fichier Python++

[[s]]
| ```python
| def test(x=0):
|     for _ in range(10):
|         print(x++)
| ```
| Code: `increment.pypp`
| 
| ```python
| import importlib.abc
| import importlib.machinery
| import sys
| import tokenize
| 
| 
| def transform(tokens):
|     stack = []
|     for token in tokens:
|         match token.type:
|             case tokenize.NAME if not stack:
|                 stack.append(token)
|             case tokenize.OP if stack and token.string == '+':
|                 if len(stack) < 2:
|                     stack.append(token)
|                 else:
|                     yield from increment_token(token, stack)
|             case _:
|                 yield from stack
|                 stack.clear()
|                 yield token
| 
| 
| def increment_token(token, stack):
|     name_token = stack.pop(0)
|     stack.clear()
| 
|     start = name_token.start
|     end = token.end
|     line = name_token.line
| 
|     yield tokenize.TokenInfo(type=tokenize.OP, string='(', start=start, end=start, line=line)
|     yield tokenize.TokenInfo(type=tokenize.NAME, string=name_token.string, start=start, end=start, line=line)
|     yield tokenize.TokenInfo(type=tokenize.OP, string=':=', start=start, end=start, line=line)
|     yield tokenize.TokenInfo(type=tokenize.NAME, string=name_token.string, start=start, end=start, line=line)
|     yield tokenize.TokenInfo(type=tokenize.OP, string='+', start=start, end=start, line=line)
|     yield tokenize.TokenInfo(type=tokenize.NUMBER, string='1', start=start, end=start, line=line)
|     yield tokenize.TokenInfo(type=tokenize.OP, string=')', start=start, end=end, line=line)
| 
| 
| class PythonPPLoader(importlib.abc.FileLoader):
|     def get_source(self, fullname):
|         path = self.get_filename(fullname)
|         with open(path, 'rb') as f:
|             tokens = tokenize.tokenize(f.readline)
|             tokens = transform(tokens)
|             return tokenize.untokenize(tokens)
| 
| 
| path_hook = importlib.machinery.FileFinder.path_hook(
|     (importlib.machinery.SourceFileLoader, ['.py']),
|     (PythonPPLoader, ['.pypp']),
| )
| sys.path_hooks.insert(0, path_hook)
| sys.path_importer_cache.clear()
| 
| import increment
| increment.test(10)
| ```

## Import de module ROT-13

[[s]]
| ```python
| qrs gbgb():
|     erghea 4
| ```
| Code: `secret.pyr`
| 
| ```python
| import codecs
| import importlib.abc
| import importlib.machinery
| import sys
| 
| 
| class Rot13Loader(importlib.abc.FileLoader):
|     def get_source(self, fullname):
|         data = self.get_data(self.get_filename(fullname))
|         return codecs.encode(data.decode(), 'rot_13')
| 
| 
| path_hook = importlib.machinery.FileFinder.path_hook(
|     (importlib.machinery.SourceFileLoader, ['.py']),
|     (Rot13Loader, ['.pyr']),
| )
| sys.path_hooks.insert(0, path_hook)
| sys.path_importer_cache.clear()
| 
| import secret
| print(secret.toto())
| ```

## Import de module BrainFuck

[[s]]
| ```brainfuck
| ++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.
| ```
| Code: `hello.bf`
| 
| ```python
| import ast
| import importlib.abc
| import importlib.machinery
| import pathlib
| import sys
| 
| 
| OPS = {
|     '>': ast.parse('cur += 1').body,
|     '<': ast.parse('cur -= 1').body,
|     '+': ast.parse('mem[cur] += 1').body,
|     '-': ast.parse('mem[cur] -= 1').body,
|     '.': ast.parse('print(chr(mem[cur]), end="")').body,
|     ',': ast.parse('mem[cur] = ord(input())').body,
|     'init': ast.parse('from collections import defaultdict\nmem, cur = defaultdict(int), 0').body,
|     'test': ast.parse('mem[cur] != 0').body[0].value,
| }
| 
| 
| def parse_body(content):
|     body = [*OPS['init']]
|     stack = [body]
| 
|     for char in content:
|         current = stack[-1]
|         match char:
|             case '[':
|                 loop = ast.While(
|                     test=OPS['test'],
|                     body=[ast.Pass()],
|                     orelse=[],
|                 )
|                 current.append(loop)
|                 stack.append(loop.body)
|             case ']':
|                 stack.pop()
|             case c if c in OPS:
|                 current.extend(OPS[c])
|             case _:
|                 raise SyntaxError
| 
|     return body
| 
| 
| def parse_tree(body):
|     tree = ast.Module(
|         body=[
|             ast.FunctionDef(
|                 name='run',
|                 args=ast.arguments(posonlyargs=[], args=[], kwonlyargs=[], kw_defaults=[], defaults=[]),
|                 decorator_list=[],
|                 body=body,
|             ),
|         ],
|         type_ignores=[],
|     )
|     ast.fix_missing_locations(tree)
|     return tree
| 
| 
| class BrainfuckLoader(importlib.abc.Loader):
|     def __init__(self, fullname, path):
|         self.path = pathlib.Path(path)
|     def exec_module(self, module):
|         content = self.path.read_text()
|         body = parse_body(content)
|         tree = parse_tree(body)
|         code = compile(tree, self.path, 'exec')
|         exec(code, module.__dict__)
| 
| 
| path_hook = importlib.machinery.FileFinder.path_hook(
|     (importlib.machinery.SourceFileLoader, ['.py']),
|     (BrainfuckLoader, ['.bf']),
| )
| sys.path_hooks.insert(0, path_hook)
| sys.path_importer_cache.clear()
| 
| import hello
| hello.run()
| ```
