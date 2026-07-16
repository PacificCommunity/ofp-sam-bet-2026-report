# BET Report Writing: Paul

> **Windows quick start:** complete setup once, then use the Kflow Connect
> shortcut for each writing session.

## ONE TIME: Set up this Windows computer

### 1. Install Kflow Connect

1. Open [the latest Kflow Connector release](https://github.com/kyuhank/Kflow/releases/latest).
2. Download the Windows installer bundle. In **Downloads**, right-click the ZIP
   file, select **Extract All**, and open the extracted folder.
3. Double-click **Install Kflow Connect - Windows First-Time Setup.cmd**.
4. If Windows User Account Control asks whether to allow changes, select
   **Yes**. Accept any Windows Package Manager (`winget`) source or licence
   prompts that appear.

The installer checks for Python, Git, GitHub CLI, Docker Desktop, and OpenSSH.
It installs only missing items and skips anything already available.

When GitHub authorization appears, use **your own GitHub account**. Follow the
displayed one-time code and browser approval instructions. The setup does not
ask you to paste a personal access token.

If Docker Desktop asks you to enable WSL 2, restart Windows, or sign out,
complete that action and then run the installer again. Items already configured
will be skipped.

### 2. Set up SSH access

1. In the extracted folder, double-click **Kflow Connect SSH Setup.cmd**.
2. At the Kflow username prompt, enter or confirm your assigned Kflow username.
3. If prompted, enter your submitter password. This is required once only when
   existing SSH access is not already valid; valid access is detected and
   reused.

## EVERY TIME: Open the report

1. Double-click **Kflow Connect**.
2. Wait for Kflow to open in your browser.

Kflow Connect starts Docker only if needed and reuses an existing helper and
tunnel. After launch, no PowerShell window remains open.

```text
Kflow > BET report writing - Paul > latest job > RStudio
RStudio > edit and Render > Git Commit > Push
```

RStudio opens the branch and commit recorded for the selected job. Commits and
pushes go to `collab/paul-writing` using your own authenticated GitHub identity.

1. Edit the report in RStudio and save your changes.
2. Select **Render** to build and review the report.
3. In the **Git** pane, select the changed files and choose **Commit**.
4. Enter a short message, complete the commit, then choose **Push**.

### Upload a file from your computer

In RStudio, open the **Files** pane, go to the destination folder, select
**Upload**, choose the file, and confirm. Include it in your next **Commit** and
**Push**.

## Quick troubleshooting

- **Docker is not ready:** Open Docker Desktop, wait until it reports that it is
  running, then double-click **Kflow Connect** again.
- **Push says the remote has advanced:** In the RStudio **Git** pane, select
  **Pull**. If it completes without a conflict, select **Push** again. If a
  conflict appears, stop and ask project support.

## Keep Git safe

- Never force-push.
- Never add credentials, private keys, or access tokens to the repository.
