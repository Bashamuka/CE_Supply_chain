import React, { useState, useRef, useEffect, useMemo } from 'react';
import { Send, ChevronLeft, ChevronRight, Loader2, Package2, RefreshCw, ArrowUpDown, Download, PieChart, FileSpreadsheet, ArrowLeft, FileX } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useEtaTrackingStore } from '../store/etaTrackingStore';
import { Part } from '../types';
import { supabase } from '../lib/supabase';
import { CSVImporter } from './CSVImporter';
import * as XLSX from 'xlsx';

interface EtaTrackingInterfaceProps {
  onSendMessage: (message: string) => void;
  loading: boolean;
}

const ITEMS_PER_PAGE = 10;

type SortField = 'order_number' | 'supplier_order' | 'part_ordered' | 'part_delivered' | 'cd_lta' | 'eta' | 'date_cf' | 'invoice_number' | 'actual_position' | 'operator_name' | 'po_customer' | 'prim_pso' | 'order_type' | 'cat_ticket_id' | 'ticket_status' | 'ship_by_date' | 'customer_name';
type SortDirection = 'asc' | 'desc';

interface StatusCount {
  status: string;
  count: number;
  color: string;
}

const partsHeaderMap = {
  'order number': 'order_number',
  'order #': 'order_number',
  'order_number': 'order_number',
  'supplier order': 'supplier_order',
  'supplier order #': 'supplier_order',
  'commande fournisseur': 'supplier_order',
  'supplier_order': 'supplier_order',
  'part number': 'part_ordered',
  'part #': 'part_ordered',
  'part ordered': 'part_ordered',
  'numéro de pièce': 'part_ordered',
  'part_number': 'part_ordered',
  'part_ordered': 'part_ordered',
  'part delivered': 'part_delivered',
  'pièce livrée': 'part_delivered',
  'part_delivered': 'part_delivered',
  'description': 'description',
  'desc': 'description',
  'quantity requested': 'quantity_requested',
  'qty requested': 'quantity_requested',
  'quantité demandée': 'quantity_requested',
  'quantity_requested': 'quantity_requested',
  'invoice quantity': 'invoice_quantity',
  'qty invoice': 'invoice_quantity',
  'quantité facturée': 'invoice_quantity',
  'invoice_quantity': 'invoice_quantity',
  'qty received irium': 'qty_received_irium',
  'qty received': 'qty_received_irium',
  'quantité reçue': 'qty_received_irium',
  'qty_received_irium': 'qty_received_irium',
  'status': 'status',
  'statut': 'status',
  'état': 'status',
  'cd lta': 'cd_lta',
  'cd/lta': 'cd_lta',
  'cd_lta': 'cd_lta',
  'invoice number': 'invoice_number',
  'invoice #': 'invoice_number',
  'numéro facture': 'invoice_number',
  'invoice_number': 'invoice_number',
  'actual position': 'actual_position',
  'position': 'actual_position',
  'position actuelle': 'actual_position',
  'actual_position': 'actual_position',
  'operator name': 'operator_name',
  'operator': 'operator_name',
  'nom opérateur': 'operator_name',
  'operator_name': 'operator_name',
  'order type': 'order_type',
  'type d\'ordre': 'order_type',
  'type ordre': 'order_type',
  'order_type': 'order_type',
  'cat ticket id': 'cat_ticket_id',
  'id ticket cat': 'cat_ticket_id',
  'ticket id': 'cat_ticket_id',
  'cat_ticket_id': 'cat_ticket_id',
  'ticket status': 'ticket_status',
  'statut ticket': 'ticket_status',
  'statut du ticket': 'ticket_status',
  'ticket_status': 'ticket_status',
  'ship by date': 'ship_by_date',
  'ship date': 'ship_by_date',
  'date d\'expédition': 'ship_by_date',
  'ship_by_date': 'ship_by_date',
  'customer name': 'customer_name',
  'nom client': 'customer_name',
  'client': 'customer_name',
  'customer_name': 'customer_name',
  'customer po': 'po_customer',
  'po number': 'po_customer',
  'po_customer': 'po_customer',
  'cf date': 'date_cf',
  'date_cf': 'date_cf',
  'datecf': 'date_cf',
  'prim pso': 'prim_pso',
  'primpso': 'prim_pso',
  'prim_pso': 'prim_pso',
  'pso': 'prim_pso',
  'comments': 'comments',
  'comment': 'comments',
  'commentaires': 'comments',
  'remarques': 'comments',
  'eta': 'eta',
  'eta date': 'eta',
  'date_eta': 'eta'
};

