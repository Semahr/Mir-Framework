unit App.Options.Loader;

interface

uses
  System.JSON,
  App.Options;

type
  TAppOptionsLoader = class sealed
  private
   const DefaultOptionsFilePath = './Config/Config.json';

    class function LoadJsonObjectFromFile(const AFilePath: string): TJSONObject; static;
    class function CloneJsonValue(const AValue: TJSONValue): TJSONValue; static;
    class procedure MergeJsonObjects(const ATarget, ASource: TJSONObject); static;
  public
    class function Execute: TAppOptions; static;
    class function LoadFromFile(const AFilePath: string): TAppOptions; static;
    class function LoadFromDefaultPath: TAppOptions; static;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  AppExceptions,
  Env.Helpers,
  Path.Helpers;

class function TAppOptionsLoader.Execute: TAppOptions;
var
  AppOptionsFilePath: string;
begin
  if TEnv.TryGetString('APP_OPTIONS_FILE_PATH', AppOptionsFilePath) then
    Exit(LoadFromFile(AppOptionsFilePath));

  Result := LoadFromDefaultPath;
end;

class function TAppOptionsLoader.LoadFromDefaultPath: TAppOptions;
begin
  var DefaultJson := LoadJsonObjectFromFile(DefaultOptionsFilePath);
  try
    Result := TJSONObject(DefaultJson.Clone);
  finally
    DefaultJson.Free;
  end;
end;

class function TAppOptionsLoader.LoadFromFile(const AFilePath: string): TAppOptions;
begin
  var DefaultJson := LoadJsonObjectFromFile(DefaultOptionsFilePath);
  try
    var LoadedJson := LoadJsonObjectFromFile(AFilePath);
    try
      MergeJsonObjects(DefaultJson, LoadedJson);
      Result := TJSONObject(DefaultJson.Clone);
    finally
      LoadedJson.Free;
    end;
  finally
    DefaultJson.Free;
  end;
end;

class function TAppOptionsLoader.LoadJsonObjectFromFile(const AFilePath: string): TJSONObject;
begin
  var NormalizedFilePath := TPathHelpers.ValidatePath(
    AFilePath,
    TPathKind.FilePath,
    True,
    True,
    False
  );

  if not TPathHelpers.CanBeOpen(NormalizedFilePath) then
    raise EInvalidDependencyException.CreateFmt(
      'File options cannot be opened: %s',
      [NormalizedFilePath]
    );

  var JsonContent := TFile.ReadAllText(NormalizedFilePath, TEncoding.UTF8);

  if JsonContent.Trim.IsEmpty then
    raise EInvalidDependencyException.CreateFmt(
      'File options is empty: %s',
      [NormalizedFilePath]
    );

  var JsonValue := TJSONObject.ParseJSONValue(JsonContent);
  if JsonValue = nil then
    raise EInvalidDependencyException.CreateFmt(
      'File options is not valid JSON: %s',
      [NormalizedFilePath]
    );

  try
    if not (JsonValue is TJSONObject) then
      raise EInvalidDependencyException.CreateFmt(
        'File options root must be a JSON object: %s',
        [NormalizedFilePath]
      );

    Result := TJSONObject(JsonValue);
    JsonValue := nil;
  finally
    JsonValue.Free;
  end;
end;

class function TAppOptionsLoader.CloneJsonValue(const AValue: TJSONValue): TJSONValue;
begin
  if AValue = nil then
    Exit(TJSONNull.Create);

  Result := TJSONObject.ParseJSONValue(AValue.ToJSON);
  if Result = nil then
    raise EInvalidDependencyException.Create('Cannot clone JSON option value.');
end;

class procedure TAppOptionsLoader.MergeJsonObjects(const ATarget, ASource: TJSONObject);
begin
  if (ATarget = nil) or (ASource = nil) then
    Exit;

  for var Index := 0 to ASource.Count - 1 do
  begin
    var SourcePair := ASource.Pairs[Index];
    var FieldName := SourcePair.JsonString.Value;
    var SourceValue := SourcePair.JsonValue;
    var TargetValue := ATarget.GetValue(FieldName);

    if (TargetValue is TJSONObject) and (SourceValue is TJSONObject) then
    begin
      MergeJsonObjects(TJSONObject(TargetValue), TJSONObject(SourceValue));
      Continue;
    end;

    var RemovedPair := ATarget.RemovePair(FieldName);
    try
      ATarget.AddPair(FieldName, CloneJsonValue(SourceValue));
    finally
      RemovedPair.Free;
    end;
  end;
end;

end.
