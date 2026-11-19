program ContainerConcurrencyTests;

{$APPTYPE CONSOLE}
{$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([]) FIELDS([])}

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.TypInfo,
  System.JSON,
  AppExceptions,
  Container.App,
  Container.Scope,
  Container.DependencyDescriptor,
  Application.Options,
  Http.Server.Options;

type
  TService = class
  public
    Ready: Integer;
  end;
  TOther = class(TService);
  TScopedService = class(TService);
  TBridge = class(TService);

  TPublishedService = class(TService)
  public
    constructor Create;
  end;

  TCountedScopedService = class(TScopedService)
  public
    constructor Create;
  end;

  TRetryService = class(TService)
  public
    constructor Create(const AOther: TOther);
  end;

  TCycleService = class(TService)
  public
    constructor Create;
  end;

  TCycleOther = class(TOther)
  public
    constructor Create;
  end;

  TSingletonCycleService = class(TService)
  public
    constructor Create;
  end;

  TSingletonCycleOther = class(TOther)
  public
    constructor Create;
  end;

  TCaptiveService = class(TService)
  public
    constructor Create;
  end;

  TCaptiveBridge = class(TBridge)
  public
    constructor Create;
  end;

  TWorker = class(TThread)
  private
    FStart: TEvent;
    FAction: TProc;
  protected
    procedure Execute; override;
  public
    Error: string;
    constructor Create(const AStart: TEvent; const AAction: TProc);
  end;

var
  PublicationCalls, ScopedConstructionCalls, RetryCalls: Integer;
  FixtureRoot, FixtureOtherRoot: TAppContainer;
  FixtureScope: TContainerScope;
  FixtureCycle, FixtureIndirect: Boolean;

constructor TPublishedService.Create;
begin
  inherited Create;
  TInterlocked.Increment(PublicationCalls);
  TThread.Sleep(20);
  Ready := 42;
end;

constructor TCountedScopedService.Create;
begin
  inherited Create;
  TInterlocked.Increment(ScopedConstructionCalls);
end;

constructor TRetryService.Create(const AOther: TOther);
begin
  inherited Create;
  if AOther = nil then
    raise Exception.Create('Reentrant singleton injection failed');
  Inc(RetryCalls);
  if RetryCalls = 1 then
    raise Exception.Create('Expected constructor failure');
end;

constructor TCycleService.Create;
begin
  inherited Create;
  if FixtureOtherRoot.Resolve(TypeInfo(TService)) = nil then
    raise Exception.Create('Resolution frames must be isolated by root');
  if FixtureCycle then
    FixtureRoot.Resolve(TypeInfo(TOther));
end;

constructor TCycleOther.Create;
begin
  inherited Create;
  FixtureRoot.Resolve(TypeInfo(TService));
end;

constructor TSingletonCycleService.Create;
begin
  inherited Create;
  FixtureRoot.Resolve(TypeInfo(TOther));
end;

constructor TSingletonCycleOther.Create;
begin
  inherited Create;
  if FixtureCycle then
    FixtureRoot.Resolve(TypeInfo(TService));
end;

constructor TCaptiveService.Create;
begin
  inherited Create;
  if FixtureIndirect then
    FixtureScope.Resolve(TypeInfo(TBridge))
  else
    FixtureScope.Resolve(TypeInfo(TScopedService));
end;

constructor TCaptiveBridge.Create;
begin
  inherited Create;
  FixtureScope.Resolve(TypeInfo(TScopedService));
end;

constructor TWorker.Create(const AStart: TEvent; const AAction: TProc);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FStart := AStart;
  FAction := AAction;
end;

procedure TWorker.Execute;
begin
  try
    if FStart.WaitFor(10000) <> wrSignaled then
      raise Exception.Create('Worker start barrier timed out');
    FAction();
  except
    on E: Exception do
      Error := E.ClassName + ': ' + E.Message;
  end;
end;

