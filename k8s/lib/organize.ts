import { readdir, mkdir, unlink } from "node:fs/promises";
import { join } from "node:path";

export async function organizeK8sFiles(sourceDir: string) {
  // 1. Find the files
  const files = await readdir(sourceDir);
  const k8sFiles = files.filter((file) => file.endsWith(".k8s.yaml"));

  for (const filename of k8sFiles) {
    // 2. Determine paths
    const folderName = filename.replace(".k8s.yaml", "");
    const targetFolder = join(sourceDir, folderName);
    const destinationPath = join(targetFolder, filename);
    const sourcePath = join(sourceDir, filename);

    // 3. Create the folder
    await mkdir(targetFolder, { recursive: true });

    // 4. COPY: Read source -> Write to destination
    const fileContent = Bun.file(sourcePath);
    await Bun.write(destinationPath, fileContent);

    // 5. UNLINK: Delete the original
    await unlink(sourcePath);

    console.log(`Processed: ${filename} -> ${folderName}/`);
  }
}
