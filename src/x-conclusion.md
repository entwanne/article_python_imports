# Conclusion

7. Conclusion
    - étapes de l'import :
        1. Résolution du nom du module
        2. Recherche du module dans le cache (court-circuit si trouvé)
        3. Résolution des modules parents dans le cas d'un paquet
        4. Identification de la spécification du module (finder)
        5. Chargement du module (loader)
        6. Stockage dans le cache
        7. Exécution du code du module (loader)
    - <https://docs.python.org/3/library/importlib.html#approximating-importlib-import-module>
    - le mécanisme des imports est paramétrable à de multiples niveaux et permet de tordre Python comme on le veut
    - Quelques liens utiles
        - <https://peps.python.org/pep-0302/>
        - <https://peps.python.org/pep-0451/>
        - <https://docs.python.org/3/reference/import.html>
        - <https://docs.python.org/3/library/importlib.html>
