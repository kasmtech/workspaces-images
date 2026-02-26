import { z } from "zod";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { dockerExec } from "../docker-exec.js";

/**
 * Helper to call the in-VM progress tracker HTTP service.
 * Falls back to direct file reads if the service is unavailable.
 */
async function progressApi(
  method: "GET" | "POST" | "PUT",
  path: string,
  body?: Record<string, unknown>,
): Promise<string> {
  const curlArgs = [
    "curl", "-sf", "-m", "5",
    "-H", "Content-Type: application/json",
  ];
  if (method === "POST" || method === "PUT") {
    curlArgs.push("-X", method);
    if (body) {
      curlArgs.push("-d", JSON.stringify(body));
    }
  }
  curlArgs.push(`http://127.0.0.1:7700${path}`);
  const { stdout } = await dockerExec(curlArgs.join(" "));
  return stdout;
}

export function registerGetProgress(
  server: McpServer,
  onToolCall: () => void,
) {
  // -----------------------------------------------------------------------
  // Get full progress data
  // -----------------------------------------------------------------------
  server.tool(
    "get_user_progress",
    "Get the user's complete career development progress including activities, goals, skills, and milestones",
    {},
    async () => {
      onToolCall();
      try {
        const raw = await progressApi("GET", "/progress");
        return { content: [{ type: "text" as const, text: raw }] };
      } catch {
        // Fallback: read file directly
        try {
          const { stdout } = await dockerExec(
            "cat /home/kasm-user/.coeadapt/progress.json 2>/dev/null || " +
            'echo \'{"activities":[],"assessments":[],"goals":[],"skills":[],"milestones":[],"progress_percent":0}\'',
          );
          return { content: [{ type: "text" as const, text: stdout }] };
        } catch (err: any) {
          return {
            content: [
              { type: "text" as const, text: `Error: ${err.stderr || err.message}` },
            ],
            isError: true,
          };
        }
      }
    },
  );

  // -----------------------------------------------------------------------
  // Get progress summary (lightweight)
  // -----------------------------------------------------------------------
  server.tool(
    "get_progress_summary",
    "Get a lightweight summary of the user's career progress: completion percentage, streak, counts",
    {},
    async () => {
      onToolCall();
      try {
        const raw = await progressApi("GET", "/progress/summary");
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Log an activity
  // -----------------------------------------------------------------------
  server.tool(
    "log_activity",
    "Log a career development activity (e.g. completed a tutorial, attended a workshop, practiced a skill)",
    {
      title: z.string().describe("Title of the activity"),
      type: z
        .enum([
          "tutorial", "workshop", "practice", "project", "assessment",
          "reading", "networking", "application", "interview", "general",
        ])
        .default("general")
        .describe("Type of activity"),
      description: z.string().optional().describe("Description of what was done"),
      duration_minutes: z.number().optional().describe("How long the activity took in minutes"),
      tags: z.array(z.string()).optional().describe("Tags/labels for the activity"),
    },
    async ({ title, type, description, duration_minutes, tags }) => {
      onToolCall();
      try {
        const raw = await progressApi("POST", "/progress/activities", {
          title,
          type,
          description: description || "",
          duration_minutes: duration_minutes || 0,
          tags: tags || [],
        });
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Create a goal
  // -----------------------------------------------------------------------
  server.tool(
    "create_goal",
    "Create a new career development goal for the user to work toward",
    {
      title: z.string().describe("Goal title"),
      description: z.string().optional().describe("Detailed description of the goal"),
      category: z
        .enum([
          "skill", "certification", "project", "job-search",
          "networking", "education", "portfolio", "general",
        ])
        .default("general")
        .describe("Goal category"),
      target_date: z.string().optional().describe("Target completion date (ISO 8601)"),
      sub_goals: z
        .array(z.string())
        .optional()
        .describe("List of sub-goal descriptions"),
    },
    async ({ title, description, category, target_date, sub_goals }) => {
      onToolCall();
      try {
        const raw = await progressApi("POST", "/progress/goals", {
          title,
          description: description || "",
          category,
          target_date,
          sub_goals: sub_goals || [],
        });
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Update a goal
  // -----------------------------------------------------------------------
  server.tool(
    "update_goal",
    "Update an existing goal's status, description, or details",
    {
      goal_id: z.number().describe("ID of the goal to update"),
      status: z
        .enum(["active", "completed", "paused", "abandoned"])
        .optional()
        .describe("New goal status"),
      title: z.string().optional().describe("Updated title"),
      description: z.string().optional().describe("Updated description"),
    },
    async ({ goal_id, status, title, description }) => {
      onToolCall();
      const updates: Record<string, unknown> = {};
      if (status) updates.status = status;
      if (title) updates.title = title;
      if (description) updates.description = description;
      try {
        const raw = await progressApi("PUT", `/progress/goals/${goal_id}`, updates);
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Record a skill
  // -----------------------------------------------------------------------
  server.tool(
    "record_skill",
    "Record or update a skill the user has demonstrated or is developing",
    {
      name: z.string().describe("Skill name (e.g. 'Python', 'Public Speaking', 'React')"),
      category: z
        .enum([
          "technical", "soft-skill", "tool", "language",
          "framework", "methodology", "domain", "general",
        ])
        .default("general")
        .describe("Skill category"),
      level: z
        .enum(["beginner", "intermediate", "advanced", "expert"])
        .default("beginner")
        .describe("Current proficiency level"),
      evidence: z
        .array(z.string())
        .optional()
        .describe("Evidence of the skill (project URLs, descriptions, etc.)"),
    },
    async ({ name, category, level, evidence }) => {
      onToolCall();
      try {
        const raw = await progressApi("POST", "/progress/skills", {
          name,
          category,
          level,
          evidence: evidence || [],
        });
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Update a skill
  // -----------------------------------------------------------------------
  server.tool(
    "update_skill",
    "Update a skill's level or add new evidence",
    {
      skill_id: z.number().describe("ID of the skill to update"),
      level: z
        .enum(["beginner", "intermediate", "advanced", "expert"])
        .optional()
        .describe("Updated proficiency level"),
      evidence: z
        .array(z.string())
        .optional()
        .describe("New evidence entries to add"),
      verified: z.boolean().optional().describe("Mark as verified by assessment"),
    },
    async ({ skill_id, level, evidence, verified }) => {
      onToolCall();
      const updates: Record<string, unknown> = {};
      if (level) updates.level = level;
      if (evidence) updates.evidence = evidence;
      if (verified !== undefined) updates.verified = verified;
      try {
        const raw = await progressApi("PUT", `/progress/skills/${skill_id}`, updates);
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Add a milestone
  // -----------------------------------------------------------------------
  server.tool(
    "add_milestone",
    "Record a career milestone or achievement (e.g. 'Got first interview', 'Completed Python course')",
    {
      title: z.string().describe("Milestone title"),
      description: z.string().optional().describe("Details about the milestone"),
      achieved: z
        .boolean()
        .default(true)
        .describe("Whether the milestone is already achieved"),
    },
    async ({ title, description, achieved }) => {
      onToolCall();
      try {
        const raw = await progressApi("POST", "/progress/milestones", {
          title,
          description: description || "",
          achieved,
        });
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );

  // -----------------------------------------------------------------------
  // Record an assessment result
  // -----------------------------------------------------------------------
  server.tool(
    "record_assessment",
    "Record the result of a skills assessment or quiz",
    {
      skill: z.string().describe("Skill being assessed"),
      score: z.number().describe("Score achieved"),
      max_score: z.number().default(100).describe("Maximum possible score"),
      type: z
        .enum(["self", "quiz", "project-review", "peer", "ai"])
        .default("self")
        .describe("Type of assessment"),
      notes: z.string().optional().describe("Notes about the assessment"),
    },
    async ({ skill, score, max_score, type, notes }) => {
      onToolCall();
      try {
        const raw = await progressApi("POST", "/progress/assessments", {
          skill,
          score,
          max_score,
          type,
          notes: notes || "",
        });
        return { content: [{ type: "text" as const, text: raw }] };
      } catch (err: any) {
        return {
          content: [
            { type: "text" as const, text: `Error: ${err.message || err}` },
          ],
          isError: true,
        };
      }
    },
  );
}
