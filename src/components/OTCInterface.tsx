import React, { useState, useEffect } from 'react';
import { 
  Search, 
  Filter, 
  Download, 
  Upload, 
  Plus, 
  Trash2, 
  Calendar,
  Package,
  Truck,
  CheckCircle,
  Clock,
  AlertCircle,
  XCircle,
  BarChart3,
  Users,
  Building2,
  FileText,
  RefreshCw,
  X
} from 'lucide-react';
import { supabase } from '../lib/supabase';

interface OTCOrder {
  id: string;
  succursale: string;
  operateur: string;
  date_cde: string;
  num_cde: string;
  po_client: string;
  reference: string;
  designation: string;
  qte_cde: number;
  qte_livree: number;
  solde: number;
  date_bl: string | null;
  num_bl: string | null;
  status: string;
  num_client: string | null;
  nom_clients: string | null;
  created_at: string;
  updated_at: string;
}

interface OTCAnalytics {
  succursale: string;
  total_orders: number;
  delivered_orders: number;
  pending_orders: number;
  in_progress_orders: number;
  cancelled_orders: number;
  total_ordered_quantity: number;
  total_delivered_quantity: number;
  total_balance: number;
  delivery_percentage: number;
  earliest_order_date: string;
  latest_order_date: string;
}

export function OTCInterface() {
  const [orders, setOrders] = useState<OTCOrder[]>([]);
  const [analytics, setAnalytics] = useState<OTCAnalytics[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedStatus, setSelectedStatus] = useState('all');
  const [selectedSuccursale, setSelectedSuccursale] = useState('all');
  const [dateRange, setDateRange] = useState({ start: '', end: '' });
  const [showAnalytics, setShowAnalytics] = useState(false);
  const [editingOrder, setEditingOrder] = useState<OTCOrder | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [showImportModal, setShowImportModal] = useState(false);
  const [importFile, setImportFile] = useState<File | null>(null);
  const [importLoading, setImportLoading] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [orderToDelete, setOrderToDelete] = useState<OTCOrder | null>(null);

  // Fetch orders from database
  const fetchOrders = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('otc_orders')
        .select('*')
        .order('date_cde', { ascending: false });

      if (error) throw error;
      setOrders(data || []);
    } catch (error) {
      console.error('Error fetching OTC orders:', error);
    } finally {
      setLoading(false);
    }
  };

  // Fetch analytics
  const fetchAnalytics = async () => {
    try {
      const { data, error } = await supabase
        .from('v_otc_analytics')
        .select('*');

      if (error) throw error;
      setAnalytics(data || []);
    } catch (error) {
      console.error('Error fetching OTC analytics:', error);
    }
  };

  useEffect(() => {
    fetchOrders();
    fetchAnalytics();
  }, []);

  // Filter orders based on search criteria
  const filteredOrders = orders.filter(order => {
    const matchesSearch = 
      order.num_cde.toLowerCase().includes(searchTerm.toLowerCase()) ||
      order.po_client?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      order.reference.toLowerCase().includes(searchTerm.toLowerCase()) ||
      order.designation.toLowerCase().includes(searchTerm.toLowerCase()) ||
      order.num_client?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      order.nom_clients?.toLowerCase().includes(searchTerm.toLowerCase());

    const matchesStatus = selectedStatus === 'all' || order.status === selectedStatus;
    const matchesSuccursale = selectedSuccursale === 'all' || order.succursale === selectedSuccursale;
    
    const matchesDateRange = 
      (!dateRange.start || order.date_cde >= dateRange.start) &&
      (!dateRange.end || order.date_cde <= dateRange.end);

    return matchesSearch && matchesStatus && matchesSuccursale && matchesDateRange;
  });

  // Get unique values for filters
  const uniqueStatuses = [...new Set(orders.map(order => order.status))];
  const uniqueSuccursales = [...new Set(orders.map(order => order.succursale))];

  // Status badge component
  const StatusBadge = ({ status }: { status: string }) => {
    const statusConfig = {
      'Delivered': { color: 'bg-green-100 text-green-800', icon: CheckCircle },
      'Pending': { color: 'bg-yellow-100 text-yellow-800', icon: Clock },
      'In Progress': { color: 'bg-blue-100 text-blue-800', icon: Truck },
      'Cancelled': { color: 'bg-red-100 text-red-800', icon: XCircle },
    };

    const config = statusConfig[status as keyof typeof statusConfig] || 
                  { color: 'bg-gray-100 text-gray-800', icon: AlertCircle };
    const Icon = config.icon;

    return (
      <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium ${config.color}`}>
        <Icon className="w-3 h-3" />
        {status}
      </span>
    );
  };

  // Export to CSV
  const exportToCSV = () => {
    const csvContent = [
      ['SUCCURSALE', 'OPERATEUR', 'DATE CDE', 'NUM CDE', 'PO CLIENT', 'REFERENCE', 
       'DESIGNATION', 'QTE CDE', 'QTE LIVREE', 'SOLDE', 'DATE BL', 'NUM BL', 
       'STATUS', 'NUM CLIENT', 'NOM CLIENTS'].join(','),
      ...filteredOrders.map(order => [
        order.succursale,
        order.operateur,
        order.date_cde,
        order.num_cde,
        order.po_client || '',
        order.reference,
        order.designation,
        order.qte_cde,
        order.qte_livree,
        order.solde,
        order.date_bl || '',
        order.num_bl || '',
        order.status,
        order.num_client || '',
        order.nom_clients || ''
      ].join(','))
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `otc_orders_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
  };

  // Import CSV function
  const handleImportCSV = async () => {
    if (!importFile) return;

    try {
      setImportLoading(true);
      const text = await importFile.text();
      const lines = text.split('\n').filter(line => line.trim());
      
      if (lines.length < 2) {
        alert('Le fichier CSV doit contenir au moins un en-tête et une ligne de données');
        return;
      }

      // Parse headers with multiple possible separators and formats
      const headerLine = lines[0];
      let headers = [];
      
      // Try different separators
      if (headerLine.includes(';')) {
        headers = headerLine.split(';').map(h => h.trim().toLowerCase());
      } else if (headerLine.includes('\t')) {
        headers = headerLine.split('\t').map(h => h.trim().toLowerCase());
      } else {
        headers = headerLine.split(',').map(h => h.trim().toLowerCase());
      }

      // Define expected headers with multiple possible variations
      const expectedHeadersMap = {
        'succursale': ['succursale', 'branch', 'branche', 'site'],
        'operateur': ['operateur', 'operator', 'user', 'utilisateur'],
        'date cde': ['date cde', 'date_cde', 'date commande', 'order date', 'date order'],
        'num cde': ['num cde', 'num_cde', 'numero commande', 'order number', 'order_number'],
        'po client': ['po client', 'po_client', 'customer po', 'customer_po', 'client po'],
        'reference': ['reference', 'ref', 'part number', 'part_number', 'part'],
        'designation': ['designation', 'description', 'desc', 'part description'],
        'qte cde': ['qte cde', 'qte_cde', 'quantity ordered', 'qty ordered', 'ordered qty'],
        'qte livree': ['qte livree', 'qte_livree', 'quantity delivered', 'qty delivered', 'delivered qty'],
        'solde': ['solde', 'balance', 'remaining', 'restant'],
        'date bl': ['date bl', 'date_bl', 'delivery date', 'livraison date'],
        'num bl': ['num bl', 'num_bl', 'delivery note', 'bon livraison', 'bl number'],
        'status': ['status', 'statut', 'etat', 'state'],
        'num client': ['num client', 'num_client', 'customer number', 'client number'],
        'nom clients': ['nom clients', 'nom_clients', 'customer name', 'client name', 'customer']
      };

      // Find matching headers
      const foundHeaders = {};
      const missingHeaders = [];

      for (const [expectedKey, possibleValues] of Object.entries(expectedHeadersMap)) {
        const foundHeader = headers.find(header => 
          possibleValues.some(possible => 
            header.includes(possible.toLowerCase()) || 
            possible.toLowerCase().includes(header)
          )
        );
        
        if (foundHeader) {
          foundHeaders[expectedKey] = foundHeader;
        } else {
          missingHeaders.push(expectedKey);
        }
      }

      // Only require essential headers
      const essentialHeaders = ['succursale', 'operateur', 'num cde', 'reference', 'designation', 'qte cde'];
      const missingEssential = missingHeaders.filter(h => essentialHeaders.includes(h));
      
      if (missingEssential.length > 0) {
        alert(`En-têtes essentiels manquants: ${missingEssential.join(', ')}\n\nEn-têtes trouvés: ${headers.join(', ')}`);
        return;
      }

      const orders = [];
      for (let i = 1; i < lines.length; i++) {
        // Parse values with same separator as headers
        let values = [];
        if (headerLine.includes(';')) {
          values = lines[i].split(';').map(v => v.trim());
        } else if (headerLine.includes('\t')) {
          values = lines[i].split('\t').map(v => v.trim());
        } else {
          values = lines[i].split(',').map(v => v.trim());
        }
        
        if (values.length !== headers.length) continue;

        const order: Partial<OTCOrder> = {};
        
        // Map values using found headers
        headers.forEach((header, index) => {
          const value = values[index];
          
          // Find which expected header this matches
          for (const [expectedKey, possibleValues] of Object.entries(expectedHeadersMap)) {
            if (possibleValues.some(possible => 
              header.includes(possible.toLowerCase()) || 
              possible.toLowerCase().includes(header)
            )) {
              // Map the value to the correct field
              switch (expectedKey) {
                case 'succursale':
                  order.succursale = value;
                  break;
                case 'operateur':
                  order.operateur = value;
                  break;
                case 'date cde':
                  order.date_cde = convertDateFormat(value) || value;
                  break;
                case 'num cde':
                  order.num_cde = value;
                  break;
                case 'po client':
                  order.po_client = value || null;
                  break;
                case 'reference':
                  order.reference = value;
                  break;
                case 'designation':
                  order.designation = value;
                  break;
                case 'qte cde':
                  order.qte_cde = parseFloat(value) || 0;
                  break;
                case 'qte livree':
                  order.qte_livree = parseFloat(value) || 0;
                  break;
                case 'solde':
                  // solde is calculated automatically, but we can use it for validation
                  break;
                case 'date bl':
                  order.date_bl = convertDateFormat(value);
                  break;
                case 'num bl':
                  order.num_bl = value || null;
                  break;
                case 'status':
                  order.status = value || 'Pending';
                  break;
                case 'num client':
                  order.num_client = value || null;
                  break;
                case 'nom clients':
                  order.nom_clients = value || null;
                  break;
              }
              break;
            }
          }
        });

        // Validate essential fields and date format
        if (order.succursale && order.operateur && order.num_cde && order.reference && order.designation) {
          // Validate date_cde format
          if (order.date_cde && !order.date_cde.match(/^\d{4}-\d{2}-\d{2}$/)) {
            console.warn(`Invalid date format for order ${order.num_cde}: ${order.date_cde}`);
            // Try to convert again or skip this order
            const convertedDate = convertDateFormat(order.date_cde);
            if (convertedDate) {
              order.date_cde = convertedDate;
            } else {
              console.error(`Cannot convert date ${order.date_cde} for order ${order.num_cde}`);
              continue; // Skip this order
            }
          }
          
          orders.push(order);
        }
      }

      if (orders.length === 0) {
        alert('Aucune commande valide trouvée dans le fichier CSV\n\nVérifiez que les dates sont au format DD/MM/YYYY (ex: 24/06/2024)');
        return;
      }

      // Clear existing data first
      console.log('Clearing existing OTC orders...');
      const { error: deleteError } = await supabase
        .from('otc_orders')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000'); // Delete all records

      if (deleteError) {
        console.error('Error clearing existing orders:', deleteError);
        alert(`Erreur lors de la suppression des données existantes: ${deleteError.message}`);
        return;
      }

      // Insert new orders
      console.log('Inserting new orders...');
      const { error } = await supabase
        .from('otc_orders')
        .insert(orders);

      if (error) {
        console.error('Error importing orders:', error);
        alert(`Erreur lors de l'import: ${error.message}`);
        return;
      }

      alert(`${orders.length} commandes importées avec succès\n\n• Données existantes supprimées\n• Nouvelles données insérées\n• Dates converties du format DD/MM/YYYY vers YYYY-MM-DD`);
      setShowImportModal(false);
      setImportFile(null);
      fetchOrders(); // Refresh the data
      fetchAnalytics();

    } catch (error) {
      console.error('Error processing CSV:', error);
      alert('Erreur lors du traitement du fichier CSV');
    } finally {
      setImportLoading(false);
    }
  };

  // Helper function to convert DD/MM/YYYY to YYYY-MM-DD
  const convertDateFormat = (dateStr: string): string | null => {
    if (!dateStr || dateStr.trim() === '') return null;
    
    // Handle DD/MM/YYYY format
    if (dateStr.includes('/')) {
      const parts = dateStr.split('/');
      if (parts.length === 3) {
        const day = parts[0].padStart(2, '0');
        const month = parts[1].padStart(2, '0');
        const year = parts[2];
        
        // Validate date components
        if (day.length === 2 && month.length === 2 && year.length === 4) {
          return `${year}-${month}-${day}`;
        }
      }
    }
    
    // Handle DD-MM-YYYY format
    if (dateStr.includes('-') && dateStr.length === 10) {
      const parts = dateStr.split('-');
      if (parts.length === 3 && parts[0].length === 2 && parts[1].length === 2 && parts[2].length === 4) {
        return `${parts[2]}-${parts[1]}-${parts[0]}`;
      }
    }
    
    // If already in YYYY-MM-DD format, return as is
    if (dateStr.match(/^\d{4}-\d{2}-\d{2}$/)) {
      return dateStr;
    }
    
    // If we can't parse it, return null
    return null;
  };

  // Delete order function
  const handleDeleteOrder = async (order: OTCOrder) => {
    try {
      const { error } = await supabase
        .from('otc_orders')
        .delete()
        .eq('id', order.id);

      if (error) {
        console.error('Error deleting order:', error);
        alert(`Erreur lors de la suppression: ${error.message}`);
        return;
      }

      alert('Commande supprimée avec succès');
      setShowDeleteModal(false);
      setOrderToDelete(null);
      fetchOrders(); // Refresh the data
      fetchAnalytics();
    } catch (error) {
      console.error('Error deleting order:', error);
      alert('Erreur lors de la suppression de la commande');
    }
  };


  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white flex items-center justify-center">
        <div className="text-center">
          <RefreshCw className="w-8 h-8 animate-spin text-[#FFCD11] mx-auto mb-4" />
          <p className="text-gray-600">Loading OTC orders...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white">
      {/* Header */}
      <div className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-2xl font-bold text-[#1A1A1A] flex items-center gap-2">
                <Package className="h-8 w-8 text-[#FFCD11]" />
                OTC - Order Tracking & Control
              </h1>
              <p className="text-gray-600 mt-1">Comprehensive order management and tracking</p>
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setShowAnalytics(!showAnalytics)}
                className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                <BarChart3 className="h-4 w-4" />
                Analytics
              </button>
              <button
                onClick={() => setShowImportModal(true)}
                className="flex items-center gap-2 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
              >
                <Upload className="h-4 w-4" />
                Import CSV
              </button>
              <button
                onClick={exportToCSV}
                className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
              >
                <Download className="h-4 w-4" />
                Export CSV
              </button>
              <button
                onClick={() => setShowForm(true)}
                className="flex items-center gap-2 px-4 py-2 bg-[#FFCD11] text-black rounded-lg hover:bg-[#FFE066] transition-colors"
              >
                <Plus className="h-4 w-4" />
                New Order
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Analytics Panel */}
      {showAnalytics && (
        <div className="bg-white shadow-sm border-b border-gray-200">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
            <h2 className="text-lg font-semibold text-[#1A1A1A] mb-4">Analytics Overview</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              {analytics.map((branch) => (
                <div key={branch.succursale} className="bg-gray-50 rounded-lg p-4">
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="font-semibold text-[#1A1A1A]">{branch.succursale}</h3>
                    <Building2 className="h-5 w-5 text-gray-600" />
                  </div>
                  <div className="space-y-1 text-sm">
                    <div className="flex justify-between">
                      <span className="text-gray-600">Total Orders:</span>
                      <span className="font-medium">{branch.total_orders}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Delivered:</span>
                      <span className="font-medium text-green-600">{branch.delivered_orders}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Pending:</span>
                      <span className="font-medium text-yellow-600">{branch.pending_orders}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Delivery %:</span>
                      <span className="font-medium text-blue-600">{branch.delivery_percentage}%</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="space-y-4">
            {/* First row - Search and basic filters */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              {/* Search */}
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                <input
                  type="text"
                  placeholder="Search orders..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#FFCD11] focus:border-[#FFCD11]"
                />
              </div>

              {/* Status Filter */}
              <select
                value={selectedStatus}
                onChange={(e) => setSelectedStatus(e.target.value)}
                className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#FFCD11] focus:border-[#FFCD11]"
              >
                <option value="all">All Status</option>
                {uniqueStatuses.map(status => (
                  <option key={status} value={status}>{status}</option>
                ))}
              </select>

              {/* Succursale Filter */}
              <select
                value={selectedSuccursale}
                onChange={(e) => setSelectedSuccursale(e.target.value)}
                className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#FFCD11] focus:border-[#FFCD11]"
              >
                <option value="all">All Branches</option>
                {uniqueSuccursales.map(succursale => (
                  <option key={succursale} value={succursale}>{succursale}</option>
                ))}
              </select>

              {/* Clear Filters */}
              <button
                onClick={() => {
                  setSearchTerm('');
                  setSelectedStatus('all');
                  setSelectedSuccursale('all');
                  setDateRange({ start: '', end: '' });
                }}
                className="flex items-center justify-center gap-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors"
              >
                <XCircle className="h-4 w-4" />
                Clear Filters
              </button>
            </div>

            {/* Second row - Date Range */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="flex gap-2">
                <label className="flex items-center gap-2 text-sm font-medium text-gray-700">
                  <Calendar className="h-4 w-4" />
                  Date Range:
                </label>
                <input
                  type="date"
                  placeholder="Start Date"
                  value={dateRange.start}
                  onChange={(e) => setDateRange(prev => ({ ...prev, start: e.target.value }))}
                  className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#FFCD11] focus:border-[#FFCD11]"
                />
                <span className="flex items-center text-gray-500">to</span>
                <input
                  type="date"
                  placeholder="End Date"
                  value={dateRange.end}
                  onChange={(e) => setDateRange(prev => ({ ...prev, end: e.target.value }))}
                  className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#FFCD11] focus:border-[#FFCD11]"
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Orders Table */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div className="bg-white rounded-lg shadow-lg overflow-hidden">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Order Details
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Customer
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Part Info
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Quantities
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Delivery
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {filteredOrders.map((order) => (
                  <tr key={order.id} className="hover:bg-gray-50">
                    <td className="px-4 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-[#1A1A1A]">
                        {order.num_cde}
                      </div>
                      <div className="text-sm text-gray-500">
                        {order.succursale} • {order.operateur}
                      </div>
                      <div className="text-xs text-gray-400">
                        {new Date(order.date_cde).toLocaleDateString()}
                      </div>
                      {order.po_client && (
                        <div className="text-xs text-blue-600">
                          PO: {order.po_client}
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-[#1A1A1A]">
                        {order.nom_clients || 'N/A'}
                      </div>
                      <div className="text-sm text-gray-500">
                        {order.num_client || 'N/A'}
                      </div>
                    </td>
                    <td className="px-4 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-[#1A1A1A]">
                        {order.reference}
                      </div>
                      <div className="text-sm text-gray-500">
                        {order.designation}
                      </div>
                    </td>
                    <td className="px-4 py-4 whitespace-nowrap">
                      <div className="text-sm text-[#1A1A1A]">
                        Ordered: <span className="font-medium">{order.qte_cde}</span>
                      </div>
                      <div className="text-sm text-gray-500">
                        Delivered: <span className="font-medium">{order.qte_livree}</span>
                      </div>
                      <div className="text-sm text-gray-500">
                        Balance: <span className="font-medium">{order.solde}</span>
                      </div>
                    </td>
                    <td className="px-4 py-4 whitespace-nowrap">
                      {order.date_bl ? (
                        <div>
                          <div className="text-sm text-[#1A1A1A]">
                            {new Date(order.date_bl).toLocaleDateString()}
                          </div>
                          <div className="text-sm text-gray-500">
                            {order.num_bl}
                          </div>
                        </div>
                      ) : (
                        <span className="text-sm text-gray-400">Not delivered</span>
                      )}
                    </td>
                    <td className="px-4 py-4 whitespace-nowrap">
                      <StatusBadge status={order.status} />
                    </td>
                    <td className="px-4 py-4 whitespace-nowrap text-sm font-medium">
                      <div className="flex justify-center">
                        <button
                          onClick={() => {
                            setOrderToDelete(order);
                            setShowDeleteModal(true);
                          }}
                          className="text-red-600 hover:text-red-900"
                          title="Delete order"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {filteredOrders.length === 0 && (
            <div className="text-center py-12">
              <Package className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">No orders found</h3>
              <p className="text-gray-500">Try adjusting your search criteria or add a new order.</p>
            </div>
          )}
        </div>

        {/* Summary */}
        <div className="mt-6 bg-white rounded-lg shadow-lg p-6">
          <h3 className="text-lg font-semibold text-[#1A1A1A] mb-4">Summary</h3>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="text-center">
              <div className="text-2xl font-bold text-[#1A1A1A]">{filteredOrders.length}</div>
              <div className="text-sm text-gray-600">Total Orders</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">
                {filteredOrders.filter(o => o.status === 'Delivered').length}
              </div>
              <div className="text-sm text-gray-600">Delivered</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-yellow-600">
                {filteredOrders.filter(o => o.status === 'Pending').length}
              </div>
              <div className="text-sm text-gray-600">Pending</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-600">
                {filteredOrders.reduce((sum, o) => sum + o.solde, 0)}
              </div>
              <div className="text-sm text-gray-600">Total Balance</div>
            </div>
          </div>
        </div>
      </div>

      {/* Import CSV Modal */}
      {showImportModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-md mx-4">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold text-[#1A1A1A]">Import CSV File</h3>
              <button
                onClick={() => setShowImportModal(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <XCircle className="h-6 w-6" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Select CSV File
                </label>
                <input
                  type="file"
                  accept=".csv"
                  onChange={(e) => setImportFile(e.target.files?.[0] || null)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#FFCD11] focus:border-[#FFCD11]"
                />
              </div>

              <div className="bg-blue-50 border-l-4 border-blue-400 p-3 rounded-r-lg">
                <div className="text-sm text-blue-800">
                  <p className="font-medium mb-1">Required CSV Format:</p>
                  <p className="text-xs">
                    SUCCURSALE, OPERATEUR, DATE CDE, NUM CDE, PO CLIENT, REFERENCE, DESIGNATION, QTE CDE, QTE LIVREE, SOLDE, DATE BL, NUM BL, STATUS, NUM CLIENT, NOM CLIENTS
                  </p>
                </div>
              </div>

              <div className="flex gap-3">
                <button
                  onClick={() => setShowImportModal(false)}
                  className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={handleImportCSV}
                  disabled={!importFile || importLoading}
                  className="flex-1 px-4 py-2 bg-[#FFCD11] text-black rounded-lg hover:bg-[#FFE066] transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                >
                  {importLoading ? (
                    <>
                      <RefreshCw className="h-4 w-4 animate-spin" />
                      Importing...
                    </>
                  ) : (
                    <>
                      <Upload className="h-4 w-4" />
                      Import
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}


      {/* Delete Confirmation Modal */}
      {showDeleteModal && orderToDelete && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
            <div className="flex items-center gap-3 mb-4">
              <div className="flex-shrink-0 w-10 h-10 bg-red-100 rounded-full flex items-center justify-center">
                <Trash2 className="h-5 w-5 text-red-600" />
              </div>
              <div>
                <h3 className="text-lg font-semibold text-[#1A1A1A]">Delete Order</h3>
                <p className="text-sm text-gray-600">This action cannot be undone.</p>
              </div>
            </div>
            
            <div className="mb-4 p-3 bg-gray-50 rounded-lg">
              <p className="text-sm text-gray-700">
                <strong>Order:</strong> {orderToDelete.num_cde}<br />
                <strong>Reference:</strong> {orderToDelete.reference}<br />
                <strong>Description:</strong> {orderToDelete.designation}
              </p>
            </div>
            
            <div className="flex gap-3">
              <button
                onClick={() => {
                  setShowDeleteModal(false);
                  setOrderToDelete(null);
                }}
                className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={() => handleDeleteOrder(orderToDelete)}
                className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
              >
                Delete Order
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
