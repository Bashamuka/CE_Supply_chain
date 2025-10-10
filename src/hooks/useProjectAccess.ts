import { useEffect, useState } from 'react';
import { useUserStore } from '../store/userStore';
import { useAdminStore } from '../store/adminStore';

export function useProjectAccess(projectId: string | undefined) {
  const { user } = useUserStore();
  const { checkProjectAccess } = useAdminStore();
  const [hasAccess, setHasAccess] = useState<boolean | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const checkAccess = async () => {
      if (!user || !projectId) {
        setHasAccess(false);
        setLoading(false);
        return;
      }

      if (user.role === 'admin') {
        setHasAccess(true);
        setLoading(false);
        return;
      }

      try {
        const access = await checkProjectAccess(user.id, projectId);
        setHasAccess(access);
      } catch (error) {
        console.error('Error checking project access:', error);
        setHasAccess(false);
      } finally {
        setLoading(false);
      }
    };

    checkAccess();
  }, [user, projectId]);

  return { hasAccess, loading };
}