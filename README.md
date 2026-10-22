# PlainTake — demo videos as code

Write the demo in TypeScript — or let your AI agent write it. PlainTake records your real web
app, terminal or Mac app, narrates and captions it, and re-records it when your UI changes.
Deterministic, versioned in Git, and it runs on your own machine: no network, no account, no API key.

![PlainTake recording a release-approval demo: the cursor moves to each target and the camera zooms in to follow it](assets/demo-preview.gif)

More videos made with PlainTake are on
[YouTube](https://www.youtube.com/@plainlabdev), [Instagram](https://www.instagram.com/plainlabdev/)
and [TikTok](https://www.tiktok.com/@plainlab).

- **Read the guide** — install, commands, Free and Pro, what it does not do: [`GUIDE.md`](GUIDE.md)
- **Download:** [latest release](https://github.com/plaintake/plaintake/releases/latest)
- **Website:** [plaintake.github.io](https://plaintake.github.io)
- **Buy a licence:** [plainlab.gumroad.com/l/plaintake](https://plainlab.gumroad.com/l/plaintake)

## For agents

Paste this into Claude Code, Codex or any coding agent:

```text
Read https://github.com/plaintake/plaintake/blob/main/GUIDE.md, install PlainTake and set up
its MCP server for this project, then write and record a demo of <what to show>.
```

The guide covers install and MCP setup. For writing scenarios, the agent should carry
[`skills/plaintake/`](skills/plaintake/) (a `SKILL.md` agent skill) and read
[`docs/scenarios.md`](docs/scenarios.md) (the full DSL reference) and
[`docs/patterns.md`](docs/patterns.md) (app-side recipes).

## Support

This repository is the download and issue channel.
[Open an issue](https://github.com/plaintake/plaintake/issues/new/choose) with the output of
`plaintake doctor --json`.

---

PlainTake is proprietary software; see [`LICENSE`](LICENSE) for the terms and
[`NOTICE.md`](NOTICE.md) for the third-party components it uses.

&copy; 2026 PlainLab
