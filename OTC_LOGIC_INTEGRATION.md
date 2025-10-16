# OTC Logic Integration in Project Management

## Overview

This document describes the integration of OTC (Order Tracking & Control) logic into the Project Management module, allowing for two different calculation methods for the "Used" percentage.

## Problem Statement

Previously, the Project Management module only used OR-based (Operational Requests) calculation for determining used quantities. This limited the flexibility of the system and didn't leverage the comprehensive OTC module data.

## Solution

We've implemented a dual-calculation system that allows projects to choose between:

1. **OR-Based Calculation** (existing logic)
2. **OTC-Based Calculation** (new logic)

## Technical Implementation

### Database Changes

#### 1. Projects Table Enhancement
```sql
ALTER TABLE projects 
ADD COLUMN calculation_method text DEFAULT 'or_based' 
CHECK (calculation_method IN ('or_based', 'otc_based'));
```

#### 2. New Materialized Views

**OTC-Based Used Quantities View:**
```sql
CREATE MATERIALIZED VIEW mv_project_parts_used_quantities_otc AS
SELECT 
  pm.project_id,
  pmp.machine_id,
  pmp.part_number,
  COALESCE(
    (SELECT SUM(otc.qte_livree)
     FROM otc_orders otc
     WHERE otc.num_bl IS NOT NULL 
       AND otc.num_bl != ''
       AND otc.reference = pmp.part_number
       AND EXISTS (
         SELECT 1 FROM project_supplier_orders pso
         WHERE pso.project_id = pm.project_id
           AND pso.supplier_order IN (
             SELECT DISTINCT supplier_order 
             FROM parts 
             WHERE part_ordered = pmp.part_number
           )
       )
    ), 0
  ) as quantity_used_otc
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id;
```

**Enhanced Used Quantities View:**
```sql
CREATE MATERIALIZED VIEW mv_project_parts_used_quantities_enhanced AS
SELECT 
  pm.project_id,
  pmp.machine_id,
  pmp.part_number,
  CASE 
    WHEN p.calculation_method = 'or_based' THEN
      COALESCE(used_or.quantity_used, 0)
    WHEN p.calculation_method = 'otc_based' THEN
      -- OTC-based calculation logic
      COALESCE(
        (SELECT SUM(otc.qte_livree)
         FROM otc_orders otc
         WHERE otc.num_bl IS NOT NULL 
           AND otc.num_bl != ''
           AND otc.reference = pmp.part_number
           AND EXISTS (
             SELECT 1 FROM project_supplier_orders pso
             WHERE pso.project_id = pm.project_id
               AND pso.supplier_order IN (
                 SELECT DISTINCT supplier_order 
                 FROM parts 
                 WHERE part_ordered = pmp.part_number
               )
           )
        ), 0
      )
    ELSE COALESCE(used_or.quantity_used, 0)
  END as quantity_used
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
JOIN projects p ON p.id = pm.project_id
LEFT JOIN mv_project_parts_used_quantities used_or 
  ON used_or.machine_id = pmp.machine_id AND used_or.part_number = pmp.part_number;
```

#### 3. Utility Functions

**Switch Calculation Method:**
```sql
CREATE OR REPLACE FUNCTION switch_project_calculation_method(
  project_uuid uuid,
  method text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Validate method
  IF method NOT IN ('or_based', 'otc_based') THEN
    RAISE EXCEPTION 'Invalid calculation method. Must be ''or_based'' or ''otc_based''';
  END IF;
  
  -- Update project calculation method
  UPDATE projects 
  SET calculation_method = method,
      updated_at = NOW()
  WHERE id = project_uuid;
  
  -- Refresh analytics for this project
  PERFORM refresh_project_analytics_views();
  
  RAISE NOTICE 'Project % calculation method switched to %', project_uuid, method;
END;
$$;
```

### Frontend Changes

#### 1. New Component: ProjectCalculationSettings
- **Location:** `src/components/ProjectCalculationSettings.tsx`
- **Purpose:** Provides UI for switching calculation methods
- **Features:**
  - List all projects with current calculation methods
  - Switch between OR-based and OTC-based calculations
  - Refresh analytics views
  - Real-time status updates

#### 2. Dashboard Integration
- **Location:** `src/components/Dashboard.tsx`
- **Addition:** New section for Project Management Settings
- **Access:** Only visible to users with 'projects' module access

#### 3. Routing
- **Route:** `/project-calculation-settings`
- **Protection:** Wrapped in `ProtectedModule` with 'projects' access

## Business Logic

