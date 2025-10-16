-- Script de diagnostic et correction du mapping CSV pour la table parts
-- Ce script analyse les données actuelles et propose des corrections

-- 1. ANALYSE DES DONNÉES ACTUELLES
-- Vérifier la structure de la table parts
DO $$
BEGIN
    RAISE NOTICE '=== ANALYSE DE LA TABLE PARTS ===';
    
    -- Compter le nombre total d'enregistrements
    PERFORM COUNT(*) FROM parts;
    RAISE NOTICE 'Nombre total d''enregistrements dans parts: %', (SELECT COUNT(*) FROM parts);
    
    -- Analyser les colonnes problématiques
    RAISE NOTICE '=== ANALYSE DES COLONNES PROBLÉMATIQUES ===';
    
    -- Vérifier les valeurs dans comments qui semblent incorrectes
    RAISE NOTICE 'Valeurs suspectes dans comments:';
    FOR rec IN 
        SELECT DISTINCT comments, COUNT(*) as count 
        FROM parts 
        WHERE comments IS NOT NULL AND comments != '' 
        GROUP BY comments 
        ORDER BY count DESC 
        LIMIT 10
    LOOP
        RAISE NOTICE '  "%" : % occurrences', rec.comments, rec.count;
    END LOOP;
    
    -- Vérifier les valeurs dans prim_pso
    RAISE NOTICE 'Valeurs dans prim_pso:';
    FOR rec IN 
        SELECT DISTINCT prim_pso, COUNT(*) as count 
        FROM parts 
        WHERE prim_pso IS NOT NULL AND prim_pso != '' 
        GROUP BY prim_pso 
        ORDER BY count DESC 
        LIMIT 10
    LOOP
        RAISE NOTICE '  "%" : % occurrences', rec.prim_pso, rec.count;
    END LOOP;
    
    -- Vérifier les valeurs dans ticket_status
    RAISE NOTICE 'Valeurs dans ticket_status:';
    FOR rec IN 
        SELECT DISTINCT ticket_status, COUNT(*) as count 
        FROM parts 
        WHERE ticket_status IS NOT NULL AND ticket_status != '' 
        GROUP BY ticket_status 
        ORDER BY count DESC 
        LIMIT 10
    LOOP
        RAISE NOTICE '  "%" : % occurrences', rec.ticket_status, rec.count;
    END LOOP;
    
    -- Vérifier les valeurs dans cat_ticket_id
    RAISE NOTICE 'Valeurs dans cat_ticket_id:';
    FOR rec IN 
        SELECT DISTINCT cat_ticket_id, COUNT(*) as count 
        FROM parts 
        WHERE cat_ticket_id IS NOT NULL AND cat_ticket_id != '' 
        GROUP BY cat_ticket_id 
        ORDER BY count DESC 
        LIMIT 10
    LOOP
        RAISE NOTICE '  "%" : % occurrences', rec.cat_ticket_id, rec.count;
    END LOOP;
    
    -- Analyser les patterns suspects
    RAISE NOTICE '=== ANALYSE DES PATTERNS SUSPECTS ===';
    
    -- Vérifier si "Steven approval" apparaît dans d'autres colonnes
    RAISE NOTICE 'Recherche de "Steven approval" dans toutes les colonnes:';
    FOR rec IN 
        SELECT 
            'order_number' as column_name, COUNT(*) as count
        FROM parts WHERE order_number ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'supplier_order' as column_name, COUNT(*) as count
        FROM parts WHERE supplier_order ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'part_ordered' as column_name, COUNT(*) as count
        FROM parts WHERE part_ordered ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'part_delivered' as column_name, COUNT(*) as count
        FROM parts WHERE part_delivered ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'description' as column_name, COUNT(*) as count
        FROM parts WHERE description ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'status' as column_name, COUNT(*) as count
        FROM parts WHERE status ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'cd_lta' as column_name, COUNT(*) as count
        FROM parts WHERE cd_lta ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'invoice_number' as column_name, COUNT(*) as count
        FROM parts WHERE invoice_number ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'actual_position' as column_name, COUNT(*) as count
        FROM parts WHERE actual_position ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'operator_name' as column_name, COUNT(*) as count
        FROM parts WHERE operator_name ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'po_customer' as column_name, COUNT(*) as count
        FROM parts WHERE po_customer ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'prim_pso' as column_name, COUNT(*) as count
        FROM parts WHERE prim_pso ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'order_type' as column_name, COUNT(*) as count
        FROM parts WHERE order_type ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'cat_ticket_id' as column_name, COUNT(*) as count
        FROM parts WHERE cat_ticket_id ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'ticket_status' as column_name, COUNT(*) as count
        FROM parts WHERE ticket_status ILIKE '%Steven approval%'
        UNION ALL
        SELECT 
            'customer_name' as column_name, COUNT(*) as count
        FROM parts WHERE customer_name ILIKE '%Steven approval%'
    LOOP
        IF rec.count > 0 THEN
            RAISE NOTICE '  Colonne "%" : % occurrences', rec.column_name, rec.count;
        END IF;
    END LOOP;
    
    -- Vérifier les valeurs "CONGO EQUIPMENT" dans différentes colonnes
    RAISE NOTICE 'Recherche de "CONGO EQUIPMENT" dans toutes les colonnes:';
    FOR rec IN 
        SELECT 
            'order_number' as column_name, COUNT(*) as count
        FROM parts WHERE order_number ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'supplier_order' as column_name, COUNT(*) as count
        FROM parts WHERE supplier_order ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'part_ordered' as column_name, COUNT(*) as count
        FROM parts WHERE part_ordered ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'part_delivered' as column_name, COUNT(*) as count
        FROM parts WHERE part_delivered ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'description' as column_name, COUNT(*) as count
        FROM parts WHERE description ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'status' as column_name, COUNT(*) as count
        FROM parts WHERE status ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'cd_lta' as column_name, COUNT(*) as count
        FROM parts WHERE cd_lta ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'invoice_number' as column_name, COUNT(*) as count
        FROM parts WHERE invoice_number ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'actual_position' as column_name, COUNT(*) as count
        FROM parts WHERE actual_position ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'operator_name' as column_name, COUNT(*) as count
        FROM parts WHERE operator_name ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'po_customer' as column_name, COUNT(*) as count
        FROM parts WHERE po_customer ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'prim_pso' as column_name, COUNT(*) as count
        FROM parts WHERE prim_pso ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'order_type' as column_name, COUNT(*) as count
        FROM parts WHERE order_type ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'cat_ticket_id' as column_name, COUNT(*) as count
        FROM parts WHERE cat_ticket_id ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'ticket_status' as column_name, COUNT(*) as count
        FROM parts WHERE ticket_status ILIKE '%CONGO EQUIPMENT%'
        UNION ALL
        SELECT 
            'customer_name' as column_name, COUNT(*) as count
        FROM parts WHERE customer_name ILIKE '%CONGO EQUIPMENT%'
    LOOP
        IF rec.count > 0 THEN
            RAISE NOTICE '  Colonne "%" : % occurrences', rec.column_name, rec.count;
        END IF;
    END LOOP;
    
    -- Vérifier les valeurs "Jordan Ngoy" dans différentes colonnes
    RAISE NOTICE 'Recherche de "Jordan Ngoy" dans toutes les colonnes:';
    FOR rec IN 
        SELECT 
            'order_number' as column_name, COUNT(*) as count
        FROM parts WHERE order_number ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'supplier_order' as column_name, COUNT(*) as count
        FROM parts WHERE supplier_order ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'part_ordered' as column_name, COUNT(*) as count
        FROM parts WHERE part_ordered ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'part_delivered' as column_name, COUNT(*) as count
        FROM parts WHERE part_delivered ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'description' as column_name, COUNT(*) as count
        FROM parts WHERE description ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'status' as column_name, COUNT(*) as count
        FROM parts WHERE status ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'cd_lta' as column_name, COUNT(*) as count
        FROM parts WHERE cd_lta ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'invoice_number' as column_name, COUNT(*) as count
        FROM parts WHERE invoice_number ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'actual_position' as column_name, COUNT(*) as count
        FROM parts WHERE actual_position ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'operator_name' as column_name, COUNT(*) as count
        FROM parts WHERE operator_name ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'po_customer' as column_name, COUNT(*) as count
        FROM parts WHERE po_customer ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'prim_pso' as column_name, COUNT(*) as count
        FROM parts WHERE prim_pso ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'order_type' as column_name, COUNT(*) as count
        FROM parts WHERE order_type ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'cat_ticket_id' as column_name, COUNT(*) as count
        FROM parts WHERE cat_ticket_id ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'ticket_status' as column_name, COUNT(*) as count
        FROM parts WHERE ticket_status ILIKE '%Jordan Ngoy%'
        UNION ALL
        SELECT 
            'customer_name' as column_name, COUNT(*) as count
        FROM parts WHERE customer_name ILIKE '%Jordan Ngoy%'
    LOOP
        IF rec.count > 0 THEN
            RAISE NOTICE '  Colonne "%" : % occurrences', rec.column_name, rec.count;
        END IF;
    END LOOP;
    
    RAISE NOTICE '=== ANALYSE TERMINÉE ===';
END $$;
