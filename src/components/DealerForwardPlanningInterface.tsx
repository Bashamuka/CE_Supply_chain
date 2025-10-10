import React, { useState, useRef, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, Download, Upload, Loader2, RefreshCw, CreditCard as Edit2, Trash2, Save, X, FileSpreadsheet, AlertCircle } from 'lucide-react';
import { useDealerForwardPlanningStore } from '../store/dealerForwardPlanningStore';
import { DealerForwardPlanning } from '../types';
import * as XLSX from 'xlsx';

const TEMPLATE_HEADERS = ['Part Number', 'Model', 'Forecast Quantity', 'Business Case Notes'];

export function DealerForwardPlanningInterface() {
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editForm, setEditForm] = useState<Partial<DealerForwardPlanning>>({});
  const [isUploading, setIsUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [uploadTotal, setUploadTotal] = useState(0);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const {
    records,
    messages,
    isLoading,
    fetchRecords,
    uploadRecords,
    updateRecord,
    deleteRecord,
    deleteAllRecords,
    addMessage,
    resetChat
  } = useDealerForwardPlanningStore();

  useEffect(() => {
    fetchRecords();
  }, [fetchRecords]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const downloadTemplate = () => {
    const templateData = [
      {
        'Part Number': 'Example: 123-4567',
        'Model': 'Example: CAT 320',
        'Forecast Quantity': 10,
        'Business Case Notes': 'Example: Q1 2025 forecast for project X'
      }
    ];

    const wb = XLSX.utils.book_new();
    const ws = XLSX.utils.json_to_sheet(templateData);

    const colWidths = [
      { wch: 20 },
      { wch: 20 },
      { wch: 18 },
      { wch: 40 }
    ];
    ws['!cols'] = colWidths;

    XLSX.utils.book_append_sheet(wb, ws, 'Template');

    const date = new Date().toISOString().split('T')[0];
    const fileName = `dealer_forward_planning_template_${date}.xlsx`;
    XLSX.writeFile(wb, fileName);

    addMessage({
      content: 'Template downloaded successfully. Fill in your forecast data and upload it back.',
      role: 'assistant'
    });
  };

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    setIsUploading(true);
    addMessage({
      content: `Processing file: ${file.name}...`,
      role: 'user'
    });

    try {
      const data = await file.arrayBuffer();
      const workbook = XLSX.read(data, { type: 'array' });
      const firstSheet = workbook.Sheets[workbook.SheetNames[0]];
      const jsonData: any[] = XLSX.utils.sheet_to_json(firstSheet);

      if (jsonData.length === 0) {
        throw new Error('No data found in file');
      }

      const recordsToUpload = jsonData
        .map(row => {
          const partNumber = String(row['Part Number'] || row['part_number'] || row['PartNumber'] || '').trim();
          const model = String(row['Model'] || row['model'] || '').trim();
          const forecastQuantity = parseFloat(String(row['Forecast Quantity'] || row['forecast_quantity'] || row['ForecastQuantity'] || '0'));
          const businessCaseNotes = String(row['Business Case Notes'] || row['business_case_notes'] || row['BusinessCaseNotes'] || '').trim();

          if (!partNumber) return null;

          return {
            part_number: partNumber,
            model: model || undefined,
            forecast_quantity: forecastQuantity || 0,
            business_case_notes: businessCaseNotes || undefined
          };
        })
        .filter(record => record !== null) as Omit<DealerForwardPlanning, 'id' | 'uploaded_by' | 'upload_date' | 'created_at' | 'updated_at'>[];

      if (recordsToUpload.length === 0) {
        throw new Error('No valid records found in file. Please ensure Part Number column is filled.');
      }

      addMessage({
        content: `Found ${recordsToUpload.length} valid record(s). Starting upload...`,
        role: 'assistant'
      });

      setUploadTotal(recordsToUpload.length);
      setUploadProgress(0);

      await uploadRecords(recordsToUpload, (current, total) => {
        setUploadProgress(current);
        setUploadTotal(total);
      });
    } catch (error) {
      console.error('File upload error:', error);
      addMessage({
        content: `Error processing file: ${error instanceof Error ? error.message : 'Unknown error'}`,
        role: 'assistant'
      });
    } finally {
      setIsUploading(false);
      setUploadProgress(0);
      setUploadTotal(0);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const exportToExcel = () => {
    if (records.length === 0) {
      addMessage({
        content: 'No records to export.',
        role: 'assistant'
      });
      return;
    }

    const exportData = records.map(record => ({
      'Part Number': record.part_number,
      'Model': record.model || '',
      'Forecast Quantity': record.forecast_quantity,
      'Business Case Notes': record.business_case_notes || '',
      'Upload Date': new Date(record.upload_date).toLocaleDateString()
    }));

    const wb = XLSX.utils.book_new();
    const ws = XLSX.utils.json_to_sheet(exportData);

    const colWidths = [
      { wch: 20 },
      { wch: 20 },
      { wch: 18 },
      { wch: 40 },
      { wch: 15 }
    ];
    ws['!cols'] = colWidths;

    XLSX.utils.book_append_sheet(wb, ws, 'Forward Planning');

    const date = new Date().toISOString().split('T')[0];
    const fileName = `dealer_forward_planning_export_${date}.xlsx`;
    XLSX.writeFile(wb, fileName);

    addMessage({
      content: `Exported ${records.length} record(s) to Excel.`,
      role: 'assistant'
    });
  };

  const handleEdit = (record: DealerForwardPlanning) => {
    setEditingId(record.id);
    setEditForm(record);
  };

  const handleCancelEdit = () => {
    setEditingId(null);
    setEditForm({});
  };

  const handleSaveEdit = async () => {
    if (!editingId) return;

    const { id, uploaded_by, upload_date, created_at, updated_at, ...updates } = editForm;
    await updateRecord(editingId, updates);
    setEditingId(null);
    setEditForm({});
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this record?')) return;
    await deleteRecord(id);
  };

  const handleDeleteAll = async () => {
    if (!confirm('Are you sure you want to delete ALL records? This action cannot be undone.')) return;
    await deleteAllRecords();
  };

  const handleReset = () => {
    resetChat();
  };

  const totalForecast = records.reduce((sum, r) => sum + r.forecast_quantity, 0);
  const uniqueParts = new Set(records.map(r => r.part_number)).size;

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
              <FileSpreadsheet className="h-8 w-8 text-white" />
            </div>
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Dealer Forward Planning Program</h1>
              <p className="text-gray-600 mt-1">Upload and manage parts forecasts</p>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div className="bg-white rounded-xl shadow-md p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Total Records</p>
                <p className="text-2xl font-bold text-gray-900">{records.length}</p>
              </div>
              <FileSpreadsheet className="h-8 w-8 text-blue-600" />
            </div>
          </div>
          <div className="bg-white rounded-xl shadow-md p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Unique Parts</p>
                <p className="text-2xl font-bold text-gray-900">{uniqueParts}</p>
              </div>
              <AlertCircle className="h-8 w-8 text-green-600" />
            </div>
          </div>
          <div className="bg-white rounded-xl shadow-md p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Total Forecast Qty</p>
                <p className="text-2xl font-bold text-gray-900">{totalForecast.toFixed(0)}</p>
              </div>
              <Upload className="h-8 w-8 text-purple-600" />
            </div>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-lg p-6 mb-6">
          <div className="flex flex-wrap items-center gap-4">
            <button
              onClick={downloadTemplate}
              className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
            >
              <Download className="h-5 w-5" />
              Download Template
            </button>
            <button
              onClick={() => fileInputRef.current?.click()}
              disabled={isLoading || isUploading}
              className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {isUploading ? (
                <>
                  <Loader2 className="h-5 w-5 animate-spin" />
                  Uploading...
                </>
              ) : (
                <>
                  <Upload className="h-5 w-5" />
                  Upload File
                </>
              )}
            </button>
            <input
              ref={fileInputRef}
              type="file"
              accept=".xlsx,.xls"
              onChange={handleFileUpload}
              className="hidden"
            />
            <button
              onClick={exportToExcel}
              disabled={records.length === 0}
              className="flex items-center gap-2 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              <Download className="h-5 w-5" />
              Export All
            </button>
            <button
              onClick={handleDeleteAll}
              disabled={records.length === 0 || isLoading}
              className="flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              <Trash2 className="h-5 w-5" />
              Delete All
            </button>
          </div>
        </div>

        {isUploading && uploadTotal > 0 && (
          <div className="bg-white rounded-xl shadow-lg p-6 mb-6">
            <div className="space-y-3">
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-700 font-medium">Uploading records...</span>
                <span className="text-gray-600">{uploadProgress} / {uploadTotal}</span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-3 overflow-hidden">
                <div
                  className="bg-gradient-to-r from-blue-600 to-blue-700 h-3 rounded-full transition-all duration-300 ease-out"
                  style={{ width: `${(uploadProgress / uploadTotal) * 100}%` }}
                />
              </div>
              <div className="text-center text-sm text-gray-500">
                {Math.round((uploadProgress / uploadTotal) * 100)}% complete
              </div>
            </div>
          </div>
        )}

        <div className="bg-white rounded-xl shadow-lg mb-32 overflow-hidden">
          <div className="h-[calc(100vh-32rem)] overflow-y-auto p-6">
            {messages.length === 0 ? (
              <div className="text-center text-gray-500 py-12">
                <FileSpreadsheet className="h-16 w-16 mx-auto mb-4 text-gray-300" />
                <p className="text-lg font-medium">Welcome to Dealer Forward Planning</p>
                <p className="text-sm mt-2">Download the template, fill it with your forecast data, and upload it back.</p>
              </div>
            ) : (
              messages.map((msg, index) => (
                <div
                  key={index}
                  className={`mb-4 ${msg.role === 'user' ? 'text-right' : 'text-left'}`}
                >
                  <div
                    className={`inline-block max-w-[80%] p-4 rounded-lg ${
                      msg.role === 'user'
                        ? 'bg-blue-600 text-white'
                        : 'bg-gray-100 text-gray-900'
                    }`}
                  >
                    <pre className="whitespace-pre-wrap font-sans text-sm">{msg.content}</pre>
                  </div>
                </div>
              ))
            )}
            <div ref={messagesEndRef} />
          </div>
        </div>

        <div className="fixed bottom-0 left-0 right-0 z-30 bg-white border-t border-gray-200 p-6 shadow-lg">
          <div className="max-w-4xl mx-auto">
            <div className="flex items-center justify-center gap-4">
              <button
                onClick={handleReset}
                className="p-3 rounded-lg hover:bg-gray-100 transition-colors"
                title="Reset chat"
              >
                <RefreshCw className="h-5 w-5 text-gray-500" />
              </button>
              <div className="text-sm text-gray-600">
                Use the buttons above to download template, upload forecasts, or export data
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
