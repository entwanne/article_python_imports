% La mécanique des imports

Le mécanisme des imports de modules en Python est plus complexe qu'il n'en a l'air.
Dans cet article je présenterai ce qu'il se passe lorsqu'on importe un module et comment Python découvre les modules à importer.  

À l'aide de plusieurs exemples (imports réseau, imports de fichiers non Python), nous explorerons aussi comment personnaliser/modifier le comportement classique des imports.

[[i]]
| Les exemples de code de cet article seront parfois présentés comme des codes Python purs, potentiellement suivis d'un chemin/nom de fichier.
| 
| ```python
| def hello():
|     print('Hello')
| ```
| 
| ```python
| class Foo:
|     pass
| ```
| Code: `module.py`
| 
| Et parfois comme des codes interactifs :
| 
| ```pycon
| >>> hello()
| Hello
| >>> from module import Foo
| ```
| 
| L'indicateur de chemin de fichier signale qu'un tel fichier doit être créé avec le contenu présenté.
| 
| En revanche dans les autres cas il ne s'agit pas d'indiquer que certains codes doivent être écrits dans des fichiers ou entrés directement dans l'interpréteur interactif, il s'agit simplement de choisir la forme qui s'adapte le mieux au contexte.
| 
| - Les blocs Python purs sont plus faciles à copier/coller, je les utilise pour présenter les fonctions et classes.
| - Les blocs interactifs permettent de comprendre rapidement le résultat d'une opération, je les utilise pour les exemples courts.
| 
| Je concidère cependant que tous les blocs seront exécutés les uns à la suite des autres dans un même interpréteur, ainsi les imports qui ont été faits précédemment ne sont pas répétés.
| 
| Dans tous les cas je vous conseille de travailler sur des fichiers et d'utiliser l'interpréteur interactif seulement pour essayer / investiguer.
| 
| Les codes sources complets (incluant tous les imports nécessaires) des exemples seront aussi fournis à la fin de l'article.
