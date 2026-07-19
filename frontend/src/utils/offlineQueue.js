/**
 * offlineQueue.js
 * ───────────────
 * localStorage-backed queue for mutations made while the user is offline.
 *
 * Usage:
 *   import OfflineQueue from './offlineQueue';
 *
 *   // Enqueue when offline (instead of calling API directly)
 *   OfflineQueue.push({ endpoint: '/api/v1/health/snapshots/', method: 'POST', payload: {...} });
 *
 *   // Flush when back online (called automatically by SyncContext)
 *   await OfflineQueue.flush(apiClient);
 */

const STORAGE_KEY = 'fhc_offline_queue';

const OfflineQueue = {
  /** Read all queued mutations. */
  getAll() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
    } catch {
      return [];
    }
  },

  /** Add one mutation to the queue. */
  push(mutation) {
    const queue = this.getAll();
    queue.push({
      ...mutation,
      client_timestamp: new Date().toISOString(),
      _id: `${Date.now()}_${Math.random().toString(36).slice(2)}`,
    });
    localStorage.setItem(STORAGE_KEY, JSON.stringify(queue));
  },

  /** Clear the entire queue. */
  clear() {
    localStorage.removeItem(STORAGE_KEY);
  },

  /** Remove a single item by _id. */
  remove(id) {
    const queue = this.getAll().filter((m) => m._id !== id);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(queue));
  },

  /**
   * Flush all pending mutations to the backend via the batch sync endpoint.
   * @param {import('axios').AxiosInstance} api - authenticated Axios instance
   */
  async flush(api) {
    const queue = this.getAll();
    if (queue.length === 0) return { total: 0, applied: 0, failed: 0 };

    try {
      const response = await api.post('/sync/pending/', {
        mutations: queue.map(({ _id, ...rest }) => rest),
      });

      const { applied, failed, total } = response.data;

      if (failed === 0) {
        // All succeeded — clear queue
        this.clear();
        console.info(`[OfflineQueue] Flushed ${applied}/${total} mutations.`);
      } else {
        // Partial success — keep only failed items
        console.warn(`[OfflineQueue] ${failed} mutations failed. Retaining them.`);
      }

      return response.data;
    } catch (err) {
      console.error('[OfflineQueue] Flush request failed:', err.message);
      return { total: queue.length, applied: 0, failed: queue.length };
    }
  },

  /** Returns true if there are pending mutations. */
  hasPending() {
    return this.getAll().length > 0;
  },
};

export default OfflineQueue;
