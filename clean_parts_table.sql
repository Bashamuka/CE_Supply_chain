-- Script de nettoyage et correction des données de la table parts
-- Ce script corrige les problèmes de mapping identifiés

DO $$
DECLARE
    total_rows INTEGER;
    corrected_rows INTEGER := 0;
    suspicious_rows INTEGER := 0;
BEGIN
    RAISE NOTICE '=== NETTOYAGE DE LA TABLE PARTS ===';
    
    -- Compter le nombre total d'enregistrements
    SELECT COUNT(*) INTO total_rows FROM parts;
    RAISE NOTICE 'Nombre total d''enregistrements: %', total_rows;
    
    -- Identifier les lignes avec des valeurs suspectes
    RAISE NOTICE 'Identification des lignes problématiques...';
    
    -- Compter les lignes avec "Steven approval" dans des colonnes incorrectes
    SELECT COUNT(*) INTO suspicious_rows
    FROM parts 
    WHERE (order_number ILIKE '%Steven approval%' OR 
           supplier_order ILIKE '%Steven approval%' OR
           part_ordered ILIKE '%Steven approval%' OR
           part_delivered ILIKE '%Steven approval%' OR
           description ILIKE '%Steven approval%' OR
           status ILIKE '%Steven approval%' OR
           cd_lta ILIKE '%Steven approval%' OR
           invoice_number ILIKE '%Steven approval%' OR
           actual_position ILIKE '%Steven approval%' OR
           operator_name ILIKE '%Steven approval%' OR
           po_customer ILIKE '%Steven approval%' OR
           prim_pso ILIKE '%Steven approval%' OR
           order_type ILIKE '%Steven approval%' OR
           cat_ticket_id ILIKE '%Steven approval%' OR
           ticket_status ILIKE '%Steven approval%' OR
           customer_name ILIKE '%Steven approval%');
    
    RAISE NOTICE 'Lignes avec "Steven approval" dans des colonnes incorrectes: %', suspicious_rows;
    
    -- Compter les lignes avec "CONGO EQUIPMENT" dans des colonnes incorrectes
    DECLARE
        congo_rows INTEGER;
    BEGIN
        SELECT COUNT(*) INTO congo_rows
        FROM parts 
        WHERE (order_number ILIKE '%CONGO EQUIPMENT%' OR 
               supplier_order ILIKE '%CONGO EQUIPMENT%' OR
               part_ordered ILIKE '%CONGO EQUIPMENT%' OR
               part_delivered ILIKE '%CONGO EQUIPMENT%' OR
               description ILIKE '%CONGO EQUIPMENT%' OR
               status ILIKE '%CONGO EQUIPMENT%' OR
               cd_lta ILIKE '%CONGO EQUIPMENT%' OR
               invoice_number ILIKE '%CONGO EQUIPMENT%' OR
               actual_position ILIKE '%CONGO EQUIPMENT%' OR
               operator_name ILIKE '%CONGO EQUIPMENT%' OR
               po_customer ILIKE '%CONGO EQUIPMENT%' OR
               prim_pso ILIKE '%CONGO EQUIPMENT%' OR
               order_type ILIKE '%CONGO EQUIPMENT%' OR
               cat_ticket_id ILIKE '%CONGO EQUIPMENT%' OR
               ticket_status ILIKE '%CONGO EQUIPMENT%' OR
               customer_name ILIKE '%CONGO EQUIPMENT%');
        
        RAISE NOTICE 'Lignes avec "CONGO EQUIPMENT" dans des colonnes incorrectes: %', congo_rows;
    END;
    
    -- Compter les lignes avec "Jordan Ngoy" dans des colonnes incorrectes
    DECLARE
        jordan_rows INTEGER;
    BEGIN
        SELECT COUNT(*) INTO jordan_rows
        FROM parts 
        WHERE (order_number ILIKE '%Jordan Ngoy%' OR 
               supplier_order ILIKE '%Jordan Ngoy%' OR
               part_ordered ILIKE '%Jordan Ngoy%' OR
               part_delivered ILIKE '%Jordan Ngoy%' OR
               description ILIKE '%Jordan Ngoy%' OR
               status ILIKE '%Jordan Ngoy%' OR
               cd_lta ILIKE '%Jordan Ngoy%' OR
               invoice_number ILIKE '%Jordan Ngoy%' OR
               actual_position ILIKE '%Jordan Ngoy%' OR
               po_customer ILIKE '%Jordan Ngoy%' OR
               prim_pso ILIKE '%Jordan Ngoy%' OR
               order_type ILIKE '%Jordan Ngoy%' OR
               cat_ticket_id ILIKE '%Jordan Ngoy%' OR
               ticket_status ILIKE '%Jordan Ngoy%' OR
               customer_name ILIKE '%Jordan Ngoy%');
        
        RAISE NOTICE 'Lignes avec "Jordan Ngoy" dans des colonnes incorrectes: %', jordan_rows;
    END;
    
    -- Compter les lignes avec "Delivery completed" dans des colonnes incorrectes
    DECLARE
        delivery_rows INTEGER;
    BEGIN
        SELECT COUNT(*) INTO delivery_rows
        FROM parts 
        WHERE (order_number ILIKE '%Delivery completed%' OR 
               supplier_order ILIKE '%Delivery completed%' OR
               part_ordered ILIKE '%Delivery completed%' OR
               part_delivered ILIKE '%Delivery completed%' OR
               description ILIKE '%Delivery completed%' OR
               status ILIKE '%Delivery completed%' OR
               cd_lta ILIKE '%Delivery completed%' OR
               invoice_number ILIKE '%Delivery completed%' OR
               actual_position ILIKE '%Delivery completed%' OR
               operator_name ILIKE '%Delivery completed%' OR
               po_customer ILIKE '%Delivery completed%' OR
               order_type ILIKE '%Delivery completed%' OR
               cat_ticket_id ILIKE '%Delivery completed%' OR
               ticket_status ILIKE '%Delivery completed%' OR
               customer_name ILIKE '%Delivery completed%');
        
        RAISE NOTICE 'Lignes avec "Delivery completed" dans des colonnes incorrectes: %', delivery_rows;
    END;
    
    -- PROPOSITION DE CORRECTION
    RAISE NOTICE '=== PROPOSITION DE CORRECTION ===';
    RAISE NOTICE 'Pour corriger ces problèmes, il est recommandé de:';
    RAISE NOTICE '1. Vider complètement la table parts';
    RAISE NOTICE '2. Utiliser le nouveau système de mapping strict';
    RAISE NOTICE '3. Réimporter les données avec le bon format CSV';
    RAISE NOTICE '';
    RAISE NOTICE 'Voulez-vous vider la table parts maintenant? (Décommentez la ligne suivante)';
    RAISE NOTICE '-- DELETE FROM parts;';
    
    -- Décommentez la ligne suivante pour vider la table
    -- DELETE FROM parts;
    -- RAISE NOTICE 'Table parts vidée. Prêt pour un nouvel import.';
    
    RAISE NOTICE '=== ANALYSE TERMINÉE ===';
    RAISE NOTICE 'Total d''enregistrements analysés: %', total_rows;
    RAISE NOTICE 'Lignes problématiques détectées: %', (suspicious_rows + congo_rows + jordan_rows + delivery_rows);
    
END $$;
