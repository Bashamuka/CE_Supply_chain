import React, { useState, useRef, useEffect, useMemo } from 'react';
import { Send, ChevronLeft, ChevronRight, Loader2, Package, RefreshCw, ArrowUpDown, Download, FileSpreadsheet, ArrowLeft, FileX, Plus, CreditCard as Edit2, Trash2, Save, X } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useOrdersStore } from '../store/ordersStore';
import { Order } from '../types';
import { supabase } from '../lib/supabase';
import { CSVImporter } from './CSVImporter';
import * as XLSX from 'xlsx';

type SortField = 'constructeur' | 'date_or' | 'num_or' | 'part_number' | 'qte_commandee' | 'qte_livree';
type SortDirection = 'asc' | 'desc';

const ITEMS_PER_PAGE = 10;

// Fonction pour formater la date au format DD-MM-YYYY
const formatDateToDDMMYYYY = (dateString: string): string => {
  if (!dateString) return '';
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return dateString;

  const day = String(date.getDate()).padStart(2, '0');
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const year = date.getFullYear();

  return `${day}-${month}-${year}`;
};

// Fonction pour convertir DD-MM-YYYY vers YYYY-MM-DD pour la base de données
const formatDateToYYYYMMDD = (dateString: string): string => {
  if (!dateString) return '';

  const dateRegex = /^(\d{2})-(\d{2})-(\d{4})$/;
  const match = dateString.match(dateRegex);

  if (!match) return dateString;

  const day = match[1];
  const month = match[2];
  const year = match[3];

  return `${year}-${month}-${day}`;
};

const ordersHeaderMap = {
  'constructeur': 'constructeur',
  'constructor': 'constructeur',
  'manufacturer': 'constructeur',
  'fabricant': 'constructeur',
  'date or': 'date_or',
  'date_or': 'date_or',
  'order date': 'date_or',
  'date commande': 'date_or',
  'num or': 'num_or',
  'num_or': 'num_or',
  'order number': 'num_or',
  'numero commande': 'num_or',
  'part number': 'part_number',
  'part_number': 'part_number',
  'reference': 'part_number',
  'qte commandee': 'qte_commandee',
  'qté commandée': 'qte_commandee',
  'qte_commandee': 'qte_commandee',
  'quantity ordered': 'qte_commandee',
  'qte livree': 'qte_livree',
  'qté livrée': 'qte_livree',
  'qte_livree': 'qte_livree',
  'quantity delivered': 'qte_livree'
};

