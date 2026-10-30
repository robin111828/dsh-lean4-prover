// dsh-lean4-prover
// 启动时把随包携带的 lean4-prover 技能注册到会话技能目录（ctx.skills）。
// 资源直接从插件包内 assets/lean4-prover 读取（持久只读目录），无需临时拷贝。
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { readFileSync } from "node:fs";
import { readFile } from "node:fs/promises";

const SKILL_NAME = "lean4-prover";
const PROVIDER = "dsh-lean4-prover";
// 内置 bundled 技能的固定优先级（与官方 skill-filesystem 文档一致：rank 600）
const BUNDLED_SKILL_RANK = 600;

const here = dirname(fileURLToPath(import.meta.url));
const skillDir = join(here, "..", "assets", SKILL_NAME);
const locator = join(skillDir, "SKILL.md");

// 极简 YAML frontmatter 解析：只取本技能需要的 name/description
function parseFrontmatter(raw) {
  const m = /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/u.exec(raw);
  if (!m) throw new Error(`${PROVIDER}: ${locator} 缺少 YAML frontmatter`);
  const meta = {};
  for (const line of m[1].split(/\r?\n/)) {
    const kv = /^([A-Za-z0-9_-]+)\s*:\s*(.*)$/.exec(line.trim());
    if (!kv) continue;
    let v = kv[2].trim();
    if (
      (v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))
    ) {
      v = v.slice(1, -1);
    }
    meta[kv[1]] = v;
  }
  return { meta, body: raw.slice(m[0].length).trim() };
}

export default function lean4ProverPlugin(ctx) {
  if (!ctx?.skills?.registerProvider) {
    ctx?.logger?.warn?.(`${PROVIDER}: 当前宿主不提供 ctx.skills 注册接口，跳过注册`);
    return;
  }

  const raw = readFileSync(locator, "utf-8");
  const { meta, body } = parseFrontmatter(raw);
  const description = meta.description;
  if (typeof description !== "string" || description.length === 0) {
    throw new Error(`${PROVIDER}: ${locator} 缺少 description`);
  }

  const candidate = {
    name: SKILL_NAME,
    description,
    invocation: { modelInvocable: true, userInvocable: true },
    provider: PROVIDER,
    source: "bundled",
    rank: BUNDLED_SKILL_RANK,
    resourceBase: { kind: "directory", path: skillDir },
    locator,
  };

  const provider = {
    name: PROVIDER,
    list: () => Promise.resolve([candidate]),
    async get(entry, options) {
      const { rank: _rank, locator: entryPath, ...summary } = entry;
      const text = await readFile(entryPath, {
        encoding: "utf-8",
        signal: options?.signal,
      });
      return { ...summary, content: parseFrontmatter(text).body };
    },
  };

  ctx.skills.registerProvider(() => provider);
  ctx.logger?.info?.(`${PROVIDER}: 已注册 bundled 技能 ${SKILL_NAME}`);
}
