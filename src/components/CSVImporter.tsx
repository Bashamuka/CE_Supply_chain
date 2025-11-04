import React, { useCallback, useState, useRef } from 'react';
import { Upload, Loader2, X } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useUserStore } from '../store/userStore';
import { ImportReportDisplay } from './ImportReportDisplay';

// Fonction pour valider le format de date français DD/MM/YYYY ou DD-MM-YYYY
const isValidFrenchDate = (dateString: string): boolean => {
  if (!dateString || typeof dateString !== 'string') return false;

  // Vérifier le format avec une regex stricte (accepte / ou -)
  const dateRegex = /^(\d{2})[\/\-](\d{2})[\/\-](\d{4})$/;
  const match = dateString.match(dateRegex);

  if (!match) return false;

  const day = parseInt(match[1], 10);
  const month = parseInt(match[2], 10);
  const year = parseInt(match[3], 10);

  // Vérifier que c'est une date valide
  const date = new Date(year, month - 1, day);
  return date.getFullYear() === year &&
         date.getMonth() === month - 1 &&
         date.getDate() === day;
};

// Fonction pour convertir DD/MM/YYYY ou DD-MM-YYYY vers YYYY-MM-DD
const convertFrenchDateToISO = (dateString: string): string => {
  if (!dateString) return '';

  const dateRegex = /^(\d{2})[\/\-](\d{2})[\/\-](\d{4})$/;
  const match = dateString.match(dateRegex);

  if (!match) return dateString;

  const day = match[1];
  const month = match[2];
  const year = match[3];

  return `${year}-${month}-${day}`;
};

interface ImportProgress {
  totalRows: number;
  processedRows: number;
  currentBatch: number;
  totalBatches: number;
  startTime: number;
  processingSpeed: number;
  estimatedTimeRemaining: number;
}

interface ImportReport {
  totalRowsImported: number;
  analyzedRows: number;
  columnMappingIssues: Array<{
    column: string;
    issue: string;
    count: number;
    examples: string[];
  }>;
  suspiciousValues: Array<{
    value: string;
    columns: string[];
    count: number;
  }>;
}

interface CSVImporterProps {
  tableName: string;
  headerMap: { [key: string]: string };
  onImportComplete?: (rowsImported: number) => void;
  onImportError?: (error: string) => void;
  allowedRoles?: string[];
  className?: string;
}

