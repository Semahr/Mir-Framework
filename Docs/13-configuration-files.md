# Configuration Files

Without an explicit configuration, the default loader expects a file at:

```text
Config/Config.json
```

A separate example file may be kept at:

```text
Config/Config.example.json
```

## Loading modes and timing

Construction of `TAppContainer` and `AddOptions<T>` before first use do not read
configuration files. `SetOptionsLoader` only configures a delegate; it does not
execute it.

| API | Files read | Timing |
| --- | --- | --- |
| `App.LoadOptions(path)` | Only `path`; no default file or environment override | Reads and validates the JSON object immediately; typed sections remain deferred |
| `TAppOptionsLoader.LoadFromFile(path)` | Only `path`; no default file or environment override | Reads and validates the JSON object when called |
| `TAppOptionsLoader.LoadWithOverrides(path)` | `Config/Config.json` plus the supplied override | Reads and recursively merges the files when called |
| `TAppOptionsLoader.Execute` | Default file plus an optional override from `APP_OPTIONS_FILE_PATH`, via `LoadWithOverrides` | The container defers execution until `EnsureLoaded` |

With no explicit configuration, the first `GetGlobalOptions`, `GetOptions`,
service resolution, or server startup triggers `EnsureLoaded`: the default
loader executes and registered sections are materialized. Calling `EnsureLoaded`
directly also starts this process.

With `LoadOptions(path)`, the root JSON has already been read and validated, but
registered sections are still materialized only at `EnsureLoaded`/first use.
Once materialization has begun, attempts to replace the loader or configuration
are rejected with an error. These APIs do not support hot reload.

### Loading one explicit file

```pascal
App := TAppContainer.Create;
try
  App.AddOptions<TLoggerOptions>;
  App.LoadOptions('./Config/Config.production.json');
  // Resolve services or start the server only after configuring options.
finally
  App.Free;
end;
```

`LoadOptions` immediately reads only `./Config/Config.production.json` and
validates its JSON root object. It does not consult `APP_OPTIONS_FILE_PATH` or
require `Config/Config.json`. An empty or whitespace-only path is rejected.
The selected file must provide the configuration needed by the registered
sections; missing values are not filled from the default file.

### Default plus override and migration

`LoadWithOverrides(path)` preserves the default-plus-override behavior: it reads
`Config/Config.json` and recursively merges the supplied override over it.
Override values win, while nested JSON objects are merged. The default file is
required for this mode. `Execute` uses this method with the optional override
selected by `APP_OPTIONS_FILE_PATH`; without an environment override, it loads
the default file alone. In the container's default flow, these reads remain
deferred until `EnsureLoaded`.

**Breaking change:** `LoadFromFile(path)` now means exactly one file, not a merge
with the default configuration. Existing callers that depend on the old merge
behavior must replace `TAppOptionsLoader.LoadFromFile(path)` with
`TAppOptionsLoader.LoadWithOverrides(path)`. Likewise, `App.LoadOptions(path)`
is a single-file startup API, not an override-merging or hot-reload API.

See [Options and Configuration](03-options-and-configuration.md) for the options
registration and materialization lifecycle.

## Default content

```json
{
  "Logger": {
    "LogLevel": "Info",
    "FilePath": "./Logs/App.log"
  }
}
```

## Logger section

Required fields:

```json
{
  "Logger": {
    "LogLevel": "Info",
    "FilePath": "./Logs/App.log"
  }
}
```

Valid `LogLevel` values:

- `Debug`
- `Info`
- `Warning`
- `Error`

## Adding application sections

If `TAppOptions` contains:

```pascal
type
  TAppOptions = record
    Logger: TLoggerOptions;
    Jwt: TJwtOptions;
  end;
```

then JSON can contain:

```json
{
  "Logger": {
    "LogLevel": "Info",
    "FilePath": "./Logs/App.log"
  },
  "Jwt": {
    "Secret": "change-me",
    "ExpirationMinutes": 60
  }
}
```

Then register the section:

```pascal
Container.AddOptions<TJwtOptions>('Jwt');
```
