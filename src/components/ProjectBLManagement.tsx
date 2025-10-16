import React, { useState } from 'react';
import { Plus, Trash2, Package, AlertTriangle, CheckCircle, Loader2 } from 'lucide-react';
import { ProjectBLNumber } from '../types';

interface ProjectBLManagementProps {
  projectId: string;
  blNumbers: ProjectBLNumber[];
  onCreateBLNumber: (data: { project_id: string; bl_number: string; description?: string }) => Promise<boolean>;
  onDeleteBLNumber: (id: string) => Promise<boolean>;
  isLoading?: boolean;
}

export function ProjectBLManagement({
  projectId,
  blNumbers,
  onCreateBLNumber,
  onDeleteBLNumber,
  isLoading = false
}: ProjectBLManagementProps) {
  const [newBLNumber, setNewBLNumber] = useState('');
  const [newBLDescription, setNewBLDescription] = useState('');
  const [showBulkModal, setShowBulkModal] = useState(false);
  const [bulkBLInput, setBulkBLInput] = useState('');
  const [isCreating, setIsCreating] = useState(false);
  const [isDeleting, setIsDeleting] = useState<string | null>(null);

  const handleAddBLNumber = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newBLNumber.trim()) return;

    setIsCreating(true);
    try {
      const result = await onCreateBLNumber({
        project_id: projectId,
        bl_number: newBLNumber.trim(),
        description: newBLDescription.trim() || undefined
      });

      if (result) {
        setNewBLNumber('');
        setNewBLDescription('');
      }
    } finally {
      setIsCreating(false);
    }
  };

  const handleBulkAddBLNumbers = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!bulkBLInput.trim()) return;

    const lines = bulkBLInput.trim().split('\n');
    const blNumbers: string[] = [];

    for (const line of lines) {
      const trimmedLine = line.trim();
      if (trimmedLine) {
        blNumbers.push(trimmedLine);
      }
    }

    if (blNumbers.length === 0) {
      alert('Aucun numéro de BL valide trouvé.');
      return;
    }

    setIsCreating(true);
    let successCount = 0;
    
    try {
      for (const blNumber of blNumbers) {
        const result = await onCreateBLNumber({
          project_id: projectId,
          bl_number: blNumber
        });
        if (result) successCount++;
      }

      if (successCount > 0) {
        setShowBulkModal(false);
        setBulkBLInput('');
        alert(`${successCount} numéro(s) de BL ajouté(s) avec succès !`);
      }
    } finally {
      setIsCreating(false);
    }
  };

  const handleDeleteBLNumber = async (id: string) => {
    if (!window.confirm('Êtes-vous sûr de vouloir supprimer ce numéro de BL ?')) return;

    setIsDeleting(id);
    try {
      await onDeleteBLNumber(id);
    } finally {
      setIsDeleting(null);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-2">
          <Package className="h-5 w-5 text-purple-600" />
          <h3 className="text-lg font-semibold text-gray-900">Gestion des Numéros de BL</h3>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setShowBulkModal(true)}
            className="flex items-center gap-2 px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors text-sm"
          >
            <Plus className="h-4 w-4" />
            Ajout en lot
          </button>
        </div>
      </div>

      {/* Information Panel */}
      <div className="bg-gradient-to-r from-purple-50 to-indigo-50 rounded-lg p-4 border border-purple-200">
        <div className="flex items-start gap-3">
          <Package className="h-5 w-5 text-purple-600 mt-0.5" />
          <div>
            <h4 className="font-semibold text-gray-900 mb-2">Méthode de Calcul OTC-Based</h4>
            <p className="text-sm text-gray-600 mb-2">
              Les numéros de BL (Bon de Livraison) permettent de calculer les sorties de pièces via le module OTC.
            </p>
            <ul className="text-xs text-gray-500 space-y-1">
              <li>• Basé sur les données de la table otc_orders</li>
              <li>• Calcul cumulatif au niveau du projet</li>
              <li>• Pas de duplication entre machines</li>
              <li>• Utilise la quantité livrée (qte_livree) des BL</li>
            </ul>
          </div>
        </div>
      </div>

      {/* Add New BL Number Form */}
      <div className="bg-white rounded-lg border border-gray-200 p-4">
        <h4 className="font-medium text-gray-900 mb-3">Ajouter un Numéro de BL</h4>
        <form onSubmit={handleAddBLNumber} className="space-y-3">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Numéro de BL *
              </label>
              <input
                type="text"
                value={newBLNumber}
                onChange={(e) => setNewBLNumber(e.target.value)}
                placeholder="Ex: BL-2024-001"
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Description (optionnel)
              </label>
              <input
                type="text"
                value={newBLDescription}
                onChange={(e) => setNewBLDescription(e.target.value)}
                placeholder="Description du BL"
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
              />
            </div>
          </div>
          <button
            type="submit"
            disabled={isCreating || !newBLNumber.trim()}
            className="flex items-center gap-2 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isCreating ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" />
                <span>Ajout en cours...</span>
              </>
            ) : (
              <>
                <Plus className="h-4 w-4" />
                <span>Ajouter le BL</span>
              </>
            )}
          </button>
        </form>
      </div>

      {/* BL Numbers List */}
      <div className="bg-white rounded-lg border border-gray-200">
        <div className="px-4 py-3 border-b border-gray-200">
          <h4 className="font-medium text-gray-900">
            Numéros de BL ({blNumbers.length})
          </h4>
        </div>
        
        {blNumbers.length === 0 ? (
          <div className="text-center py-8">
            <Package className="h-12 w-12 text-gray-400 mx-auto mb-3" />
            <p className="text-gray-500">Aucun numéro de BL configuré</p>
            <p className="text-sm text-gray-400">Ajoutez des numéros de BL pour utiliser la méthode de calcul OTC-based</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-200">
            {blNumbers.map((blNumber) => (
              <div key={blNumber.id} className="px-4 py-3 flex items-center justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <Package className="h-4 w-4 text-purple-600" />
                    <span className="font-medium text-gray-900">{blNumber.bl_number}</span>
                  </div>
                  {blNumber.description && (
                    <p className="text-sm text-gray-500 mt-1">{blNumber.description}</p>
                  )}
                  <p className="text-xs text-gray-400 mt-1">
                    Ajouté le {new Date(blNumber.created_at!).toLocaleDateString('fr-FR')}
                  </p>
                </div>
                <button
                  onClick={() => handleDeleteBLNumber(blNumber.id)}
                  disabled={isDeleting === blNumber.id}
                  className="flex items-center gap-1 px-2 py-1 text-red-600 hover:text-red-700 hover:bg-red-50 rounded transition-colors disabled:opacity-50"
                >
                  {isDeleting === blNumber.id ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    <Trash2 className="h-4 w-4" />
                  )}
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Bulk Add Modal */}
      {showBulkModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-md mx-4">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Ajout en Lot de Numéros de BL</h3>
            <form onSubmit={handleBulkAddBLNumbers} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Numéros de BL (un par ligne)
                </label>
                <textarea
                  value={bulkBLInput}
                  onChange={(e) => setBulkBLInput(e.target.value)}
                  placeholder="BL-2024-001&#10;BL-2024-002&#10;BL-2024-003"
                  rows={6}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                />
              </div>
              <div className="flex justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setShowBulkModal(false)}
                  className="px-4 py-2 text-gray-600 hover:text-gray-800 transition-colors"
                >
                  Annuler
                </button>
                <button
                  type="submit"
                  disabled={isCreating || !bulkBLInput.trim()}
                  className="flex items-center gap-2 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isCreating ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      <span>Ajout en cours...</span>
                    </>
                  ) : (
                    <>
                      <Plus className="h-4 w-4" />
                      <span>Ajouter</span>
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
