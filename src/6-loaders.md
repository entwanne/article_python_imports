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
...     start, end, line = name_token.start, token.end, name_token.line
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

On peut utiliser ce même mécanisme de `FileLoader` pour importer des fichiers chiffrés.

Pour l'exemple on va imaginer un chiffrement ROT-13[^rot13] du fichier, mais ça fonctionnerait très bien avec un chiffrement AES ou RSA à condition de stocker la clé de déchiffrement dans un endroit accessible sur le système.  
À l'inverse ça pourrait aussi être utilisé avec un algorithme de signature tel que RSA pour assurer l'authenticité du fichier importé.

[^rot13]: Sachez d'ailleurs que Python 2 offrait nativement la possibilité d'importer des fichiers `.py` encodés en ROT-13 en précisant l'encodage à l'aide d'un commentaire `# coding: rot13` en en-tête de fichier.

Mais dites vous bien que le code déchiffré sera à un moment ou un autre accessible dans la mémoire (et la clé de déchiffrement présente sur le système), ce n'est pas une mesure de sécurité à proprement parler.

Le décodage sera donc opéré dans la méthode `get_source` du `FileLoader`, en faisant appel au module `codecs`.

```pycon
>>> import codecs
>>> class Rot13Loader(importlib.abc.FileLoader):
...     def get_source(self, fullname):
...         data = self.get_data(self.get_filename(fullname))
...         return codecs.encode(data.decode(), 'rot_13')
...
```

On met en place le _hook_ comme précédemment.

```pycon
>>> path_hook = importlib.machinery.FileFinder.path_hook(
...     (importlib.machinery.SourceFileLoader, ['.py']),
...     (Rot13Loader, ['.pyr']),
... )
>>> sys.path_hooks.insert(0, path_hook)
>>> sys.path_importer_cache.clear()
```

[[i]]
| Là encore en raison de l'ordre de priorité ce nouveau _finder_ prend le pas sur les autres _file finders_ existants, nos fichiers Python++ ne sont donc plus importables suite à cet ajout.

Et on est alors en mesure d'importer le fichier `.pyr` suivant.

```python
qrs gbgb():
    erghea 4
```
Code: `secret.pyr`

```pycon
>>> import secret
>>> secret.toto()
4
```

## Importer un module écrit dans un autre langage

Enfin en dernier exemple je vous propose de manipuler directement un AST Python pour produire du _bytecode_.
L'idée est de permettre d'importer des modules écrits en BrainFuck que l'on compilera en Python à la volée.

*[AST]: Abstract Syntax Tree

Le BrainFuck n'a pas de notion de module ni de fonction, juste de code à exécuter.
On considérera alors qu'un module BrainFuck définit une unique fonction `run` qui exécute le code source lorsqu'elle est appelée.

Brainfuck est un langage rudimentaire qui fonctionne avec un curseur qui avance le long d'une bande utilisée comme mémoire et permet de lire/écrire à la position du curseur, et de déplacer ce curseur.  
Il ne dispose alors que de quelques instructions :

