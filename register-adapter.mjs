import fs from 'fs';
import path from 'path';

// This path is relative to the cloned repo inside the Docker container
const registryPath = '/paperclip/packages/server/src/adapters/registry.ts';

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

if (fs.existsSync(registryPath)) {
    let content = fs.readFileSync(registryPath, 'utf8');
    // Prevent double registration if script runs twice
    if (!content.includes('hermes_local')) {
        content += registrationCode;
        fs.writeFileSync(registryPath, content);
        console.log("✅ Successfully registered hermes_local in registry.ts");
    } else {
        console.log("ℹ️ hermes_local already registered.");
    }
} else {
    console.error("❌ Could not find registry.ts at " + registryPath);
    process.exit(1);
}