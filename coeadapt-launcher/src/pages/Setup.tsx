import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useDocker } from "../hooks/useDocker";
import { useContainer } from "../hooks/useContainer";
import { useDiskSpace } from "../hooks/useDiskSpace";
import { ProgressBar } from "../components/ProgressBar";
import { Spinner } from "../components/Spinner";
import { STRINGS } from "../lib/constants";
import { tauri } from "../lib/tauri";

type Step = "welcome" | "system" | "docker" | "pull" | "starting" | "ready";
const STEPS: Step[] = ["welcome", "system", "docker", "pull", "starting", "ready"];

function CheckIcon() {
  return (
    <svg className="w-5 h-5 text-success" fill="none" viewBox="0 0 24 24" strokeWidth={2.5} stroke="currentColor">
      <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
    </svg>
  );
}

export default function Setup() {
  const [step, setStep] = useState<Step>("welcome");
  const navigate = useNavigate();
  const docker = useDocker();
  const container = useContainer();
  const disk = useDiskSpace();
  const stepIndex = STEPS.indexOf(step);

  useEffect(() => {
    if (step === "system" && disk.status) {
      if (!disk.status.meets_minimum) return;
      setStep("docker");
    }
  }, [step, disk.status]);

  useEffect(() => {
    if (step === "docker" && docker.isAvailable) setStep("pull");
  }, [step, docker.isAvailable]);

  useEffect(() => {
    if (step === "docker" && !docker.isAvailable && !docker.loading) {
      const interval = setInterval(() => docker.refresh(), 5000);
      return () => clearInterval(interval);
    }
  }, [step, docker]);

  const handlePull = async () => {
    try {
      const exists = await tauri.checkImageExists();
      if (exists) { setStep("starting"); handleStart(); return; }
      await container.pullImage();
      setStep("starting");
      handleStart();
    } catch { /* container.error */ }
  };

  const handleStart = async () => {
    try {
      const status = await tauri.getWorkspaceStatus();
      if (status.state === "NotFound") await container.createWorkspace();
      else if (status.state === "Stopped") await container.startWorkspace();
      await tauri.waitForReady();
      setStep("ready");
    } catch { /* hook handles */ }
  };

  useEffect(() => { if (step === "pull") handlePull(); }, [step]);

  return (
    <div className="min-h-screen bg-surface-0 flex flex-col">
      {/* Ambient glow */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-96 h-96 rounded-full bg-brand-600/5 blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-96 h-96 rounded-full bg-brand-400/5 blur-3xl" />
      </div>

      {/* Step progress */}
      {step !== "welcome" && (
        <div className="relative z-10 px-8 pt-6">
          <div className="max-w-md mx-auto flex gap-1.5">
            {STEPS.slice(1).map((s, i) => (
              <div key={s} className={`h-1 flex-1 rounded-full transition-all duration-500 ${i < stepIndex ? "brand-gradient" : "bg-surface-300"}`} />
            ))}
          </div>
        </div>
      )}

      <div className="relative z-10 flex-1 flex items-center justify-center p-8">
        <div className="max-w-md w-full">

          {step === "welcome" && (
            <div className="text-center animate-fade-in space-y-8">
              <img src="/logo-color.png" alt="Coeadapt" className="w-20 h-20 mx-auto animate-breathe" />
              <div className="space-y-3">
                <h1 className="text-3xl font-bold tracking-tight">{STRINGS.WELCOME_TITLE}</h1>
                <p className="text-text-secondary text-lg leading-relaxed">Your AI-powered career workspace,<br />ready in minutes.</p>
              </div>
              <button onClick={() => { setStep("system"); disk.refresh(); }} className="btn-primary text-base px-10 py-3.5">
                Get Started
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={2.5} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="M13.5 4.5 21 12m0 0-7.5 7.5M21 12H3" /></svg>
              </button>
              <p className="text-text-faint text-xs">Adapting Together</p>
            </div>
          )}

          {step === "system" && (
            <div className="animate-fade-in space-y-8 text-center">
              <div className="space-y-3">
                <h2 className="text-2xl font-semibold">{STRINGS.SETUP_CHECKING_SYSTEM}</h2>
                <p className="text-text-muted text-sm">Making sure everything is ready</p>
              </div>
              <div className="glass-card p-6">
                {disk.status ? (
                  disk.status.meets_minimum ? (
                    <div className="flex items-center gap-3 animate-fade-in">
                      <CheckIcon />
                      <div className="text-left"><p className="text-sm font-medium">Storage ready</p><p className="text-xs text-text-muted">{disk.status.available_gb} GB available</p></div>
                    </div>
                  ) : (
                    <div className="flex items-center gap-3 animate-fade-in">
                      <svg className="w-5 h-5 text-danger" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" /></svg>
                      <div className="text-left"><p className="text-sm font-medium text-danger">Insufficient storage</p><p className="text-xs text-text-muted">Need 15 GB, only {disk.status.available_gb} GB available</p></div>
                    </div>
                  )
                ) : (
                  <div className="flex items-center gap-3"><Spinner size="sm" /><span className="text-sm text-text-secondary">Checking storage...</span></div>
                )}
              </div>
            </div>
          )}

          {step === "docker" && (
            <div className="animate-fade-in space-y-8 text-center">
              <div className="space-y-3">
                <h2 className="text-2xl font-semibold">{STRINGS.SETUP_DOCKER_CHECKING}</h2>
                <p className="text-text-muted text-sm">We need Docker Desktop to run your workspace</p>
              </div>
              <div className="glass-card p-6">
                {docker.loading ? (
                  <div className="flex items-center gap-3"><Spinner size="sm" /><span className="text-sm text-text-secondary">Detecting...</span></div>
                ) : docker.isAvailable ? (
                  <div className="flex items-center gap-3 animate-fade-in">
                    <CheckIcon /><div className="text-left"><p className="text-sm font-medium">Docker Desktop found</p><p className="text-xs text-text-muted">{docker.info?.version}</p></div>
                  </div>
                ) : (
                  <div className="space-y-5 animate-fade-in">
                    <p className="text-sm text-text-secondary">{STRINGS.SETUP_DOCKER_NOT_FOUND}</p>
                    <a href="https://www.docker.com/products/docker-desktop/" target="_blank" rel="noreferrer" className="btn-primary inline-flex">
                      Download Docker Desktop
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="M13.5 6H5.25A2.25 2.25 0 0 0 3 8.25v10.5A2.25 2.25 0 0 0 5.25 21h10.5A2.25 2.25 0 0 0 18 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25" /></svg>
                    </a>
                    <div className="flex items-center gap-2 justify-center text-text-faint"><Spinner size="sm" /><span className="text-xs">Waiting for Docker Desktop...</span></div>
                  </div>
                )}
              </div>
            </div>
          )}

          {step === "pull" && (
            <div className="animate-fade-in space-y-8 text-center">
              <div className="space-y-3">
                <h2 className="text-2xl font-semibold">{STRINGS.SETUP_PULLING}</h2>
                <p className="text-text-muted text-sm">{STRINGS.SETUP_PULLING_SUBTITLE}</p>
              </div>
              <div className="glass-card p-6 space-y-4">
                {container.pullProgress ? (
                  <ProgressBar percent={container.pullProgress.percent} label={container.pullProgress.status.slice(0, 60)} />
                ) : (
                  <ProgressBar percent={0} indeterminate label="Preparing download..." />
                )}
              </div>
              {container.error && (
                <div className="space-y-3 animate-fade-in"><p className="text-danger text-sm">{container.error}</p><button onClick={handlePull} className="btn-secondary">Try Again</button></div>
              )}
            </div>
          )}

          {step === "starting" && (
            <div className="animate-fade-in space-y-8 text-center">
              <h2 className="text-2xl font-semibold">{STRINGS.SETUP_STARTING}</h2>
              <Spinner size="lg" />
              <p className="text-text-muted text-sm">This usually takes about 30 seconds</p>
            </div>
          )}

          {step === "ready" && (
            <div className="animate-fade-in space-y-8 text-center">
              <div className="w-16 h-16 mx-auto rounded-2xl brand-gradient flex items-center justify-center">
                <svg className="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" strokeWidth={2.5} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" /></svg>
              </div>
              <h2 className="text-3xl font-bold">{STRINGS.SETUP_READY}</h2>
              <p className="text-text-secondary">Your workspace is running and ready to use.</p>
              <button onClick={() => { container.openWorkspace(); navigate("/claude-setup"); }} className="btn-primary text-lg px-10 py-4">
                Open Workspace
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" d="M13.5 4.5 21 12m0 0-7.5 7.5M21 12H3" /></svg>
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
