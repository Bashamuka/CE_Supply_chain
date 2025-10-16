-- Script de test pour valider les corrections du mapping CSV
-- Ce script teste le nouveau système de mapping strict - FOCUS UNIQUEMENT SUR LE MAPPING

DO $$
DECLARE
    test_data RECORD;
    mapping_correct BOOLEAN := TRUE;
    issues_found INTEGER := 0;
BEGIN
    RAISE NOTICE '=== TEST DU MAPPING CSV VERS BASE DE DONNÉES ===';
    
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
    
    -- Analyser les données existantes pour détecter les problèmes de mapping
    RAISE NOTICE 'Analyse des données existantes pour détecter les problèmes de mapping...';
    
    DECLARE
        total_rows INTEGER;
        mapping_issues INTEGER := 0;
    BEGIN
        SELECT COUNT(*) INTO total_rows FROM parts;
        RAISE NOTICE 'Total d''enregistrements: %', total_rows;
        
        -- Vérifier les colonnes avec des types de données incorrects
        RAISE NOTICE 'Vérification des types de données...';
        
        -- Vérifier les colonnes numériques
        DECLARE
            invalid_qty_req INTEGER;
            invalid_inv_qty INTEGER;
            invalid_qty_rec INTEGER;
        BEGIN
            -- Vérifier quantity_requested
            SELECT COUNT(*) INTO invalid_qty_req
            FROM parts 
            WHERE quantity_requested IS NOT NULL 
            AND (quantity_requested::text !~ '^[0-9]+\.?[0-9]*$' OR quantity_requested < 0);
            
            -- Vérifier invoice_quantity
            SELECT COUNT(*) INTO invalid_inv_qty
            FROM parts 
            WHERE invoice_quantity IS NOT NULL 
            AND (invoice_quantity::text !~ '^[0-9]+\.?[0-9]*$' OR invoice_quantity < 0);
            
            -- Vérifier qty_received_irium
            SELECT COUNT(*) INTO invalid_qty_rec
            FROM parts 
            WHERE qty_received_irium IS NOT NULL 
            AND (qty_received_irium::text !~ '^[0-9]+\.?[0-9]*$' OR qty_received_irium < 0);
            
            IF invalid_qty_req > 0 THEN
                RAISE NOTICE '❌ Colonne quantity_requested: % valeurs numériques invalides', invalid_qty_req;
                mapping_issues := mapping_issues + invalid_qty_req;
            END IF;
            
            IF invalid_inv_qty > 0 THEN
                RAISE NOTICE '❌ Colonne invoice_quantity: % valeurs numériques invalides', invalid_inv_qty;
                mapping_issues := mapping_issues + invalid_inv_qty;
            END IF;
            
            IF invalid_qty_rec > 0 THEN
                RAISE NOTICE '❌ Colonne qty_received_irium: % valeurs numériques invalides', invalid_qty_rec;
                mapping_issues := mapping_issues + invalid_qty_rec;
            END IF;
        END;
        
        -- Vérifier les colonnes de date
        DECLARE
            invalid_eta INTEGER;
            invalid_date_cf INTEGER;
            invalid_ship_date INTEGER;
        BEGIN
            -- Vérifier eta
            SELECT COUNT(*) INTO invalid_eta
            FROM parts 
            WHERE eta IS NOT NULL AND eta != ''
            AND eta !~ '^\d{2}[\/\-]\d{2}[\/\-]\d{4}$';
            
            -- Vérifier date_cf
            SELECT COUNT(*) INTO invalid_date_cf
            FROM parts 
            WHERE date_cf IS NOT NULL AND date_cf != ''
            AND date_cf !~ '^\d{2}[\/\-]\d{2}[\/\-]\d{4}$';
            
            -- Vérifier ship_by_date
            SELECT COUNT(*) INTO invalid_ship_date
            FROM parts 
            WHERE ship_by_date IS NOT NULL AND ship_by_date != ''
            AND ship_by_date !~ '^\d{2}[\/\-]\d{2}[\/\-]\d{4}$';
            
            IF invalid_eta > 0 THEN
                RAISE NOTICE '❌ Colonne eta: % dates au format incorrect (attendu: DD/MM/YYYY)', invalid_eta;
                mapping_issues := mapping_issues + invalid_eta;
            END IF;
            
            IF invalid_date_cf > 0 THEN
                RAISE NOTICE '❌ Colonne date_cf: % dates au format incorrect (attendu: DD/MM/YYYY)', invalid_date_cf;
                mapping_issues := mapping_issues + invalid_date_cf;
            END IF;
            
            IF invalid_ship_date > 0 THEN
                RAISE NOTICE '❌ Colonne ship_by_date: % dates au format incorrect (attendu: DD/MM/YYYY)', invalid_ship_date;
                mapping_issues := mapping_issues + invalid_ship_date;
            END IF;
        END;
        
        -- Vérifier les colonnes avec des valeurs vides (probablement mal mappées)
        DECLARE
            empty_order_num INTEGER;
            empty_part_ordered INTEGER;
            empty_description INTEGER;
        BEGIN
            SELECT COUNT(*) INTO empty_order_num
            FROM parts 
            WHERE order_number IS NULL OR order_number = '';
            
            SELECT COUNT(*) INTO empty_part_ordered
            FROM parts 
            WHERE part_ordered IS NULL OR part_ordered = '';
            
            SELECT COUNT(*) INTO empty_description
            FROM parts 
            WHERE description IS NULL OR description = '';
            
            IF empty_order_num > total_rows * 0.8 THEN
                RAISE NOTICE '❌ Colonne order_number: %%% valeurs vides (probablement mal mappée)', 
                    ROUND((empty_order_num::float / total_rows) * 100);
                mapping_issues := mapping_issues + empty_order_num;
            END IF;
            
            IF empty_part_ordered > total_rows * 0.8 THEN
                RAISE NOTICE '❌ Colonne part_ordered: %%% valeurs vides (probablement mal mappée)', 
                    ROUND((empty_part_ordered::float / total_rows) * 100);
                mapping_issues := mapping_issues + empty_part_ordered;
            END IF;
            
            IF empty_description > total_rows * 0.8 THEN
                RAISE NOTICE '❌ Colonne description: %%% valeurs vides (probablement mal mappée)', 
                    ROUND((empty_description::float / total_rows) * 100);
                mapping_issues := mapping_issues + empty_description;
            END IF;
        END;
        
        issues_found := mapping_issues;
        
        IF issues_found = 0 THEN
            RAISE NOTICE '✅ Aucun problème de mapping détecté dans les données existantes';
        ELSE
            RAISE NOTICE '❌ % problèmes de mapping détectés dans les données existantes', issues_found;
            mapping_correct := FALSE;
        END IF;
    END;
    
    -- Résumé du test
    RAISE NOTICE '=== RÉSUMÉ DU TEST DE MAPPING ===';
    IF mapping_correct AND issues_found = 0 THEN
        RAISE NOTICE '✅ MAPPING CSV VALIDÉ - Toutes les colonnes sont correctement mappées';
    ELSE
        RAISE NOTICE '❌ MAPPING CSV NON VALIDÉ - Correction nécessaire';
        RAISE NOTICE 'Recommandations:';
        RAISE NOTICE '1. Vider la table parts: DELETE FROM parts;';
        RAISE NOTICE '2. Utiliser le template CSV fourni avec exactement 23 colonnes';
        RAISE NOTICE '3. Réimporter avec le nouveau système de mapping strict';
    END IF;
    
    RAISE NOTICE '=== FIN DU TEST DE MAPPING ===';
    
END $$;
