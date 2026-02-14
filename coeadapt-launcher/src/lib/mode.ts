/**
 * Standalone mode activates automatically when no valid Clerk key is configured.
 * The default .env ships with "pk_test_REPLACE_ME", which triggers standalone mode.
 *
 * Standalone mode: workspace + MCP + Claude — no CoeAdapt account needed.
 * CoeAdapt mode:   + Cora chat, career tracking, cloud sync.
 */
export const STANDALONE_MODE =
  !import.meta.env.VITE_CLERK_PUBLISHABLE_KEY ||
  import.meta.env.VITE_CLERK_PUBLISHABLE_KEY === "pk_test_REPLACE_ME";
