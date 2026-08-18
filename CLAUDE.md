# Project rules for Claude

## What this is

SSHServerShutdown is a small Windows console application that shuts down a Synology DiskStation
over SSH. It reads server, port, user and password from a `Config.xml` next to the executable,
opens an SSH connection with the NuGet package
[SSH.NET](https://www.nuget.org/packages/SSH.NET/), runs the Synology poweroff task, waits, runs
`poweroff` and closes the connection. It is shipped as an Inno Setup installer, it is **not** a
NuGet package: no `GeneratePackageOnBuild`, no push script.

One solution `src/SSHServerShutdown.sln` with exactly one project:

- `src/SSHServerShutdown/SSHServerShutdown.csproj`, `OutputType` `Exe`, the whole application.

There is no test project, no `.github` folder, no pipeline file and no `Directory.Build.props`.

Layout inside `src/SSHServerShutdown`:

- `Program.cs`: the entire logic. `Main` loads the configuration and opens the `SshClient`,
  `Shutdown` sends the two commands, `InitConfiguration` loads the XML file and
  `CreateObjectsFromString` deserializes it. The methods do one thing each, keep new logic in that
  shape.
- `Config.cs`: the payload type with `ServerName`, `ServerPort`, `User` and `Password`.
- `Config.xml`: the shipped default configuration with a dummy server and a dummy password. It is
  copied to the output directory with `CopyToOutputDirectory=Always` and it goes into the
  installer.
- `GlobalUsings.cs`: all usings of the project.
- `License.txt`: copied to the output directory, identical to the `License.txt` in the repository
  root, and the one the installer shows as its license.
- `Shutdown.ico`: the `ApplicationIcon` and the `SetupIconFile` of the installer.

`Setup` holds the installer sources: `SSHServerShutdown-Setup.iss` (Inno Setup 6) and
`build-setup-files.bat` (cleans `bin` and `obj`, publishes self contained, deletes the `*.pdb`,
checks the credentials in `Config.xml`). The batch file only publishes, it does not compile the
installer, that step runs separately with `ISCC.exe`. The built `SSHServerShutdown-Setup.exe` is
**not** tracked, it is attached to the GitHub release of the matching tag.

Repository root: `README.md` (the only user documentation), `Changelog.md`, `License.txt` (MIT),
`.gitattributes` and `.gitignore`. There is no `Updating.md` and no `HowToUse.md`.

## Build

```powershell
dotnet build src/SSHServerShutdown.sln -c Release
```

There are no tests, so there is nothing to run with `dotnet test`. A behaviour change is verified
by starting the published executable and looking at the console output, not by a test run.

- Single target framework `net10.0-windows` in the single project, no multi-targeting.
  `RuntimeIdentifiers` is `win-x64` and the publish in `Setup/build-setup-files.bat` is self
  contained, so the target machine needs no installed .NET runtime. Check that with the
  published `SSHServerShutdown.runtimeconfig.json`: it has to list `includedFrameworks`, a
  `framework` block means the publish fell back to framework dependent.
- All build properties live directly in `SSHServerShutdown.csproj`. There is **no**
  `Directory.Build.props` in this repository.
- `TreatWarningsAsErrors` is enabled, so every warning breaks the build, NuGet warnings (`NU****`)
  from restore included. A clean build reports zero warnings, keep it that way.
- `NU1803` (HTTP source usage during restore) is the one warning suppressed via `NoWarn`. Fix
  warnings instead of extending that list. `NuGetAudit` and `NuGetAuditMode=all` are on, so a
  vulnerable package fails the build. That is not theoretical: version 1.0.7.0 shipped with
  `SSH.NET 2024.2.0`, and when the advisory `GHSA-q939-rpr3-3284` appeared, restore started failing
  with `NU1903` for everyone who checked out that commit.
- Versions come from GitVersion.MsBuild out of the git tags, for example `1.0.8-1` for the first
  commit after tag `1.0.8`. Never edit a version property or an assembly version by hand.
- Restore needs nuget.org. If a private feed is configured globally on the machine and answers 404
  for public packages, restore fails with `NU1301`. Then build with an explicit source:
  `dotnet build src/SSHServerShutdown.sln --source https://api.nuget.org/v3/index.json`.

## Code conventions

Follow the surrounding code, it is consistent throughout every file:

- File header comment block with `<copyright file="..." company="Hämmer Electronics">` and a
  `<summary>`, then the file-scoped namespace.
- XML doc comments on every type and every member, private members included, no exceptions.
- `Nullable`, `ImplicitUsings` and `LangVersion latest` are enabled.
- New `using` directives go into `GlobalUsings.cs`, inside the existing `#pragma warning disable
  IDE0065` block, never at the top of a file. The editorconfig requires usings inside the namespace
  (`csharp_using_directive_placement=inside_namespace:warning`), which global usings cannot
  satisfy, that is what the pragma is for. Do not add other pragmas. The comment text in that block
  is German because Visual Studio generated it, leave it alone.
- Fields, properties, methods and events are always accessed with `this.` qualification
  (`dotnet_style_qualification_for_*` at severity `warning`). `Program` and its members are static,
  so the qualification does not show up in the current code.
- `src/.editorconfig` also enforces braces everywhere, no multiple blank lines, four spaces, CRLF,
  UTF-8, file scoped namespaces, `System` usings sorted first and `IDE0005` as warning. Analyzer
  warnings are fixed, not silenced.

## Known quirks

Do not silently "clean up" these, they are existing behaviour:

- **The user interface is German, the code is English.** Every `Console.WriteLine` in `Program.cs`
  writes German text, while the file headers, the XML doc comments and the commit messages are
  English. There is no resource file and no language switch, the strings are hard coded.
- **The Synology commands are not verified from here.** `Shutdown` sends
  `execute /usr/syno/bin/syno_poweroff_task`, waits seven seconds and sends `poweroff`. The leading
  `execute` is not a shell builtin, and `RunCommand` ignores the exit status and the output, so a
  failing command looks exactly like a successful one. Whether this works depends on the DSM
  version on the other end and cannot be tested without a DiskStation. Do not "fix" the command
  string blindly, that trades a working shutdown for a guess.
- **The seven second wait is a fixed `Thread.Sleep(7000)`.** There is no check whether the poweroff
  task actually finished, the number is an estimate.
- **A broken configuration produces a confusing message, not a clear one.** `InitConfiguration`
  catches every exception, prints it and returns `null`, and `Main` then turns that `null` into an
  empty `Config` with `?? new()`. The `SshClient` constructor is what finally complains, about an
  empty host name rather than about the unreadable file.
- **`Config.xml` is overwritten on every build.** `CopyToOutputDirectory` is `Always`, so a local
  build replaces an edited configuration in `bin`. The installer ships the file too, so an update
  overwrites the installed configuration with the dummy values.
- **The password sits in plain text in `Config.xml`.** That is what the application was written
  for, there is no encryption and no credential store.
- **Deserialization goes through a string.** `InitConfiguration` loads the file into an
  `XDocument`, `CreateObjectsFromString` calls `ToString()` on it and feeds that through a
  `StringReader` into the `XmlSerializer`. Loading the file directly into the serializer would do
  the same job, the detour also drops the XML declaration, which does not matter because a .NET
  string is already UTF-16.
- **The installer does not belong in the repository.** `Setup/SSHServerShutdown-Setup.exe` is
  covered by the `*.exe` rule in `.gitignore` and it stays that way. It is uploaded as an asset of
  the GitHub release for its tag. Up to and including version 1.0.8 it was committed with
  `git add -f`, so those copies are still in the history and cannot be removed without rewriting
  published history. Never bring that back with another `git add -f`.
- **`build-setup-files.bat` refuses to build with real credentials.** The published `Config.xml`
  goes straight into the installer, so the script checks that it still holds the placeholder
  server `202.202.202.202` and the placeholder password. If not it deletes `bin\publish` and exits
  with 1. When the placeholder values are ever changed, that check has to be changed with them.
- **The `.iss` file is UTF-8 with BOM on purpose.** Inno Setup 6 reads a script as UTF-8 only
  when a BOM is present, otherwise it falls back to the system code page and turns the umlaut in
  the publisher name into mojibake. Keep the BOM when editing that file.
- **`.gitattributes` sets `* text=auto`**, every rule of the Visual Studio template below it is
  commented out. A binary file that must not be normalized needs its own rule.
- **AppVeyor badge without CI in the repository.** `README.md` links an AppVeyor build that is
  configured outside of this repository.
- **`MyAppURL` in the `.iss` points at `www.softwareload24.de.tl`**, which is where the installer
  sends the user through the "Program on the web" start menu entry.
- **`src/SSHServerShutdown.sln.DotSettings`** is tracked and holds nothing but a ReSharper user
  dictionary of the German words used in the console output. Leave it alone.

## Releasing

1. Make the change.
2. Add an entry at the top of `Changelog.md` in the existing format:
   `* **Version 1.0.8.0 (2026-08-18)** : Short description.`
3. Set `MyAppVersion` in `Setup/SSHServerShutdown-Setup.iss` to the same four part version, keeping
   the BOM and the CRLF line endings of that file.
4. Commit that.
5. Tag the commit with the plain version number, no `v` prefix (`1.0.8`, `1.0.7`, ...). The existing
   tags are lightweight tags, create new ones the same way. The tag has to exist **before** the
   installer is built, otherwise GitVersion burns a prerelease version such as
   `1.0.8-1+Branch.master.Sha...` into the shipped executable.
6. Push the commit and the tag.
7. Run `Setup/build-setup-files.bat` and then `ISCC.exe Setup/SSHServerShutdown-Setup.iss`. The
   batch file aborts if `Config.xml` carries anything but the placeholder credentials.
8. Create the GitHub release for the tag and attach `Setup/SSHServerShutdown-Setup.exe` to it. Do
   **not** commit the installer. `gh` is not installed on this machine, so this runs against the
   REST API. The token comes from the Windows Credential Manager, the same one `git push` uses:
   feed `git credential fill` with protocol and host and read the `password` line back. Then
   `POST /repos/SeppPenner/SSHServerShutdown/releases` for the release and a second call against
   `uploads.github.com` for the asset. `scripts/github_release.ps1` does both.

The version in `Changelog.md` has four parts (`1.0.8.0`), the tag has three (`1.0.8`).

## Git

- **Never amend a commit.** No `git commit --amend`, not for a typo in the message, not to add a
  forgotten file, not even when the commit is still local. Write a follow-up commit instead. The
  release versions come from tags on exact commits, an amended commit leaves its tag pointing at a
  commit that no longer exists in the branch.

## Writing style

- Commit messages are written **in English only**: short, precise subject line, explanatory body
  when needed.
- Code comments and comments in project files such as `.csproj` are **always English**, regardless
  of the language used in the conversation. The user facing console output stays German.
- **No em dashes or en dashes**, neither in prose, commit messages, code comments nor
  documentation. Use a regular hyphen, comma, colon, parentheses or a separate sentence.
- German texts (documentation, chat replies) always use real umlauts and the sharp s, never ASCII
  transliterations. Identifiers, file names and configuration keys stay unchanged where umlauts are
  technically undesirable.
