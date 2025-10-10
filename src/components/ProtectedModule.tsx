import React, { useEffect, useState } from 'react';
import { Lock, AlertCircle, X, ArrowLeft } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useUserStore } from '../store/userStore';
import { useAdminStore } from '../store/adminStore';
import type { ModuleName } from '../types';

interface ProtectedModuleProps {
  moduleName: ModuleName;
  moduleLabel: string;
  children: React.ReactNode;
}

export default function ProtectedModule({ moduleName, moduleLabel, children }: ProtectedModuleProps) {
  const navigate = useNavigate();
  const { user } = useUserStore();
  const { checkModuleAccess } = useAdminStore();
  const [hasAccess, setHasAccess] = useState<boolean | null>(null);
  const [loading, setLoading] = useState(true);
  const [showDeniedModal, setShowDeniedModal] = useState(false);

  useEffect(() => {
    const checkAccess = async () => {
      if (!user) {
        setHasAccess(false);
        setLoading(false);
        setShowDeniedModal(true);
        return;
      }

      if (user.role === 'admin') {
        setHasAccess(true);
        setLoading(false);
        return;
      }

      try {
        const access = await checkModuleAccess(user.id, moduleName);
        setHasAccess(access);
        if (!access) {
          setShowDeniedModal(true);
        }
      } catch (error) {
        console.error('Error checking module access:', error);
        setHasAccess(false);
        setShowDeniedModal(true);
      } finally {
        setLoading(false);
      }
    };

    checkAccess();
  }, [user, moduleName]);

  const handleClose = () => {
    setShowDeniedModal(false);
    navigate('/');
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Vérification des permissions...</p>
        </div>
      </div>
    );
  }

  if (!hasAccess && showDeniedModal) {
    return (
      <>
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full transform transition-all">
            <div className="p-6">
              <div className="flex justify-between items-start mb-4">
                <div className="flex-1">
                  <div className="flex items-center justify-center mb-4">
                    <div className="relative">
                      <div className="bg-red-100 rounded-full p-4">
                        <Lock className="w-12 h-12 text-red-600" />
                      </div>
                      <div className="absolute -bottom-1 -right-1 bg-yellow-500 rounded-full p-1">
                        <AlertCircle className="w-5 h-5 text-white" />
                      </div>
                    </div>
                  </div>
                  <h2 className="text-2xl font-bold text-gray-900 text-center mb-2">
                    Accès Refusé
                  </h2>
                </div>
                <button
                  onClick={handleClose}
                  className="text-gray-400 hover:text-gray-600 transition-colors"
                >
                  <X className="w-6 h-6" />
                </button>
              </div>

              <div className="space-y-4">
                <p className="text-gray-600 text-center">
                  Vous n'avez pas les droits nécessaires pour accéder au module{' '}
                  <span className="font-semibold text-gray-900">{moduleLabel}</span>.
                </p>

                <div className="bg-yellow-50 border-l-4 border-yellow-400 p-4 rounded">
                  <div className="flex">
                    <AlertCircle className="w-5 h-5 text-yellow-600 mt-0.5 mr-3 flex-shrink-0" />
                    <div>
                      <p className="text-sm text-yellow-800">
                        <strong>Note :</strong> Si vous pensez que vous devriez avoir accès à ce module,
                        veuillez contacter un administrateur pour obtenir les permissions appropriées.
                      </p>
                    </div>
                  </div>
                </div>

                <button
                  onClick={handleClose}
                  className="w-full flex items-center justify-center space-x-2 px-4 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
                >
                  <ArrowLeft className="w-5 h-5" />
                  <span>Retour au Dashboard</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </>
    );
  }

  if (!hasAccess) {
    return null;
  }

  return <>{children}</>;
}