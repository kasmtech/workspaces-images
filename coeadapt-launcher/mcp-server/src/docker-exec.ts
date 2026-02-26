import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const CONTAINER_NAME = "coeadapt-workspace";

export async function dockerExec(
  command: string,
): Promise<{ stdout: string; stderr: string }> {
  return execFileAsync(
    "docker",
    ["exec", CONTAINER_NAME, "bash", "-c", command],
    { timeout: 30000, maxBuffer: 10 * 1024 * 1024 },
  );
}

export async function isContainerRunning(): Promise<boolean> {
  try {
    const { stdout } = await execFileAsync("docker", [
      "inspect",
      "-f",
      "{{.State.Running}}",
      CONTAINER_NAME,
    ]);
    return stdout.trim() === "true";
  } catch {
    return false;
  }
}
