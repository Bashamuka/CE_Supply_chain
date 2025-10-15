import React, { useCallback, useState, useRef } from 'react';
import { Upload, Loader2, X } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useUserStore } from '../store/userStore';

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
    
    for (let i = 0; i < line.length; i++) {
      const char = line[i];
      
      if (char === '"') {
        if (inQuotes && line[i + 1] === '"') {
          current += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if ((char === ',' || char === ';') && !inQuotes) {
        result.push(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    
    result.push(current.trim());
    return result;
  };

  const validateHeaders = (headers: string[]): string[] => {
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
          record[header] = value ? parseFloat(value.replace(/\s/g, '')) || 0 : 0;
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
    </div>
  );
}