import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';

// Ищем файл registry.ts рекурсивно внутри папки /paperclip
function findRegistryFile(dir) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const fullPath = path.join(dir, file);
        if (fs.statSync(fullPath).isDirectory()) {
            if (file === 'node_modules' || file === '.git') continue;
            const found = findRegistryFile(fullPath);
            if (found) return found;
        } else if (file === 'registry.ts' && fullPath.includes('adapters')) {
            return fullPath;
        }
    }
    return null;
}

const registryPath = findRegistryFile('/paperclip');

const registrationCode = `
import * as hermesLocal from "hermes-paperclip-adapter";
import {
  execute,
  testEnvironment,
  detectModel,
  listSkills,
  syncSkills,
  sessionCodec,
} from "hermes-paperclip-adapter/server";

registry.set("hermes_local", {
  ...hermesLocal,
  execute,
  testEnvironment,
  detectModel,
  listSkills,
  syncSkills,
  sessionCodec,
});
`;

if (registryPath) {
    console.log(`🎯 Found registry at: ${registryPath}`);
    let content = fs.readFileSync(registryPath, 'utf8');
    if (!content.includes('hermes_local')) {
        content += registrationCode;
        fs.writeFileSync(registryPath, content);
        console.log("✅ Hermes adapter registered successfully.");
    } else {
        console.log("ℹ️ Hermes adapter already present.");
    }
} else {
    console.error("❌ FATAL: Could not find registry.ts anywhere in /paperclip");
    process.exit(1);
}