- `>`, avancer le curseur d'une position.
- `<`, reculer d'une position.
- `+`, incrémenter la valeur située sous le curseur.
- `-`, décrémenter la valeur située sous le curseur.
- `.`, afficher la valeur située sous le curseur comme un caractère ASCII.
- `[` et `]` pour gérer des boucles (boucle tant que la valeur sous le curseur n'est pas nulle).
- `,`, pour lire un caractère depuis l'entrée standard.

Pour les instructions simples, on peut définir une table d'association entre instruction BrainFuck et nœud d'AST Python.
Les instructions plus complexes (boucles) seront gérées à part.  
On ajoute aussi dans cette table deux nœuds `init` et `test` qui serviront respectivement à initialiser la mémoire et à tester que la case actuelle n'est pas nulle (pour utiliser comme condition de boucle).

Afin de représenter la mémoire on utilisera un dictionnaire où les clés seront les positions, ce qui facilitera la gestion d'une mémoire infinie. On peut faire appel à `defaultdict` du module `collections` (qu'il faudra alors s'assurer d'importer à l'initialisation du module) pour s'assurer que toute position correspondra à une case mémoire initialisée (à zéro).

```pycon
>>> import ast
>>> OPS = {
...     '>': ast.parse('cur += 1').body,
...     '<': ast.parse('cur -= 1').body,
...     '+': ast.parse('mem[cur] += 1').body,
...     '-': ast.parse('mem[cur] -= 1').body,
...     '.': ast.parse('print(chr(mem[cur]), end="")').body,
...     ',': ast.parse('mem[cur] = ord(input())').body,
...     'init': ast.parse('from collections import defaultdict\nmem, cur = defaultdict(int), 0').body,
...     'test': ast.parse('mem[cur] != 0').body[0].value,
... }
```

On peut déjà commencer par écrire quelques fonctions utilitaires pour construire notre AST.

Par exemple une fonction `parse_body` qui prend en entrée un texte représentant un code BrainFuck et renvoie une liste de nœuds AST correspondant aux intructions _bytecode_ Python.  
C'est cette fonction qui devra gérer les boucles, en utilisant pour cela une pile : lorsqu'on rencontre un `[` on initialise un nœud `while` avec notre condition (`OPS['test']`) que l'on ajoute à la pile, et lorsque l'on rencontre un `]` on dépile le nœud présent.
Chaque instruction rencontrée sera ensuite ajoutée au dernier nœud de la pile.

```pycon
>>> def parse_body(content):
...     body = [*OPS['init']]
...     stack = [body]
...     for char in content:
...         current = stack[-1]
...         match char:
...             case '[':
...                 loop = ast.While(
...                     test=OPS['test'],
...                     body=[ast.Pass()],
...                     orelse=[],
...                 )
...                 current.append(loop)
...                 stack.append(loop.body)
...             case ']':
...                 stack.pop()
...             case c if c in OPS:
...                 current.extend(OPS[c])
...             case _:
...                 raise SyntaxError
...     return body
... 
```

Afin de construire un module et une fonction `run`, on ajoute une autre fonction `parse_tree` recevant une liste de nœuds AST (`body`) et construisant les nœuds manquants pour former un module.  
On pensera à utiliser la fonction `ast.fix_missing_locations` pour compléter les informations de position que nous n'avons pas renseignées sur nos nœuds (et qui permet à Python d'afficher des informations cohérentes sur l'emplacement de l'erreur quand une exception survient).

```pycon
>>> def parse_tree(body):
...     tree = ast.Module(
...         body=[
...             ast.FunctionDef(
...                 name='run',
...                 args=ast.arguments(posonlyargs=[], args=[], kwonlyargs=[], kw_defaults=[], defaults=[]),
...                 decorator_list=[],
...                 body=body,
...             ),
...         ],
...         type_ignores=[],
...     )
...     ast.fix_missing_locations(tree)
...     return tree
...
```

Enfin on partira cette fois d'un _loader_ vide (`importlib.abc.Loader`) et la transformation du code se fera directement dans la méthode `exec_module`.  
Les fonctions natives `compile` et `exec` de Python nous permettront respectivement de transformer l'AST en _bytecode_ et d'exécuter le _bytecode_ dans l'espace de noms du module.

```pycon
>>> import pathlib
>>> class BrainfuckLoader(importlib.abc.Loader):
...     def __init__(self, fullname, path):
...         self.path = pathlib.Path(path)
...     def exec_module(self, module):
...         content = self.path.read_text()
...         body = parse_body(content)
...         tree = parse_tree(body)
...         code = compile(tree, self.path, 'exec')
...         exec(code, module.__dict__)
...
```

On ajoute à nouveau un _hook_ pour rendre disponible le _loader_.

```pycon
>>> path_hook = importlib.machinery.FileFinder.path_hook(
...     (importlib.machinery.SourceFileLoader, ['.py']),
...     (BrainfuckLoader, ['.bf']),
... )
>>> sys.path_hooks.insert(0, path_hook)
>>> sys.path_importer_cache.clear()
```

On peut prendre cet exemple de _hello world_ en BrainFuck.

```brainfuck
++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.
```
Code: `hello.bf`

Importer le module `hello` donne alors accès à une fonction `run` qui exécute ce _hello world_.

```pycon
>>> import hello
>>> hello
<module 'hello' from '/tmp/hello.bf'>
>>> dir(hello)
['__builtins__', '__doc__', '__file__', '__loader__', '__name__', '__package__', '__spec__', 'run']
>>> hello.run()
Hello World!
```