export function OrdersInterface() {
  const [message, setMessage] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [searchResults, setSearchResults] = useState<Order[]>([]);
  const [sortField, setSortField] = useState<SortField>('date_or');
  const [sortDirection, setSortDirection] = useState<SortDirection>('desc');
  const [isExporting, setIsExporting] = useState(false);
  const [isExcelUploading, setIsExcelUploading] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editForm, setEditForm] = useState<Partial<Order>>({});
  const [showAddForm, setShowAddForm] = useState(false);
  const [newOrder, setNewOrder] = useState<Omit<Order, 'id' | 'created_at' | 'updated_at'>>({
    constructeur: '',
    date_or: '',
    num_or: '',
    part_number: '',
    qte_commandee: 0,
    qte_livree: 0
  });
  const excelFileInputRef = useRef<HTMLInputElement>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const tableRef = useRef<HTMLDivElement>(null);
  const { messages, addMessage, isLoading, setIsLoading, resetChat, unmatchedTerms, setUnmatchedTerms } = useOrdersStore();

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
    setEditingId(null);
    setShowAddForm(false);
  };

  const handleImportComplete = (rowsImported: number) => {
    addMessage({
      content: `Import successful! ${rowsImported} order records processed.`,
      role: 'assistant'
    });
    loadAllOrders();
  };

  const handleImportError = (error: string) => {
    addMessage({
      content: `Import error: ${error}`,
      role: 'assistant'
    });
  };

  const loadAllOrders = async () => {
    try {
      const { data, error } = await supabase
        .from('orders')
        .select('*')
        .order('date_or', { ascending: false });

      if (error) throw error;
      setSearchResults(data || []);
    } catch (error) {
      console.error('Error loading orders:', error);
    }
  };

  useEffect(() => {
    loadAllOrders();
  }, []);

  const exportToExcel = async () => {
    try {
      setIsExporting(true);

      const sortedResults = getSortedResults(searchResults);

      const exportData = sortedResults.map(order => ({
        'Constructeur': order.constructeur || '',
        'Date Commande': formatDateToDDMMYYYY(order.date_or) || '',
        'Num Commande': order.num_or || '',
        'Part Number': order.part_number || '',
        'Qté Commandée': order.qte_commandee || 0,
        'Qté Livrée': order.qte_livree || 0,
        'Solde': (order.qte_commandee || 0) - (order.qte_livree || 0)
      }));

      const wb = XLSX.utils.book_new();
      const ws = XLSX.utils.json_to_sheet(exportData);

      const colWidths = [
        { wch: 20 },
        { wch: 15 },
        { wch: 20 },
        { wch: 20 },
        { wch: 15 },
        { wch: 15 },
        { wch: 15 }
      ];
      ws['!cols'] = colWidths;

      XLSX.utils.book_append_sheet(wb, ws, 'Orders');

      const date = new Date().toISOString().split('T')[0];
      const fileName = `orders_${date}.xlsx`;
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
      const fileName = `unmatched_orders_${date}.xlsx`;
      XLSX.writeFile(wb, fileName);

      addMessage({
        content: "Unmatched terms exported successfully.",
        role: 'assistant'
      });
    } catch (error) {
      console.error('Error exporting unmatched terms:', error);
      addMessage({
        content: "An error occurred during unmatched terms export.",
        role: 'assistant'
      });
    }
  };

  const handleExcelButtonClick = () => {
    excelFileInputRef.current?.click();
  };

  const handleExcelUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    setIsExcelUploading(true);
    setIsLoading(true);
    setCurrentPage(1);

    addMessage({
      content: `Processing Excel file: ${file.name}...`,
      role: 'user'
    });

    try {
      const data = await file.arrayBuffer();
      const workbook = XLSX.read(data, { type: 'array' });
      const firstSheet = workbook.Sheets[workbook.SheetNames[0]];
      const jsonData: any[] = XLSX.utils.sheet_to_json(firstSheet, { defval: '' });

      if (jsonData.length === 0) {
        throw new Error('No data found in Excel file');
      }

      const searchTerms = new Set<string>();
      jsonData.forEach(row => {
        Object.entries(row).forEach(([key, value]) => {
          const mappedKey = ordersHeaderMap[key.toLowerCase().trim()];
          if (mappedKey && value && String(value).trim()) {
            searchTerms.add(String(value).trim());
          }
        });
      });

      const uniqueSearchTerms = Array.from(searchTerms);

      addMessage({
        content: `Found ${uniqueSearchTerms.length} unique search terms. Starting search...`,
        role: 'assistant'
      });

      const results = await searchOrders(uniqueSearchTerms, addMessage);

      const unmatchedTerms: string[] = [];
      for (const originalTerm of uniqueSearchTerms) {
        const term = originalTerm.toLowerCase();
        let foundMatchForThisTerm = false;

        for (const order of results) {
          if (
            order.constructeur?.toLowerCase().includes(term) ||
            order.num_or?.toLowerCase().includes(term) ||
            order.part_number?.toLowerCase().includes(term)
          ) {
            foundMatchForThisTerm = true;
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
          ? `Found more than 10,000 orders matching your Excel search terms. Showing first 10,000 results.`
          : `Found ${results.length} order(s) matching your Excel search terms.`;

        addMessage({
          content: message,
          role: 'assistant'
        });

        if (unmatchedTerms.length > 0) {
          addMessage({
            content: `⚠️ ${unmatchedTerms.length} search term(s) did not match any orders. Click the "Export Unmatched" button to see which terms were not found.`,
            role: 'assistant'
          });
        }
      } else {
        addMessage({
          content: "No orders found matching your Excel search terms.",
          role: 'assistant'
        });
      }
    } catch (error) {
      console.error('Excel upload error:', error);
      addMessage({
        content: `Error processing Excel file: ${error instanceof Error ? error.message : 'Unknown error'}`,
        role: 'assistant'
      });
    } finally {
      setIsExcelUploading(false);
      setIsLoading(false);
      if (excelFileInputRef.current) {
        excelFileInputRef.current.value = '';
      }
    }
  };

  const searchOrders = async (queries: string | string[], addMessage?: (message: { content: string; role: 'user' | 'assistant' }) => void) => {
    try {
      console.log('Searching with criteria:', queries);

      if (!Array.isArray(queries)) {
        const supabaseQuery = supabase.from('orders').select('*')
          .or(`constructeur.ilike.%${queries}%,num_or.ilike.%${queries}%,part_number.ilike.%${queries}%`);

        const { data, error } = await supabaseQuery;
        if (error) {
          console.error('Search error:', error);
          throw error;
        }
        return data || [];
      }

      const BATCH_SIZE = 10;
      const allResults: Order[] = [];
      const seenIds = new Set<string>();

      for (let i = 0; i < queries.length; i += BATCH_SIZE) {
        const batch = queries.slice(i, i + BATCH_SIZE);

        if (addMessage) {
          addMessage({
            content: `Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(queries.length / BATCH_SIZE)} (${batch.length} terms)...`,
            role: 'assistant'
          });
        }

        const orConditions = batch.map(query =>
          `constructeur.ilike.%${query}%,num_or.ilike.%${query}%,part_number.ilike.%${query}%`
        ).join(',');

        const supabaseQuery = supabase.from('orders').select('*').or(orConditions);
        const { data, error } = await supabaseQuery;

        if (error) {
          console.error(`Batch ${Math.floor(i / BATCH_SIZE) + 1} search error:`, error);
          throw error;
        }

        if (data) {
          data.forEach(order => {
            if (!seenIds.has(order.id)) {
              seenIds.add(order.id);
              allResults.push(order);
            }
          });
        }

        await new Promise(resolve => setTimeout(resolve, 100));
      }

      return allResults.slice(0, 10000);
    } catch (error) {
      console.error('Error searching orders:', error);
      throw error;
    }
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
        const results = await searchOrders(userMessage, addMessage);
        setSearchResults(results);

        if (results.length > 0) {
          const message = `Found ${results.length} order(s) matching your search.`;
          addMessage({
            content: message,
            role: 'assistant',
          });
        } else {
          addMessage({
            content: "No orders found matching your search.",
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

  const handleAddOrder = async () => {
    if (!newOrder.constructeur || !newOrder.date_or || !newOrder.num_or || !newOrder.part_number) {
      addMessage({
        content: "Please fill in all required fields (Constructeur, Date, Num Order, Part Number).",
        role: 'assistant'
      });
      return;
    }

    try {
      setIsLoading(true);
      const orderToInsert = {
        ...newOrder,
        date_or: formatDateToYYYYMMDD(newOrder.date_or)
      };
      const { data, error } = await supabase
        .from('orders')
        .insert([orderToInsert])
        .select();

      if (error) throw error;

      addMessage({
        content: "Order added successfully.",
        role: 'assistant'
      });

      setNewOrder({
        constructeur: '',
        date_or: '',
        num_or: '',
        part_number: '',
        qte_commandee: 0,
        qte_livree: 0
      });
      setShowAddForm(false);
      loadAllOrders();
    } catch (error) {
      console.error('Error adding order:', error);
      addMessage({
        content: "Error adding order. Please try again.",
        role: 'assistant'
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleEdit = (order: Order) => {
    setEditingId(order.id);
    setEditForm({
      ...order,
      date_or: formatDateToDDMMYYYY(order.date_or)
    });
  };

  const handleCancelEdit = () => {
    setEditingId(null);
    setEditForm({});
  };

  const handleSaveEdit = async () => {
    if (!editingId) return;

    try {
      setIsLoading(true);
      const updateData = {
        ...editForm,
        date_or: editForm.date_or ? formatDateToYYYYMMDD(editForm.date_or) : editForm.date_or
      };
      const { error } = await supabase
        .from('orders')
        .update(updateData)
        .eq('id', editingId);

      if (error) throw error;

      addMessage({
        content: "Order updated successfully.",
        role: 'assistant'
      });

      setEditingId(null);
      setEditForm({});
      loadAllOrders();
    } catch (error) {
      console.error('Error updating order:', error);
      addMessage({
        content: "Error updating order. Please try again.",
        role: 'assistant'
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this order?')) return;

    try {
      setIsLoading(true);
      const { error } = await supabase
        .from('orders')
        .delete()
        .eq('id', id);

      if (error) throw error;

      addMessage({
        content: "Order deleted successfully.",
        role: 'assistant'
      });

      loadAllOrders();
    } catch (error) {
      console.error('Error deleting order:', error);
      addMessage({
        content: "Error deleting order. Please try again.",
        role: 'assistant'
      });
    } finally {
      setIsLoading(false);
    }
  };

  const getSortedResults = (results: Order[]) => {
    return [...results].sort((a, b) => {
      let aValue = a[sortField];
      let bValue = b[sortField];

      if (typeof aValue === 'string') aValue = aValue.toLowerCase();
      if (typeof bValue === 'string') bValue = bValue.toLowerCase();

      if (aValue < bValue) return sortDirection === 'asc' ? -1 : 1;
      if (aValue > bValue) return sortDirection === 'asc' ? 1 : -1;
      return 0;
    });
  };

  const sortedResults = useMemo(() => getSortedResults(searchResults), [searchResults, sortField, sortDirection]);
  const paginatedResults = sortedResults.slice((currentPage - 1) * ITEMS_PER_PAGE, currentPage * ITEMS_PER_PAGE);

  const handleSort = (field: SortField) => {
    if (sortField === field) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('asc');
    }
  };

  const renderSearchResults = () => {
    if (searchResults.length === 0) return null;

    return (
      <div ref={tableRef} className="bg-white rounded-xl shadow-lg overflow-hidden mb-6 animate-fadeIn">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gradient-to-r from-blue-600 to-blue-700 text-white sticky top-0 z-10">
              <tr>
                <th className="px-3 py-3 text-left font-semibold cursor-pointer hover:bg-blue-800 transition-colors" onClick={() => handleSort('constructeur')}>
                  <div className="flex items-center gap-1">
                    Constructeur
                    <ArrowUpDown className="h-3 w-3" />
                  </div>
                </th>
                <th className="px-3 py-3 text-left font-semibold cursor-pointer hover:bg-blue-800 transition-colors" onClick={() => handleSort('date_or')}>
                  <div className="flex items-center gap-1">
                    Date
                    <ArrowUpDown className="h-3 w-3" />
                  </div>
                </th>
                <th className="px-3 py-3 text-left font-semibold cursor-pointer hover:bg-blue-800 transition-colors" onClick={() => handleSort('num_or')}>
                  <div className="flex items-center gap-1">
                    Num Commande
                    <ArrowUpDown className="h-3 w-3" />
                  </div>
                </th>
                <th className="px-3 py-3 text-left font-semibold cursor-pointer hover:bg-blue-800 transition-colors" onClick={() => handleSort('part_number')}>
                  <div className="flex items-center gap-1">
                    Part Number
                    <ArrowUpDown className="h-3 w-3" />
                  </div>
                </th>
                <th className="px-3 py-3 text-right font-semibold cursor-pointer hover:bg-blue-800 transition-colors" onClick={() => handleSort('qte_commandee')}>
                  <div className="flex items-center justify-end gap-1">
                    Qté Cmd
                    <ArrowUpDown className="h-3 w-3" />
                  </div>
                </th>
                <th className="px-3 py-3 text-right font-semibold cursor-pointer hover:bg-blue-800 transition-colors" onClick={() => handleSort('qte_livree')}>
                  <div className="flex items-center justify-end gap-1">
                    Qté Livrée
                    <ArrowUpDown className="h-3 w-3" />
                  </div>
                </th>
                <th className="px-3 py-3 text-right font-semibold">
                  Solde
                </th>
                <th className="px-3 py-3 text-center font-semibold">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {paginatedResults.map((order) => (
                <tr key={order.id} className="hover:bg-gray-50 transition-colors">
                  {editingId === order.id ? (
                    <>
                      <td className="px-3 py-2">
                        <input
                          type="text"
                          value={editForm.constructeur || ''}
                          onChange={(e) => setEditForm({ ...editForm, constructeur: e.target.value })}
                          className="w-full px-2 py-1 border rounded text-sm"
                        />
                      </td>
                      <td className="px-3 py-2">
                        <input
                          type="text"
                          placeholder="DD-MM-YYYY"
                          value={editForm.date_or || ''}
                          onChange={(e) => setEditForm({ ...editForm, date_or: e.target.value })}
                          className="w-full px-2 py-1 border rounded text-sm"
                        />
                      </td>
                      <td className="px-3 py-2">
                        <input
                          type="text"
                          value={editForm.num_or || ''}
                          onChange={(e) => setEditForm({ ...editForm, num_or: e.target.value })}
                          className="w-full px-2 py-1 border rounded text-sm"
                        />
                      </td>
                      <td className="px-3 py-2">
                        <input
                          type="text"
                          value={editForm.part_number || ''}
                          onChange={(e) => setEditForm({ ...editForm, part_number: e.target.value })}
                          className="w-full px-2 py-1 border rounded text-sm"
                        />
                      </td>
                      <td className="px-3 py-2">
                        <input
                          type="number"
                          step="0.01"
                          value={editForm.qte_commandee || 0}
                          onChange={(e) => setEditForm({ ...editForm, qte_commandee: parseFloat(e.target.value) })}
                          className="w-full px-2 py-1 border rounded text-sm text-right"
                        />
                      </td>
                      <td className="px-3 py-2">
                        <input
                          type="number"
                          step="0.01"
                          value={editForm.qte_livree || 0}
                          onChange={(e) => setEditForm({ ...editForm, qte_livree: parseFloat(e.target.value) })}
                          className="w-full px-2 py-1 border rounded text-sm text-right"
                        />
                      </td>
                      <td className="px-3 py-2 text-right font-medium">
                        {((editForm.qte_commandee || 0) - (editForm.qte_livree || 0)).toFixed(2)}
                      </td>
                      <td className="px-3 py-2">
                        <div className="flex items-center justify-center gap-2">
                          <button
                            onClick={handleSaveEdit}
                            className="p-1 text-green-600 hover:bg-green-100 rounded transition-colors"
                            title="Save"
                          >
                            <Save className="h-4 w-4" />
                          </button>
                          <button
                            onClick={handleCancelEdit}
                            className="p-1 text-gray-600 hover:bg-gray-100 rounded transition-colors"
                            title="Cancel"
                          >
                            <X className="h-4 w-4" />
                          </button>
                        </div>
                      </td>
                    </>
                  ) : (
                    <>
                      <td className="px-3 py-2">{order.constructeur}</td>
                      <td className="px-3 py-2">{formatDateToDDMMYYYY(order.date_or)}</td>
                      <td className="px-3 py-2 font-medium">{order.num_or}</td>
                      <td className="px-3 py-2">{order.part_number}</td>
                      <td className="px-3 py-2 text-right">{order.qte_commandee.toFixed(2)}</td>
                      <td className="px-3 py-2 text-right">{order.qte_livree.toFixed(2)}</td>
                      <td className="px-3 py-2 text-right font-medium">
                        <span className={order.qte_commandee - order.qte_livree > 0 ? 'text-orange-600' : 'text-green-600'}>
                          {(order.qte_commandee - order.qte_livree).toFixed(2)}
                        </span>
                      </td>
                      <td className="px-3 py-2">
                        <div className="flex items-center justify-center gap-2">
                          <button
                            onClick={() => handleEdit(order)}
                            className="p-1 text-blue-600 hover:bg-blue-100 rounded transition-colors"
                            title="Edit"
                          >
                            <Edit2 className="h-4 w-4" />
                          </button>
                          <button
                            onClick={() => handleDelete(order.id)}
                            className="p-1 text-red-600 hover:bg-red-100 rounded transition-colors"
                            title="Delete"
                          >
                            <Trash2 className="h-4 w-4" />
                          </button>
                        </div>
                      </td>
                    </>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {totalPages > 1 && (
          <div className="flex items-center justify-between px-6 py-4 border-t border-gray-200 bg-gray-50">
            <div className="text-sm text-gray-600">
              Showing {((currentPage - 1) * ITEMS_PER_PAGE) + 1} to {Math.min(currentPage * ITEMS_PER_PAGE, totalResults)} of {totalResults} orders
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                disabled={currentPage === 1}
                className="p-2 rounded-lg hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                <ChevronLeft className="h-5 w-5" />
              </button>
              <span className="text-sm font-medium">
                Page {currentPage} of {totalPages}
              </span>
              <button
                onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                disabled={currentPage === totalPages}
                className="p-2 rounded-lg hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
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
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <Link to="/dashboard" className="inline-flex items-center gap-2 text-blue-600 hover:text-blue-700 transition-colors mb-4">
            <ArrowLeft className="h-4 w-4" />
            <span className="text-sm font-medium">Back to Dashboard</span>
          </Link>
          <div className="flex items-center gap-4">
            <div className="bg-gradient-to-r from-blue-600 to-blue-700 p-3 rounded-xl shadow-lg">
              <Package className="h-8 w-8 text-white" />
            </div>
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Orders Movement Tracking</h1>
              <p className="text-gray-600 mt-1">Track order entries and deliveries</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-lg p-6 mb-6">
          <div className="flex flex-wrap items-center gap-4 mb-4">
            <button
              onClick={() => setShowAddForm(!showAddForm)}
              className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
            >
              <Plus className="h-5 w-5" />
              Add Order
            </button>
            <button
              onClick={exportToExcel}
              disabled={searchResults.length === 0 || isExporting}
              className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {isExporting ? (
                <>
                  <Loader2 className="h-5 w-5 animate-spin" />
                  Exporting...
                </>
              ) : (
                <>
                  <Download className="h-5 w-5" />
                  Export to Excel
                </>
              )}
            </button>
            {unmatchedTerms.length > 0 && (
              <button
                onClick={exportUnmatchedToExcel}
                className="flex items-center gap-2 px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition-colors"
              >
                <FileX className="h-5 w-5" />
                Export Unmatched ({unmatchedTerms.length})
              </button>
            )}
          </div>

          {showAddForm && (
            <div className="bg-gray-50 rounded-lg p-4 mb-4">
              <h3 className="font-semibold text-gray-900 mb-3">Add New Order</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Constructeur *</label>
                  <input
                    type="text"
                    value={newOrder.constructeur}
                    onChange={(e) => setNewOrder({ ...newOrder, constructeur: e.target.value })}
                    className="w-full px-3 py-2 border rounded-lg text-sm"
                    placeholder="Manufacturer name"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Date * (DD-MM-YYYY)</label>
                  <input
                    type="text"
                    placeholder="DD-MM-YYYY"
                    value={newOrder.date_or}
                    onChange={(e) => setNewOrder({ ...newOrder, date_or: e.target.value })}
                    className="w-full px-3 py-2 border rounded-lg text-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Num Commande *</label>
                  <input
                    type="text"
                    value={newOrder.num_or}
                    onChange={(e) => setNewOrder({ ...newOrder, num_or: e.target.value })}
                    className="w-full px-3 py-2 border rounded-lg text-sm"
                    placeholder="Order number"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Part Number *</label>
                  <input
                    type="text"
                    value={newOrder.part_number}
                    onChange={(e) => setNewOrder({ ...newOrder, part_number: e.target.value })}
                    className="w-full px-3 py-2 border rounded-lg text-sm"
                    placeholder="Part reference"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Qté Commandée</label>
                  <input
                    type="number"
                    step="0.01"
                    value={newOrder.qte_commandee}
                    onChange={(e) => setNewOrder({ ...newOrder, qte_commandee: parseFloat(e.target.value) || 0 })}
                    className="w-full px-3 py-2 border rounded-lg text-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Qté Livrée</label>
                  <input
                    type="number"
                    step="0.01"
                    value={newOrder.qte_livree}
                    onChange={(e) => setNewOrder({ ...newOrder, qte_livree: parseFloat(e.target.value) || 0 })}
                    className="w-full px-3 py-2 border rounded-lg text-sm"
                  />
                </div>
              </div>
              <div className="flex gap-2 mt-4">
                <button
                  onClick={handleAddOrder}
                  disabled={isLoading}
                  className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 transition-colors"
                >
                  Save Order
                </button>
                <button
                  onClick={() => setShowAddForm(false)}
                  className="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}

          <CSVImporter
            tableName="orders"
            headerMap={ordersHeaderMap}
            onImportComplete={handleImportComplete}
            onImportError={handleImportError}
          />
        </div>

        <div className="bg-white rounded-xl shadow-lg mb-32 overflow-hidden">
          <div className="h-[calc(100vh-28rem)] overflow-y-auto p-6">
            {messages.map((msg, index) => (
              <div
                key={index}
                className={`mb-4 ${
                  msg.role === 'user' ? 'text-right' : 'text-left'
                }`}
              >
                <div
                  className={`inline-block max-w-[80%] p-4 rounded-lg ${
                    msg.role === 'user'
                      ? 'bg-blue-600 text-white'
                      : 'bg-gray-100 text-gray-900'
                  }`}
                >
                  <pre className="whitespace-pre-wrap font-sans text-sm sm:text-base">{msg.content}</pre>
                </div>
              </div>
            ))}

            {renderSearchResults()}
            <div ref={messagesEndRef} />
          </div>
        </div>

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
                    placeholder="Search by constructor, order number, or part number..."
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
                    <Loader2 className="h-4 w-4 sm:h-5 sm:w-5 animate-spin" />
                  ) : (
                    <Send className="h-4 w-4 sm:h-5 sm:w-5" />
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
}
