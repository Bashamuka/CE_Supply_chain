/*
  # Suppression du trigger search_vector

  1. Changements
    - Suppression du trigger parts_vector_update
    - Suppression de la fonction parts_search_vector_trigger
    - Suppression de la fonction parts_search_vector

  Cette migration nettoie les objets de base de données liés à la fonctionnalité
  de recherche vectorielle qui n'est plus utilisée.
*/

-- Suppression du trigger s'il existe
DROP TRIGGER IF EXISTS parts_vector_update ON parts;

-- Suppression des fonctions si elles existent
DROP FUNCTION IF EXISTS parts_search_vector_trigger();
DROP FUNCTION IF EXISTS parts_search_vector(text, text, text, text, text, text);