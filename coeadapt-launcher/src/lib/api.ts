/**
 * Typed API client for Coeadapt platform communication.
 *
 * Automatically attaches auth headers (Clerk JWT or device token).
 * Handles 401, 429, and 500+ errors with appropriate strategies.
 */

const API_BASE = import.meta.env.VITE_COEADAPT_API_URL || "http://localhost:5000";

type GetTokenFn = () => Promise<string | null>;

let _getToken: GetTokenFn | null = null;
let _deviceToken: string | null = null;

/** Called once from AuthWiring to inject Clerk's getToken function. */
export function setAuthProvider(getToken: GetTokenFn) {
  _getToken = getToken;
}

/** Called after login to set the device token for background use. */
export function setDeviceToken(token: string | null) {
  _deviceToken = token;
}

/** Get the current device token (for passing to MCP sidecar). */
export function getDeviceToken(): string | null {
  return _deviceToken;
}

async function getAuthHeader(): Promise<Record<string, string>> {
  // Prefer Clerk JWT for interactive requests
  if (_getToken) {
    try {
      const token = await _getToken();
      if (token) {
        return { Authorization: `Bearer ${token}` };
      }
    } catch {
      // Clerk not available, fall through
    }
  }
  // Fall back to device token
  if (_deviceToken) {
    return { Authorization: `Bearer ${_deviceToken}` };
  }
  return {};
}

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
    public code?: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export async function apiFetch<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const authHeaders = await getAuthHeader();
  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...authHeaders,
      ...(options.headers as Record<string, string>),
    },
  });

  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new ApiError(
      res.status,
      body.error || body.message || res.statusText,
      body.code,
    );
  }

  return res.json();
}

// ---------------------------------------------------------------------------
// Typed API methods (mirrors COEADAPT_API.md)
// ---------------------------------------------------------------------------

export const api = {
  // Health & system
  health: () => apiFetch<{ status: string; timestamp: string }>("/api/career-box/health"),

  // Token management
  verifyToken: () =>
    apiFetch<{ valid: boolean; userId?: string; deviceName?: string; expiresAt?: string; reason?: string }>(
      "/api/career-box/verify-token",
      { method: "POST" },
    ),
  generateDeviceToken: (deviceName: string) =>
    apiFetch<{ success: boolean; token: string; deviceName: string; expiresAt: string; expiresIn: number }>(
      "/api/career-box/generate-token",
      { method: "POST", body: JSON.stringify({ deviceName }) },
    ),

  // User profile
  getUser: () => apiFetch<any>("/api/auth/user"),

  // Plans
  getPlans: () => apiFetch<any>("/api/plans/me"),
  getPlan: (id: string) => apiFetch<any>(`/api/plans/${id}`),
  getPlanTasks: (planId: string) => apiFetch<any>(`/api/plans/${planId}/tasks`),

  // Tasks
  getTasks: () => apiFetch<any>("/api/tasks/me"),
  getTask: (id: string) => apiFetch<any>(`/api/tasks/${id}`),
  updateTask: (id: string, updates: Record<string, unknown>) =>
    apiFetch<any>(`/api/tasks/${id}`, { method: "PUT", body: JSON.stringify(updates) }),

  // Evidence
  submitEvidence: (taskId: string, evidence: Record<string, unknown>) =>
    apiFetch<any>(`/api/tasks/${taskId}/evidence`, { method: "POST", body: JSON.stringify(evidence) }),

  // Goals
  getGoals: () => apiFetch<any>("/api/goals/me"),
  createGoal: (goal: Record<string, unknown>) =>
    apiFetch<any>("/api/goals", { method: "POST", body: JSON.stringify(goal) }),
  updateGoal: (id: string, updates: Record<string, unknown>) =>
    apiFetch<any>(`/api/goals/${id}`, { method: "PATCH", body: JSON.stringify(updates) }),

  // Habits
  getHabits: () => apiFetch<any>("/api/habits"),
  getHabitsToday: () => apiFetch<any>("/api/habits/today"),
  createHabit: (habit: Record<string, unknown>) =>
    apiFetch<any>("/api/habits", { method: "POST", body: JSON.stringify(habit) }),
  completeHabit: (id: string) =>
    apiFetch<any>(`/api/habits/${id}/complete`, { method: "POST" }),
  getHabitStats: () => apiFetch<any>("/api/habits/stats/overview"),

  // Jobs
  getJobs: () => apiFetch<any>("/api/jobs"),
  discoverJobs: () => apiFetch<any>("/api/jobs/discover"),
  bookmarkJob: (jobId: string) =>
    apiFetch<any>(`/api/jobs/${jobId}/bookmark`, { method: "POST" }),
  getBookmarks: () => apiFetch<any>("/api/jobs/bookmarks/me"),

  // Portfolio
  getPortfolio: () => apiFetch<any>("/api/portfolio/items"),

  // Skills
  getVerifiedSkills: () => apiFetch<any>("/api/skills/verified"),

  // Market / Radar
  getMarketFit: () => apiFetch<any>("/api/radar/market-fit"),
  getSkillDeltas: () => apiFetch<any>("/api/radar/skill-deltas"),

  // Subscription
  getSubscription: () =>
    apiFetch<{ status: string; plan: string; features: Record<string, boolean> }>("/api/subscription/status"),

  // Notifications
  getNotifications: () => apiFetch<any>("/api/notifications/me"),

  // Chat with Cora (non-streaming)
  sendMessage: (message: string, threadId?: string) =>
    apiFetch<{ response: string; threadId: string; timestamp: string }>(
      "/api/chatbot/agent",
      { method: "POST", body: JSON.stringify({ message, threadId: threadId || "default" }) },
    ),
};
