import { SignIn, useAuth } from "@clerk/clerk-react";
import { useEffect } from "react";
import { useNavigate } from "react-router-dom";

export default function Login() {
  const { isSignedIn, isLoaded } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (isLoaded && isSignedIn) {
      navigate("/setup");
    }
  }, [isLoaded, isSignedIn, navigate]);

  return (
    <div className="min-h-screen bg-surface-0 flex flex-col items-center justify-center p-6">
      <div className="flex items-center gap-3 mb-8 animate-fade-in">
        <img src="/logo-color.png" alt="" className="w-8 h-8" />
        <span className="font-semibold text-xl text-text-primary">Coeadapt</span>
      </div>
      <p className="text-text-muted text-sm mb-6 animate-fade-in delay-100">
        Sign in to connect your Career Box to Navi
      </p>
      <div className="w-full max-w-sm animate-fade-in delay-200">
        <SignIn
          appearance={{
            elements: {
              rootBox: "w-full",
              card: "bg-surface-100 border border-surface-300 shadow-none rounded-2xl",
              headerTitle: "text-text-primary",
              headerSubtitle: "text-text-muted",
              formFieldInput:
                "bg-surface-200 border-surface-300 text-text-primary placeholder:text-text-faint rounded-lg",
              formFieldLabel: "text-text-secondary",
              formButtonPrimary:
                "bg-gradient-to-r from-brand-700 to-blue-500 hover:from-brand-600 hover:to-blue-400 rounded-xl",
              footerActionLink: "text-brand-400",
              socialButtonsBlockButton:
                "bg-surface-200 border-surface-300 text-text-primary hover:bg-surface-300 rounded-lg",
              socialButtonsBlockButtonText: "text-text-primary",
              dividerLine: "bg-surface-300",
              dividerText: "text-text-faint",
              identityPreviewEditButton: "text-brand-400",
              formFieldInputShowPasswordButton: "text-text-muted",
            },
          }}
          routing="hash"
        />
      </div>
    </div>
  );
}
