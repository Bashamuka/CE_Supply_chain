import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { ArrowLeft, Plus, CreditCard as Edit2, Trash2, Save, X, Package, TrendingUp, Loader2, BarChart3, FileText } from 'lucide-react';
import { useProjectsStore } from '../store/projectsStore';
import { useUserStore } from '../store/userStore';
import { ProjectMachine, ProjectMachinePart, ProjectMachineOrderNumber } from '../types';
import { ProjectBLManagement } from './ProjectBLManagement';
import { ProjectMethodValidation } from './ProjectMethodValidation';

const BRANCH_OPTIONS = [
  { value: 'gdc', label: 'GDC' },
  { value: 'jdc', label: 'JDC' },
  { value: 'cat_network', label: 'CAT Network' },
  { value: 'succ_10', label: 'Branch 10' },
  { value: 'succ_20', label: 'Branch 20' },
  { value: 'succ_11', label: 'Branch 11' },
  { value: 'succ_12', label: 'Branch 12' },
  { value: 'succ_13', label: 'Branch 13' },
  { value: 'succ_14', label: 'Branch 14' },
  { value: 'succ_19', label: 'Branch 19' },
  { value: 'succ_21', label: 'Branch 21' },
  { value: 'succ_22', label: 'Branch 22' },
  { value: 'succ_24', label: 'Branch 24' },
  { value: 'succ_30', label: 'Branch 30' },
  { value: 'succ_40', label: 'Branch 40' },
  { value: 'succ_50', label: 'Branch 50' },
  { value: 'succ_60', label: 'Branch 60' },
  { value: 'succ_70', label: 'Branch 70' },
  { value: 'succ_80', label: 'Branch 80' },
  { value: 'succ_90', label: 'Branch 90' }
];

