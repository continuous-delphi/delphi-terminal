# Command Bundles

A command bundle is a JSON file that distributes a set of saved commands
for delphi-terminal. Bundles let tool authors ship pre-configured
commands alongside their tools -- for example, a set of commands for the
Continuous-Delphi PowerShell toolchain.

## Bundle file format

A bundle file is a JSON object with three fields:

```json
{
  "prefix": "cd.",
  "description": "Continuous-Delphi PowerShell toolchain commands",
  "commands": [
    {
      "name": "cd.clean",
      "shell": "pwsh",
      "command": "delphi-clean",
      "workdir": "${ProjectDir}"
    },
    {
      "name": "cd.build",
      "shell": "pwsh",
      "command": "Invoke-DelphiBuild -ProjectFile ${ProjectFile}",
      "workdir": "${ProjectDir}"
    },
    {
      "name": "cd.incver",
      "shell": "pwsh",
      "command": "Invoke-DelphiIncVer",
      "workdir": "${ProjectDir}"
    }
  ]
}
```

### Fields

**prefix** (required): A short string that identifies the bundle. Every
command name in the bundle should start with this prefix. On import,
all existing commands whose name starts with this prefix are deleted
before the bundle's commands are added. This makes reimport safe --
updating a bundle replaces its commands without touching user-defined
commands.

Convention: use a dot-separated namespace, e.g. `cd.` for
Continuous-Delphi, `myteam.` for internal team commands.

**description** (required): A human-readable description shown in the
import confirmation dialog.

**commands** (required): An array of command objects. Each command has:

| Field    | Required | Description |
|----------|----------|-------------|
| name     | yes      | Display name. Should start with the bundle prefix. |
| shell    | yes      | Target shell: `active`, `cmd`, `pwsh`, or `powershell`. |
| command  | yes      | The command text. May contain `${Variable}` tokens. |
| workdir  | no       | Working directory. If set, the shell cd's here before running the command. May contain `${Variable}` tokens or be a static path. |

### Shell types

- **active** -- runs in whichever tab is currently selected
- **cmd** -- runs in the CMD tab
- **pwsh** -- runs in the pwsh (PowerShell 7+) tab
- **powershell** -- runs in the legacy PowerShell tab

## Variable tokens

Both `command` and `workdir` fields support these variable tokens,
expanded at execution time:

| Token               | Value |
|---------------------|-------|
| `${ProjectDir}`     | Directory of the active project |
| `${ProjectFile}`    | Full path of the active project (.dproj) |
| `${FileDir}`        | Directory of the currently focused editor file |
| `${FilePath}`       | Full path of the currently focused editor file |
| `${FileName}`       | File name only of the currently focused editor file |
| `${radTerminalDir}` | Directory where the delphi-terminal plugin is installed |

Variables are case-insensitive. If a variable cannot be resolved (e.g.
`${ProjectDir}` when no project is open), the command is aborted and an
error message is displayed in the terminal output.

### Shell-aware quoting

Variable values are automatically quoted for the target shell to handle
paths with spaces or special characters:

- **CMD**: Values are wrapped in double quotes. Trailing backslashes are
  stripped to prevent the `\"` escape-quote trap.
- **PowerShell** (pwsh and legacy): Values are wrapped in single quotes.
  Internal single quotes are doubled (`O'Brien` becomes `'O''Brien'`).

## Importing a bundle

1. Open **Tools > Options > Third Party > delphi-terminal**
2. Click **Saved Commands...**
3. Click **Import...**
4. Select the `.json` bundle file
5. Review the confirmation dialog (shows the prefix, description, and
   how many existing commands with that prefix will be replaced)
6. Click **Yes** to import

To update a bundle, simply import the same file (or a newer version)
again. All commands matching the prefix are replaced.

## Creating your own bundle

1. Choose a prefix that identifies your tool or team (e.g. `mytools.`)
2. Create a JSON file following the format above
3. Name every command starting with your prefix
4. Test the commands manually in delphi-terminal first
5. Distribute the `.json` file alongside your tools

### Example: a minimal bundle

```json
{
  "prefix": "demo.",
  "description": "Demo commands for testing",
  "commands": [
    {
      "name": "demo.hello",
      "shell": "active",
      "command": "echo Hello from delphi-terminal"
    },
    {
      "name": "demo.projinfo",
      "shell": "pwsh",
      "command": "Write-Host 'Project: ${ProjectFile}'",
      "workdir": "${ProjectDir}"
    }
  ]
}
```

## Notes

- Bundle files are standard JSON -- any text editor can create them
- The prefix is matched case-insensitively during import
- Users can edit imported commands after import; reimporting will
  overwrite those edits for commands matching the prefix
- Commands without the bundle's prefix are never affected by import
