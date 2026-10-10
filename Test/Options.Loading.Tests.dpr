program OptionsLoadingTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  System.JSON,
  AppExceptions,
  App.Options.Loader,
  Container.App,
  Http.Server.Options;

const
  CustomJson = '{"HttpServer":{"Port":9090}}';

procedure Check(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure ExpectInvalidDependency(const AAction: TProc; const AMessage: string);
var
  Raised: Boolean;
begin
  Raised := False;
  try
    AAction();
  except
    on E: EInvalidDependencyException do
      Raised := True;
  end;
  Check(Raised, AMessage);
end;

procedure CheckPort(const ARoot: TJSONObject; const AExpected: Integer);
var
  Section: TJSONValue;
  Port: TJSONValue;
begin
  Check(ARoot <> nil, 'Root JSON must exist');
  Section := ARoot.GetValue('HttpServer');
  Check(Section is TJSONObject, 'HttpServer must be a JSON object');
  Port := TJSONObject(Section).GetValue('Port');
  Check(Port is TJSONNumber, 'HttpServer.Port must be a JSON number');
  Check(TJSONNumber(Port).AsInt = AExpected, 'Unexpected HttpServer.Port');
end;

procedure TestConstructionAndRegistration;
var
  Container: TAppContainer;
begin
  Check(not TDirectory.Exists('Config'), 'Test must start without Config');
  Container := TAppContainer.Create;
  try
    Check(Container <> nil, 'Constructor must succeed without default options');
    Container.AddOptions<THttpServerOptions>;
    Check(not TDirectory.Exists('Config'), 'Registration must not create Config');
  finally
    Container.Free;
  end;
end;

procedure TestCustomLoad(const APath: string);
var
  Container: TAppContainer;
  Root: TJSONObject;
  LoaderCalls: Integer;
begin
  Check(not TDirectory.Exists('Config'), 'Custom load must run without Config');
  TFile.WriteAllText(APath, CustomJson, TEncoding.UTF8);
  LoaderCalls := 0;
  Container := TAppContainer.Create;
  try
    Container.AddOptions<THttpServerOptions>;
    Container.LoadOptions(APath);
    // Removing the source distinguishes immediate loading from deferred I/O.
    TFile.Delete(APath);
    Root := Container.GetGlobalOptions;
    CheckPort(Root, 9090);
    TFile.WriteAllText(APath, CustomJson, TEncoding.UTF8);
    ExpectInvalidDependency(
      procedure
      begin
        Container.LoadOptions(APath);
      end,
      'LoadOptions must reject changes after materialization');
    ExpectInvalidDependency(
      procedure
      begin
        Container.SetOptionsLoader(
          function: TJSONObject
          begin
            Inc(LoaderCalls);
            Result := TJSONObject.Create;
          end);
      end,
      'SetOptionsLoader must reject changes after materialization');
    Check(LoaderCalls = 0, 'Rejected loader must not execute');
    Check(Container.GetGlobalOptions = Root, 'Root must remain cached');
    CheckPort(Root, 9090);
  finally
    // Root belongs to the container.
    Container.Free;
  end;
end;

procedure TestInvalidJson(const APath: string);
var
  Container: TAppContainer;
begin
  TFile.WriteAllText(APath, '{"HttpServer":', TEncoding.UTF8);
  Container := TAppContainer.Create;
  try
    ExpectInvalidDependency(
      procedure
      begin
        Container.LoadOptions(APath);
      end,
      'LoadOptions must reject malformed JSON immediately, without a getter');
    TFile.WriteAllText(APath, '[]', TEncoding.UTF8);
    ExpectInvalidDependency(
      procedure
      begin
        Container.LoadOptions(APath);
      end,
      'LoadOptions must reject a non-object JSON root immediately');
  finally
    Container.Free;
  end;
end;

procedure TestDeferredLoader;
var
  Container: TAppContainer;
  LoaderCalls: Integer;
  Root: TJSONObject;
begin
  LoaderCalls := 0;
  Container := TAppContainer.Create;
  try
    Container.SetOptionsLoader(
      function: TJSONObject
      begin
        Inc(LoaderCalls);
        Result := TJSONObject.Create;
        Result.AddPair('HttpServer',
          TJSONObject.Create.AddPair('Port', TJSONNumber.Create(9090)));
      end);
    Check(LoaderCalls = 0, 'SetOptionsLoader must be deferred');
    Container.AddOptions<THttpServerOptions>;
    Check(LoaderCalls = 0, 'AddOptions must not invoke the loader');
    Root := Container.GetGlobalOptions;
    Check(LoaderCalls = 1, 'First materialization must invoke the loader once');
    CheckPort(Root, 9090);
    Check(Container.GetGlobalOptions = Root, 'Repeated access must reuse the root');
    Check(LoaderCalls = 1, 'Repeated access must not invoke the loader again');
  finally
    Container.Free;
  end;
end;

procedure TestLoaderModes(const APath: string);
var
  Root: TJSONObject;
  Section: TJSONObject;
begin
  TFile.WriteAllText(APath, CustomJson, TEncoding.UTF8);
  Root := TAppOptionsLoader.LoadFromFile(APath);
  try
    CheckPort(Root, 9090);
  finally
    Root.Free;
  end;

  // Only this final test creates a default, inside the isolated directory.
  TDirectory.CreateDirectory('Config');
  TFile.WriteAllText(TPath.Combine('Config', 'Config.json'),
    '{"HttpServer":{"Port":8080,"DefaultOnly":true},"DefaultRoot":true}',
    TEncoding.UTF8);
  Root := TAppOptionsLoader.LoadFromFile(APath);
  try
    CheckPort(Root, 9090);
    Check(Root.Count = 1, 'LoadFromFile must not merge default root values');
    Section := TJSONObject(Root.GetValue('HttpServer'));
    Check(Section.Count = 1, 'LoadFromFile must not merge default section values');
  finally
    Root.Free;
  end;

  Root := TAppOptionsLoader.LoadWithOverrides(APath);
  try
    CheckPort(Root, 9090);
    Check(Root.GetValue<Boolean>('DefaultRoot'), 'Merge must preserve default root values');
    Section := TJSONObject(Root.GetValue('HttpServer'));
    Check(Section.GetValue<Boolean>('DefaultOnly'), 'Merge must preserve nested default values');
  finally
    Root.Free;
  end;
end;

procedure RunTests;
var
  OriginalDirectory: string;
  TemporaryDirectory: string;
  Id: TGUID;
begin
  OriginalDirectory := GetCurrentDir;
  Check(CreateGUID(Id) = 0, 'Cannot generate a temporary directory name');
  TemporaryDirectory := TPath.Combine(TPath.GetTempPath,
    'Options.Loading.Tests-' + GUIDToString(Id));
  Check(not TDirectory.Exists(TemporaryDirectory), 'Temporary directory must be new');
  TDirectory.CreateDirectory(TemporaryDirectory);
  try
    Check(SetCurrentDir(TemporaryDirectory), 'Cannot enter temporary directory');
    TestConstructionAndRegistration;
    TestCustomLoad(TPath.Combine(TemporaryDirectory, 'custom.json'));
    TestInvalidJson(TPath.Combine(TemporaryDirectory, 'invalid.json'));
    TestDeferredLoader;
    TestLoaderModes(TPath.Combine(TemporaryDirectory, 'custom.json'));
  finally
    try
      Check(SetCurrentDir(OriginalDirectory), 'Cannot restore working directory');
    finally
      TDirectory.Delete(TemporaryDirectory, True);
    end;
  end;
end;

begin
  try
    RunTests;
    Writeln('Options loading tests passed.');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
