program ContainerConcurrencyTests;

{$APPTYPE CONSOLE}

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
    Root.AddSingletonFactory<TService, TService>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        Result := TService.Create;
      end);
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
    ExpectFrozen(procedure begin
      Root.AddFactory(TypeInfo(TBridge),
        function(const Resolve: TDependencyResolver): TObject
        begin Result := TBridge.Create; end, dlSingleton);
    end);
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
    Root.AddSingletonFactory<TService, TService>(
      function(const Resolve: TDependencyResolver): TObject
      begin Result := TService.Create; end);
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
  Calls, ScopedCalls: Integer;
  Published: Pointer;
begin
  Calls := 0;
  ScopedCalls := 0;
  Published := nil;
  Root := NewContainer;
  try
    Root.AddSingletonFactory<TService, TService>(
      function(const Resolve: TDependencyResolver): TObject
      var Service: TService;
      begin
        TInterlocked.Increment(Calls);
        Service := TService.Create;
        TThread.Sleep(20);
        Service.Ready := 42;
        Result := Service;
      end);
    Root.AddScopedFactory<TScopedService, TScopedService>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        TInterlocked.Increment(ScopedCalls);
        Result := TScopedService.Create;
      end);
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
    Check(Calls = 1, 'Concurrent singleton factory must execute exactly once');
    Check(ScopedCalls = 24, 'Each worker must construct exactly two scoped instances');
  finally
    Root.Free;
  end;
end;

procedure TestReentrancyAndRetry;
var
  Root: TAppContainer;
  Calls: Integer;
  Instance: TObject;
begin
  Root := NewContainer;
  Calls := 0;
  try
    Root.AddSingletonFactory<TOther, TOther>(
      function(const Resolve: TDependencyResolver): TObject
      begin Result := TOther.Create; end);
    Root.AddSingletonFactory<TService, TService>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        Inc(Calls);
        Check(Resolve(TypeInfo(TOther)) <> nil, 'Reentrant singleton resolution failed');
        if Calls = 1 then
          raise Exception.Create('Expected factory failure');
        if Calls = 2 then
          Exit(nil);
        Result := TService.Create;
      end);
    Root.Prepare;
    try
      Root.Resolve(TypeInfo(TService));
      Check(False, 'First singleton resolution must fail');
    except
      on E: Exception do
        Check(E.Message = 'Expected factory failure', 'Unexpected factory exception: ' + E.Message);
    end;
    ExpectMissing(procedure begin Root.Resolve(TypeInfo(TService)); end,
      'Nil singleton result must fail');
    Instance := Root.Resolve(TypeInfo(TService));
    Check(Instance <> nil, 'Failed singleton must be retried');
    Check(Root.Resolve(TypeInfo(TService)) = Instance, 'Successful retry must be cached');
    Check(Calls = 3, 'Failures/nil must not be cached; successful result must be cached');
  finally
    Root.Free;
  end;
end;

procedure TestCyclesAndCleanup;
var
  Root, OtherRoot: TAppContainer;
  Cycle: Boolean;
begin
  Root := NewContainer;
  OtherRoot := NewContainer;
  Cycle := True;
  try
    OtherRoot.AddSingletonFactory<TService, TService>(
      function(const Resolve: TDependencyResolver): TObject
      begin Result := TService.Create; end);
    OtherRoot.Prepare;
    Root.AddSingletonFactory<TService, TService>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        Check(OtherRoot.Resolve(TypeInfo(TService)) <> nil,
          'Resolution frames must be isolated by root');
        if Cycle then
          Resolve(TypeInfo(TOther));
        Result := TService.Create;
      end);
    Root.AddTransientFactory<TOther, TOther>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        Resolve(TypeInfo(TService));
        Result := TOther.Create;
      end);
    Root.Prepare;
    ExpectMissing(procedure begin Root.Resolve(TypeInfo(TService)); end,
      'Indirect singleton/transient cycle must fail');
    ExpectMissing(procedure begin Root.Resolve(TypeInfo(TService)); end,
      'Repeated cycle must fail without leaving stale resolution frames');
    Cycle := False;
    Check(Root.Resolve(TypeInfo(TService)) <> nil, 'Frames must unwind after cycle exception');
  finally
    Root.Free;
    OtherRoot.Free;
  end;
end;

procedure TestSingletonCycleAndCleanup;
var
  Root: TAppContainer;
  Cycle: Boolean;
  Instance: TObject;
begin
  Root := NewContainer;
  Cycle := True;
  try
    Root.AddSingletonFactory<TService, TService>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        Resolve(TypeInfo(TOther));
        Result := TService.Create;
      end);
    Root.AddSingletonFactory<TOther, TOther>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        if Cycle then
          Resolve(TypeInfo(TService));
        Result := TOther.Create;
      end);
    Root.Prepare;
    ExpectMissing(procedure begin Root.Resolve(TypeInfo(TService)); end,
      'Indirect singleton/singleton cycle must fail');
    ExpectMissing(procedure begin Root.Resolve(TypeInfo(TOther)); end,
      'Singleton cycle must unwind frames for both registrations');
    Cycle := False;
    Instance := Root.Resolve(TypeInfo(TService));
    Check(Instance <> nil, 'Singleton cycle must allow retry after exception');
    Check(Root.Resolve(TypeInfo(TService)) = Instance,
      'Successful singleton retry after cycle must be cached');
    Check(Root.Resolve(TypeInfo(TOther)) <> nil,
      'Nested singleton must be available after cycle recovery');
  finally
    Root.Free;
  end;
end;

procedure TestCaptiveScoped;
var
  Root: TAppContainer;
  Scope: TContainerScope;
  Cached: TObject;
  Indirect: Boolean;
begin
  Root := NewContainer;
  Scope := nil;
  Indirect := False;
  try
    Root.AddScopedFactory<TScopedService, TScopedService>(
      function(const Resolve: TDependencyResolver): TObject
      begin Result := TScopedService.Create; end);
    Root.AddTransientFactory<TBridge, TBridge>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        Scope.Resolve(TypeInfo(TScopedService));
        Result := TBridge.Create;
      end);
    Root.AddSingletonFactory<TService, TService>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        if Indirect then
          Scope.Resolve(TypeInfo(TBridge))
        else
          Scope.Resolve(TypeInfo(TScopedService));
        Result := TService.Create;
      end);
    Root.Prepare;
    Scope := Root.CreateScope;
    Cached := Scope.Resolve(TypeInfo(TScopedService));
    ExpectMissing(procedure begin Root.Resolve(TypeInfo(TService)); end,
      'Singleton must reject cached scoped service through captured scope');
    Indirect := True;
    ExpectMissing(procedure begin Root.Resolve(TypeInfo(TService)); end,
      'Singleton must reject indirect cached scoped capture through transient factory');
    Check(Scope.Resolve(TypeInfo(TScopedService)) = Cached,
      'Failed captive resolution must unwind frames and preserve scoped cache');
  finally
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
