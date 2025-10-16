import React, { useState } from 'react';
import { AlertTriangle, CheckCircle, X, Info } from 'lucide-react';

interface ImportReport {
  totalRowsImported: number;
  analyzedRows: number;
  columnMappingIssues: Array<{
    column: string;
    issue: string;
    count: number;
    examples: string[];
  }>;
  suspiciousValues: Array<{
    value: string;
    columns: string[];
    count: number;
  }>;
}

interface ImportReportDisplayProps {
  report: ImportReport | null;
  onClose: () => void;
}

export function ImportReportDisplay({ report, onClose }: ImportReportDisplayProps) {
  if (!report) return null;

  const hasIssues = report.columnMappingIssues.length > 0;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg max-w-4xl w-full max-h-[90vh] overflow-y-auto">
        <div className="p-6">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-2xl font-bold text-gray-900">
              Rapport d'Import - Table Parts
            </h2>
            <button
              onClick={onClose}
              className="p-2 hover:bg-gray-100 rounded-full transition-colors"
            >
              <X className="h-6 w-6 text-gray-500" />
            </button>
          </div>

          {/* Résumé */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
            <div className="bg-blue-50 p-4 rounded-lg">
              <div className="flex items-center">
                <Info className="h-8 w-8 text-blue-600 mr-3" />
                <div>
                  <p className="text-sm font-medium text-blue-800">Total Importé</p>
                  <p className="text-2xl font-bold text-blue-900">{report.totalRowsImported.toLocaleString()}</p>
                </div>
              </div>
            </div>
            <div className="bg-green-50 p-4 rounded-lg">
              <div className="flex items-center">
                <CheckCircle className="h-8 w-8 text-green-600 mr-3" />
                <div>
                  <p className="text-sm font-medium text-green-800">Analysées</p>
                  <p className="text-2xl font-bold text-green-900">{report.analyzedRows.toLocaleString()}</p>
                </div>
              </div>
            </div>
            <div className={`p-4 rounded-lg ${hasIssues ? 'bg-red-50' : 'bg-green-50'}`}>
              <div className="flex items-center">
                {hasIssues ? (
                  <AlertTriangle className="h-8 w-8 text-red-600 mr-3" />
                ) : (
                  <CheckCircle className="h-8 w-8 text-green-600 mr-3" />
                )}
                <div>
                  <p className={`text-sm font-medium ${hasIssues ? 'text-red-800' : 'text-green-800'}`}>
                    Statut
                  </p>
                  <p className={`text-lg font-bold ${hasIssues ? 'text-red-900' : 'text-green-900'}`}>
                    {hasIssues ? 'Problèmes Détectés' : 'Import Réussi'}
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Valeurs suspectes - Supprimé car pas pertinent pour le mapping */}

          {/* Problèmes de mapping */}
          {report.columnMappingIssues.length > 0 && (
            <div className="mb-6">
              <h3 className="text-lg font-semibold text-orange-800 mb-3 flex items-center">
                <AlertTriangle className="h-5 w-5 mr-2" />
                Problèmes de Mapping CSV Détectés
              </h3>
              <div className="space-y-3">
                {report.columnMappingIssues.map((issue, index) => (
                  <div key={index} className="bg-orange-50 border border-orange-200 rounded-lg p-4">
                    <div className="flex justify-between items-start mb-2">
                      <h4 className="font-medium text-orange-800">
                        Colonne "{issue.column}"
                      </h4>
                      <span className="text-sm text-orange-600 bg-orange-100 px-2 py-1 rounded">
                        {issue.count} lignes
                      </span>
                    </div>
                    <p className="text-sm text-orange-700 mb-2">
                      {issue.issue}
                    </p>
                    {issue.examples.length > 0 && (
                      <div>
                        <p className="text-xs text-orange-600 mb-1">Exemples de valeurs:</p>
                        <div className="flex flex-wrap gap-1">
                          {issue.examples.map((example, exIndex) => (
                            <span key={exIndex} className="text-xs bg-orange-100 text-orange-800 px-2 py-1 rounded">
                              "{example}"
                            </span>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Message de succès */}
          {!hasIssues && (
            <div className="bg-green-50 border border-green-200 rounded-lg p-6 text-center">
              <CheckCircle className="h-12 w-12 text-green-600 mx-auto mb-4" />
              <h3 className="text-lg font-semibold text-green-800 mb-2">
                Mapping CSV Réussi !
              </h3>
              <p className="text-green-700">
                Toutes les colonnes CSV ont été correctement mappées vers la base de données. Aucun problème de mapping détecté.
              </p>
            </div>
          )}

          {/* Recommandations */}
          {hasIssues && (
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <h4 className="font-medium text-blue-800 mb-2">Recommandations pour corriger le mapping:</h4>
              <ul className="text-sm text-blue-700 space-y-1">
                <li>• Vérifiez que votre fichier CSV a exactement 23 colonnes</li>
                <li>• Assurez-vous que les en-têtes correspondent au template fourni</li>
                <li>• Vérifiez que les données sont dans les bonnes colonnes selon leur position</li>
                <li>• Les colonnes numériques doivent contenir uniquement des nombres</li>
                <li>• Les colonnes de date doivent être au format DD/MM/YYYY ou DD-MM-YYYY</li>
                <li>• Utilisez le template CSV fourni comme référence</li>
                <li>• Réessayez l'import après correction</li>
              </ul>
            </div>
          )}

          <div className="flex justify-end mt-6">
            <button
              onClick={onClose}
              className="px-6 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors"
            >
              Fermer
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
