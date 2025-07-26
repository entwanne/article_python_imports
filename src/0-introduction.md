% La mécanique des imports

Le mécanisme des imports de modules en Python est plus complexe qu'il n'en a l'air.
Dans cet article je présenterai ce qu'il se passe lorsqu'on importe un module et comment Python découvre les modules à importer.  

À l'aide de plusieurs exemples (imports réseau, imports de fichiers non Python), nous explorerons aussi comment personnaliser/modifier le comportement classique des imports.

-----

La plupart des exemples dans cet article seront présentés comme suit :

```pycon
>>> def hello():
...     print('Hello')
...
>>> hello()
Hello
```

Cela signifie qu'ils sont exécutés directement depuis l'interpréteur interactif de Python.