procedure Check(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure ExpectMissing(const AAction: TProc; const AMessage: string);
var
  Raised: Boolean;
begin
  Raised := False;
  try
    AAction();
  except
    on E: EMissingDependencyException do
      Raised := True;
  end;
  Check(Raised, AMessage);
end;

procedure ExpectFrozen(const AAction: TProc);
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
  Check(Raised, 'Registration must be frozen after Prepare');
end;

function NewContainer: TAppContainer;
begin
  Result := TAppContainer.Create;
  Result.SetOptionsLoader(
    function: TJSONObject
    begin
      Result := TJSONObject.Create;
      Result.AddPair('Application',
        TJSONObject.Create.AddPair('Environment', 'production'));
      Result.AddPair('HttpServer',
        TJSONObject.Create.AddPair('Port', TJSONNumber.Create(8080)));
    end);
  Result.AddOptions<THttpServerOptions>;
end;

procedure RunParallel(const AAction: TProc);
const
  WorkerCount = 12;
var
  Start: TEvent;
  Workers: array[0..WorkerCount - 1] of TWorker;
  I: Integer;
begin
  Start := TEvent.Create(nil, True, False, '');
  for I := Low(Workers) to High(Workers) do
    Workers[I] := nil;
  try
    try
      for I := Low(Workers) to High(Workers) do
      begin
        Workers[I] := TWorker.Create(Start, AAction);
        Workers[I].Start;
      end;
    finally
      Start.SetEvent;
      for I := Low(Workers) to High(Workers) do
        if Workers[I] <> nil then
          Workers[I].WaitFor;
    end;
    for I := Low(Workers) to High(Workers) do
      Check(Workers[I].Error = '', 'Worker failed: ' + Workers[I].Error);
  finally
    for I := Low(Workers) to High(Workers) do
      Workers[I].Free;
    Start.Free;
  end;
end;

procedure TestPrepareAndFreeze;
var
  Root: TAppContainer;
  Calls: Integer;
  Options: TApplicationOptions;
begin
  Calls := 0;
  Root := NewContainer;
  try
    Root.SetOptionsLoader(
      function: TJSONObject
      begin
        Inc(Calls);
        Result := TJSONObject.Create;
        Result.AddPair('Application',
          TJSONObject.Create.AddPair('Environment', 'production'));
        Result.AddPair('HttpServer',
          TJSONObject.Create.AddPair('Port', TJSONNumber.Create(8080)));
      end);
    Root.AddSingleton<TService, TService>;
    Root.Resolve(TypeInfo(TService));
    // Neither lazy service resolution nor lazy options loading freezes registration.
    Options := Root.GetOptions<TApplicationOptions>;
    Options.Free;
    Root.AddTransient<TOther, TOther>;
    Root.Prepare;
    Root.Prepare;
    Check(Calls = 1, 'Prepare must reuse options loaded before Prepare');
    ExpectFrozen(procedure begin Root.AddSingleton<TBridge, TBridge>; end);
    ExpectFrozen(procedure begin Root.AddScoped<TBridge, TBridge>; end);
    ExpectFrozen(procedure begin Root.AddTransient<TBridge, TBridge>; end);
    ExpectFrozen(procedure begin Root.AddOptions<THttpServerOptions>; end);
    ExpectFrozen(procedure begin Root.AddController(TService); end);
    ExpectFrozen(procedure begin Root.Use(TService); end);
    ExpectFrozen(procedure begin Root.AddAttributeHandler(TService); end);

  finally
    Root.Free;
  end;

  Calls := 0;
  Root := NewContainer;
  try
    Root.SetOptionsLoader(
      function: TJSONObject
      begin
        Inc(Calls);
        Result := TJSONObject.Create;
        Result.AddPair('Application', TJSONObject.Create);
        Result.AddPair('HttpServer', TJSONObject.Create);
      end);
    Check(Calls = 0, 'Loader must remain lazy');
    Root.Prepare;
    Root.Prepare;
    Check(Calls = 1, 'Prepare must load options exactly once');
  finally
    Root.Free;
  end;
end;

procedure TestPrepareFailureAndRetry;
var
  Root: TAppContainer;
  Calls: Integer;
  Failed: Boolean;
begin
  Root := NewContainer;
  Calls := 0;
  try
    Root.SetOptionsLoader(
      function: TJSONObject
      begin
        Inc(Calls);
        if Calls = 1 then
          raise Exception.Create('Expected options loader failure');
        Result := TJSONObject.Create;
        Result.AddPair('Application',
          TJSONObject.Create.AddPair('Environment', 'production'));
        Result.AddPair('HttpServer',
          TJSONObject.Create.AddPair('Port', TJSONNumber.Create(8080)));
      end);
    Failed := False;
    try
      Root.Prepare;
    except
      on E: Exception do
      begin
        Check(E.Message = 'Expected options loader failure',
          'Unexpected Prepare exception: ' + E.Message);
        Failed := True;
      end;
    end;
    Check(Failed, 'Prepare must propagate options loader failure');
    Check(Calls = 1, 'First Prepare must invoke loader once');
    Root.AddSingleton<TService, TService>;
    Root.Prepare;
    Root.Prepare;
    Check(Calls = 2, 'Prepare must retry failed loading and cache successful loading');
    Check(Root.Resolve(TypeInfo(TService)) <> nil,
      'Registration after failed Prepare must remain available');
    ExpectFrozen(procedure begin Root.AddTransient<TOther, TOther>; end);
  finally
    Root.Free;
  end;
end;

procedure TestPublicationAndScopes;
var
  Root: TAppContainer;
  Published: Pointer;
begin
  PublicationCalls := 0;
  ScopedConstructionCalls := 0;
  Published := nil;
  Root := NewContainer;
  try
    Root.AddSingleton<TService, TPublishedService>;
    Root.AddScoped<TScopedService, TCountedScopedService>;
    Root.Prepare;
    RunParallel(
      procedure
      var
        First, Second: TContainerScope;
        Service: TObject;
        I: Integer;
      begin
        First := Root.CreateScope;
        try
          Second := Root.CreateScope;
          try
            for I := 1 to 100 do
            begin
              Service := Root.Resolve(TypeInfo(TService));
              Check(TService(Service).Ready = 42, 'Partially published singleton');
              TInterlocked.CompareExchange(Published, Pointer(Service), nil);
              Check(Pointer(Service) = Published, 'Singleton identity differs between threads');
              Check(First.Resolve(TypeInfo(TService)) = Service, 'Scope singleton differs');
              Check(First.Resolve(TypeInfo(TScopedService)) =
                First.Resolve(TypeInfo(TScopedService)), 'Same scope must reuse instance');
              Check(First.Resolve(TypeInfo(TScopedService)) <>
                Second.Resolve(TypeInfo(TScopedService)), 'Different scopes must be isolated');
            end;
          finally
            Second.Free;
          end;
        finally
          First.Free;
        end;
      end);
    Check(PublicationCalls = 1, 'Concurrent singleton constructor must execute exactly once');
    Check(ScopedConstructionCalls = 24, 'Each worker must construct exactly two scoped instances');
  finally
    Root.Free;
  end;
end;

procedure TestReentrancyAndRetry;
var
  Root: TAppContainer;
  Instance: TObject;
begin
  Root := NewContainer;
  RetryCalls := 0;
  try
    Root.AddSingleton<TOther, TOther>;
    Root.AddSingleton<TService, TRetryService>;
    Root.Prepare;
    try
      Root.Resolve(TypeInfo(TService));
      Check(False, 'First singleton resolution must fail');
    except
      on E: Exception do
        Check(E.Message = 'Expected constructor failure', 'Unexpected constructor exception: ' + E.Message);
    end;
    Instance := Root.Resolve(TypeInfo(TService));
    Check(Instance <> nil, 'Failed singleton must be retried');
    Check(Root.Resolve(TypeInfo(TService)) = Instance, 'Successful retry must be cached');
    Check(RetryCalls = 2, 'Failed construction must not be cached; successful result must be cached');
  finally
    Root.Free;
  end;
end;

procedure TestCyclesAndCleanup;
var
  Root, OtherRoot: TAppContainer;
begin
  Root := NewContainer;
  OtherRoot := NewContainer;
  FixtureRoot := Root;
  FixtureOtherRoot := OtherRoot;
  FixtureCycle := True;
  try
    OtherRoot.AddSingleton<TService, TService>;
    OtherRoot.Prepare;
    Root.AddSingleton<TService, TCycleService>;
    Root.AddTransient<TOther, TCycleOther>;
    Root.Prepare;
    ExpectMissing(procedure begin Root.Resolve(TypeInfo(TService)); end,
      'Indirect singleton/transient cycle must fail');
    ExpectMissing(procedure begin Root.Resolve(TypeInfo(TService)); end,
      'Repeated cycle must fail without leaving stale resolution frames');
    FixtureCycle := False;
    Check(Root.Resolve(TypeInfo(TService)) <> nil, 'Frames must unwind after cycle exception');
  finally
    FixtureRoot := nil;
    FixtureOtherRoot := nil;
    Root.Free;
    OtherRoot.Free;
  end;
end;

procedure TestSingletonCycleAndCleanup;
var
  Root: TAppContainer;
  Instance: TObject;
begin
  Root := NewContainer;
  FixtureRoot := Root;
  FixtureCycle := True;
  try
    Root.AddSingleton<TService, TSingletonCycleService>;
    Root.AddSingleton<TOther, TSingletonCycleOther>;
    Root.Prepare;
    ExpectMissing(procedure begin Root.Resolve(TypeInfo(TService)); end,
      'Indirect singleton/singleton cycle must fail');
    ExpectMissing(procedure begin Root.Resolve(TypeInfo(TOther)); end,
      'Singleton cycle must unwind frames for both registrations');
    FixtureCycle := False;
    Instance := Root.Resolve(TypeInfo(TService));
    Check(Instance <> nil, 'Singleton cycle must allow retry after exception');
    Check(Root.Resolve(TypeInfo(TService)) = Instance,
      'Successful singleton retry after cycle must be cached');
    Check(Root.Resolve(TypeInfo(TOther)) <> nil,
      'Nested singleton must be available after cycle recovery');
  finally
    FixtureRoot := nil;
    Root.Free;
  end;
end;

procedure TestCaptiveScoped;
var
  Root: TAppContainer;
  Scope: TContainerScope;
  Cached: TObject;
begin
  Root := NewContainer;
  Scope := nil;
  FixtureScope := nil;
  FixtureIndirect := False;
  try
    Root.AddScoped<TScopedService, TScopedService>;
    Root.AddTransient<TBridge, TCaptiveBridge>;
    Root.AddSingleton<TService, TCaptiveService>;
    Root.Prepare;
    Scope := Root.CreateScope;
    FixtureScope := Scope;
    Cached := Scope.Resolve(TypeInfo(TScopedService));
    ExpectMissing(procedure begin Root.Resolve(TypeInfo(TService)); end,
      'Singleton must reject cached scoped service through captured scope');
    FixtureIndirect := True;
    ExpectMissing(procedure begin Root.Resolve(TypeInfo(TService)); end,
      'Singleton must reject indirect cached scoped capture through transient constructor');
    Check(Scope.Resolve(TypeInfo(TScopedService)) = Cached,
      'Failed captive resolution must unwind frames and preserve scoped cache');
  finally
    FixtureScope := nil;
    Scope.Free;
    Root.Free;
  end;
end;

var
  Done: TEvent;
  Watchdog: TThread;
begin
  Done := TEvent.Create(nil, True, False, '');
  Watchdog := TThread.CreateAnonymousThread(
    procedure
    begin
      if Done.WaitFor(30000) <> wrSignaled then
      begin
        Writeln('FAIL: container concurrency watchdog exceeded 30 seconds.');
        Halt(2);
      end;
    end);
  Watchdog.FreeOnTerminate := False;
  Watchdog.Start;
  try
    try
      TestPrepareAndFreeze;
      TestPrepareFailureAndRetry;
      TestPublicationAndScopes;
      TestReentrancyAndRetry;
      TestCyclesAndCleanup;
      TestSingletonCycleAndCleanup;
      TestCaptiveScoped;
      Writeln('Container concurrency tests passed.');
    except
      on E: Exception do
      begin
        Writeln(E.ClassName + ': ' + E.Message);
        ExitCode := 1;
      end;
    end;
  finally
    Done.SetEvent;
    Watchdog.WaitFor;
    Watchdog.Free;
    Done.Free;
  end;
end.
