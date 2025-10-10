import React from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, BookOpen, Package2, Warehouse, GitBranch, Upload, Download, FileSpreadsheet, Search, Filter, Eye, Users, Shield, Database } from 'lucide-react';

export function UserGuide() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-[#F5F5F5] to-white">
      {/* Header */}
      <div className="sticky top-0 z-20 bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex items-center gap-4">
            <Link
              to="/"
              className="flex items-center gap-2 text-gray-600 hover:text-[#1A1A1A] transition-colors"
            >
              <ArrowLeft className="h-5 w-5" />
              <span>Back to Dashboard</span>
            </Link>
          </div>
          <div className="mt-4">
            <h1 className="text-2xl sm:text-3xl font-bold text-[#1A1A1A] flex items-center gap-3">
              <BookOpen className="h-8 w-8 text-blue-600" />
              User Guide
            </h1>
            <p className="text-gray-600 mt-2">
              Complete guide to using the CE-Parts Supply Chain Hub
            </p>
          </div>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Introduction */}
        <div className="bg-white rounded-xl shadow-lg p-8 mb-8">
          <div className="flex items-center gap-3 mb-6">
            <div className="bg-gradient-to-r from-[#1A1A1A] to-[#333333] p-3 rounded-xl">
              <Package2 className="h-6 w-6 text-[#FFCD11]" />
            </div>
            <h2 className="text-2xl font-bold text-[#1A1A1A]">Welcome to CE-Parts Supply Chain Hub</h2>
          </div>
          <p className="text-gray-700 leading-relaxed mb-4">
            This application is designed to help you efficiently manage and track parts across the Congo Equipment supply chain. 
            You can search for parts, check stock availability, find equivalent parts, and track delivery schedules.
          </p>
          <div className="bg-[#FFF3CC] border-l-4 border-[#FFCD11] p-4 rounded-r-lg">
            <p className="text-[#1A1A1A] font-medium">
              💡 <strong>Quick Tip:</strong> Use the search functionality in each module to quickly find the information you need. 
              You can also upload Excel files for batch processing!
            </p>
          </div>
        </div>

        {/* Navigation Overview */}
        <div className="bg-white rounded-xl shadow-lg p-8 mb-8">
          <h2 className="text-xl font-bold text-[#1A1A1A] mb-6 flex items-center gap-2">
            <Database className="h-6 w-6 text-blue-600" />
            Application Modules
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="border border-gray-200 rounded-lg p-4">
              <div className="flex items-center gap-3 mb-3">
                <div className="bg-blue-100 p-2 rounded-lg">
                  <Package2 className="h-5 w-5 text-blue-600" />
                </div>
                <h3 className="font-semibold text-[#1A1A1A]">ETA Tracking</h3>
              </div>
              <p className="text-sm text-gray-600">
                Track order statuses, delivery dates, and part availability across all suppliers.
              </p>
            </div>
            <div className="border border-gray-200 rounded-lg p-4">
              <div className="flex items-center gap-3 mb-3">
                <div className="bg-green-100 p-2 rounded-lg">
                  <Warehouse className="h-5 w-5 text-green-600" />
                </div>
                <h3 className="font-semibold text-[#1A1A1A]">Stock Availability</h3>
              </div>
              <p className="text-sm text-gray-600">
                Check stock levels across all branches and locations in real-time.
              </p>
            </div>
            <div className="border border-gray-200 rounded-lg p-4">
              <div className="flex items-center gap-3 mb-3">
                <div className="bg-purple-100 p-2 rounded-lg">
                  <GitBranch className="h-5 w-5 text-purple-600" />
                </div>
                <h3 className="font-semibold text-[#1A1A1A]">Parts Equivalence</h3>
              </div>
              <p className="text-sm text-gray-600">
                Find equivalent parts and cross-references for better sourcing options.
              </p>
            </div>
          </div>
        </div>

        {/* ETA Tracking Guide */}
        <div className="bg-white rounded-xl shadow-lg p-8 mb-8">
          <h2 className="text-xl font-bold text-[#1A1A1A] mb-6 flex items-center gap-2">
            <Package2 className="h-6 w-6 text-blue-600" />
            ETA Tracking Module
          </h2>
          
          <div className="space-y-6">
            <div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-3">What you can search for:</h3>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li><strong>Order Numbers:</strong> Internal order references</li>
                <li><strong>Supplier Orders:</strong> Supplier-specific order numbers</li>
                <li><strong>Part Numbers:</strong> Ordered or delivered part references</li>
                <li><strong>Customer PO:</strong> Customer purchase order numbers</li>
                <li><strong>Status:</strong> Order status (Sourced, Shipped, Griefed, etc.)</li>
                <li><strong>Prim PSO:</strong> Primary PSO references</li>
              </ul>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-3">How to use:</h3>
              <ol className="list-decimal list-inside space-y-2 text-gray-700">
                <li>Enter your search term in the search box at the bottom</li>
                <li>Press Enter or click the send button</li>
                <li>View results in the table with sorting and pagination</li>
                <li>Use the Excel button to upload multiple search terms at once</li>
                <li>Export results to Excel for further analysis</li>
              </ol>
            </div>

            <div className="bg-blue-50 border-l-4 border-blue-500 p-4 rounded-r-lg">
              <p className="text-blue-800">
                <strong>Pro Tip:</strong> The status statistics show you a quick overview of your search results, 
                helping you identify patterns in order statuses.
              </p>
            </div>
          </div>
        </div>

        {/* Stock Availability Guide */}
        <div className="bg-white rounded-xl shadow-lg p-8 mb-8">
          <h2 className="text-xl font-bold text-[#1A1A1A] mb-6 flex items-center gap-2">
            <Warehouse className="h-6 w-6 text-green-600" />
            Stock Availability Module
          </h2>
          
          <div className="space-y-6">
            <div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-3">Available locations:</h3>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
                <div className="bg-gray-50 p-2 rounded">GDC</div>
                <div className="bg-gray-50 p-2 rounded">JDC</div>
                <div className="bg-gray-50 p-2 rounded">CAT Network</div>
                <div className="bg-gray-50 p-2 rounded">SUCC 10</div>
                <div className="bg-gray-50 p-2 rounded">SUCC 20</div>
                <div className="bg-gray-50 p-2 rounded">SUCC 11-14</div>
                <div className="bg-gray-50 p-2 rounded">SUCC 19-24</div>
                <div className="bg-gray-50 p-2 rounded">SUCC 30-90</div>
              </div>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-3">Search capabilities:</h3>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li><strong>Part Numbers:</strong> Exact or partial part number matches</li>
                <li><strong>Descriptions:</strong> Search within part descriptions</li>
                <li><strong>Batch Search:</strong> Upload Excel files with multiple part numbers</li>
                <li><strong>Real-time Data:</strong> Current stock levels across all locations</li>
              </ul>
            </div>

            <div className="bg-green-50 border-l-4 border-green-500 p-4 rounded-r-lg">
              <p className="text-green-800">
                <strong>Best Practice:</strong> Use the Excel upload feature when checking availability for multiple parts. 
                The system will show you which parts were found and which weren't.
              </p>
            </div>
          </div>
        </div>

        {/* Parts Equivalence Guide */}
        <div className="bg-white rounded-xl shadow-lg p-8 mb-8">
          <h2 className="text-xl font-bold text-[#1A1A1A] mb-6 flex items-center gap-2">
            <GitBranch className="h-6 w-6 text-purple-600" />
            Parts Equivalence Module
          </h2>
          
          <div className="space-y-6">
            <div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-3">Find alternatives for:</h3>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li><strong>Original Parts:</strong> Search by original part number</li>
                <li><strong>Equivalent Parts:</strong> Find what can replace a specific part</li>
                <li><strong>Descriptions:</strong> Search within part descriptions</li>
                <li><strong>Cross-references:</strong> Bidirectional equivalence lookup</li>
              </ul>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-3">Use cases:</h3>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li>Finding substitute parts when original is unavailable</li>
                <li>Cost optimization by finding cheaper alternatives</li>
                <li>Sourcing from different suppliers</li>
                <li>Maintenance planning with alternative parts</li>
              </ul>
            </div>

            <div className="bg-purple-50 border-l-4 border-purple-500 p-4 rounded-r-lg">
              <p className="text-purple-800">
                <strong>Important:</strong> Always verify compatibility with your technical team before using equivalent parts, 
                especially for critical applications.
              </p>
            </div>
          </div>
        </div>

        {/* File Operations Guide */}
        <div className="bg-white rounded-xl shadow-lg p-8 mb-8">
          <h2 className="text-xl font-bold text-[#1A1A1A] mb-6 flex items-center gap-2">
            <FileSpreadsheet className="h-6 w-6 text-orange-600" />
            File Operations
          </h2>
          
          <div className="space-y-6">
            <div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-3 flex items-center gap-2">
                <Upload className="h-5 w-5 text-blue-600" />
                Excel Upload (Batch Search)
              </h3>
              <ol className="list-decimal list-inside space-y-2 text-gray-700">
                <li>Prepare an Excel file (.xlsx or .xls) with search terms in the first column</li>
                <li>Click the Excel button (📊) in any module</li>
                <li>Select your file and wait for processing</li>
                <li>Review the results showing matched and unmatched terms</li>
              </ol>
              <div className="bg-blue-50 p-3 rounded-lg mt-3">
                <p className="text-blue-800 text-sm">
                  <strong>Tip:</strong> The system automatically removes duplicates and processes up to 10,000 search terms efficiently.
                </p>
              </div>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-3 flex items-center gap-2">
                <Download className="h-5 w-5 text-green-600" />
                Excel Export
              </h3>
              <ol className="list-decimal list-inside space-y-2 text-gray-700">
                <li>Perform your search to get results</li>
                <li>Click the "Export to Excel" button</li>
                <li>The file will be automatically downloaded with current date</li>
                <li>Open in Excel for further analysis or reporting</li>
              </ol>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-3 flex items-center gap-2">
                <Upload className="h-5 w-5 text-red-600" />
                CSV Import (Admin Only)
              </h3>
              <p className="text-gray-700 mb-2">
                Administrators can import new data using the CSV import feature:
              </p>
              <ul className="list-disc list-inside space-y-1 text-gray-700">
                <li>Prepare CSV files with proper column headers</li>
                <li>Use the "Import CSV file" button in each module</li>
                <li>Monitor import progress with real-time updates</li>
                <li>Existing data is replaced during import</li>
              </ul>
            </div>
          </div>
        </div>

        {/* Interface Features Guide */}
        <div className="bg-white rounded-xl shadow-lg p-8 mb-8">
          <h2 className="text-xl font-bold text-[#1A1A1A] mb-6 flex items-center gap-2">
            <Eye className="h-6 w-6 text-indigo-600" />
            Interface Features
          </h2>
          
          <div className="space-y-6">
            <div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-3 flex items-center gap-2">
                <Filter className="h-5 w-5 text-blue-600" />
                Sorting & Filtering
              </h3>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li>Click column headers to sort data (ascending/descending)</li>
                <li>Use the search box for real-time filtering</li>
                <li>Results are limited to 10,000 items for performance</li>
                <li>Pagination controls at the bottom of tables</li>
              </ul>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-3 flex items-center gap-2">
                <Search className="h-5 w-5 text-green-600" />
                Search Tips
              </h3>
              <ul className="list-disc list-inside space-y-2 text-gray-700">
                <li>Use partial matches - you don't need the complete part number</li>
                <li>Search is case-insensitive</li>
                <li>Multiple words will search across all relevant fields</li>
                <li>Use the reset button (🔄) to clear your search and start over</li>
              </ul>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-3">Status Indicators</h3>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                <div className="flex items-center gap-2">
                  <span className="status-completed">Completed</span>
                  <span className="text-sm text-gray-600">Delivered/Finished</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="status-pending">Pending</span>
                  <span className="text-sm text-gray-600">In Progress</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="status-delayed">Delayed</span>
                  <span className="text-sm text-gray-600">Late/Issues</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* User Roles & Permissions */}
        <div className="bg-white rounded-xl shadow-lg p-8 mb-8">
          <h2 className="text-xl font-bold text-[#1A1A1A] mb-6 flex items-center gap-2">
            <Users className="h-6 w-6 text-gray-600" />
            User Roles & Permissions
          </h2>
          
          <div className="space-y-4">
            <div className="border border-gray-200 rounded-lg p-4">
              <div className="flex items-center gap-2 mb-2">
                <Shield className="h-5 w-5 text-red-600" />
                <h3 className="font-semibold text-[#1A1A1A]">Administrator</h3>
              </div>
              <ul className="list-disc list-inside space-y-1 text-gray-700 text-sm">
                <li>Full access to all modules</li>
                <li>Can import CSV data</li>
                <li>Can export all data</li>
                <li>User management capabilities</li>
              </ul>
            </div>
            
            <div className="border border-gray-200 rounded-lg p-4">
              <div className="flex items-center gap-2 mb-2">
                <Users className="h-5 w-5 text-blue-600" />
                <h3 className="font-semibold text-[#1A1A1A]">Employee</h3>
              </div>
              <ul className="list-disc list-inside space-y-1 text-gray-700 text-sm">
                <li>Access to all search modules</li>
                <li>Can export search results</li>
                <li>Can upload Excel files for batch search</li>
                <li>Cannot import CSV data</li>
              </ul>
            </div>
            
            <div className="border border-gray-200 rounded-lg p-4">
              <div className="flex items-center gap-2 mb-2">
                <Eye className="h-5 w-5 text-green-600" />
                <h3 className="font-semibold text-[#1A1A1A]">Consultant</h3>
              </div>
              <ul className="list-disc list-inside space-y-1 text-gray-700 text-sm">
                <li>Read-only access to search modules</li>
                <li>Can export search results</li>
                <li>Limited to specific data sets</li>
                <li>Cannot import any data</li>
              </ul>
            </div>
          </div>
        </div>

        {/* Troubleshooting */}
        <div className="bg-white rounded-xl shadow-lg p-8 mb-8">
          <h2 className="text-xl font-bold text-[#1A1A1A] mb-6">Troubleshooting</h2>
          
          <div className="space-y-4">
            <div>
              <h3 className="font-semibold text-[#1A1A1A] mb-2">Common Issues:</h3>
              <div className="space-y-3">
                <div className="bg-gray-50 p-3 rounded-lg">
                  <p className="font-medium text-gray-800">No search results found</p>
                  <p className="text-sm text-gray-600">Try using partial part numbers or check spelling. The search is case-insensitive but requires some matching characters.</p>
                </div>
                
                <div className="bg-gray-50 p-3 rounded-lg">
                  <p className="font-medium text-gray-800">Excel upload not working</p>
                  <p className="text-sm text-gray-600">Ensure your file is .xlsx or .xls format and has data in the first column. Check file size (max 10MB recommended).</p>
                </div>
                
                <div className="bg-gray-50 p-3 rounded-lg">
                  <p className="font-medium text-gray-800">Slow performance</p>
                  <p className="text-sm text-gray-600">Large searches may take time. Results are limited to 10,000 items. Try more specific search terms.</p>
                </div>
                
                <div className="bg-gray-50 p-3 rounded-lg">
                  <p className="font-medium text-gray-800">Permission denied</p>
                  <p className="text-sm text-gray-600">Contact your administrator if you need access to additional features or data import capabilities.</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Contact & Support */}
        <div className="bg-gradient-to-r from-[#1A1A1A] to-[#333333] rounded-xl shadow-lg p-8 text-white">
          <h2 className="text-xl font-bold mb-4 flex items-center gap-2">
            <Package2 className="h-6 w-6 text-[#FFCD11]" />
            Support & Contact
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h3 className="font-semibold mb-2 text-[#FFCD11]">Technical Support</h3>
              <p className="text-gray-300 text-sm">
                For technical issues, data problems, or feature requests, contact your IT administrator 
                or the Congo Equipment technical support team.
              </p>
            </div>
            <div>
              <h3 className="font-semibold mb-2 text-[#FFCD11]">Business Questions</h3>
              <p className="text-gray-300 text-sm">
                For questions about parts availability, equivalences, or supply chain processes, 
                contact your parts department or supply chain manager.
              </p>
            </div>
          </div>
          <div className="mt-6 pt-6 border-t border-gray-600">
            <p className="text-center text-gray-400 text-sm">
              CE-Parts Supply Chain Hub - Powered by Congo Equipment® | Version 1.0
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}