export function CSVImporter({
  tableName,
  headerMap,
  onImportComplete,
  onImportError,
  allowedRoles = ['admin'],
  className = ''
}: CSVImporterProps) {
  const [isUploading, setIsUploading] = useState(false);
  const [progress, setProgress] = useState<ImportProgress | null>(null);
  const [importReport, setImportReport] = useState<ImportReport | null>(null);
  const abortControllerRef = useRef<AbortController | null>(null);
  const user = useUserStore((state) => state.user);

  const BATCH_SIZE = 1000;
  const CHUNK_SIZE = 1024 * 1024;

  // Déduplique un lot pour stock_dispo par part_number (dernier en entrée gagne)
  const deduplicateStockDispo = (rows: Record<string, any>[]) => {
    const byPartNumber = new Map<string, Record<string, any>>();
    for (const row of rows) {
      const key = (row.part_number ?? '').toString().toUpperCase().trim();
      if (!key) continue;
      byPartNumber.set(key, { ...row, part_number: key });
    }
    return Array.from(byPartNumber.values());
  };

  const formatDuration = (ms: number): string => {
    if (ms < 1000) return `${Math.floor(ms)}ms`;
    const seconds = Math.floor(ms / 1000);
    if (seconds < 60) return `${seconds}s`;
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}m ${remainingSeconds}s`;
  };

  const generateImportReport = async (totalRows: number): Promise<ImportReport> => {
    try {
      // Analyser TOUTES les données importées pour détecter les problèmes de mapping
      console.log('Analyse de toutes les données de la table parts...');
      
      const { data: analysisData, error } = await supabase
        .from('parts')
        .select(`
          order_number, supplier_order, part_ordered, part_delivered, description,
          quantity_requested, invoice_quantity, qty_received_irium, status, cd_lta,
          eta, date_cf, invoice_number, actual_position, operator_name, po_customer,
          comments, prim_pso, order_type, cat_ticket_id, ticket_status, ship_by_date, customer_name
        `);
        // Pas de limite - analyser toutes les lignes

      if (error) {
        console.error('Erreur lors de l\'analyse:', error);
        return {
          totalRowsImported: totalRows,
          analyzedRows: 0,
          columnMappingIssues: [],
          suspiciousValues: []
        };
      }

      const report = {
        totalRowsImported: totalRows,
        analyzedRows: analysisData?.length || 0,
        columnMappingIssues: [] as Array<{
          column: string;
          issue: string;
          count: number;
          examples: string[];
        }>,
        suspiciousValues: [] as Array<{
          value: string;
          columns: string[];
          count: number;
        }>
      };

      console.log(`Analyse de ${report.analyzedRows} lignes...`);

      // Définir les colonnes attendues et leurs types de données typiques
      const expectedColumns = [
        { name: 'order_number', type: 'string', shouldContain: ['numbers', 'letters'] },
        { name: 'supplier_order', type: 'string', shouldContain: ['numbers', 'letters'] },
        { name: 'part_ordered', type: 'string', shouldContain: ['numbers', 'letters', 'dashes'] },
        { name: 'part_delivered', type: 'string', shouldContain: ['numbers', 'letters', 'dashes'] },
        { name: 'description', type: 'string', shouldContain: ['text', 'words'] },
        { name: 'quantity_requested', type: 'number', shouldContain: ['numbers'] },
        { name: 'invoice_quantity', type: 'number', shouldContain: ['numbers'] },
        { name: 'qty_received_irium', type: 'number', shouldContain: ['numbers'] },
        { name: 'status', type: 'string', shouldContain: ['status_words'] },
        { name: 'cd_lta', type: 'string', shouldContain: ['letters', 'numbers'] },
        { name: 'eta', type: 'date', shouldContain: ['dates'] },
        { name: 'date_cf', type: 'date', shouldContain: ['dates'] },
        { name: 'invoice_number', type: 'string', shouldContain: ['numbers', 'letters'] },
        { name: 'actual_position', type: 'string', shouldContain: ['text'] },
        { name: 'operator_name', type: 'string', shouldContain: ['names'] },
        { name: 'po_customer', type: 'string', shouldContain: ['numbers', 'letters'] },
        { name: 'comments', type: 'string', shouldContain: ['text'] },
        { name: 'prim_pso', type: 'string', shouldContain: ['letters', 'numbers'] },
        { name: 'order_type', type: 'string', shouldContain: ['type_words'] },
        { name: 'cat_ticket_id', type: 'string', shouldContain: ['numbers', 'letters'] },
        { name: 'ticket_status', type: 'string', shouldContain: ['status_words'] },
        { name: 'ship_by_date', type: 'date', shouldContain: ['dates'] },
        { name: 'customer_name', type: 'string', shouldContain: ['names', 'text'] }
      ];

      // Analyser chaque colonne pour détecter les problèmes de mapping
      for (const columnDef of expectedColumns) {
        const columnName = columnDef.name;
        let emptyCount = 0;
        let invalidTypeCount = 0;
        const nonEmptyValues: string[] = [];
        const invalidValues: string[] = [];

        for (const row of analysisData || []) {
          const value = row[columnName];
          
          if (!value || (typeof value === 'string' && value.trim() === '')) {
            emptyCount++;
          } else {
            const stringValue = String(value);
            if (nonEmptyValues.length < 10) {
              nonEmptyValues.push(stringValue);
            }
            
            // Vérifier le type de données selon la colonne
            let isValidType = true;
            
            if (columnDef.type === 'number') {
              const numValue = parseFloat(stringValue.replace(/,/g, ''));
              if (isNaN(numValue)) {
                isValidType = false;
                invalidTypeCount++;
                if (invalidValues.length < 5) {
                  invalidValues.push(stringValue);
                }
              }
            } else if (columnDef.type === 'date') {
              // Vérifier si c'est une date valide (format DD/MM/YYYY ou DD-MM-YYYY)
              const dateRegex = /^(\d{2})[\/\-](\d{2})[\/\-](\d{4})$/;
              if (!dateRegex.test(stringValue.trim())) {
                isValidType = false;
                invalidTypeCount++;
                if (invalidValues.length < 5) {
                  invalidValues.push(stringValue);
                }
              }
            }
          }
        }

        const totalRows = analysisData?.length || 0;
        const nonEmptyRows = totalRows - emptyCount;
        
        // Détecter les problèmes de mapping
        if (emptyCount > totalRows * 0.9) { // Plus de 90% de valeurs vides
          report.columnMappingIssues.push({
            column: columnName,
            issue: `Colonne probablement vide ou mal mappée (${emptyCount}/${totalRows} valeurs vides)`,
            count: emptyCount,
            examples: nonEmptyValues.slice(0, 3)
          });
        } else if (invalidTypeCount > nonEmptyRows * 0.5) { // Plus de 50% de valeurs de type incorrect
          report.columnMappingIssues.push({
            column: columnName,
            issue: `Type de données incorrect (${invalidTypeCount}/${nonEmptyRows} valeurs invalides pour ${columnDef.type})`,
            count: invalidTypeCount,
            examples: invalidValues.slice(0, 3)
          });
        }
      }

      // Détecter les décalages de colonnes en analysant les patterns
      // Si une colonne contient des données qui semblent appartenir à une autre colonne
      const columnPatterns = {
        'order_number': /^[A-Z0-9\-]+$/i,
        'supplier_order': /^[A-Z0-9\-]+$/i,
        'part_ordered': /^[A-Z0-9\-\.]+$/i,
        'quantity_requested': /^\d+(\.\d+)?$/,
        'invoice_quantity': /^\d+(\.\d+)?$/,
        'qty_received_irium': /^\d+(\.\d+)?$/,
        'status': /^(Delivered|In Transit|Backorder|Pending|Completed)$/i,
        'eta': /^\d{2}[\/\-]\d{2}[\/\-]\d{4}$/,
        'date_cf': /^\d{2}[\/\-]\d{2}[\/\-]\d{4}$/,
        'ship_by_date': /^\d{2}[\/\-]\d{2}[\/\-]\d{4}$/
      };

      for (const [columnName, pattern] of Object.entries(columnPatterns)) {
        let mismatchCount = 0;
        const mismatchExamples: string[] = [];
        
        for (const row of analysisData || []) {
          const value = row[columnName];
          if (value && typeof value === 'string' && value.trim() !== '') {
            if (!pattern.test(value.trim())) {
              mismatchCount++;
              if (mismatchExamples.length < 3) {
                mismatchExamples.push(value.trim());
              }
            }
          }
        }
        
        const totalNonEmpty = (analysisData || []).filter(row => 
          row[columnName] && typeof row[columnName] === 'string' && row[columnName].trim() !== ''
        ).length;
        
        if (mismatchCount > totalNonEmpty * 0.3) { // Plus de 30% de valeurs ne correspondent pas au pattern
          report.columnMappingIssues.push({
            column: columnName,
            issue: `Format de données incorrect (${mismatchCount}/${totalNonEmpty} valeurs ne correspondent pas au format attendu)`,
            count: mismatchCount,
            examples: mismatchExamples
          });
        }
      }

      // Afficher le rapport dans la console
      console.log('=== RAPPORT D\'IMPORT PARTS ===');
      console.log(`Total lignes importées: ${report.totalRowsImported}`);
      console.log(`Lignes analysées: ${report.analyzedRows}`);
      
      if (report.columnMappingIssues.length > 0) {
        console.log('\n❌ PROBLÈMES DE MAPPING DÉTECTÉS:');
        for (const issue of report.columnMappingIssues) {
          console.log(`  Colonne "${issue.column}": ${issue.issue}`);
          if (issue.examples.length > 0) {
            console.log(`    Exemples: ${issue.examples.join(', ')}`);
          }
        }
      } else {
        console.log('\n✅ IMPORT RÉUSSI - Aucun problème de mapping détecté');
        console.log('Toutes les colonnes sont correctement mappées');
      }

      console.log('=== FIN DU RAPPORT ===');

      return report;
    } catch (error) {
      console.error('Erreur lors de la génération du rapport:', error);
      return {
        totalRowsImported: totalRows,
        analyzedRows: 0,
        columnMappingIssues: [],
        suspiciousValues: []
      };
    }
  };

  const updateProgress = (currentProgress: Partial<ImportProgress>) => {
    setProgress(prev => {
      if (!prev) return null;
      const now = Date.now();
      const elapsedTime = now - prev.startTime;
      const processingSpeed = currentProgress.processedRows 
        ? (currentProgress.processedRows / elapsedTime) * 1000 
        : prev.processingSpeed;
      const remainingRows = prev.totalRows - (currentProgress.processedRows || prev.processedRows);
      const estimatedTimeRemaining = remainingRows / processingSpeed * 1000;

      return {
        ...prev,
        ...currentProgress,
        processingSpeed,
        estimatedTimeRemaining
      };
    });
  };

  const parseCSVLine = (line: string): string[] => {
    const result: string[] = [];
    let current = '';
    let inQuotes = false;
    
    // Détecter le délimiteur principal (virgule ou point-virgule)
    const commaCount = (line.match(/,/g) || []).length;
    const semicolonCount = (line.match(/;/g) || []).length;
    const delimiter = commaCount > semicolonCount ? ',' : ';';
    
    for (let i = 0; i < line.length; i++) {
      const char = line[i];
      
      if (char === '"') {
        if (inQuotes && line[i + 1] === '"') {
          current += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char === delimiter && !inQuotes) {
        result.push(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    
    result.push(current.trim());
    
    // Pour la table parts, s'assurer qu'on a le bon nombre de colonnes
    if (tableName === 'parts' && result.length !== 23) {
      console.warn(`Nombre de colonnes incorrect pour parts: ${result.length} au lieu de 23`);
      // Ajuster le nombre de colonnes si nécessaire
      while (result.length < 23) {
        result.push('');
      }
      if (result.length > 23) {
        result.splice(23);
      }
    }
    
    return result;
  };

  const validateHeaders = (headers: string[]): string[] => {
    const validatedHeaders: string[] = [];
    const missingHeaders: string[] = [];
    const invalidHeaders: string[] = [];
    
    // Pour la table parts, nous devons avoir un mapping strict
    if (tableName === 'parts') {
      // Définir l'ordre attendu des colonnes pour la table parts
      const expectedColumns = [
        'order_number', 'supplier_order', 'part_ordered', 'part_delivered', 'description',
        'quantity_requested', 'invoice_quantity', 'qty_received_irium', 'status', 'cd_lta',
        'eta', 'date_cf', 'invoice_number', 'actual_position', 'operator_name', 'po_customer',
        'comments', 'prim_pso', 'order_type', 'cat_ticket_id', 'ticket_status', 'ship_by_date', 'customer_name'
      ];
      
      // Créer un mapping strict basé sur la position
      for (let i = 0; i < headers.length; i++) {
        const header = headers[i];
        const normalizedHeader = header.toLowerCase().trim();
        const mappedColumn = headerMap[normalizedHeader];
        
        if (mappedColumn) {
          validatedHeaders.push(mappedColumn);
        } else {
          // Si le header n'est pas reconnu, utiliser la position pour mapper
          if (i < expectedColumns.length) {
            validatedHeaders.push(expectedColumns[i]);
            invalidHeaders.push(`"${header}" -> "${expectedColumns[i]}"`);
          } else {
            validatedHeaders.push(`unknown_column_${i}`);
            invalidHeaders.push(`"${header}" -> "unknown_column_${i}"`);
          }
        }
      }
      
      // Vérifier les colonnes manquantes
      const mappedColumns = new Set(validatedHeaders);
      for (const expectedCol of expectedColumns) {
        if (!mappedColumns.has(expectedCol)) {
          missingHeaders.push(expectedCol);
        }
      }
      
      // Afficher les avertissements
      if (invalidHeaders.length > 0) {
        console.warn('Headers non reconnus mappés par position:', invalidHeaders);
      }
      if (missingHeaders.length > 0) {
        console.warn('Colonnes attendues manquantes:', missingHeaders);
      }
      
      return validatedHeaders;
    }
    
    // Pour les autres tables, utiliser l'ancien comportement
    return headers.map(header => {
      const normalizedHeader = header.toLowerCase().trim();
      return headerMap[normalizedHeader] || normalizedHeader;
    });
  };

  const processChunk = async (
    chunk: string,
    headers: string[],
    isFirstChunk: boolean,
    remainingLine: string
  ): Promise<[Record<string, any>[], string]> => {
    let lines = chunk.split('\n');
    
    if (remainingLine) {
      lines[0] = remainingLine + lines[0];
    }
    
    const newRemainingLine = lines.pop() || '';
    const startIndex = isFirstChunk ? 1 : 0;
    const records: Record<string, any>[] = [];
    
    for (let i = startIndex; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;
      
      const values = parseCSVLine(line);
      const record: Record<string, any> = {};
      
      headers.forEach((header, index) => {
        let value = values[index] || '';
        value = value.trim();

        // Validation et conversion pour les champs de date dans la table parts
        if (tableName === 'parts' && (header === 'eta' || header === 'date_cf' || header === 'ship_by_date')) {
          if (value && !isValidFrenchDate(value)) {
            throw new Error(`Invalid date format for ${header}: "${value}". Expected format: DD/MM/YYYY or DD-MM-YYYY (e.g., 13/10/2025 or 13-10-2025)`);
          }
          record[header] = value || null;
        }
        // Validation et conversion pour les champs de date dans la table orders
        else if (tableName === 'orders' && header === 'date_or') {
          if (value && !isValidFrenchDate(value)) {
            throw new Error(`Invalid date format for ${header}: "${value}". Expected format: DD/MM/YYYY or DD-MM-YYYY (e.g., 13/10/2025 or 13-10-2025)`);
          }
          record[header] = value ? convertFrenchDateToISO(value) : null;
        }
        // Handle numeric fields
        else if (header.startsWith('qté_') || header.startsWith('qte_') || header.includes('quantity') || header.includes('qty_')) {
          if (!value || value.trim() === '') {
            record[header] = null;
          } else {
            const parsed = parseFloat(value.replace(/\s/g, ''));
            record[header] = isNaN(parsed) ? null : parsed;
          }
        } else {
          // Normalisation spécifique pour stock_dispo: part_number unique et sans casse/espaces
          if (tableName === 'stock_dispo' && header === 'part_number') {
            record[header] = value ? value.toUpperCase().trim() : value;
          } else {
            record[header] = value;
          }
        }
      });
      
      records.push(record);
    }
    
    return [records, newRemainingLine];
  };

  const processCSVFile = useCallback(async (file: File) => {
    if (!user) {
      onImportError?.('You must be logged in to import files.');
      return;
    }

    try {
      setIsUploading(true);
      abortControllerRef.current = new AbortController();
      const signal = abortControllerRef.current.signal;

      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();

      if (profileError) {
        throw new Error(`Error checking permissions: ${profileError.message}`);
      }

      if (!allowedRoles.includes(profile.role)) {
        throw new Error(`Only ${allowedRoles.join(', ')} users can import files`);
      }

      setProgress({
        totalRows: 0,
        processedRows: 0,
        currentBatch: 0,
        totalBatches: 0,
        startTime: Date.now(),
        processingSpeed: 0,
        estimatedTimeRemaining: 0
      });

      const headerReader = new FileReader();
      const headerChunk = file.slice(0, CHUNK_SIZE);
      
      const headers = await new Promise<string[]>((resolve, reject) => {
        headerReader.onload = () => {
          const text = headerReader.result as string;
          const firstLine = text.split('\n')[0];
          resolve(validateHeaders(parseCSVLine(firstLine)));
        };
        headerReader.onerror = () => reject(headerReader.error);
        headerReader.readAsText(headerChunk);
      });

      const totalRows = await new Promise<number>((resolve) => {
        let count = 0;
        const reader = new FileReader();
        let remainingLine = '';
        
        const processChunkForCounting = (chunk: string) => {
          const lines = (remainingLine + chunk).split('\n');
          remainingLine = lines.pop() || '';
          count += lines.length;
        };
        
        reader.onload = () => {
          processChunkForCounting(reader.result as string);
          resolve(count - 1);
        };
        
        reader.readAsText(file);
      });

      setProgress(prev => ({
        ...prev!,
        totalRows,
        totalBatches: Math.ceil(totalRows / BATCH_SIZE)
      }));

      // Vider la table avant l'import (sauf pour dealer_forward_planning)
      if (tableName !== 'dealer_forward_planning') {
        const { error: deleteError } = await supabase
          .from(tableName)
          .delete()
          .not('id', 'is', null);

        if (deleteError) {
          throw new Error(`Error clearing table: ${deleteError.message}`);
        }
      }

      let offset = 0;
      let remainingLine = '';
      let processedRows = 0;
      let currentBatch: Record<string, any>[] = [];
      let batchNumber = 0;

      while (offset < file.size) {
        if (signal.aborted) {
          throw new Error('Import cancelled');
        }

        const chunk = file.slice(offset, offset + CHUNK_SIZE);
        const chunkText = await new Promise<string>((resolve, reject) => {
          const reader = new FileReader();
          reader.onload = () => resolve(reader.result as string);
          reader.onerror = reject;
          reader.readAsText(chunk);
        });

        const [records, newRemainingLine] = await processChunk(
          chunkText,
          headers,
          offset === 0,
          remainingLine
        );

        remainingLine = newRemainingLine;
        currentBatch.push(...records);
        processedRows += records.length;

        while (currentBatch.length >= BATCH_SIZE) {
          const batch = currentBatch.splice(0, BATCH_SIZE);
          batchNumber++;

          const payload = tableName === 'stock_dispo' ? deduplicateStockDispo(batch) : batch;
          const { error: insertError } = await supabase
            .from(tableName)
            .upsert(payload, {
              onConflict: tableName === 'stock_dispo' ? 'part_number' : undefined,
              ignoreDuplicates: tableName !== 'stock_dispo'
            });

          if (insertError) {
            console.error('Insert error:', insertError);
            throw new Error(
              `Error inserting batch ${batchNumber}: ${insertError.message}`
            );
          }

          updateProgress({
            processedRows,
            currentBatch: batchNumber
          });
        }

        offset += CHUNK_SIZE;
      }

      if (currentBatch.length > 0) {
        const payload = tableName === 'stock_dispo' ? deduplicateStockDispo(currentBatch) : currentBatch;
        const { error: insertError } = await supabase
          .from(tableName)
          .upsert(payload, {
            onConflict: tableName === 'stock_dispo' ? 'part_number' : undefined,
            ignoreDuplicates: tableName !== 'stock_dispo'
          });

        if (insertError) {
          console.error('Final insert error:', insertError);
          throw new Error(
            `Error inserting final batch: ${insertError.message}`
          );
        }
      }

      // Pour la table parts, générer un rapport de validation
      if (tableName === 'parts') {
        const report = await generateImportReport(processedRows);
        setImportReport(report);
      }
      
      onImportComplete?.(processedRows);
    } catch (error) {
      console.error('Detailed error:', error);
      if (error instanceof Error) {
        if (error.message === 'Import cancelled') {
          onImportError?.('Import was cancelled');
        } else {
          onImportError?.(error.message);
        }
      } else {
        onImportError?.('An unexpected error occurred during import');
      }
    } finally {
      setIsUploading(false);
      setProgress(null);
      abortControllerRef.current = null;
    }
  }, [user, tableName, headerMap, onImportComplete, onImportError, allowedRoles]);

  const handleFileChange = useCallback((event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      if (!file.name.toLowerCase().endsWith('.csv')) {
        onImportError?.('Please select a valid CSV file');
        return;
      }
      processCSVFile(file);
    }
  }, [processCSVFile]);

  const handleCancel = useCallback(() => {
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
  }, []);

  if (!user || !allowedRoles.includes(user.role)) {
    return null;
  }

  return (
    <div className={`flex flex-col gap-4 ${className}`}>
      <label className="flex items-center gap-2 px-4 py-2 bg-[#FFCD11] text-black rounded-lg cursor-pointer hover:bg-[#FFD84D] transition-colors duration-200">
        {isUploading ? (
          <>
            <Loader2 className="h-5 w-5 animate-spin" />
            <span className="font-medium">Import in progress...</span>
          </>
        ) : (
          <>
            <Upload className="h-5 w-5" />
            <span className="font-medium">Import CSV file</span>
          </>
        )}
        <input
          type="file"
          className="hidden"
          accept=".csv"
          onChange={handleFileChange}
          disabled={isUploading}
        />
      </label>

      {progress && (
        <div className="bg-white rounded-lg shadow-md p-4">
          <div className="flex justify-between items-center mb-2">
            <h3 className="font-medium">Import Progress</h3>
            <button
              onClick={handleCancel}
              className="p-1 hover:bg-gray-100 rounded-full transition-colors"
              title="Cancel import"
            >
              <X className="h-5 w-5 text-gray-500" />
            </button>
          </div>
          
          <div className="space-y-2">
            <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
              <div
                className="h-full bg-[#FFCD11] transition-all duration-300"
                style={{ width: `${(progress.processedRows / progress.totalRows) * 100}%` }}
              />
            </div>
            
            <div className="flex justify-between text-sm text-gray-600">
              <span>{progress.processedRows.toLocaleString()} / {progress.totalRows.toLocaleString()} rows</span>
              <span>{Math.round((progress.processedRows / progress.totalRows) * 100)}%</span>
            </div>
            
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <span className="text-gray-500">Speed:</span>
                <span className="ml-2">{Math.round(progress.processingSpeed)} rows/s</span>
              </div>
              <div>
                <span className="text-gray-500">Time remaining:</span>
                <span className="ml-2">{formatDuration(progress.estimatedTimeRemaining)}</span>
              </div>
              <div>
                <span className="text-gray-500">Current batch:</span>
                <span className="ml-2">{progress.currentBatch} / {progress.totalBatches}</span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Affichage du rapport d'import pour la table parts */}
      {importReport && (
        <ImportReportDisplay
          report={importReport}
          onClose={() => setImportReport(null)}
        />
      )}
    </div>
  );
}