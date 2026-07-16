# BET 2026 Report Writing

Use Kflow to edit and render the BET 2026 assessment report in a reproducible RStudio workspace. The report source is in [`bet-2026-report/`](bet-2026-report/).

## Install Kflow Connect

Current installer release: [Kflow Connect 20260716-190428](https://github.com/PacificCommunity/ofp-sam-bet-2026-report/releases/tag/kflow-connector-20260716-190428)

- [Windows ZIP](https://github.com/PacificCommunity/ofp-sam-bet-2026-report/releases/download/kflow-connector-20260716-190428/kflow-connector-noumea-host.zip)
- [macOS and Linux TAR.GZ](https://github.com/PacificCommunity/ofp-sam-bet-2026-report/releases/download/kflow-connector-20260716-190428/kflow-connector-noumea-host.tar.gz)
- [SHA256 checksums](https://github.com/PacificCommunity/ofp-sam-bet-2026-report/releases/download/kflow-connector-20260716-190428/kflow-connector-noumea-host-SHA256SUMS.txt)

Kflow Connect includes the local RStudio helper. It reuses working GitHub, SSH, Docker, and helper setup instead of replacing it.

## Account check

Before starting, confirm these two requirements:

- Your Kflow login is the same as your GitHub username.
- Your GitHub account has write access to this repository.

RStudio uses the GitHub credentials on your own computer. A job created by another person does not reuse that person's credentials. Commits and pushes therefore use the GitHub account of the person who opens RStudio, provided the two requirements above are met.

## Windows first-time setup

1. Download **Windows ZIP** above.
2. Right-click the ZIP, choose **Extract All**, and open the extracted folder. Do not run files from inside the ZIP preview.
3. Double-click **Install Kflow Connect - Windows First-Time Setup.cmd**.
4. Approve the Windows administrator prompt if it appears. The installer checks Python, Git, GitHub CLI, Docker Desktop, OpenSSH, WSL 2, and the local RStudio helper. Working installations are skipped.
5. When the browser opens, sign in to the GitHub account whose username matches your Kflow login and approve GitHub CLI access.
6. If Windows or Docker Desktop requests a restart or WSL 2 completion, finish that step and run **Install Kflow Connect - Windows First-Time Setup.cmd** once more.
7. Double-click **Kflow Connect SSH Setup.cmd**. Enter the assigned Kflow account name when prompted. Enter the account password once if requested; typed passwords are not displayed or stored.
8. Open **Kflow Connect** from the Start menu or double-click **Kflow Connect.cmd** in the extracted folder.

Kflow Connect starts Docker Desktop when required, waits for it, starts the local helper and SSH tunnel in the background, and opens Kflow in the default browser. No PowerShell window needs to remain open.

## macOS first-time setup

1. Download and extract **macOS and Linux TAR.GZ** above.
2. Control-click **Install Kflow Connect.command**, choose **Open**, and choose **Open** again if Gatekeeper asks.
3. Run **Kflow Connect SSH Setup.command** and enter the assigned Kflow account when prompted.
4. Open the installed **Kflow Connect** application or double-click **Kflow Connect.command**.

The installer reuses existing tools and can install missing prerequisites. Docker Desktop is started automatically when required.

## Linux first-time setup

1. Download and extract **macOS and Linux TAR.GZ** above.
2. Double-click **Install Kflow Connect.desktop** and choose **Trust and Launch** or **Allow Launching** if requested. The terminal alternative is `./install.sh`.
3. Run **Kflow Connect SSH Setup.desktop** and enter the assigned Kflow account when prompted.
4. Open **Kflow Connect** from the application menu or double-click **Kflow Connect.desktop**.

## Daily writing workflow

1. Open **Kflow Connect**.
2. Open the assigned BET report-writing task.
3. Open RStudio from the **latest job card**, not from the task-level shortcut. Each job opens the branch and exact commit attached to that job.
4. Wait while the Docker image is prepared. If the image is missing locally, Kflow downloads it automatically on first use.
5. Edit files under `bet-2026-report/`.
6. Render from the RStudio **Render** button, or run `quarto render bet-2026.qmd --to pdf` from the `bet-2026-report` directory.
7. Review the PDF in RStudio.
8. In the RStudio Git pane, select the intended files, click **Commit**, enter a message, and click **Push**.
9. Return to the Kflow task and click **Run**. Every task run clones the current remote branch again, so the new job uses the latest pushed commit.

The opened repository should show the assigned branch, not `HEAD detached`. Kflow configures its upstream automatically. Never force-push.

## Add a file from your computer

In RStudio, open the **Files** pane, browse to the destination folder, choose **Upload**, and select the local file. Commit and push it with the other report changes.

## What happens automatically

- Docker Desktop is started on Windows and macOS when it is not already running.
- A missing Docker image is downloaded automatically; an existing image is reused.
- The local RStudio helper starts in the background and listens only on the local computer.
- The SSH tunnel starts in the background and is reused when healthy.
- Every Task **Run** starts from the latest commit on its configured remote branch.
- The submitted Git commit opens in RStudio on a normal tracking branch.
- GitHub credentials remain on the user's computer and are mounted read-only for Git operations.
- Work in an existing dirty or divergent workspace is preserved rather than reset.

## Troubleshooting

- If the first RStudio start is slow, leave Kflow open while the Docker image downloads, then refresh the job.
- If GitHub push is unavailable, rerun the first-time installer and sign in with the GitHub username that matches the Kflow login.
- If SSH setup asks for a password every time, rerun the SSH setup and allow it to register the generated public key.
- If Docker requests a restart, restart the computer and rerun the first-time installer once.
- If an older job opens an outdated report state, close it and open RStudio from the newest job card.
- Do not commit passwords, access tokens, private keys, or credential files to this repository.
