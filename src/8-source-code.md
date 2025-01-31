# Codes sources des exemples

[[s | Import d'archives `.tar.gz`]]
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

[[s | Import de fichier Python++]]
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

[[s | Import de module ROT-13]]
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

[[s | Import de module BrainFuck]]
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

[[s | Import de module auto-installable]]
| ```python
| import atexit
| import importlib.abc
| import importlib.util
| import subprocess
| import sys
| 
| 
| class PipFinder(importlib.abc.MetaPathFinder):
|     def __init__(self, *allowed_modules):
|         self.allowed_modules = set(allowed_modules)
| 
|     def find_spec(self, fullname, path=None, target=None):
|         if fullname not in self.allowed_modules:
|             return None
| 
|         subprocess.run(['pip', 'install', fullname])
|         atexit.register(subprocess.run, ['pip', 'uninstall', fullname])
| 
|         return importlib.util.find_spec(fullname)
| 
| 
| sys.meta_path.append(PipFinder('requests'))  # On autorise seulement requests pour cet exemple
| import requests
| print(requests.get('https://zestedesavoir.com'))
| ```

[[s | Imports réseau]]
| ```python
| import http.server
| import importlib.abc
| import importlib.util
| import sys
| import threading
| import urllib.request
| 
| 
| class ServerHandler(http.server.BaseHTTPRequestHandler):
|     files = {
|         'remote.py': b'def test():\n    print("Hello")'
|     }
| 
|     def do_GET(self):
|         filename = self.path[1:]
|         content = self.files.get(filename)
|         if content is None:
|             self.send_error(404)
|         else:
|             self.send_response(200)
|             self.end_headers()
|             self.wfile.write(content)
| 
|     def do_HEAD(self):
|         filename = self.path[1:]
|         if filename in self.files:
|             self.send_response(200)
|             self.end_headers()
|         else:
|             self.send_error(404)
| 
| 
| class NetworkLoader(importlib.abc.SourceLoader):
|     def __init__(self, baseurl):
|         self.baseurl = baseurl
| 
|     def get_url(self, fullname):
|         return f'{self.baseurl}/{fullname}.py'
| 
|     def get_data(self, url):
|         with urllib.request.urlopen(url) as f:
|             return f.read()
| 
|     def get_filename(self, name):
|         return f'{self.get_url(name)}'
| 
|     def exists(self, name):
|         req = urllib.request.Request(self.get_url(name), method='HEAD')
|         try:
|             with urllib.request.urlopen(req) as f:
|                 pass
|         except:
|             return False
|         return f.status == 200
| 
| 
| class NetworkFinder(importlib.abc.MetaPathFinder):
|     def __init__(self, baseurl):
|         self.loader = NetworkLoader(baseurl)
| 
|     def find_spec(self, fullname, path=None, target=None):
|         if self.loader.exists(fullname):
|             return importlib.util.spec_from_loader(fullname, self.loader)
| 
| 
| server = http.server.HTTPServer(('', 8080), ServerHandler)
| thr = threading.Thread(target=server.serve_forever)
| 
| sys.meta_path.append(NetworkFinder('http://localhost:8080'))
| 
| try:
|     thr.start()
|     import remote
|     remote.test()
| finally:
|     # On ferme le serveur et on attend proprement le thread
|     server.shutdown()
|     thr.join()
| ```

[[s | Import dynamique]]
| ```python
| import importlib.abc
| import importlib.util
| import sys
| 
| 
| class DynamicLoader(importlib.abc.Loader):
|     def __init__(self, attributes):
|         self.attributes = attributes
| 
|     def exec_module(self, module):
|         module.__dict__.update(self.attributes)
| 
| 
| class DynamicFinder(importlib.abc.MetaPathFinder):
|     def find_spec(self, fullname, path=None, target=None):
|         if fullname.startswith('dynamic__'):
|             parts = fullname.split('__')[1:]
|             attributes = dict(part.split('_') for part in parts)
|             return importlib.util.spec_from_loader(
|                 fullname,
|                 DynamicLoader(attributes)
|             )
| 
| 
| sys.meta_path.append(DynamicFinder())
| 
| import dynamic__title_Dynamic__author_Doe as mod
| 
| print(mod)
| print(mod.title)
| print(mod.author)
| ```
