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

export default function Setup() {
  const [step, setStep] = useState<Step>("welcome");
  const navigate = useNavigate();
  const docker = useDocker();
  const container = useContainer();
  const disk = useDiskSpace();

  // Auto-advance through steps
  useEffect(() => {
    if (step === "system" && disk.status) {
      if (!disk.status.meets_minimum) return; // Stay on system step
      setStep("docker");
    }
  }, [step, disk.status]);

  useEffect(() => {
    if (step === "docker" && docker.isAvailable) {
      setStep("pull");
    }
  }, [step, docker.isAvailable]);

  useEffect(() => {
    if (step === "docker" && !docker.isAvailable && !docker.loading) {
      // Poll for Docker every 5 seconds
      const interval = setInterval(() => docker.refresh(), 5000);
      return () => clearInterval(interval);
    }
  }, [step, docker]);

  const handlePull = async () => {
    try {
      const exists = await tauri.checkImageExists();
      if (exists) {
        setStep("starting");
        handleStart();
        return;
      }
      await container.pullImage();
      setStep("starting");
      handleStart();
    } catch {
      // Error is shown via container.error
    }
  };

  const handleStart = async () => {
    try {
      const status = await tauri.getWorkspaceStatus();
      if (status.state === "NotFound") {
        await container.createWorkspace();
      } else if (status.state === "Stopped") {
        await container.startWorkspace();
      }
      await tauri.waitForReady();
      setStep("ready");
    } catch {
      // Error handled by container hook
    }
  };

  useEffect(() => {
    if (step === "pull") {
      handlePull();
    }
  }, [step]);

  return (
    <div className="min-h-screen bg-navy-900 flex items-center justify-center p-8">
      <div className="max-w-lg w-full space-y-8 text-center">
        {/* Welcome */}
        {step === "welcome" && (
          <div className="space-y-6">
            <h1 className="text-3xl font-bold text-white">{STRINGS.WELCOME_TITLE}</h1>
            <p className="text-gray-400 text-lg">{STRINGS.WELCOME_SUBTITLE}</p>
            <button
              onClick={() => {
                setStep("system");
                disk.refresh();
              }}
              className="px-8 py-3 bg-coral-500 hover:bg-coral-600 text-white font-semibold rounded-lg transition-colors text-lg"
            >
              {STRINGS.BTN_GET_STARTED}
            </button>
          </div>
        )}

        {/* System Check */}
        {step === "system" && (
          <div className="space-y-6">
            <h2 className="text-2xl font-bold text-white">{STRINGS.SETUP_CHECKING_SYSTEM}</h2>
            {disk.status ? (
              disk.status.meets_minimum ? (
                <div className="flex items-center justify-center gap-2 text-emerald-400">
                  <span>&#10003;</span>
                  <span>{STRINGS.SETUP_DISK_OK} ({disk.status.available_gb}GB free)</span>
                </div>
              ) : (
                <div className="space-y-4">
                  <p className="text-red-400">{STRINGS.SETUP_DISK_MINIMUM}</p>
                  <p className="text-gray-400">
                    You currently have {disk.status.available_gb}GB available.
                  </p>
                </div>
              )
            ) : (
              <Spinner />
            )}
          </div>
        )}

        {/* Docker Detection */}
        {step === "docker" && (
          <div className="space-y-6">
            <h2 className="text-2xl font-bold text-white">{STRINGS.SETUP_DOCKER_CHECKING}</h2>
            {docker.loading ? (
              <Spinner />
            ) : docker.isAvailable ? (
              <div className="flex items-center justify-center gap-2 text-emerald-400">
                <span>&#10003;</span>
                <span>{STRINGS.SETUP_DOCKER_FOUND}</span>
              </div>
            ) : (
              <div className="space-y-4">
                <p className="text-gray-400">{STRINGS.SETUP_DOCKER_NOT_FOUND}</p>
                <a
                  href="https://www.docker.com/products/docker-desktop/"
                  target="_blank"
                  rel="noreferrer"
                  className="inline-block px-6 py-3 bg-coral-500 hover:bg-coral-600 text-white font-semibold rounded-lg transition-colors"
                >
                  {STRINGS.SETUP_DOCKER_INSTALL}
                </a>
                <p className="text-sm text-gray-500">
                  Waiting for Docker Desktop... (checking every 5 seconds)
                </p>
              </div>
            )}
          </div>
        )}

        {/* Pulling Image */}
        {step === "pull" && (
          <div className="space-y-6">
            <h2 className="text-2xl font-bold text-white">{STRINGS.SETUP_PULLING}</h2>
            <p className="text-gray-400">{STRINGS.SETUP_PULLING_SUBTITLE}</p>
            {container.pullProgress ? (
              <ProgressBar
                percent={container.pullProgress.percent}
                label={container.pullProgress.status.slice(0, 60)}
              />
            ) : (
              <ProgressBar percent={0} indeterminate label="Preparing download..." />
            )}
            {container.error && (
              <div className="space-y-2">
                <p className="text-red-400 text-sm">{container.error}</p>
                <button
                  onClick={handlePull}
                  className="px-4 py-2 bg-coral-500 text-white rounded-lg"
                >
                  {STRINGS.BTN_RETRY}
                </button>
              </div>
            )}
          </div>
        )}

        {/* Starting */}
        {step === "starting" && (
          <div className="space-y-6">
            <h2 className="text-2xl font-bold text-white">{STRINGS.SETUP_STARTING}</h2>
            <Spinner size="lg" />
            <p className="text-gray-400">This usually takes about 30 seconds...</p>
          </div>
        )}

        {/* Ready */}
        {step === "ready" && (
          <div className="space-y-6">
            <h2 className="text-3xl font-bold text-white">{STRINGS.SETUP_READY}</h2>
            <button
              onClick={() => {
                container.openWorkspace();
                navigate("/claude-setup");
              }}
              className="px-8 py-4 bg-coral-500 hover:bg-coral-600 text-white font-semibold rounded-xl transition-colors text-xl"
            >
              {STRINGS.BTN_OPEN_WORKSPACE}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
