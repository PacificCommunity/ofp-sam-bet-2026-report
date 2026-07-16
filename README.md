# BET 2026 report writing for Paul

## First-time Windows setup

1. Download [Kflow Connect for Windows](https://github.com/kyuhank/Kflow/releases/download/kflow-connector-20260716-1335/kflow-connector-20260716-1335.zip).
2. Right-click the ZIP, choose **Extract All**, and open the extracted folder.
3. Double-click **Install Kflow Connect - Windows First-Time Setup.cmd**.
4. Complete the GitHub sign-in when the browser opens.
5. If Docker Desktop requests a restart or WSL 2 setup, complete it and run the installer once more.
6. Double-click **Kflow Connect SSH Setup.cmd** and enter the assigned Kflow account.
7. Start Docker Desktop, then open **Kflow Connect**.

Do not run the installer from inside the ZIP preview.

## Writing workflow

~~~mermaid
flowchart LR
    A["Open Kflow"] --> B["Start newest job"]
    B --> C["Open RStudio"]
    C --> D["Write or upload"]
    D --> E["Commit and Push"]
    E --> F["Updates are merged"]
    F --> B
~~~

1. Open **Kflow Connect**.
2. Open **BET report writing - Paul**.
3. Start a new job after any new changes have been merged, then click **RStudio** on that newest job.
4. Write in <code>bet-2026-report/sections/</code>.
5. In the RStudio **Git** pane, select the changed files, click **Commit**, enter a short message, and click **Push**.

A new job opens the latest committed writing at the time the job is created.

## Add a file from the laptop

1. In RStudio, open the **Files** pane.
2. Open the folder where the file belongs.
3. Click **Upload** and choose the file from the laptop.
4. Confirm the file appears in the **Git** pane, then commit and push it.

Put new report figures in <code>bet-2026-report/Figures/static/</code>.

## If something does not work

~~~mermaid
flowchart TD
    A["Something is not working"] --> B{"Does Kflow open?"}
    B -- "No" --> C["Run Kflow Connect SSH Setup"]
    B -- "Yes" --> D{"Does RStudio open?"}
    D -- "No" --> E["Start Docker Desktop and reopen Kflow"]
    D -- "Yes" --> F{"Does Push work?"}
    F -- "No" --> G["Check GitHub write access and sign in again"]
    F -- "Yes, but writing is old" --> H["Start a new job"]
~~~

| Problem | What to do |
|---|---|
| RStudio does not open | Start Docker Desktop and reopen **Kflow Connect**. |
| Kflow does not open | Run **Kflow Connect SSH Setup.cmd** again. |
| The report looks older than the latest merge | Start a new job and open RStudio from that job. |
| Push is rejected | Ask for repository write access, then sign in to GitHub again. |

If the connection drops after RStudio opens, the work remains on the laptop. Use **Kflow Local RStudio** to reopen it and push after reconnecting.
