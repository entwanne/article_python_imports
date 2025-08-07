# Conclusion

En conclusion, je vous propose un résumé des différentes étapes de l'import réalisées par Python :

1. Résolution du nom du module
2. Recherche du module dans le cache (court-circuit si trouvé)
3. Résolution des modules parents dans le cas d'un paquet
4. Identification de la spécification du module (_finder_)
5. Chargement du module (_loader_)
6. Stockage dans le cache
7. Exécution du code du module (_loader_)

Je tiens aussi à vous rappeler que le mécanisme des imports est paramétrable à de multiples niveaux et permet de tordre Python comme on le veut, pour autant les exemples présentés dans cet article sont plus farfelus les uns que les autres et ne devraient pas être utilisés dans du code de production.
Des usages légitimes de ces mécanismes pourraient concerner de l'appel de procédure distante, de la signature de modules ou de la mise en place d'imports paresseux (n'évaluant le contenu qu'au dernier moment) par exemple.

Pour compléter, je peux aussi vous renvoyer vers [ce billet](https://zestedesavoir.com/billets/1842/notes-sur-les-modules-et-packages-en-python/) qui reprend différents points du mécanisme des imports.

Enfin quelques liens utiles vers les pages de références de Python :

- <https://docs.python.org/3/reference/import.html>
- <https://docs.python.org/3/library/importlib.html> et plus particulièrement [l'algorithme d'import](https://docs.python.org/3/library/importlib.html#approximating-importlib-import-module)
- [PEP 302 – New Import Hooks](https://peps.python.org/pep-0302/)
- [PEP 451 – A ModuleSpec Type for the Import System](https://peps.python.org/pep-0451/)
