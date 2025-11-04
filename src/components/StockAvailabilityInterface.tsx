import React, { useState, useRef, useEffect, useMemo } from 'react';
import { Send, ChevronLeft, ChevronRight, Loader2, Warehouse, RefreshCw, ArrowUpDown, Download, FileSpreadsheet, ArrowLeft, FileX } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useStockAvailabilityStore } from '../store/stockAvailabilityStore';
import { StockDispo } from '../types';
import { supabase } from '../lib/supabase';
import { CSVImporter } from './CSVImporter';
import * as XLSX from 'xlsx';

type SortField = 'part_number' | 'description';
type SortDirection = 'asc' | 'desc';

const ITEMS_PER_PAGE = 10;

const stockHeaderMap = {
  'part number': 'part_number',
  'part_number': 'part_number',
  'description': 'description',
  'qté gdc': 'qté_gdc',
  'qte gdc': 'qté_gdc',
  'qty gdc': 'qté_gdc',
  'qté jdc': 'qté_jdc',
  'qte jdc': 'qté_jdc',
  'qty jdc': 'qté_jdc',
  'qté cat network': 'qté_cat_network',
  'qte cat network': 'qté_cat_network',
  'qty cat network': 'qté_cat_network'
};

export function StockAvailabilityInterface() {
  const [message, setMessage] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [searchResults, setSearchResults] = useState<StockDispo[]>([]);
  const [sortField, setSortField] = useState<SortField>('part_number');
  const [sortDirection, setSortDirection] = useState<SortDirection>('asc');
  const [isExporting, setIsExporting] = useState(false);
  const [isExcelUploading, setIsExcelUploading] = useState(false);
  const excelFileInputRef = useRef<HTMLInputElement>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const tableRef = useRef<HTMLDivElement>(null);
  const { messages, addMessage, isLoading, setIsLoading, resetChat, unmatchedTerms, setUnmatchedTerms } = useStockAvailabilityStore();

  const totalResults = searchResults.length;
  const totalPages = Math.ceil(totalResults / ITEMS_PER_PAGE);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleReset = () => {
    resetChat();
    setSearchResults([]);
    setCurrentPage(1);
    setMessage('');
  };

  const handleImportComplete = (rowsImported: number) => {
    addMessage({
      content: `Import successful! ${rowsImported} stock records processed.`,
      role: 'assistant'
    });
  };

  const handleImportError = (error: string) => {
    addMessage({
      content: `Import error: ${error}`,
      role: 'assistant'
    });
  };

  const exportToExcel = async () => {
    try {
      setIsExporting(true);
      
      const sortedResults = getSortedResults(searchResults);
      
      const exportData = sortedResults.map(stock => ({
        'Part Number': stock.part_number || '',
        'Description': stock.description || '',
        'GDC': stock.qté_gdc || 0,
        'JDC': stock.qté_jdc || 0,
        'CAT Network': stock.qté_cat_network || 0,
        'SUCC 10': stock.qté_succ_10 || 0,
        'SUCC 20': stock.qté_succ_20 || 0,
        'SUCC 11': stock.qté_succ_11 || 0,
        'SUCC 12': stock.qté_succ_12 || 0,
        'SUCC 13': stock.qté_succ_13 || 0,
        'SUCC 14': stock.qté_succ_14 || 0,
        'SUCC 19': stock.qté_succ_19 || 0,
        'SUCC 21': stock.qté_succ_21 || 0,
        'SUCC 22': stock.qté_succ_22 || 0,
        'SUCC 24': stock.qté_succ_24 || 0,
        'SUCC 30': stock.qté_succ_30 || 0,
        'SUCC 40': stock.qté_succ_40 || 0,
        'SUCC 50': stock.qté_succ_50 || 0,
        'SUCC 60': stock.qté_succ_60 || 0,
        'SUCC 70': stock.qté_succ_70 || 0,
        'SUCC 80': stock.qté_succ_80 || 0,
        'SUCC 90': stock.qté_succ_90 || 0
      }));

      const wb = XLSX.utils.book_new();
      const ws = XLSX.utils.json_to_sheet(exportData);

      const colWidths = Array(22).fill({ wch: 12 });
      colWidths[0] = { wch: 20 }; // Part Number
      colWidths[1] = { wch: 30 }; // Description
      ws['!cols'] = colWidths;

      XLSX.utils.book_append_sheet(wb, ws, 'Stock Availability');

      const date = new Date().toISOString().split('T')[0];
      const fileName = `stock_availability_${date}.xlsx`;
      XLSX.writeFile(wb, fileName);

      addMessage({
        content: "Excel export generated successfully.",
        role: 'assistant'
      });
    } catch (error) {
      console.error('Error during Excel export:', error);
      addMessage({
        content: "An error occurred during Excel export.",
        role: 'assistant'
      });
    } finally {
      setIsExporting(false);
    }
  };

  const exportUnmatchedToExcel = async () => {
    try {
      if (unmatchedTerms.length === 0) return;
      
      const exportData = unmatchedTerms.map(term => ({
        'Unmatched Search Term': term
      }));

      const wb = XLSX.utils.book_new();
      const ws = XLSX.utils.json_to_sheet(exportData);

      const colWidths = [{ wch: 30 }];
      ws['!cols'] = colWidths;

      XLSX.utils.book_append_sheet(wb, ws, 'Unmatched Terms');

      const date = new Date().toISOString().split('T')[0];
      const fileName = `stock_unmatched_terms_${date}.xlsx`;
      XLSX.writeFile(wb, fileName);

      addMessage({
        content: `Excel file with ${unmatchedTerms.length} unmatched terms downloaded successfully.`,
        role: 'assistant'
      });
    } catch (error) {
      console.error('Error during unmatched terms export:', error);
      addMessage({
        content: "An error occurred during unmatched terms export.",
        role: 'assistant'
      });
    }
  };

  const searchStock = async (queries: string | string[], addMessage?: (message: { content: string; role: 'user' | 'assistant' }) => void) => {
    try {
      console.log('Searching stock with criteria:', queries);
      
      // Handle single query
      if (!Array.isArray(queries)) {
        const supabaseQuery = supabase.from('stock_dispo').select('*')
          .or(`part_number.ilike.%${queries}%,description.ilike.%${queries}%`);
        
        const { data, error } = await supabaseQuery;
        if (error) {
          console.error('Search error:', error);
          throw error;
        }
        return data?.slice(0, 10000) || [];
      }
      
      // Handle array of queries with batching
      const BATCH_SIZE = 10; // Process 10 terms at a time to avoid query length limits
      const allResults: StockDispo[] = [];
      const resultIds = new Set<number>(); // Track unique results to avoid duplicates
      
      for (let i = 0; i < queries.length; i += BATCH_SIZE) {
        const batch = queries.slice(i, i + BATCH_SIZE);
        console.log(`Processing stock batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(queries.length / BATCH_SIZE)} (${batch.length} terms)`);
        
        // Add progress message
        if (addMessage) {
          addMessage({
            content: `🔍 Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(queries.length / BATCH_SIZE)} (${batch.length} terms)...`,
            role: 'assistant'
          });
        }
        
        const orConditions = batch.map(query => 
          `part_number.ilike.%${query}%,description.ilike.%${query}%`
        ).join(',');
        
        const supabaseQuery = supabase.from('stock_dispo').select('*').or(orConditions);
        const { data, error } = await supabaseQuery;
        
        if (error) {
          console.error(`Stock batch ${Math.floor(i / BATCH_SIZE) + 1} search error:`, error);
          throw error;
        }
        
        // Add unique results to avoid duplicates
        if (data) {
          data.forEach(stock => {
            if (!resultIds.has(stock.id)) {
              resultIds.add(stock.id);
              allResults.push(stock);
            }
          });
        }
        
        // Add a small delay between batches to avoid overwhelming the database
        if (i + BATCH_SIZE < queries.length) {
          await new Promise(resolve => setTimeout(resolve, 100));
        }
      }
      
      const filteredData = allResults.slice(0, 10000);
      console.log('Total unique stock results found:', filteredData.length);
      return filteredData;
    } catch (error) {
      console.error('Search error:', error);
      throw error;
    }
  };

  const handleExcelUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    event.target.value = '';

    if (!file.name.toLowerCase().match(/\.(xlsx|xls)$/)) {
      addMessage({
        content: "Please select a valid Excel file (.xlsx or .xls).",
        role: 'assistant'
      });
      return;
    }

    setIsExcelUploading(true);
    setIsLoading(true);
    setCurrentPage(1);

    addMessage({
      content: `Processing Excel file: ${file.name}...`,
      role: 'assistant'
    });

    try {
      const arrayBuffer = await file.arrayBuffer();
      const workbook = XLSX.read(arrayBuffer, { type: 'array' });
      
      const firstSheetName = workbook.SheetNames[0];
      const worksheet = workbook.Sheets[firstSheetName];
      
      const jsonData = XLSX.utils.sheet_to_json(worksheet, { header: 1 });
      
      const searchTerms: string[] = [];
      for (let i = 0; i < jsonData.length; i++) {
        const row = jsonData[i] as any[];
        if (row && row[0] && typeof row[0] === 'string' && row[0].trim()) {
          searchTerms.push(row[0].trim());
        } else if (row && row[0] && typeof row[0] === 'number') {
          searchTerms.push(row[0].toString());
        }
      }

      if (searchTerms.length === 0) {
        addMessage({
          content: "No search terms found in the Excel file. Please ensure the first column contains the part numbers you want to search for.",
          role: 'assistant'
        });
        return;
      }

      addMessage({
        content: `Found ${searchTerms.length} search terms in Excel file. Searching stock database...`,
        role: 'assistant'
      });

      const uniqueSearchTerms = [...new Set(searchTerms.map(term => term.trim().toLowerCase()))];
      
      if (uniqueSearchTerms.length < searchTerms.length) {
        const duplicatesRemoved = searchTerms.length - uniqueSearchTerms.length;
        addMessage({
          content: `🔄 Removed ${duplicatesRemoved} duplicate(s). Using ${uniqueSearchTerms.length} unique search terms for optimization.`,
          role: 'assistant'
        });
      }

      const results = await searchStock(uniqueSearchTerms, addMessage);
      
      const unmatchedTerms: string[] = [];
      const matchedTermsSet = new Set<string>();
      
      for (const originalTerm of uniqueSearchTerms) {
        const termLower = originalTerm;
        let foundMatchForThisTerm = false;
        
        for (const stock of results) {
          const fieldsToCheck = [
            stock.part_number,
            stock.description
          ];
          
          const matchFound = fieldsToCheck.some(field => 
            field && field.toLowerCase().includes(termLower)
          );
          
          if (matchFound) {
            foundMatchForThisTerm = true;
            matchedTermsSet.add(originalTerm);
            break;
          }
        }
        
        if (!foundMatchForThisTerm) {
          unmatchedTerms.push(originalTerm);
        }
      }
      
      setSearchResults(results);
      
      if (results.length > 0) {
        const message = results.length >= 10000 
          ? `Found more than 10,000 stock items matching your Excel search terms. Showing first 10,000 results.`
          : `Found ${results.length} stock item(s) matching your Excel search terms.`;
        
        addMessage({
          content: message,
          role: 'assistant',
        });
        
        if (matchedTermsSet.size > 0) {
          addMessage({
            content: `✅ ${matchedTermsSet.size} search terms found matches in the stock database.`,
            role: 'assistant',
          });
        }
      } else {
        addMessage({
          content: "No stock items found matching the search terms from your Excel file.",
          role: 'assistant',
        });
      }
      
      if (unmatchedTerms.length > 0) {
        const unmatchedMessage = `❌ ${unmatchedTerms.length} search terms did not find any matches:\n\n${unmatchedTerms.map(term => `• ${term}`).join('\n')}`;
        addMessage({
          content: unmatchedMessage,
          role: 'assistant',
        });
      }
    } catch (error) {
      console.error('Excel processing error:', error);
      addMessage({
        content: "An error occurred while processing the Excel file. Please ensure it's a valid Excel file and try again.",
        role: 'assistant',
      });
    } finally {
      setIsExcelUploading(false);
      setIsLoading(false);
    }
  };

  const handleExcelButtonClick = () => {
    if (excelFileInputRef.current) {
      excelFileInputRef.current.click();
    }
  };

  const handleSort = (field: SortField) => {
    if (sortField === field) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('asc');
    }
  };

  const getSortedResults = (results: StockDispo[]) => {
    return [...results].sort((a, b) => {
      const valueA = (a[sortField] || '').toString().toLowerCase();
      const valueB = (b[sortField] || '').toString().toLowerCase();
      const comparison = valueA.localeCompare(valueB);
      return sortDirection === 'asc' ? comparison : -comparison;
    });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (message.trim() && !isLoading) {
      const userMessage = message.trim();
      setMessage('');
      setIsLoading(true);
      setCurrentPage(1);
      
      addMessage({
        content: userMessage,
        role: 'user',
      });

      try {
        const results = await searchStock(userMessage, addMessage);
        setSearchResults(results);
        
        if (results.length > 0) {
          const message = results.length >= 10000 
            ? `Found more than 10,000 stock items matching your search. Showing first 10,000 results.`
            : `Found ${results.length} stock item(s) matching your search.`;
          
          addMessage({
            content: message,
            role: 'assistant',
          });
        } else {
          addMessage({
            content: "No stock items found matching your search.",
            role: 'assistant',
          });
        }
      } catch (error) {
        console.error('Search error:', error);
        addMessage({
          content: "An error occurred during the search. Please try again.",
          role: 'assistant',
        });
      } finally {
        setIsLoading(false);
      }
    }
  };

  const renderSearchResults = () => {
    if (searchResults.length === 0) return null;

    const sortedResults = getSortedResults(searchResults);
    const start = (currentPage - 1) * ITEMS_PER_PAGE;
    const paginatedResults = sortedResults.slice(start, start + ITEMS_PER_PAGE);

    return (
      <div className="bg-white rounded-xl shadow-lg overflow-hidden mt-6 animate-fadeIn">
        <div className="p-4 border-b border-gray-200 flex flex-col sm:flex-row justify-between items-center gap-4">
          <h3 className="text-lg font-semibold text-gray-800">
            Stock Availability Results
          </h3>
          <div className="flex flex-col sm:flex-row gap-2">
            {unmatchedTerms.length > 0 && (
              <button
                onClick={exportUnmatchedToExcel}
                className="w-full sm:w-auto flex items-center justify-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg
                         hover:bg-red-700 transition-colors duration-200"
                title={`Download ${unmatchedTerms.length} unmatched search terms`}
              >
                <FileX className="h-5 w-5" />
                <span>Unmatched ({unmatchedTerms.length})</span>
              </button>
            )}
            <button
              onClick={exportToExcel}
              disabled={isExporting}
              className="w-full sm:w-auto flex items-center justify-center gap-2 px-4 py-2 bg-[#1A1A1A] text-white rounded-lg
                       hover:bg-[#333333] transition-colors duration-200
                       disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isExporting ? (
                <Loader2 className="h-5 w-5 animate-spin" />
              ) : (
                <Download className="h-5 w-5" />
              )}
              <span>Export to Excel</span>
            </button>
          </div>
        </div>
        <div className="relative">
          <div 
            ref={tableRef}
            className="overflow-x-auto scrollbar-thin scrollbar-thumb-gray-400 scrollbar-track-gray-100"
          >
            <table className="w-full min-w-[1200px]">
              <thead className="sticky top-0 z-10 bg-gradient-to-r from-[#1A1A1A] to-[#333333] text-white">
                <tr>
                  <th onClick={() => handleSort('part_number')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Part Number
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('description')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Description
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th className="p-3">GDC</th>
                  <th className="p-3">JDC</th>
                  <th className="p-3">CAT Network</th>
                  <th className="p-3">SUCC 10</th>
                  <th className="p-3">SUCC 20</th>
                  <th className="p-3">SUCC 11</th>
                  <th className="p-3">SUCC 12</th>
                  <th className="p-3">SUCC 13</th>
                  <th className="p-3">SUCC 14</th>
                  <th className="p-3">SUCC 19</th>
                  <th className="p-3">SUCC 21</th>
                  <th className="p-3">SUCC 22</th>
                  <th className="p-3">SUCC 24</th>
                  <th className="p-3">SUCC 30</th>
                  <th className="p-3">SUCC 40</th>
                  <th className="p-3">SUCC 50</th>
                  <th className="p-3">SUCC 60</th>
                  <th className="p-3">SUCC 70</th>
                  <th className="p-3">SUCC 80</th>
                  <th className="p-3">SUCC 90</th>
                </tr>
              </thead>
              <tbody>
                {paginatedResults.map((stock, index) => (
                  <tr key={index} className="border-b border-gray-200 hover:bg-gray-50">
                    <td className="p-3 font-medium">{stock.part_number || '-'}</td>
                    <td className="p-3 max-w-[200px] truncate" title={stock.description || '-'}>
                      {stock.description || '-'}
                    </td>
                    <td className="p-3 text-center">{stock.qté_gdc ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_jdc ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_cat_network ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_10 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_20 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_11 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_12 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_13 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_14 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_19 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_21 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_22 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_24 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_30 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_40 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_50 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_60 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_70 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_80 ?? '-'}</td>
                    <td className="p-3 text-center">{stock.qté_succ_90 ?? '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {totalPages > 1 && (
          <div className="flex flex-col sm:flex-row justify-between items-center gap-4 px-4 py-3 bg-gray-50 border-t border-gray-200">
            <div className="text-sm text-gray-700 text-center sm:text-left">
              Showing {start + 1} to {Math.min(start + ITEMS_PER_PAGE, totalResults)} of {totalResults} results
            </div>
            <div className="flex items-center space-x-2">
              <button
                onClick={() => setCurrentPage(currentPage - 1)}
                disabled={currentPage === 1}
                className="pagination-button"
              >
                <ChevronLeft className="h-5 w-5" />
              </button>
              <span className="text-sm font-medium px-2">
                Page {currentPage} of {totalPages}
              </span>
              <button
                onClick={() => setCurrentPage(currentPage + 1)}
                disabled={currentPage === totalPages}
                className="pagination-button"
              >
                <ChevronRight className="h-5 w-5" />
              </button>
            </div>
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="flex flex-col min-h-screen bg-gradient-to-br from-[#F5F5F5] to-white">
      {/* Header */}
      <div className="sticky top-0 z-20 bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <Link
                to="/"
                className="flex items-center gap-2 text-gray-600 hover:text-[#1A1A1A] transition-colors"
              >
                <ArrowLeft className="h-5 w-5" />
                <span>Back to Dashboard</span>
              </Link>
            </div>
            <div className="flex items-center gap-4">
              <CSVImporter
                tableName="stock_dispo"
                headerMap={stockHeaderMap}
                onImportComplete={handleImportComplete}
                onImportError={handleImportError}
                allowedRoles={['admin']}
              />
            </div>
          </div>
          <div className="mt-4">
            <h1 className="text-2xl sm:text-3xl font-bold text-[#1A1A1A] flex items-center gap-3">
              <Warehouse className="h-8 w-8 text-green-600" />
              Availabilities CE & CAT
            </h1>
            <p className="text-gray-600 mt-2">
              Search for stock availability by part number or description across all locations
            </p>
          </div>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto pb-[120px] sm:pb-[168px]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">
          {messages.length === 0 && (
            <div className="text-center mt-8 sm:mt-12">
              <div className="bg-white rounded-2xl shadow-xl p-4 sm:p-8 max-w-2xl mx-auto transform transition-all duration-300 hover:shadow-2xl">
                <div className="bg-gradient-to-r from-green-500 to-green-600 p-4 rounded-full w-16 h-16 sm:w-20 sm:h-20 mx-auto mb-4 sm:mb-6 flex items-center justify-center">
                  <Warehouse className="h-8 w-8 sm:h-10 sm:w-10 text-white" />
                </div>
                <h2 className="text-xl sm:text-2xl font-bold text-gray-800 mb-3 sm:mb-4">
                  Stock Availability Search
                </h2>
                <p className="text-gray-600 text-sm sm:text-base leading-relaxed">
                  Search for stock availability across all locations. You can search by part number or description, 
                  or upload an Excel file with multiple search terms.
                </p>
              </div>
            </div>
          )}

          {messages.map((message, index) => (
            <div
              key={index}
              className={`flex ${message.role === 'user' ? 'justify-end' : 'justify-start'} animate-fadeIn`}
            >
              <div
                className={`max-w-[85%] sm:max-w-[70%] p-3 sm:p-4 rounded-2xl ${
                  message.role === 'user'
                    ? 'bg-[#1A1A1A] text-white'
                    : 'bg-white shadow-md border border-gray-200'
                }`}
              >
                <div className="text-sm sm:text-base whitespace-pre-wrap break-words">
                  {message.content}
                </div>
              </div>
            </div>
          ))}

          {isLoading && (
            <div className="flex justify-start animate-fadeIn">
              <div className="bg-white shadow-md border border-gray-200 p-3 sm:p-4 rounded-2xl">
                <div className="flex items-center gap-2 text-gray-600">
                  <Loader2 className="h-4 w-4 sm:h-5 sm:w-5 animate-spin" />
                  <span className="text-sm sm:text-base">Searching...</span>
                </div>
              </div>
            </div>
          )}

          {renderSearchResults()}
          <div ref={messagesEndRef} />
        </div>
      </div>

      {/* Fixed Input Form */}
      <div className="fixed bottom-0 left-0 right-0 z-30 bg-white border-t border-gray-200 p-3 sm:p-6 shadow-lg">
        <form onSubmit={handleSubmit} className="max-w-4xl mx-auto">
          <div className="flex items-center gap-2 sm:gap-4">
            <button
              type="button"
              onClick={handleReset}
              className="p-2 sm:p-3 rounded-lg hover:bg-[#F5F5F5] transition-colors duration-200"
              title="Reset conversation"
            >
              <RefreshCw className="h-5 w-5 text-gray-500" />
            </button>
            <button
              type="button"
              onClick={handleExcelButtonClick}
              disabled={isLoading || isExcelUploading}
              className="flex items-center gap-1 sm:gap-2 p-2 sm:p-3 rounded-lg bg-green-600 text-white hover:bg-green-700 transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
              title="Search using Excel file"
            >
              {isExcelUploading ? (
                <Loader2 className="h-4 w-4 sm:h-5 sm:w-5 animate-spin" />
              ) : (
                <FileSpreadsheet className="h-4 w-4 sm:h-5 sm:w-5" />
              )}
              <span className="hidden sm:inline text-sm">Excel</span>
            </button>
            <input
              ref={excelFileInputRef}
              type="file"
              accept=".xlsx,.xls"
              onChange={handleExcelUpload}
              className="hidden"
            />
            <div className="relative flex-1">
              <input
                type="text"
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                placeholder="Search by part number or description..."
                className="cat-input w-full text-sm sm:text-base"
                disabled={isLoading}
              />
            </div>
            <button
              type="submit"
              disabled={isLoading || !message.trim()}
              className="cat-button"
            >
              {isLoading ? (
                <Loader2 className="h-5 w-5 animate-spin" />
              ) : (
                <Send className="h-5 w-5" />
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}