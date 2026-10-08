# Repository Guidelines

## Project Structure & Module Organization

This is a Delphi 7 VCL demonstration kept in the repository root. `DelphiCDSDemo.dpr` is the entry point. `DemoData.pas` creates the four in-memory `TClientDataSet` examples (users, patients, tasks, and medicines). `MainForm.pas` contains dataset selection, the read-only grid, live search, per-column filters, multi-column sorting, and CRUD actions. `ColumnFilter.pas` builds the filter dialog and evaluates conditions. `ColumnChooser.pas` lets users choose and reorder visible fields. `RecordEditor.pas` builds the modal field editor at runtime. There are no DFM files, external assets, or committed tests. `README.md` explains user-facing behavior; `DelphiCDSDemo.exe` is generated locally and ignored by Git.

## Build, Test, and Development Commands

Open `DelphiCDSDemo.dpr` in Delphi 7 and build it, or run `dcc32 -Q DelphiCDSDemo.dpr` from the repository root when `dcc32` is on `PATH`. Run the application with `.\DelphiCDSDemo.exe` in PowerShell. The project includes `MidasLib` for local client dataset support.

No automated test suite or coverage target is configured. After a change, compile with Delphi 7 and exercise each dataset: select it and confirm record 1 is active, edit and cancel a record, edit and save, create and cancel, create and save, and accept and reject the delete confirmation. Check that the grid itself cannot edit records and highlights the full current row, that double-clicking a header separator fits its column without opening the editor, and that the trailing blank column follows grid and column resizing, that search marks matching cells in yellow, that Filter shows only records matching a visible column, and that clearing or closing search preserves any column filters, that multiple column filters combine with AND and show green header icons, that hiding a column removes its filter and sort criterion while visibility persists per CDS, that only the left header icons cycle ascending/descending/original order, that Shift-click on those icons adds sort priorities while memo columns stay unsortable, and that restarting restores sample data and the per-CDS grid layout, sort, and filters from `DelphiCDSDemo.ini`.

## Coding Style & Naming Conventions

Use Delphi 7 syntax and VCL components; avoid newer language features and third-party controls. Follow the existing two-space indentation. Name units and types in PascalCase (`TRecordEditorForm`), private fields with an `F` prefix, and event handlers by action (`DeleteClick`). Keep UI forms constructed in Pascal so the project remains independent of DFM resources. No formatter or linter is configured.

## Commit & Pull Request Guidelines

The history is short, so no established commit convention can be inferred. Use short imperative subjects such as `Add task sample fields`. Pull requests should describe the behavior changed, include Delphi 7 build and manual test results, and add a screenshot when the UI changes.

## Data Scope

Keep sample record changes in memory. `DelphiCDSDemo.ini` beside the executable stores only per-CDS grid settings and is ignored by Git. Do not add dataset file saving, database providers, or `ApplyUpdates` without an explicit scope change.