export function ProjectDetailsInterface() {
  const { projectId } = useParams<{ projectId: string }>();
  const user = useUserStore((state) => state.user);
  const {
    currentProject,
    machines,
    machineOrderNumbers,
    machineParts,
    supplierOrders,
    branches,
    blNumbers,
    isLoading,
    error,
    fetchProjectById,
    fetchMachines,
    fetchMachineOrderNumbers,
    fetchMachineParts,
    fetchSupplierOrders,
    fetchBranches,
    fetchBLNumbers,
    createMachine,
    updateMachine,
    deleteMachine,
    createMachineOrderNumber,
    deleteMachineOrderNumber,
    createMachinePart,
    updateMachinePart,
    deleteMachinePart,
    createSupplierOrder,
    deleteSupplierOrder,
    createBranch,
    deleteBranch,
    createBLNumber,
    deleteBLNumber
  } = useProjectsStore();

  const [activeTab, setActiveTab] = useState<'machines' | 'suppliers' | 'branches' | 'bl' | 'analytics'>('machines');
  const [showMachineModal, setShowMachineModal] = useState(false);
  const [editingMachine, setEditingMachine] = useState<ProjectMachine | null>(null);
  const [selectedMachine, setSelectedMachine] = useState<string | null>(null);
  const [showPartModal, setShowPartModal] = useState(false);
  const [editingPart, setEditingPart] = useState<ProjectMachinePart | null>(null);
  const [newSupplierOrder, setNewSupplierOrder] = useState('');
  const [newBranch, setNewBranch] = useState('');

  const [machineForm, setMachineForm] = useState({
    name: '',
    description: '',
    start_date: '',
    end_date: ''
  });

  const [newOrderNumber, setNewOrderNumber] = useState('');

  const [partForm, setPartForm] = useState({
    part_number: '',
    description: '',
    quantity_required: 0
  });

  const [bulkPartInput, setBulkPartInput] = useState('');
  const [bulkOrderNumberInput, setBulkOrderNumberInput] = useState('');
  const [showBulkOrderModal, setShowBulkOrderModal] = useState(false);
  const [bulkOrderMachineId, setBulkOrderMachineId] = useState<string | null>(null);
  const [bulkSupplierOrderInput, setBulkSupplierOrderInput] = useState('');
  const [showBulkSupplierModal, setShowBulkSupplierModal] = useState(false);

  const isAdmin = user?.role === 'admin';

  useEffect(() => {
    if (projectId) {
      fetchProjectById(projectId);
      fetchMachines(projectId);
      fetchSupplierOrders(projectId);
      fetchBranches(projectId);
      fetchBLNumbers(projectId);
    }
  }, [projectId, fetchProjectById, fetchMachines, fetchSupplierOrders, fetchBranches, fetchBLNumbers]);

  useEffect(() => {
    if (selectedMachine) {
      fetchMachineParts(selectedMachine);
      fetchMachineOrderNumbers(selectedMachine);
    }
  }, [selectedMachine, fetchMachineParts, fetchMachineOrderNumbers]);

  const handleCreateMachine = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!projectId) return;

    const result = await createMachine({
      project_id: projectId,
      ...machineForm
    });

    if (result) {
      setShowMachineModal(false);
      setMachineForm({
        name: '',
        description: '',
        start_date: '',
        end_date: '',
        order_number: ''
      });
    }
  };

  const handleUpdateMachine = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingMachine) return;

    await updateMachine(editingMachine.id, machineForm);
    setShowMachineModal(false);
    setEditingMachine(null);
    setMachineForm({
      name: '',
      description: '',
      start_date: '',
      end_date: '',
      order_number: ''
    });
  };

  const handleDeleteMachine = async (id: string) => {
    if (window.confirm('Delete this machine and all its parts?')) {
      await deleteMachine(id);
      if (selectedMachine === id) {
        setSelectedMachine(null);
      }
    }
  };

  const openEditMachine = (machine: ProjectMachine) => {
    setEditingMachine(machine);
    setMachineForm({
      name: machine.name,
      description: machine.description || '',
      start_date: machine.start_date || '',
      end_date: machine.end_date || ''
    });
    setShowMachineModal(true);
  };

  const handleAddOrderNumber = async (machineId: string) => {
    if (!newOrderNumber.trim()) return;

    const result = await createMachineOrderNumber({
      machine_id: machineId,
      order_number: newOrderNumber.trim()
    });

    if (result) {
      setNewOrderNumber('');
    }
  };

  const handleBulkAddOrderNumbers = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!bulkOrderMachineId || !bulkOrderNumberInput.trim()) return;

    const lines = bulkOrderNumberInput.trim().split('\n');
    const orderNumbers: string[] = [];

    for (const line of lines) {
      const trimmedLine = line.trim();
      if (trimmedLine) {
        orderNumbers.push(trimmedLine);
      }
    }

    if (orderNumbers.length === 0) {
      alert('No valid OR number found.');
      return;
    }

    let successCount = 0;
    for (const orderNumber of orderNumbers) {
      const result = await createMachineOrderNumber({
        machine_id: bulkOrderMachineId,
        order_number: orderNumber
      });
      if (result) successCount++;
    }

    if (successCount > 0) {
      setShowBulkOrderModal(false);
      setBulkOrderNumberInput('');
      setBulkOrderMachineId(null);
      alert(`${successCount} OR number(s) added successfully!`);
    }
  };

  const handleCreatePart = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedMachine) return;

    const result = await createMachinePart({
      machine_id: selectedMachine,
      ...partForm
    });

    if (result) {
      setShowPartModal(false);
      setPartForm({
        part_number: '',
        description: '',
        quantity_required: 0
      });
    }
  };

  const handleUpdatePart = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingPart) return;

    await updateMachinePart(editingPart.id, partForm);
    setShowPartModal(false);
    setEditingPart(null);
    setPartForm({
      part_number: '',
      description: '',
      quantity_required: 0
    });
  };

  const handleDeletePart = async (id: string) => {
    if (window.confirm('Delete this part?')) {
      await deleteMachinePart(id);
    }
  };

  const openEditPart = (part: ProjectMachinePart) => {
    setEditingPart(part);
    setPartForm({
      part_number: part.part_number,
      description: part.description || '',
      quantity_required: part.quantity_required
    });
    setBulkPartInput('');
    setShowPartModal(true);
  };

  const handleBulkCreateParts = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedMachine || !bulkPartInput.trim()) return;

    const lines = bulkPartInput.trim().split('\n');
    const parts: Array<{ part_number: string; description: string; quantity_required: number }> = [];

    for (const line of lines) {
      if (!line.trim()) continue;

      const columns = line.split('\t').map(col => col.trim());

      if (columns.length >= 2) {
        const part_number = columns[0];
        const quantity = parseFloat(columns[1]) || 0;
        const description = columns.length >= 3 ? columns[2] : '';

        if (part_number && quantity > 0) {
          parts.push({
            part_number,
            description,
            quantity_required: quantity
          });
        }
      }
    }

    if (parts.length === 0) {
      alert('No valid part found. Expected format:\nPart_number [TAB] Quantity [TAB] Description (optional)');
      return;
    }

    let successCount = 0;
    for (const part of parts) {
      const result = await createMachinePart({
        machine_id: selectedMachine,
        ...part
      });
      if (result) successCount++;
    }

    if (successCount > 0) {
      setShowPartModal(false);
      setBulkPartInput('');
      setPartForm({
        part_number: '',
        description: '',
        quantity_required: 0
      });
      alert(`${successCount} part(s) added successfully!`);
    }
  };

  const handleBulkAddSupplierOrders = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!projectId || !bulkSupplierOrderInput.trim()) return;

    const lines = bulkSupplierOrderInput.trim().split('\n');
    const supplierOrders: string[] = [];

    for (const line of lines) {
      const trimmedLine = line.trim();
      if (trimmedLine) {
        supplierOrders.push(trimmedLine);
      }
    }

    if (supplierOrders.length === 0) {
      alert('No valid supplier order found.');
      return;
    }

    let successCount = 0;
    for (const order of supplierOrders) {
      const result = await createSupplierOrder({
        project_id: projectId,
        supplier_order: order
      });
      if (result) successCount++;
    }

    if (successCount > 0) {
      setShowBulkSupplierModal(false);
      setBulkSupplierOrderInput('');
      alert(`${successCount} supplier order(s) added successfully!`);
    }
  };

  const handleAddSupplierOrder = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!projectId || !newSupplierOrder.trim()) return;

    const result = await createSupplierOrder({
      project_id: projectId,
      supplier_order: newSupplierOrder.trim()
    });

    if (result) {
      setNewSupplierOrder('');
    }
  };

  const handleAddBranch = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!projectId || !newBranch) return;

    const result = await createBranch({
      project_id: projectId,
      branch_code: newBranch
    });

    if (result) {
      setNewBranch('');
    }
  };

  if (isLoading && !currentProject) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-gray-400" />
      </div>
    );
  }

  if (!currentProject) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <p className="text-gray-500 mb-4">Projet non trouvé</p>
          <Link to="/projects" className="text-blue-600 hover:text-blue-700">
            Back to Projects
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-7xl mx-auto">
        <div className="mb-6">
          <Link
            to="/projects"
            className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 transition-colors mb-4"
          >
            <ArrowLeft className="h-5 w-5" />
            Back to Projects
          </Link>

          <div className="flex justify-between items-start">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">{currentProject.name}</h1>
              {currentProject.description && (
                <p className="text-gray-600 mt-2">{currentProject.description}</p>
              )}
            </div>
            <div className="flex gap-3">
              <Link
                to={`/projects/${projectId}/dashboard`}
                className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                <BarChart3 className="h-5 w-5" />
                Comparative Dashboard
              </Link>
              <Link
                to={`/projects/${projectId}/analytics`}
                className="flex items-center gap-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors"
              >
                <TrendingUp className="h-5 w-5" />
                Detailed Analytics
              </Link>
            </div>
          </div>
        </div>

        {error && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
            <p className="text-red-800">{error}</p>
          </div>
        )}

        {/* Project Method Validation */}
        {projectId && (
          <div className="mb-6">
            <ProjectMethodValidation projectId={projectId} />
          </div>
        )}

        <div className="bg-white rounded-lg shadow">
          <div className="border-b">
            <div className="flex">
              <button
                onClick={() => setActiveTab('machines')}
                className={`px-6 py-3 font-medium transition-colors ${
                  activeTab === 'machines'
                    ? 'text-blue-600 border-b-2 border-blue-600'
                    : 'text-gray-600 hover:text-gray-900'
                }`}
              >
                Machines
              </button>
              <button
                onClick={() => setActiveTab('suppliers')}
                className={`px-6 py-3 font-medium transition-colors ${
                  activeTab === 'suppliers'
                    ? 'text-blue-600 border-b-2 border-blue-600'
                    : 'text-gray-600 hover:text-gray-900'
                }`}
              >
                Supplier Orders
              </button>
              <button
                onClick={() => setActiveTab('branches')}
                className={`px-6 py-3 font-medium transition-colors ${
                  activeTab === 'branches'
                    ? 'text-blue-600 border-b-2 border-blue-600'
                    : 'text-gray-600 hover:text-gray-900'
                }`}
              >
                Branches
              </button>
              <button
                onClick={() => setActiveTab('bl')}
                className={`px-6 py-3 font-medium transition-colors ${
                  activeTab === 'bl'
                    ? 'text-blue-600 border-b-2 border-blue-600'
                    : 'text-gray-600 hover:text-gray-900'
                }`}
              >
                <div className="flex items-center gap-2">
                  <Package className="h-4 w-4" />
                  Numéros de BL
                </div>
              </button>
            </div>
          </div>

          <div className="p-6">
            {activeTab === 'machines' && (
              <div>
                <div className="flex justify-between items-center mb-6">
                  <h2 className="text-xl font-semibold text-gray-900">Project Machines</h2>
                  {isAdmin && (
                    <button
                      onClick={() => {
                        setEditingMachine(null);
                        setMachineForm({
                          name: '',
                          description: '',
                          start_date: '',
                          end_date: ''
                        });
                        setShowMachineModal(true);
                      }}
                      className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
                    >
                      <Plus className="h-5 w-5" />
                      Add Machine
                    </button>
                  )}
                </div>

                {machines.length === 0 ? (
                  <p className="text-center text-gray-500 py-8">No machines configured</p>
                ) : (
                  <div className="space-y-4">
                    {machines.map((machine) => (
                      <div key={machine.id} className="border rounded-lg">
                        <div className="p-4 bg-gray-50 flex justify-between items-center">
                          <div className="flex-1">
                            <h3 className="font-semibold text-gray-900">{machine.name}</h3>
                            {machine.description && (
                              <p className="text-sm text-gray-600 mt-1">{machine.description}</p>
                            )}
                          </div>
                          <div className="flex gap-2">
                            <button
                              onClick={() =>
                                setSelectedMachine(selectedMachine === machine.id ? null : machine.id)
                              }
                              className="px-3 py-1 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 transition-colors"
                            >
                              {selectedMachine === machine.id ? 'Close' : 'Parts & ORs'}
                            </button>
                            {isAdmin && (
                              <>
                                <button
                                  onClick={() => openEditMachine(machine)}
                                  className="p-2 border border-gray-300 rounded hover:bg-white transition-colors"
                                >
                                  <Edit2 className="h-4 w-4 text-gray-600" />
                                </button>
                                <button
                                  onClick={() => handleDeleteMachine(machine.id)}
                                  className="p-2 border border-red-300 rounded hover:bg-red-50 transition-colors"
                                >
                                  <Trash2 className="h-4 w-4 text-red-600" />
                                </button>
                              </>
                            )}
                          </div>
                        </div>

                        {selectedMachine === machine.id && (
                          <div className="p-4 border-t space-y-6">
                            <div>
                              <div className="flex justify-between items-center mb-3">
                                <h4 className="font-medium text-gray-900">Linked OR Numbers</h4>
                                {isAdmin && (
                                  <div className="flex gap-2">
                                    <input
                                      type="text"
                                      value={newOrderNumber}
                                      onChange={(e) => setNewOrderNumber(e.target.value)}
                                      placeholder="Ex: OR-2025-001"
                                      className="px-3 py-1 border rounded text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                                      onKeyPress={(e) => {
                                        if (e.key === 'Enter') {
                                          handleAddOrderNumber(machine.id);
                                        }
                                      }}
                                    />
                                    <button
                                      onClick={() => handleAddOrderNumber(machine.id)}
                                      disabled={!newOrderNumber.trim()}
                                      className="px-3 py-1 bg-green-600 text-white text-sm rounded hover:bg-green-700 transition-colors disabled:opacity-50"
                                    >
                                      Add
                                    </button>
                                    <button
                                      onClick={() => {
                                        setBulkOrderMachineId(machine.id);
                                        setShowBulkOrderModal(true);
                                      }}
                                      className="px-3 py-1 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 transition-colors"
                                      title="Add multiple OR numbers at once"
                                    >
                                      <Plus className="h-4 w-4" />
                                    </button>
                                  </div>
                                )}
                              </div>

                              {machineOrderNumbers.length === 0 ? (
                                <p className="text-sm text-gray-500 text-center py-2">No linked OR number</p>
                              ) : (
                                <div className="flex flex-wrap gap-2">
                                  {machineOrderNumbers.map((orderNum) => (
                                    <div
                                      key={orderNum.id}
                                      className="flex items-center gap-2 px-3 py-1 bg-blue-50 border border-blue-200 rounded-full text-sm"
                                    >
                                      <span className="font-medium text-blue-900">{orderNum.order_number}</span>
                                      {isAdmin && (
                                        <button
                                          onClick={() => deleteMachineOrderNumber(orderNum.id)}
                                          className="text-red-600 hover:text-red-700"
                                        >
                                          <X className="h-3 w-3" />
                                        </button>
                                      )}
                                    </div>
                                  ))}
                                </div>
                              )}
                            </div>

                            <div>
                              <div className="flex justify-between items-center mb-4">
                                <h4 className="font-medium text-gray-900">Required Parts</h4>
                              {isAdmin && (
                                <button
                                  onClick={() => {
                                    setEditingPart(null);
                                    setPartForm({
                                      part_number: '',
                                      description: '',
                                      quantity_required: 0
                                    });
                                    setShowPartModal(true);
                                  }}
                                  className="flex items-center gap-2 px-3 py-1 bg-green-600 text-white text-sm rounded hover:bg-green-700 transition-colors"
                                >
                                  <Plus className="h-4 w-4" />
                                  Add Part(s)
                                </button>
                              )}
                            </div>

                            {machineParts.length === 0 ? (
                              <p className="text-center text-gray-500 py-4">No parts configured</p>
                            ) : (
                              <div className="overflow-x-auto">
                                <table className="w-full text-sm">
                                  <thead className="bg-gray-50">
                                    <tr>
                                      <th className="px-4 py-2 text-left font-medium text-gray-700">
                                        Part Number
                                      </th>
                                      <th className="px-4 py-2 text-left font-medium text-gray-700">
                                        Description
                                      </th>
                                      <th className="px-4 py-2 text-left font-medium text-gray-700">
                                        Required Quantity
                                      </th>
                                      {isAdmin && (
                                        <th className="px-4 py-2 text-left font-medium text-gray-700">
                                          Actions
                                        </th>
                                      )}
                                    </tr>
                                  </thead>
                                  <tbody className="divide-y">
                                    {machineParts.map((part) => (
                                      <tr key={part.id} className="hover:bg-gray-50">
                                        <td className="px-4 py-2">{part.part_number}</td>
                                        <td className="px-4 py-2">{part.description || '-'}</td>
                                        <td className="px-4 py-2">{part.quantity_required}</td>
                                        {isAdmin && (
                                          <td className="px-4 py-2">
                                            <div className="flex gap-2">
                                              <button
                                                onClick={() => openEditPart(part)}
                                                className="p-1 border border-gray-300 rounded hover:bg-white transition-colors"
                                              >
                                                <Edit2 className="h-3 w-3 text-gray-600" />
                                              </button>
                                              <button
                                                onClick={() => handleDeletePart(part.id)}
                                                className="p-1 border border-red-300 rounded hover:bg-red-50 transition-colors"
                                              >
                                                <Trash2 className="h-3 w-3 text-red-600" />
                                              </button>
                                            </div>
                                          </td>
                                        )}
                                      </tr>
                                    ))}
                                  </tbody>
                                </table>
                              </div>
                            )}
                            </div>
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {activeTab === 'suppliers' && (
              <div>
                <h2 className="text-xl font-semibold text-gray-900 mb-6">Supplier Orders</h2>

                {isAdmin && (
                  <div className="mb-6 space-y-3">
                    <form onSubmit={handleAddSupplierOrder}>
                      <div className="flex gap-2">
                        <input
                          type="text"
                          value={newSupplierOrder}
                          onChange={(e) => setNewSupplierOrder(e.target.value)}
                          placeholder="Supplier order number"
                          className="flex-1 px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                        />
                        <button
                          type="submit"
                          disabled={!newSupplierOrder.trim()}
                          className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50"
                        >
                          Add
                        </button>
                        <button
                          type="button"
                          onClick={() => setShowBulkSupplierModal(true)}
                          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-2"
                          title="Add multiple orders at once"
                        >
                          <Plus className="h-5 w-5" />
                          <span>Ajout multiple</span>
                        </button>
                      </div>
                    </form>
                  </div>
                )}

                {supplierOrders.length === 0 ? (
                  <p className="text-center text-gray-500 py-8">No supplier orders</p>
                ) : (
                  <div className="space-y-2">
                    {supplierOrders.map((order) => (
                      <div
                        key={order.id}
                        className="flex justify-between items-center p-3 border rounded-lg hover:bg-gray-50"
                      >
                        <div>
                          <p className="font-medium text-gray-900">{order.supplier_order}</p>
                          {order.description && (
                            <p className="text-sm text-gray-600">{order.description}</p>
                          )}
                        </div>
                        {isAdmin && (
                          <button
                            onClick={() => deleteSupplierOrder(order.id)}
                            className="p-2 border border-red-300 rounded hover:bg-red-50 transition-colors"
                          >
                            <Trash2 className="h-4 w-4 text-red-600" />
                          </button>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {activeTab === 'branches' && (
              <div>
                <h2 className="text-xl font-semibold text-gray-900 mb-6">
                  Branches pour vérification du stock
                </h2>

                {isAdmin && (
                  <form onSubmit={handleAddBranch} className="mb-6">
                    <div className="flex gap-2">
                      <select
                        value={newBranch}
                        onChange={(e) => setNewBranch(e.target.value)}
                        className="flex-1 px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                      >
                        <option value="">Select a branch</option>
                        {BRANCH_OPTIONS.filter(
                          (option) => !branches.find((b) => b.branch_code === option.value)
                        ).map((option) => (
                          <option key={option.value} value={option.value}>
                            {option.label}
                          </option>
                        ))}
                      </select>
                      <button
                        type="submit"
                        disabled={!newBranch}
                        className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50"
                      >
                        Add
                      </button>
                    </div>
                  </form>
                )}

                {branches.length === 0 ? (
                  <p className="text-center text-gray-500 py-8">No branch selected</p>
                ) : (
                  <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
                    {branches.map((branch) => (
                      <div
                        key={branch.id}
                        className="flex justify-between items-center p-3 border rounded-lg hover:bg-gray-50"
                      >
                        <span className="font-medium text-gray-900">
                          {BRANCH_OPTIONS.find((o) => o.value === branch.branch_code)?.label ||
                            branch.branch_code}
                        </span>
                        {isAdmin && (
                          <button
                            onClick={() => deleteBranch(branch.id)}
                            className="p-1 border border-red-300 rounded hover:bg-red-50 transition-colors"
                          >
                            <Trash2 className="h-3 w-3 text-red-600" />
                          </button>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {activeTab === 'bl' && (
              <div>
                <ProjectBLManagement
                  projectId={projectId!}
                  blNumbers={blNumbers}
                  onCreateBLNumber={createBLNumber}
                  onDeleteBLNumber={deleteBLNumber}
                  isLoading={isLoading}
                />
              </div>
            )}
          </div>
        </div>

        {showMachineModal && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-lg max-w-2xl w-full">
              <div className="p-6">
                <h2 className="text-2xl font-bold text-gray-900 mb-6">
                  {editingMachine ? 'Edit Machine' : 'New Machine'}
                </h2>

                <form onSubmit={editingMachine ? handleUpdateMachine : handleCreateMachine} className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Machine Name *
                    </label>
                    <input
                      type="text"
                      required
                      value={machineForm.name}
                      onChange={(e) => setMachineForm({ ...machineForm, name: e.target.value })}
                      className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                      placeholder="Ex: Machine 1"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Description
                    </label>
                    <textarea
                      value={machineForm.description}
                      onChange={(e) => setMachineForm({ ...machineForm, description: e.target.value })}
                      className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                      rows={2}
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Start Date
                      </label>
                      <input
                        type="date"
                        value={machineForm.start_date}
                        onChange={(e) => setMachineForm({ ...machineForm, start_date: e.target.value })}
                        className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                      />
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        End Date
                      </label>
                      <input
                        type="date"
                        value={machineForm.end_date}
                        onChange={(e) => setMachineForm({ ...machineForm, end_date: e.target.value })}
                        className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                      />
                    </div>
                  </div>

                  <div className="flex gap-3 pt-4">
                    <button
                      type="submit"
                      className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
                    >
                      {editingMachine ? 'Save' : 'Create'}
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setShowMachineModal(false);
                        setEditingMachine(null);
                      }}
                      className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                    >
                      Cancel
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        )}

        {showPartModal && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-lg max-w-4xl w-full max-h-[90vh] overflow-y-auto">
              <div className="p-6">
                <h2 className="text-2xl font-bold text-gray-900 mb-6">
                  {editingPart ? 'Edit Part' : 'Add Parts'}
                </h2>

                {!editingPart && (
                  <div className="mb-6">
                    <div className="flex gap-2 mb-4 border-b">
                      <button
                        type="button"
                        onClick={() => setBulkPartInput('')}
                        className={`px-4 py-2 font-medium transition-colors ${
                          !bulkPartInput
                            ? 'text-blue-600 border-b-2 border-blue-600'
                            : 'text-gray-600 hover:text-gray-900'
                        }`}
                      >
                        Ajout simple
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          if (!bulkPartInput) {
                            setBulkPartInput('123-456\t5\tPart description 1\n789-012\t10\tPart description 2');
                          }
                        }}
                        className={`px-4 py-2 font-medium transition-colors ${
                          bulkPartInput
                            ? 'text-blue-600 border-b-2 border-blue-600'
                            : 'text-gray-600 hover:text-gray-900'
                        }`}
                      >
                        Ajout en masse (copier-coller)
                      </button>
                    </div>
                  </div>
                )}

                {editingPart || !bulkPartInput ? (
                  <form onSubmit={editingPart ? handleUpdatePart : handleCreatePart} className="space-y-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Part Number *
                      </label>
                      <input
                        type="text"
                        required
                        value={partForm.part_number}
                        onChange={(e) => setPartForm({ ...partForm, part_number: e.target.value })}
                        className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                        placeholder="Ex: 123-456-789"
                      />
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Description
                      </label>
                      <input
                        type="text"
                        value={partForm.description}
                        onChange={(e) => setPartForm({ ...partForm, description: e.target.value })}
                        className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                      />
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Required Quantity *
                      </label>
                      <input
                        type="number"
                        required
                        min="0"
                        step="1"
                        value={partForm.quantity_required}
                        onChange={(e) =>
                          setPartForm({ ...partForm, quantity_required: parseFloat(e.target.value) || 0 })
                        }
                        className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                      />
                    </div>

                    <div className="flex gap-3 pt-4">
                      <button
                        type="submit"
                        className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
                      >
                        {editingPart ? 'Save' : 'Create'}
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          setShowPartModal(false);
                          setEditingPart(null);
                          setBulkPartInput('');
                        }}
                        className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                      >
                        Cancel
                      </button>
                    </div>
                  </form>
                ) : (
                  <form onSubmit={handleBulkCreateParts} className="space-y-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        Collez vos données ici (séparées par tabulations)
                      </label>
                      <div className="mb-2 p-3 bg-blue-50 border border-blue-200 rounded-lg text-sm text-blue-800">
                        <p className="font-medium mb-1">Format attendu (séparation par TAB):</p>
                        <p className="font-mono text-xs mb-2">Part_number [TAB] Quantity [TAB] Description (optional)</p>
                        <p className="text-xs">
                          💡 Copiez directement depuis Excel/Sheets: sélectionnez vos colonnes et faites Ctrl+C puis Ctrl+V ici
                        </p>
                      </div>
                      <textarea
                        value={bulkPartInput}
                        onChange={(e) => setBulkPartInput(e.target.value)}
                        className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none font-mono text-sm"
                        rows={12}
                        placeholder="Example:
123-456	5	Part description 1
789-012	10	Part description 2
345-678	3	Part description 3"
                      />
                      <p className="text-xs text-gray-500 mt-2">
                        {bulkPartInput.trim().split('\n').filter(line => line.trim()).length} line(s) detected
                      </p>
                    </div>

                    <div className="flex gap-3 pt-4">
                      <button
                        type="submit"
                        disabled={!bulkPartInput.trim()}
                        className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50"
                      >
                        Import Parts
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          setShowPartModal(false);
                          setEditingPart(null);
                          setBulkPartInput('');
                        }}
                        className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                      >
                        Cancel
                      </button>
                    </div>
                  </form>
                )}
              </div>
            </div>
          </div>
        )}

        {showBulkOrderModal && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
              <div className="p-6">
                <h2 className="text-2xl font-bold text-gray-900 mb-6">
                  Add Multiple OR Numbers
                </h2>

                <form onSubmit={handleBulkAddOrderNumbers} className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      OR Numbers (one per line)
                    </label>
                    <div className="mb-2 p-3 bg-blue-50 border border-blue-200 rounded-lg text-sm text-blue-800">
                      <p className="font-medium mb-1">Format attendu:</p>
                      <p className="text-xs mb-2">One OR number per line</p>
                      <p className="text-xs">
                        💡 Copiez une colonne depuis Excel/Sheets et collez-la ici
                      </p>
                    </div>
                    <textarea
                      value={bulkOrderNumberInput}
                      onChange={(e) => setBulkOrderNumberInput(e.target.value)}
                      className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none font-mono text-sm"
                      rows={10}
                      placeholder="Exemple:
OR-2025-001
OR-2025-002
OR-2025-003
OR-2025-004"
                    />
                    <p className="text-xs text-gray-500 mt-2">
                      {bulkOrderNumberInput.trim().split('\n').filter(line => line.trim()).length} number(s) detected
                    </p>
                  </div>

                  <div className="flex gap-3 pt-4">
                    <button
                      type="submit"
                      disabled={!bulkOrderNumberInput.trim()}
                      className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50"
                    >
                      Import OR Numbers
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setShowBulkOrderModal(false);
                        setBulkOrderNumberInput('');
                        setBulkOrderMachineId(null);
                      }}
                      className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                    >
                      Cancel
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        )}

        {showBulkSupplierModal && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
              <div className="p-6">
                <h2 className="text-2xl font-bold text-gray-900 mb-6">
                  Add Multiple Supplier Orders
                </h2>

                <form onSubmit={handleBulkAddSupplierOrders} className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Supplier Orders (one per line)
                    </label>
                    <div className="mb-2 p-3 bg-blue-50 border border-blue-200 rounded-lg text-sm text-blue-800">
                      <p className="font-medium mb-1">Format attendu:</p>
                      <p className="text-xs mb-2">One supplier order per line</p>
                      <p className="text-xs">
                        💡 Copiez une colonne depuis Excel/Sheets et collez-la ici
                      </p>
                    </div>
                    <textarea
                      value={bulkSupplierOrderInput}
                      onChange={(e) => setBulkSupplierOrderInput(e.target.value)}
                      className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none font-mono text-sm"
                      rows={10}
                      placeholder="Exemple:
CF-2025-001
CF-2025-002
CF-2025-003
CF-2025-004"
                    />
                    <p className="text-xs text-gray-500 mt-2">
                      {bulkSupplierOrderInput.trim().split('\n').filter(line => line.trim()).length} order(s) detected
                    </p>
                  </div>

                  <div className="flex gap-3 pt-4">
                    <button
                      type="submit"
                      disabled={!bulkSupplierOrderInput.trim()}
                      className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50"
                    >
                      Import Orders
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setShowBulkSupplierModal(false);
                        setBulkSupplierOrderInput('');
                      }}
                      className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                    >
                      Cancel
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}