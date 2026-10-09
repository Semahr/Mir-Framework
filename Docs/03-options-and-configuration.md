# Options and Configuration

The framework exposes typed configuration through `IOptions<T>` and `TOptions<T>`.

Core unit:

```text
Source/Core/Options.Port.pas
```

Registration/runtime unit:

```text
Source/Core/Options.Registry.pas
```

## Core types

Options are declared as classes that inherit from `TOptionsSection`.

```pascal
type
  TOptionsSection = class abstract
  protected
    function GetSectionName: string; virtual; abstract;
  public
    property SectionName: string read GetSectionName;
  end;

  IOptions<T: class> = interface
    function GetValue: T;
    property Value: T read GetValue;
  end;

  TOptions<T: class> = class(TInterfacedObject, IOptions<T>)
  end;
```

`TOptionsSection` defines the JSON section name. `IOptions<T>` is the dependency injected into services.

## Declaring an options class

Create a class that inherits from `TOptionsSection` and override `GetSectionName`.

Example:

```pascal
unit Logger.Options;

interface

uses
  Options.Port;

type
  TLoggerOptions = class(TOptionsSection)
  private
    FLogLevel: string;
    FFilePath: string;

    function GetSectionName: string; override;
  public
    property LogLevel: string read FLogLevel write FLogLevel;
    property FilePath: string read FFilePath write FFilePath;
  end;

implementation

function TLoggerOptions.GetSectionName: string;
begin
  Result := 'Logger';
end;

end.
```

Given this class, the configuration file must contain a `Logger` object:

```json
{
  "Logger": {
    "LogLevel": "INFO",
    "FilePath": "./Logs/app.log"
  }
}
```

The JSON property names are mapped to writable public/published properties in the options class.

## Consuming options

Dependencies consume options through `IOptions<TSpecificOptions>`.

```pascal
type
  TLogger = class(TInterfacedObject, ILogger)
  private
    FOptions: TLoggerOptions;
  public
    constructor Create(const AOptions: IOptions<TLoggerOptions>);
  end;

constructor TLogger.Create(const AOptions: IOptions<TLoggerOptions>);
begin
  inherited Create;
  FOptions := AOptions.Value;
end;
```

`AOptions.Value` returns the typed options object, for example `TLoggerOptions`.

## Root options

The framework uses a JSON root object.

Unit:

```text
Source/Core/App.Options.pas
```

Current type:

```pascal
type
  TAppOptions = TJSONObject;
```

The root JSON contains one object per registered section:

```json
{
  "HttpServer": {
    "Port": 8080
  },
  "Logger": {
    "LogLevel": "INFO",
    "FilePath": "./Logs/app.log"
  }
}
```

## Loader

The default loader is configured by `TAppContainer`.

Unit:

```text
Source/Core/App.Options.Loader.pas
```

The default loader is:

```pascal
TAppOptionsLoader.Execute
```

It loads a JSON object from the default configuration file, optionally merging an override file from `APP_OPTIONS_FILE_PATH`.

The container calls the loader through `TOptionsRegistry.EnsureLoaded` and caches
its result until a new loader is configured.

### Selecting a configuration file explicitly

Use `LoadOptions` during bootstrap to select an override file in code:

```pascal
App := TAppContainer.Create;
try
  App.LoadOptions('./Config/Config.production.json');
  App.AddOptions<TLoggerOptions>;
  // Register and resolve application services after selecting the configuration.
finally
  App.Free;
end;
```

This delegates to `TAppOptionsLoader.LoadFromFile`: it reads
`./Config/Config.json` and recursively merges the specified file over it. Values
in the specified file win; nested JSON objects are merged. The default file is
still required. An empty or whitespace-only path is rejected.

The explicit load does not consult `APP_OPTIONS_FILE_PATH`. However, the
constructor still performs its original default/environment-based load before
`LoadOptions` can be called, so that initial configuration must also be valid.

Loading is immediate and rematerializes registered option sections, including
`THttpServerOptions`. Call this before resolving services or starting the server:
previously obtained option objects/interfaces can become invalid when replaced.
This is a startup configuration API, not a hot-reload mechanism.

## Registering sections

Use `AddOptions<TOptions>` to expose a section as `IOptions<TOptions>`.

```pascal
Container.AddOptions<TLoggerOptions>;
Container.AddOptions<TDatabaseOptions>;
```

`TOptions` must inherit from `TOptionsSection` and implement `GetSectionName`.

```pascal
type
  TDatabaseOptions = class(TOptionsSection)
  private
    FConnectionString: string;

    function GetSectionName: string; override;
  public
    property ConnectionString: string read FConnectionString write FConnectionString;
  end;

function TDatabaseOptions.GetSectionName: string;
begin
  Result := 'Database';
end;
```

This registration exposes:

```pascal
IOptions<TDatabaseOptions>
```

and expects the root JSON to contain:

```json
{
  "Database": {
    "ConnectionString": "..."
  }
}
```

## Default options

`TAppContainer` registers HTTP server options by default:

```pascal
AddOptions<THttpServerOptions>;
```

Applications can register their own sections during bootstrap:

```pascal
App.AddOptions<TLoggerOptions>;
```

## Loading and registration behavior

The constructor configures the default loader, which loads options immediately.
Setting another loader (including through `LoadOptions`) triggers another load.

The flow is:

```mermaid
flowchart TD
    A[SetOptionsLoader during construction or explicit configuration] --> B[EnsureLoaded]
    B --> C[Run root JSON loader once]
    C --> D[Register IOptions<TJSONObject>]
    D --> E[Run registered section materializers]
    E --> F[Extract each TOptionsSection from JSON]
    F --> G[Create TOptions<TSection>]
    G --> H[Register IOptions<TSection> in container]
```

## Important implementation detail

`IOptions<T>` instances are registered with an exact `TValue` for the closed generic interface, for example:

```pascal
IOptions<TLoggerOptions>
```

This avoids reconstructing generic interfaces dynamically during constructor invocation and keeps `AOptions.Value` safe when injected through RTTI.

## Notes

- Options sections are classes, not records.
- Every options section must inherit from `TOptionsSection`.
- `GetSectionName` determines the JSON object name in the root configuration.
- The root options value is a `TJSONObject`.
- Dependencies should consume `IOptions<TSpecificOptions>` instead of `TSpecificOptions` directly.
- `TOptions<T>` owns the contained options object and frees it when the options wrapper is destroyed.