### OR-Based Calculation (Existing)
- **Data Source:** `orders` table
- **Key Field:** `qte_livree` (delivered quantity)
- **Linking:** Through `project_machine_order_numbers` → `orders.num_or`
- **Scope:** Machine-specific calculation
- **Use Case:** Traditional operational request tracking

### OTC-Based Calculation (New)
- **Data Source:** `otc_orders` table
- **Key Field:** `qte_livree` (delivered quantity)
- **Linking:** Through `project_supplier_orders` → `parts.supplier_order` → `otc_orders.reference`
- **Scope:** Project-level cumulative calculation
- **Use Case:** Comprehensive delivery note tracking
- **Advantage:** No duplication across machines in same project

## Usage Instructions

### For Administrators

1. **Access Settings:**
   - Navigate to Dashboard
   - Click "Calculation Settings" in Project Management Settings section
   - Or go directly to `/project-calculation-settings`

2. **Switch Calculation Method:**
   - Select a project from the list
   - Click "Switch to OTC" or "Switch to OR"
   - Wait for confirmation message
   - Analytics will be automatically refreshed

3. **Refresh Analytics:**
   - Click "Refresh Analytics" button
   - Wait for completion confirmation

### For Developers

1. **Database Queries:**
   ```sql
   -- Check project calculation methods
   SELECT * FROM v_project_calculation_methods;
   
   -- Switch calculation method
   SELECT switch_project_calculation_method('project_id', 'otc_based');
   
   -- Refresh analytics
   SELECT refresh_project_analytics_views();
   ```

2. **API Calls:**
   ```typescript
   // Switch calculation method
   const { error } = await supabase.rpc('switch_project_calculation_method', {
     project_uuid: projectId,
     method: 'otc_based'
   });
   
   // Refresh analytics
   const { error } = await supabase.rpc('refresh_project_analytics_views');
   ```

## Migration Steps

1. **Apply Database Migration:**
   ```bash
   # Execute the migration
   psql -d your_database -f supabase/migrations/20251015130000_add_otc_logic_to_project_management.sql
   ```

2. **Test the Integration:**
   ```bash
   # Run test script
   psql -d your_database -f test_otc_logic_integration.sql
   ```

3. **Deploy Frontend Changes:**
   - The new component and routes are already integrated
   - No additional deployment steps required

## Performance Considerations

### Materialized Views
- **Refresh Strategy:** Manual refresh via `refresh_project_analytics_views()`
- **Indexing:** Optimized indexes on all key columns
- **Concurrent Refresh:** Uses `CONCURRENTLY` for non-blocking updates

### Query Optimization
- **Project-Level Aggregation:** OTC calculation aggregates at project level to avoid duplication
- **Efficient Joins:** Optimized join conditions for better performance
- **Selective Updates:** Only affected views are refreshed when switching methods

## Monitoring and Maintenance

### Health Checks
```sql
-- Check view refresh status
SELECT schemaname, matviewname, hasindexes, ispopulated 
FROM pg_matviews 
WHERE matviewname LIKE 'mv_project_%';

-- Monitor calculation method distribution
SELECT calculation_method, COUNT(*) 
FROM projects 
GROUP BY calculation_method;
```

### Troubleshooting
1. **Views Not Updating:**
   - Run `SELECT refresh_project_analytics_views();`
   - Check for errors in PostgreSQL logs

2. **OTC Data Not Found:**
   - Verify `otc_orders` table has data
   - Check `num_bl` field is not NULL/empty
   - Ensure proper linking through `project_supplier_orders`

3. **Performance Issues:**
   - Check materialized view refresh times
   - Monitor query execution plans
   - Consider additional indexing if needed

## Future Enhancements

### Potential Improvements
1. **Automatic Refresh:** Schedule-based refresh of materialized views
2. **Hybrid Calculation:** Combine both methods for comprehensive tracking
3. **Historical Tracking:** Track calculation method changes over time
4. **Performance Metrics:** Add monitoring for calculation performance

### Integration Opportunities
1. **Real-time Updates:** WebSocket-based real-time analytics updates
2. **Advanced Analytics:** Machine learning-based usage predictions
3. **Reporting:** Enhanced reporting with calculation method context

## Conclusion

The OTC logic integration provides a flexible and comprehensive solution for project analytics calculation. By supporting both OR-based and OTC-based methods, the system can adapt to different business requirements while maintaining data integrity and performance.

The implementation follows best practices for database design, frontend architecture, and user experience, ensuring a robust and maintainable solution for the CE-Parts Supply Chain Hub.
