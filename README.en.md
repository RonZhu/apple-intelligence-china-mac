# Apple Intelligence & Siri AI on a China-region Mac — a complete field report

A **China-mainland Mac Studio (M5 Ultra, macOS 27.0.1)** went from "Siri AI is not available" to working Siri AI conversations, Writing Tools, Private Cloud Compute, **Siri web search** (weather / news / facts) and the **ChatGPT extension**. The full guide is in Chinese ([README.md](README.md), [docs/](docs/)); this page is a summary.

> ⚠️ This lowers your Mac's startup security, partially disables SIP and loads a third-party kernel extension. It bypasses Apple's regional restriction, may stop working at any time, and is entirely at your own risk. Back up first. No third-party binaries are distributed here.

## Who is restricted (Apple, Sept 2026)

- **Devices purchased in mainland China**: Apple Intelligence does not work, wherever you are.
- **Apple Account region in mainland China**: Siri AI does not work.
- **EU**: Siri AI is available on Mac (English device + Siri language), not on iPhone/iPad/Watch.
- Siri AI currently requires English, and device language must equal Siri language.

Sources: [Apple Intelligence availability](https://support.apple.com/en-us/121115), [Siri AI (Beta)](https://support.apple.com/en-us/127893).

## The three gates

1. **Eligibility (local)** — `eligibilityd` rejects devices whose region is `CH/A`. A tiny kext ([SkyBlue997/enableMacosAI](https://github.com/SkyBlue997/enableMacosAI), commit `9c617ed`) rewrites `region-info` to `LL/A` in IORegistry. Build it yourself from source.
2. **Resources** — once eligible (domain answer `4`), macOS downloads several GB of models.
3. **Network** — Siri AI, PCC, web search and ChatGPT need a stable route to Apple/OpenAI services that are not reachable correctly from mainland China.

## Steps (see docs/ for exact commands)

1. Prepare: backup, non-China Apple Account, English (US) for both system and Siri, record original `csrutil` / `bputil -d` / `region-info`.
2. Build `RegionSpoof.kext` from source (outside iCloud-synced folders), ad-hoc sign.
3. Recovery: Startup Security Utility → Reduced Security + "Allow user management of kernel extensions from identified developers"; then `csrutil enable --without kext`. Never `csrutil disable`, never `amfi_get_out_of_my_way`.
4. Copy to `/Library/Extensions`, `kmutil load` (fails with 27 the first time), approve in Privacy & Security, reboot. The approved kext then loads at every boot via the AuxKC — no extra loader needed.
5. **New finding:** after every cold boot, `eligibilityd` starts ~5 s after launchd and caches the old `CH` region, so eligibility stays `2` even though the kext is loaded. `launchctl kickstart` of eligibilityd is blocked by SIP (150). Fix: `sudo launchctl reboot userspace` → both domains become `4`. An optional LaunchDaemon in [`scripts/auto-eligibility-fix/`](scripts/auto-eligibility-fix/) does this once per boot (experimental).
6. **Network findings (Surge for Mac):**
   - `searchtoold` (Siri web search) is sandboxed to remote port **443 only** (`com.apple.omniSearch.searchtoold.sb`), so it cannot reach a local HTTP/SOCKS proxy on `127.0.0.1:6152/6153` → EPERM → "Something's wrong". `assistantd` has no such limit, which is why chat works but search doesn't.
   - Fix: enhanced mode (TUN) ON, keep system proxy ON, add `api-siri-prod.apple.com` to `skip-proxy`, and add `PROCESS-NAME,searchtoold,<US group>` **before** any Apple rule set containing `IP-CIDR,17.0.0.0/8,DIRECT` (otherwise raw-IP requests are sent direct and Apple closes them with 0 bytes).
   - With Tailscale MagicDNS, system DNS is forwarded to local (poisoned) resolvers; this also breaks the final step of ChatGPT-extension sign-in. Fix: `tailscale set --accept-dns=false` and resolve `*.ts.net` via `server:100.100.100.100` in Surge `[Host]`.
   - Never add the `skip-proxy` line to an iPhone profile (iOS ignores `PROCESS-NAME`, so it would break Siri search there).

Agent skill: [`skills/china-mac-apple-intelligence/`](skills/china-mac-apple-intelligence/SKILL.md) — a gate-based runbook for AI coding assistants (e.g. Claude Code): read-only triage first, one next step at a time, and every sudo / Recovery / approval step is handed to the human. Install by copying the folder into `~/.claude/skills/`.

Snippet: [`examples/surge-apple-intelligence.conf`](examples/surge-apple-intelligence.conf). Read-only health check: [`scripts/check-status.sh`](scripts/check-status.sh).

## License

Docs: CC BY 4.0. Scripts and examples: MIT. Upstream kext code is linked, not copied (no upstream license).