export function EtaTrackingInterface({ onSendMessage, loading }: EtaTrackingInterfaceProps) {
  const [message, setMessage] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [searchResults, setSearchResults] = useState<Part[]>([]);
  const [sortField, setSortField] = useState<SortField>('order_number');
  const [sortDirection, setSortDirection] = useState<SortDirection>('asc');
  const [isExporting, setIsExporting] = useState(false);
  const [isExcelUploading, setIsExcelUploading] = useState(false);
  const [includeCompleted, setIncludeCompleted] = useState(true);
  const excelFileInputRef = useRef<HTMLInputElement>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const tableRef = useRef<HTMLDivElement>(null);
  const { messages, addMessage, isLoading, setIsLoading, resetChat, unmatchedTerms, setUnmatchedTerms } = useEtaTrackingStore();

  const totalResults = searchResults.length;
  const totalPages = Math.ceil(totalResults / ITEMS_PER_PAGE);

  const statusColors = {
    'Sourced': '#4CAF50',
    'Shipped': '#2196F3',
    'Griefed': '#F44336',
    'ESD Available': '#9C27B0',
    'ESD Needed': '#FF9800',
    'Future Dated': '#607D8B'
  };

  const statusStats = useMemo(() => {
    if (searchResults.length === 0) return [];

    const statusCounts: { [key: string]: number } = {};
    searchResults.forEach(part => {
      const status = part.status || 'Pending';
      statusCounts[status] = (statusCounts[status] || 0) + 1;
    });

    return Object.entries(statusCounts).map(([status, count]) => ({
      status,
      count,
      percentage: (count / searchResults.length) * 100,
      color: statusColors[status as keyof typeof statusColors] || '#9E9E9E'
    }));
  }, [searchResults]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  // Reset pagination when search results change
  useEffect(() => {
    if (searchResults.length > 0) {
      setCurrentPage(1);
    }
  }, [searchResults]);

  const handleReset = () => {
    resetChat();
    setSearchResults([]);
    setCurrentPage(1);
    setMessage('');
  };

  const handleImportComplete = (rowsImported: number) => {
    addMessage({
      content: `Import successful! ${rowsImported} records processed.`,
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
      
      const exportData = sortedResults.map(part => ({
        'Order Number': part.order_number || '',
        'Order Type': part.order_type || '',
        'Customer PO': part.po_customer || '',
        'Customer Name': part.customer_name || '',
        'Supplier Order': part.supplier_order || '',
        'Ordered Part': part.part_ordered || '',
        'Delivered Part': part.part_delivered || '',
        'Description': part.description || '',
        'Status': part.status || 'Pending',
        'Requested Quantity': part.quantity_requested || 0,
        'Invoiced Quantity': part.invoice_quantity || 0,
        'Received Quantity': part.qty_received_irium || 0,
        'CF Date': part.date_cf || '',
        'CD/LTA': part.cd_lta || '',
        'ETA': part.eta || '',
        'Ship by Date': part.ship_by_date || '',
        'Invoice Number': part.invoice_number || '',
        'Current Position': part.actual_position || '',
        'Operator': part.operator_name || '',
        'CAT Ticket ID': part.cat_ticket_id || '',
        'Ticket Status': part.ticket_status || '',
        'Prim PSO': part.prim_pso || '',
        'Comments': part.comments || ''
      }));

      const wb = XLSX.utils.book_new();
      const ws = XLSX.utils.json_to_sheet(exportData);

      const colWidths = [
        { wch: 15 }, { wch: 15 }, { wch: 15 }, { wch: 20 }, { wch: 20 }, { wch: 15 }, 
        { wch: 15 }, { wch: 30 }, { wch: 15 }, { wch: 10 }, { wch: 10 }, { wch: 10 }, 
        { wch: 12 }, { wch: 10 }, { wch: 12 }, { wch: 12 }, { wch: 15 }, { wch: 20 }, 
        { wch: 15 }, { wch: 15 }, { wch: 15 }, { wch: 15 }, { wch: 30 }
      ];
      ws['!cols'] = colWidths;

      XLSX.utils.book_append_sheet(wb, ws, 'ETA Search Results');

      const date = new Date().toISOString().split('T')[0];
      const fileName = `eta_search_results_${date}.xlsx`;
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
      const fileName = `eta_unmatched_terms_${date}.xlsx`;
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

  const searchParts = async (queries: string | string[], addMessage?: (message: { content: string; role: 'user' | 'assistant' }) => void) => {
    try {
      console.log('Searching with criteria:', queries);
      console.log('Include completed orders:', includeCompleted);

      // Handle single query
      if (!Array.isArray(queries)) {
        let supabaseQuery = supabase.from('parts').select('*')
          .or(`order_number.ilike.%${queries}%,supplier_order.ilike.%${queries}%,part_ordered.ilike.%${queries}%,po_customer.ilike.%${queries}%,status.ilike.%${queries}%,prim_pso.ilike.%${queries}%,customer_name.ilike.%${queries}%`);

        if (!includeCompleted) {
          supabaseQuery = supabaseQuery.not('comments', 'ilike', '%Delivery completed%');
        }

        const { data, error } = await supabaseQuery;
        if (error) {
          console.error('Search error:', error);
          throw error;
        }
        return data || [];
      }
      
      // Handle array of queries with batching
      const BATCH_SIZE = 10; // Process 10 terms at a time to avoid query length limits
      const allResults: Part[] = [];
      const resultIds = new Set<number>(); // Track unique results to avoid duplicates
      
      for (let i = 0; i < queries.length; i += BATCH_SIZE) {
        const batch = queries.slice(i, i + BATCH_SIZE);
        console.log(`Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(queries.length / BATCH_SIZE)} (${batch.length} terms)`);
        
        // Add progress message
        addMessage({
          content: `🔍 Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(queries.length / BATCH_SIZE)} (${batch.length} terms)...`,
          role: 'assistant'
        });
        
        const orConditions = batch.map(query =>
          `order_number.ilike.%${query}%,supplier_order.ilike.%${query}%,part_ordered.ilike.%${query}%,po_customer.ilike.%${query}%,status.ilike.%${query}%,prim_pso.ilike.%${query}%,customer_name.ilike.%${query}%`
        ).join(',');

        let supabaseQuery = supabase.from('parts').select('*').or(orConditions);

        if (!includeCompleted) {
          supabaseQuery = supabaseQuery.not('comments', 'ilike', '%Delivery completed%');
        }

        const { data, error } = await supabaseQuery;
        
        if (error) {
          console.error(`Batch ${Math.floor(i / BATCH_SIZE) + 1} search error:`, error);
          throw error;
        }
        
        // Add unique results to avoid duplicates
        if (data) {
          data.forEach(part => {
            if (!resultIds.has(part.id)) {
              resultIds.add(part.id);
              allResults.push(part);
            }
          });
        }
        
        // Add a small delay between batches to avoid overwhelming the database
        if (i + BATCH_SIZE < queries.length) {
          await new Promise(resolve => setTimeout(resolve, 100));
        }
      }
      
      console.log('Total unique results found:', allResults.length);
      return allResults;
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
          content: "No search terms found in the Excel file. Please ensure the first column contains the data you want to search for.",
          role: 'assistant'
        });
        return;
      }

      addMessage({
        content: `Found ${searchTerms.length} search terms in Excel file. Searching database...`,
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

      const results = await searchParts(uniqueSearchTerms, addMessage);
      
      const unmatchedTerms: string[] = [];
      const matchedTermsSet = new Set<string>();
      
      for (const originalTerm of uniqueSearchTerms) {
        const termLower = originalTerm;
        let foundMatchForThisTerm = false;
        
        for (const part of results) {
          const fieldsToCheck = [
            part.order_number,
            part.supplier_order,
            part.part_ordered,
            part.po_customer,
            part.status,
            part.prim_pso,
            part.customer_name
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
      setUnmatchedTerms(unmatchedTerms);
      
      if (results.length > 0) {
        const message = results.length >= 10000 
          ? `Found more than 10,000 parts matching your Excel search terms. Showing first 10,000 results.`
          : `Found ${results.length} part(s) matching your Excel search terms.`;
        
        addMessage({
          content: message,
          role: 'assistant',
        });
        
        if (matchedTermsSet.size > 0) {
          addMessage({
            content: `✅ ${matchedTermsSet.size} search terms found matches in the database.`,
            role: 'assistant',
          });
        }
      } else {
        addMessage({
          content: "No parts found matching the search terms from your Excel file.",
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

  const getSortedResults = (results: Part[]) => {
    return [...results].sort((a, b) => {
      let comparison = 0;
      if (sortField === 'eta' || sortField === 'date_cf') {
        const dateA = a[sortField] ? new Date(a[sortField]).getTime() : 0;
        const dateB = b[sortField] ? new Date(b[sortField]).getTime() : 0;
        comparison = dateA - dateB;
      } else {
        const valueA = (a[sortField] || '').toString().toLowerCase();
        const valueB = (b[sortField] || '').toString().toLowerCase();
        comparison = valueA.localeCompare(valueB);
      }
      return sortDirection === 'asc' ? comparison : -comparison;
    });
  };

  const getStatusClass = (status: string | null, comments: string | null) => {
    // Priorité à la vérification des commentaires pour "Delivery completed"
    if (comments && comments.toLowerCase().includes('delivery completed')) {
      return 'status-completed';
    }
    
    if (!status) return 'status-pending';
    const statusLower = status.toLowerCase();
    if (statusLower.includes('delay') || statusLower.includes('late')) {
      return 'status-delayed';
    }
    return 'status-pending';
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
        const results = await searchParts(userMessage, addMessage);
        setSearchResults(results);
        
        if (results.length > 0) {
          const message = `Found ${results.length} part(s) matching your search.`;
          addMessage({
            content: message,
            role: 'assistant',
          });
        } else {
          addMessage({
            content: "No parts found matching your search.",
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

  const renderStatusStats = () => {
    if (statusStats.length === 0) return null;

    return (
      <div className="bg-white rounded-xl shadow-lg p-6 mb-6 animate-fadeIn">
        <div className="flex items-center gap-2 mb-4">
          <PieChart className="h-5 w-5 text-gray-700" />
          <h3 className="text-lg font-semibold text-gray-800">
            Order Statistics
          </h3>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {statusStats.map((stat) => (
            <div key={stat.status} className="bg-gray-50 rounded-lg p-4">
              <div className="flex justify-between items-center mb-2">
                <span className="font-medium text-gray-700">{stat.status}</span>
                <span className="text-sm font-bold">{stat.count}</span>
              </div>
              <div className="relative h-2 bg-gray-200 rounded-full overflow-hidden">
                <div
                  className="absolute top-0 left-0 h-full rounded-full transition-all duration-500"
                  style={{
                    width: `${stat.percentage}%`,
                    backgroundColor: stat.color
                  }}
                />
              </div>
              <div className="mt-1 text-right text-sm text-gray-500">
                {stat.percentage.toFixed(1)}%
              </div>
            </div>
          ))}
        </div>
      </div>
    );
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
            Search Results
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
                  <th onClick={() => handleSort('order_number')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Order Number
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('order_type')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Order Type
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('po_customer')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Customer PO
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('customer_name')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Customer Name
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('supplier_order')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Supplier Order
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('part_ordered')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Ordered Part
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('part_delivered')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Delivered Part
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th className="p-3">Description</th>
                  <th className="p-3">Status</th>
                  <th className="p-3">Requested Qty</th>
                  <th className="p-3">Invoiced Qty</th>
                  <th className="p-3">Received Qty</th>
                  <th onClick={() => handleSort('date_cf')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      CF Date
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('cd_lta')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      CD/LTA
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('eta')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      ETA
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('ship_by_date')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Ship by Date
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('invoice_number')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Invoice Number
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('actual_position')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Current Position
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('operator_name')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Operator
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('cat_ticket_id')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      CAT Ticket ID
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('ticket_status')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Ticket Status
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th onClick={() => handleSort('prim_pso')} className="p-3 cursor-pointer hover:bg-[#333333] transition-colors">
                    <div className="flex items-center gap-1 whitespace-nowrap">
                      Prim PSO
                      <ArrowUpDown className="h-4 w-4" />
                    </div>
                  </th>
                  <th className="p-3">Comments</th>
                </tr>
              </thead>
              <tbody>
                {paginatedResults.map((part, index) => (
                  <tr key={index} className="border-b border-gray-200 hover:bg-gray-50">
                    <td className="p-3 font-medium">{part.order_number || '-'}</td>
                    <td className="p-3">{part.order_type || '-'}</td>
                    <td className="p-3">{part.po_customer || '-'}</td>
                    <td className="p-3">{part.customer_name || '-'}</td>
                    <td className="p-3">{part.supplier_order || '-'}</td>
                    <td className="p-3">{part.part_ordered || '-'}</td>
                    <td className="p-3">{part.part_delivered || '-'}</td>
                    <td className="p-3 max-w-[200px] truncate" title={part.description || '-'}>
                      {part.description || '-'}
                    </td>
                    <td className="p-3">
                      <span className={`${getStatusClass(part.status, part.comments)} whitespace-nowrap`}>
                        {part.status || 'Pending'}
                      </span>
                    </td>
                    <td className="p-3 text-center">{part.quantity_requested || '0'}</td>
                    <td className="p-3 text-center">{part.invoice_quantity || '0'}</td>
                    <td className="p-3 text-center">{part.qty_received_irium || '0'}</td>
                    <td className="p-3">{part.date_cf || '-'}</td>
                    <td className="p-3">{part.cd_lta || '-'}</td>
                    <td className="p-3">{part.eta || '-'}</td>
                    <td className="p-3">{part.ship_by_date || '-'}</td>
                    <td className="p-3">{part.invoice_number || '-'}</td>
                    <td className="p-3">{part.actual_position || '-'}</td>
                    <td className="p-3">{part.operator_name || '-'}</td>
                    <td className="p-3">{part.cat_ticket_id || '-'}</td>
                    <td className="p-3">{part.ticket_status || '-'}</td>
                    <td className="p-3">{part.prim_pso || '-'}</td>
                    <td className="p-3 max-w-[200px] truncate" title={part.comments || '-'}>
                      {part.comments || '-'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {totalPages > 1 && (
          <div className="flex flex-col sm:flex-row justify-between items-center gap-4 px-4 py-3 bg-gray-50 border-t border-gray-200">
            <div className="text-sm text-gray-700 text-center sm:text-left">
              Showing {((currentPage - 1) * ITEMS_PER_PAGE) + 1} to {Math.min(currentPage * ITEMS_PER_PAGE, totalResults)} of {totalResults} results
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
                tableName="parts"
                headerMap={partsHeaderMap}
                onImportComplete={handleImportComplete}
                onImportError={handleImportError}
                allowedRoles={['admin']}
              />
            </div>
          </div>
          <div className="mt-4">
            <h1 className="text-2xl sm:text-3xl font-bold text-[#1A1A1A] flex items-center gap-3">
              <Package2 className="h-8 w-8 text-[#FFCD11]" />
              ETA Tracking
            </h1>
            <p className="text-gray-600 mt-2">
              Search for parts by order number, supplier reference, part number, customer PO, status, or Prim PSO
            </p>
          </div>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto pb-[120px] sm:pb-[168px]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">
          {messages.length === 0 && (
            <div className="text-center mt-8 sm:mt-12">
              <div className="bg-white rounded-2xl shadow-xl p-4 sm:p-8 max-w-2xl mx-auto transform transition-all duration-300 hover:shadow-2xl">
                <div className="bg-gradient-to-r from-[#1A1A1A] to-[#333333] p-4 rounded-full w-16 h-16 sm:w-20 sm:h-20 mx-auto mb-4 sm:mb-6 flex items-center justify-center">
                  <Package2 className="h-8 w-8 sm:h-10 sm:w-10 text-[#FFCD11]" />
                </div>
                <h2 className="text-2xl sm:text-3xl font-bold text-[#1A1A1A] mb-4 sm:mb-6">
                  ETA Tracking
                </h2>
                <p className="text-gray-600 text-sm sm:text-base leading-relaxed">
                  Search for parts by order number, supplier reference, part number, customer PO, customer name, status, or Prim PSO. 
                  You can also upload an Excel file with multiple search terms for batch processing.
                </p>
              </div>
            </div>
          )}

          {messages.map((msg) => (
            <div
              key={msg.id}
              className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
            >
              <div
                className={`max-w-[95%] sm:max-w-[85%] md:max-w-[75%] rounded-xl px-4 py-3 sm:px-6 sm:py-4 ${
                  msg.role === 'user'
                    ? 'chat-message-user'
                    : 'chat-message-assistant'
                }`}
              >
                <pre className="whitespace-pre-wrap font-sans text-sm sm:text-base">{msg.content}</pre>
              </div>
            </div>
          ))}

          {searchResults.length > 0 && renderStatusStats()}
          {renderSearchResults()}
          <div ref={messagesEndRef} />
        </div>
      </div>

      {/* Fixed Input Form */}
      <div className="fixed bottom-0 left-0 right-0 z-30 bg-white border-t border-gray-200 p-3 sm:p-6 shadow-lg">
        <div className="max-w-4xl mx-auto">
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
              <label className="flex items-center gap-2 px-3 py-2 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors cursor-pointer" title="Include completed deliveries">
                <input
                  type="checkbox"
                  checked={includeCompleted}
                  onChange={(e) => setIncludeCompleted(e.target.checked)}
                  className="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 focus:ring-2 cursor-pointer"
                />
                <span className="text-sm text-gray-700 whitespace-nowrap hidden sm:inline">Completed</span>
                <span className="text-xs text-gray-700 sm:hidden">✓</span>
              </label>
              <button
                type="button"
                onClick={handleExcelButtonClick}
                disabled={isLoading || isExcelUploading}
                className="flex items-center gap-1 sm:gap-2 p-2 sm:p-3 rounded-lg bg-blue-600 text-white hover:bg-blue-700 transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
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
                  placeholder="Search by order number, supplier order, part reference, customer PO, status, or Prim PSO..."
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
    </div>
  );
}