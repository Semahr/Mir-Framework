# JSON Configuration

Default configuration is loaded by `TAppOptionsLoader`.

Unit:

```text
Source/Core/App.Options.Loader.pas
```

Default file:

```text
./Config/Config.json
```

Example:

```json
{
  "Logger": {
    "LogLevel": "Info",
    "FilePath": "./Logs/App.log"
  }
}
```

## Loading from file

```pascal
TAppOptionsLoader.LoadFromDefaultPath;
```

or:

```pascal
TAppOptionsLoader.LoadFromFile('./Config/Production.json');
```

`LoadFromFile` loads the default file first, then loads the provided file and merges it over the default JSON.

## Merge behavior

Objects are merged recursively.

Default:

```json
{
  "Logger": {
    "LogLevel": "Info",
    "FilePath": "./Logs/App.log"
  }
}
```

Override:

```json
{
  "Logger": {
    "LogLevel": "Debug"
  }
}
```

Result:

```json
{
  "Logger": {
    "LogLevel": "Debug",
    "FilePath": "./Logs/App.log"
  }
}
```

## Type conversion

The loader uses:

```pascal
TJsonHelpers.ToRecord<TAppOptions>(JsonObject)
```

Supported option field types include:

- integers and compatible ordinal values;
- floating point numbers;
- `Currency`;
- `string`;
- `Char`;
- `Boolean`;
- enums from strings;
- nested records;
- dynamic arrays;
- classes from JSON objects, if they have a default constructor and public/published writable properties;
- `TDateTime`;
- `TDate`;
- `TTime`;
- `TTimeSpan`;
- `TGUID`;
- `TBytes` from Base64;
- `null`, converted to default values.

## Limitations

Avoid options that contain complex runtime objects or unclear ownership, such as:

- `TObjectList<T>`;
- `TDictionary<TKey, TValue>`;
- `TStream`;
- `TComponent`;
- `TCustomAttribute` instances.

Reason:

- records are copied by value;
- class fields are copied as references;
- ownership becomes ambiguous;
- some classes are not designed for JSON deserialization through public properties.

Prefer plain records, arrays, enums, dates, GUIDs and simple classes specifically designed as configuration objects.
