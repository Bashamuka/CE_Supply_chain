import React, { useState, useEffect } from 'react';
import { AlertTriangle, CheckCircle, FileText, Package, Settings } from 'lucide-react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';

interface ProjectMethodValidationProps {
  projectId: string;
  onValidationChange?: (hasMixedMethods: boolean) => void;
}

interface ValidationResult {
  hasORs: boolean;
  hasBLs: boolean;
  hasMixedMethods: boolean;
  orCount: number;
  blCount: number;
  recommendation: string;
}

export function ProjectMethodValidation({ projectId, onValidationChange }: ProjectMethodValidationProps) {
  const [validation, setValidation] = useState<ValidationResult | null>(null);
  const [loading, setLoading] = useState(true);

  const checkProjectMethods = async () => {
    if (!projectId) return;

    try {
      setLoading(true);

      // Check for ORs (machine order numbers)
      const { data: orData, error: orError } = await supabase
        .from('project_machine_order_numbers')
        .select('id')
        .in('machine_id', 
          supabase
            .from('project_machines')
            .select('id')
            .eq('project_id', projectId)
        );

      if (orError) throw orError;

      // Check for BLs
      const { data: blData, error: blError } = await supabase
        .from('project_bl_numbers')
        .select('id')
        .eq('project_id', projectId);

      if (blError) throw blError;

      const orCount = orData?.length || 0;
      const blCount = blData?.length || 0;
      const hasORs = orCount > 0;
      const hasBLs = blCount > 0;
      const hasMixedMethods = hasORs && hasBLs;

      let recommendation = '';
      if (hasMixedMethods) {
        recommendation = 'Ce projet utilise les deux méthodes de calcul. Veuillez choisir une seule méthode pour éviter les conflits.';
      } else if (hasORs && !hasBLs) {
        recommendation = 'Ce projet utilise la méthode OR-based. Vous pouvez ajouter des numéros de BL pour basculer vers OTC-based.';
      } else if (hasBLs && !hasORs) {
        recommendation = 'Ce projet utilise la méthode OTC-based. Vous pouvez ajouter des numéros de commande pour basculer vers OR-based.';
      } else {
        recommendation = 'Ce projet n\'utilise aucune méthode de calcul. Ajoutez des numéros de commande ou des BL pour commencer.';
      }

      const result: ValidationResult = {
        hasORs,
        hasBLs,
        hasMixedMethods,
        orCount,
        blCount,
        recommendation
      };

      setValidation(result);
      onValidationChange?.(hasMixedMethods);
    } catch (error) {
      console.error('Error checking project methods:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    checkProjectMethods();
  }, [projectId]);

  if (loading) {
    return (
      <div className="bg-gray-50 rounded-lg p-4">
        <div className="flex items-center gap-2">
          <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
          <span className="text-sm text-gray-600">Vérification des méthodes de calcul...</span>
        </div>
      </div>
    );
  }

  if (!validation) {
    return null;
  }

  const getStatusIcon = () => {
    if (validation.hasMixedMethods) {
      return <AlertTriangle className="h-5 w-5 text-red-500" />;
    } else if (validation.hasORs || validation.hasBLs) {
      return <CheckCircle className="h-5 w-5 text-green-500" />;
    } else {
      return <Settings className="h-5 w-5 text-gray-500" />;
    }
  };

  const getStatusColor = () => {
    if (validation.hasMixedMethods) {
      return 'bg-red-50 border-red-200 text-red-800';
    } else if (validation.hasORs || validation.hasBLs) {
      return 'bg-green-50 border-green-200 text-green-800';
    } else {
      return 'bg-gray-50 border-gray-200 text-gray-800';
    }
  };

  return (
    <div className={`rounded-lg p-4 border ${getStatusColor()}`}>
      <div className="flex items-start gap-3">
        {getStatusIcon()}
        <div className="flex-1">
          <h3 className="font-semibold mb-2">Statut des Méthodes de Calcul</h3>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-3">
            <div className="flex items-center gap-2">
              <FileText className="h-4 w-4 text-blue-600" />
              <span className="text-sm">
                <strong>ORs:</strong> {validation.orCount} numéro(s)
              </span>
            </div>
            <div className="flex items-center gap-2">
              <Package className="h-4 w-4 text-purple-600" />
              <span className="text-sm">
                <strong>BLs:</strong> {validation.blCount} numéro(s)
              </span>
            </div>
          </div>

          <p className="text-sm mb-3">{validation.recommendation}</p>

          {validation.hasMixedMethods && (
            <div className="bg-red-100 border border-red-300 rounded-lg p-3 mb-3">
              <div className="flex items-center gap-2 mb-2">
                <AlertTriangle className="h-4 w-4 text-red-600" />
                <span className="font-semibold text-red-800">Action Requise</span>
              </div>
              <p className="text-sm text-red-700 mb-2">
                Ce projet utilise les deux méthodes de calcul simultanément. Cela peut causer des incohérences dans les calculs.
              </p>
              <div className="flex gap-2">
                <button
                  onClick={() => window.location.reload()}
                  className="inline-flex items-center gap-1 px-3 py-1 bg-red-600 text-white rounded text-sm hover:bg-red-700 transition-colors"
                >
                  <Settings className="h-3 w-3" />
                  Actualiser la page
                </button>
              </div>
            </div>
          )}

          {!validation.hasMixedMethods && (validation.hasORs || validation.hasBLs) && (
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
              <div className="flex items-center gap-2 mb-2">
                <CheckCircle className="h-4 w-4 text-blue-600" />
                <span className="font-semibold text-blue-800">Configuration Valide</span>
              </div>
              <p className="text-sm text-blue-700">
                Ce projet utilise une seule méthode de calcul. Les calculs seront cohérents.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
