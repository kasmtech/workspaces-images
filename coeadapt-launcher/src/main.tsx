import React from "react";
import ReactDOM from "react-dom/client";
import { ClerkProvider } from "@clerk/clerk-react";
import { STANDALONE_MODE } from "./lib/mode";
import App from "./App";
import "./index.css";

const CLERK_PUBLISHABLE_KEY = import.meta.env.VITE_CLERK_PUBLISHABLE_KEY;

if (!CLERK_PUBLISHABLE_KEY && !STANDALONE_MODE) {
  console.warn("Missing VITE_CLERK_PUBLISHABLE_KEY — auth will not work");
}

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    {STANDALONE_MODE ? (
      <App />
    ) : (
      <ClerkProvider publishableKey={CLERK_PUBLISHABLE_KEY || ""}>
        <App />
      </ClerkProvider>
    )}
  </React.StrictMode>,
);
