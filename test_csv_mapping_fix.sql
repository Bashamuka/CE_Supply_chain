-- Script de test pour valider les corrections du mapping CSV
-- Ce script teste le nouveau système de mapping strict

DO $$
DECLARE
    test_data RECORD;
    mapping_correct BOOLEAN := TRUE;
    issues_found INTEGER := 0;
BEGIN
    RAISE NOTICE '=== TEST DU NOUVEAU SYSTÈME DE MAPPING ===';
    
    -- Vérifier la structure de la table parts
    RAISE NOTICE 'Vérification de la structure de la table parts...';
    
    -- Compter les colonnes attendues
    DECLARE
        column_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO column_count
        FROM information_schema.columns 
        WHERE table_name = 'parts' AND table_schema = 'public';
        
        RAISE NOTICE 'Nombre de colonnes dans la table parts: %', column_count;
        
        IF column_count = 23 THEN
            RAISE NOTICE '✅ Structure de table correcte (23 colonnes)';
        ELSE
            RAISE NOTICE '❌ Structure de table incorrecte (attendu: 23, trouvé: %)', column_count;
            mapping_correct := FALSE;
        END IF;
    END;
    
    -- Vérifier les colonnes attendues
    RAISE NOTICE 'Vérification des colonnes attendues...';
    
    DECLARE
        expected_columns TEXT[] := ARRAY[
            'id', 'order_number', 'supplier_order', 'part_ordered', 'part_delivered', 
            'description', 'quantity_requested', 'invoice_quantity', 'qty_received_irium', 
            'status', 'cd_lta', 'eta', 'date_cf', 'invoice_number', 'actual_position', 
            'operator_name', 'po_customer', 'comments', 'prim_pso', 'order_type', 
            'cat_ticket_id', 'ticket_status', 'ship_by_date', 'customer_name'
        ];
        missing_columns TEXT[] := ARRAY[]::TEXT[];
        col TEXT;
    BEGIN
        FOREACH col IN ARRAY expected_columns
        LOOP
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'parts' AND column_name = col AND table_schema = 'public'
            ) THEN
                missing_columns := array_append(missing_columns, col);
            END IF;
        END LOOP;
        
        IF array_length(missing_columns, 1) IS NULL THEN
            RAISE NOTICE '✅ Toutes les colonnes attendues sont présentes';
        ELSE
            RAISE NOTICE '❌ Colonnes manquantes: %', array_to_string(missing_columns, ', ');
            mapping_correct := FALSE;
        END IF;
    END;
    
    -- Analyser les données existantes pour détecter les problèmes
    RAISE NOTICE 'Analyse des données existantes...';
    
    -- Compter les lignes avec des valeurs suspectes
    DECLARE
        steven_count INTEGER;
        congo_count INTEGER;
        jordan_count INTEGER;
        delivery_count INTEGER;
        total_rows INTEGER;
    BEGIN
        SELECT COUNT(*) INTO total_rows FROM parts;
        
        -- Compter "Steven approval" dans des colonnes incorrectes
        SELECT COUNT(*) INTO steven_count
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
        
        -- Compter "CONGO EQUIPMENT" dans des colonnes incorrectes
        SELECT COUNT(*) INTO congo_count
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
        
        -- Compter "Jordan Ngoy" dans des colonnes incorrectes
        SELECT COUNT(*) INTO jordan_count
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
        
        -- Compter "Delivery completed" dans des colonnes incorrectes
        SELECT COUNT(*) INTO delivery_count
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
        
        RAISE NOTICE 'Total d''enregistrements: %', total_rows;
        RAISE NOTICE 'Lignes avec "Steven approval" mal placé: %', steven_count;
        RAISE NOTICE 'Lignes avec "CONGO EQUIPMENT" mal placé: %', congo_count;
        RAISE NOTICE 'Lignes avec "Jordan Ngoy" mal placé: %', jordan_count;
        RAISE NOTICE 'Lignes avec "Delivery completed" mal placé: %', delivery_count;
        
        issues_found := steven_count + congo_count + jordan_count + delivery_count;
        
        IF issues_found = 0 THEN
            RAISE NOTICE '✅ Aucun problème de mapping détecté dans les données existantes';
        ELSE
            RAISE NOTICE '❌ % problèmes de mapping détectés dans les données existantes', issues_found;
            mapping_correct := FALSE;
        END IF;
    END;
    
    -- Résumé du test
    RAISE NOTICE '=== RÉSUMÉ DU TEST ===';
    IF mapping_correct AND issues_found = 0 THEN
        RAISE NOTICE '✅ SYSTÈME DE MAPPING VALIDÉ - Prêt pour un nouvel import';
    ELSE
        RAISE NOTICE '❌ SYSTÈME DE MAPPING NON VALIDÉ - Correction nécessaire';
        RAISE NOTICE 'Recommandations:';
        RAISE NOTICE '1. Vider la table parts: DELETE FROM parts;';
        RAISE NOTICE '2. Utiliser le template CSV fourni';
        RAISE NOTICE '3. Réimporter avec le nouveau système de mapping strict';
    END IF;
    
    RAISE NOTICE '=== FIN DU TEST ===';
    
END $$;
