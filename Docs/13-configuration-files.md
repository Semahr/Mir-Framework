# Configuration Files

The framework expects a default configuration file at:

```text
Config/Config.json
```

A separate example file may be kept at:

```text
Config/Config.example.json
```

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
