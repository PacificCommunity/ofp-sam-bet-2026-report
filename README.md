# BET 2026 report writing

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
    C --> D["Write or replace figures"]
    D --> E["Render PDF"]
    E --> F["Commit and Push"]
~~~

1. Open **Kflow Connect**.
2. Open **BET report writing - Paul** or **BET report writing - Kyuhan**.
3. Click **RStudio**. Each task opens its own writing branch.
4. Write in <code>bet-2026-report/sections/</code>.
5. Put or replace report images directly in <code>bet-2026-report/Figures/</code>.
6. In the Terminal, run <code>bash run.sh</code> from the repository root.
7. In the RStudio **Git** pane, select the changed files, click **Commit**, enter a short message, and click **Push**.

The Kflow job output contains only <code>bet-2026-report.pdf</code>. The report
does not download or depend on a Results job.

## Citation and cross-reference examples

Use an existing key from <code>bet-2026-report/references.bib</code>:

```markdown
Standardisation choices can affect abundance indices [@maunder_standardizing_2004].
@maunder_standardizing_2004 discusses this issue in detail.
```

Reference a labelled figure or table with <code>@fig-...</code> or
<code>@tbl-...</code>:

```markdown
The assessment regions are shown in @fig-region-map.
Reference-point notation is summarised in @tbl-reference-point-symbols.
```

Add a figure with a unique label, then use that label in the text:

```markdown
![Short, complete caption.](Figures/my-figure.png){#fig-my-figure width=100%}

The main pattern is visible in @fig-my-figure.
```

The existing files <code>sections/Figures.qmd</code> and
<code>sections/Tables.qmd</code> are working examples. Figure labels must start
with <code>fig-</code>; table chunk labels must start with <code>tbl-</code>.

## Add a file from the laptop

1. In RStudio, open the **Files** pane.
2. Open the folder where the file belongs.
3. Click **Upload** and choose the file from the laptop.
4. Confirm the file appears in the **Git** pane, then commit and push it.

The repository includes a small example figure set in
<code>bet-2026-report/Figures/</code>. Replace an existing file with the same
name to update it without changing the section source, or add a file and its
entry to <code>sections/Figures.qmd</code>.

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
| The report looks older than the latest push | Reopen RStudio from the task, or start a new PDF job. |
| Push is rejected | Ask for repository write access, then sign in to GitHub again. |

If the connection drops after RStudio opens, the work remains on the laptop. Use **Kflow Local RStudio** to reopen it and push after reconnecting.
