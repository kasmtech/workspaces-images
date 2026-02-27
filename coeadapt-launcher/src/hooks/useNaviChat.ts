import { useState, useCallback, useRef } from "react";
import { useAuth } from "@clerk/clerk-react";
import { getDeviceToken } from "../lib/api";

const API_BASE = import.meta.env.VITE_COEADAPT_API_URL || "http://localhost:5000";

export interface ChatMessage {
  id: string;
  role: "user" | "assistant";
  content: string;
  timestamp: string;
}

export function useNaviChat(threadId: string = "default") {
  const { getToken } = useAuth();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [isStreaming, setIsStreaming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  const getAuthHeader = useCallback(async (): Promise<string> => {
    try {
      const clerkToken = await getToken();
      if (clerkToken) return `Bearer ${clerkToken}`;
    } catch {
      // Fall through to device token
    }
    const deviceToken = getDeviceToken();
    if (deviceToken) return `Bearer ${deviceToken}`;
    throw new Error("Not authenticated");
  }, [getToken]);

  const sendMessage = useCallback(
    async (text: string) => {
      setError(null);

      const userMsg: ChatMessage = {
        id: `user-${Date.now()}`,
        role: "user",
        content: text,
        timestamp: new Date().toISOString(),
      };

      const assistantMsg: ChatMessage = {
        id: `assistant-${Date.now()}`,
        role: "assistant",
        content: "",
        timestamp: new Date().toISOString(),
      };

      setMessages((prev) => [...prev, userMsg, assistantMsg]);
      setIsStreaming(true);

      try {
        const authHeader = await getAuthHeader();
        const controller = new AbortController();
        abortRef.current = controller;

        const response = await fetch(`${API_BASE}/api/chatbot/agent/stream?message=${encodeURIComponent(text)}&threadId=${encodeURIComponent(threadId)}`, {
          headers: { Authorization: authHeader },
          signal: controller.signal,
        });

        if (!response.ok) {
          const body = await response.json().catch(() => ({}));
          throw new Error(body.error || body.message || `HTTP ${response.status}`);
        }

        const reader = response.body?.getReader();
        const decoder = new TextDecoder();

        if (!reader) throw new Error("No response body");

        let buffer = "";
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          buffer = lines.pop() || "";

          for (const line of lines) {
            if (!line.startsWith("data: ")) continue;
            try {
              const data = JSON.parse(line.slice(6));
              if (data.type === "content" || data.content) {
                const chunk = data.content || data.text || "";
                setMessages((prev) => {
                  const updated = [...prev];
                  const last = updated[updated.length - 1];
                  if (last?.role === "assistant") {
                    last.content += chunk;
                  }
                  return updated;
                });
              } else if (data.type === "error") {
                setError(data.error || "An error occurred");
              }
            } catch {
              // Skip malformed SSE lines
            }
          }
        }
      } catch (err: any) {
        if (err.name !== "AbortError") {
          setError(err.message || "Failed to send message");
          // Remove empty assistant message on error
          setMessages((prev) => {
            const last = prev[prev.length - 1];
            if (last?.role === "assistant" && !last.content) {
              return prev.slice(0, -1);
            }
            return prev;
          });
        }
      } finally {
        setIsStreaming(false);
        abortRef.current = null;
      }
    },
    [getAuthHeader, threadId],
  );

  const stopStreaming = useCallback(() => {
    abortRef.current?.abort();
  }, []);

  const clearMessages = useCallback(() => {
    setMessages([]);
    setError(null);
  }, []);

  return { messages, isStreaming, error, sendMessage, stopStreaming, clearMessages };
}
