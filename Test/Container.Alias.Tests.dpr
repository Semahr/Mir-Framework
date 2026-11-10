program ContainerAliasTests;

{$APPTYPE CONSOLE}
{$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([]) FIELDS([])}

uses
  System.SysUtils,
  System.Classes,
  System.TypInfo,
  System.Rtti,
  System.JSON,
  AppExceptions,
  Container.App,
  Container.Scope,
  Container.DependencyDescriptor,
  Dependency.Attributes;

type
  IPrimary = interface
    ['{553FA94C-F492-452B-A571-70F2507F6701}']
    function PrimaryValue: Integer;
  end;
  IAlias = interface
    ['{553FA94C-F492-452B-A571-70F2507F6702}']
    function AliasValue: Integer;
  end;
  IOther = interface
    ['{553FA94C-F492-452B-A571-70F2507F6703}']
    function OtherValue: Integer;
  end;
  IMissing = interface
    ['{553FA94C-F492-452B-A571-70F2507F6704}']
  end;

  ISecondAlias = interface
    ['{553FA94C-F492-452B-A571-70F2507F6705}']
    function SecondAliasValue: Integer;
  end;

  // TComponent interfaces do not transfer lifetime ownership to interface references.
  TService = class(TComponent, IPrimary, IAlias, ISecondAlias)
  public
    class var Destroyed: Integer;
    [Inject]
    constructor Create; reintroduce;
    function PrimaryValue: Integer;
    function AliasValue: Integer;
    function SecondAliasValue: Integer;
    destructor Destroy; override;
  end;

  TConsumer = class(TComponent)
  public
    Primary: IPrimary;
    Alias: IAlias;
    constructor Create(AOwner: TComponent); overload; override;
    [Inject]
    constructor Create(const APrimary: IPrimary; const AAlias: IAlias); reintroduce; overload;
  end;

  TIncompatibleConsumer = class(TComponent)
  public
    [Inject]
    constructor Create(const AOther: IOther); reintroduce;
  end;

constructor TService.Create;
begin
  inherited Create(nil);
end;

function TService.SecondAliasValue: Integer;
begin
  Result := 41;
end;

function TService.PrimaryValue: Integer;
begin
  Result := 17;
end;

function TService.AliasValue: Integer;
begin
  Result := 29;
end;

destructor TService.Destroy;
begin
  Inc(Destroyed);
  inherited;
end;

constructor TConsumer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  raise Exception.Create('Wrong constructor selected');
end;

constructor TConsumer.Create(const APrimary: IPrimary; const AAlias: IAlias);
begin
  inherited Create(nil);
  Primary := APrimary;
  Alias := AAlias;
end;

constructor TIncompatibleConsumer.Create(const AOther: IOther);
begin
  inherited Create(nil);
  raise Exception.Create('Incompatible interface reached constructor');
end;

procedure Check(const Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure ExpectFailure(const Action: TProc; const MessageText: string);
var
  Raised: Boolean;
begin
  Raised := False;
  try
    Action();
  except
    on E: EMissingDependencyException do Raised := True;
    on E: EInvalidDependencyException do Raised := True;
    on E: EArgumentException do Raised := True;
  end;
  Check(Raised, MessageText);
end;

function NewContainer: TAppContainer;
begin
  Result := TAppContainer.Create;
  Result.SetOptionsLoader(
    function: TJSONObject
    begin
      Result := TJSONObject.Create;
      Result.AddPair('Application', TJSONObject.Create);
      Result.AddPair('HttpServer', TJSONObject.Create);
    end);
end;

procedure TestSingletonAndInjection;
var
  Root: TAppContainer;
  Scope: TContainerScope;
  Service: TObject;
  Consumer: TConsumer;
  Primary: IPrimary;
  Alias: IAlias;
  SupportedAlias: IAlias;
  Calls: Integer;
begin
  TService.Destroyed := 0;
  Calls := 0;
  Root := NewContainer;
  try
    Root.AddSingletonFactory<IPrimary, TService>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        Inc(Calls);
        Result := TService.Create;
      end);
    Root.AddAlias<IAlias, IPrimary>;
    Root.AddAlias<ISecondAlias, IPrimary>;
    Root.AddTransient<TConsumer, TConsumer>;
    Check(Root.GetDescriptor(TypeInfo(IAlias)) = Root.GetDescriptor(TypeInfo(IPrimary)),
      'Alias must expose principal descriptor');
    Check(Root.GetDescriptor(TypeInfo(ISecondAlias)) = Root.GetDescriptor(TypeInfo(IPrimary)),
      'Second alias must expose the same principal descriptor');
    Root.Prepare;
    Root.Prepare;
    Scope := Root.CreateScope;
    try
      Root.Resolve<IPrimary>; // Ignored result is valid for singleton warmup.
      Primary := Root.Resolve<IPrimary>;
      Alias := Root.Resolve<IAlias>;
      Service := Root.Resolve(TypeInfo(IAlias));
      Check(Primary.PrimaryValue = 17, 'Generic primary contract');
      Check(Alias.AliasValue = 29, 'Generic alias must use its exact GUID');
      Check(Supports(Service, IAlias, SupportedAlias), 'Underlying object supports alias');
      Check(Alias = SupportedAlias, 'Generic alias must expose the underlying object interface');
      Check(Service = Root.Resolve(TypeInfo(IPrimary)), 'Singleton alias identity');
      Check(Service = Root.Resolve(TypeInfo(ISecondAlias)), 'Multiple singleton aliases identity');
      Check(Service = Scope.Resolve(TypeInfo(ISecondAlias)), 'Scope second alias singleton identity');
      Check(Service = Scope.Resolve(TypeInfo(IAlias)), 'Scope must reuse root singleton');
      // Resolve twice: also exercises injection after singleton caching.
      Consumer := TConsumer(Scope.Resolve(TypeInfo(TConsumer)));
      Check(Consumer.Primary.PrimaryValue = 17, 'Exact primary TValue injection');
      Check(Consumer.Alias.AliasValue = 29, 'Exact alias TValue injection');
      Consumer := TConsumer(Scope.Resolve(TypeInfo(TConsumer)));
      Check(Consumer.Alias.AliasValue = 29, 'Repeated alias injection');
      Check(Calls = 1, 'Alias must not construct another singleton');
    finally
      SupportedAlias := nil;
      Alias := nil;
      Primary := nil;
      Scope.Free;
    end;
    Check(TService.Destroyed = 0, 'Scope must not own singleton alias');
  finally
    Root.Free;
  end;
  Check(TService.Destroyed = 1, 'Singleton must be destroyed exactly once');
end;

procedure TestTypedSingletonValue;
var
  Root: TAppContainer;
  Scope: TContainerScope;
  Service: TService;
  Primary: IPrimary;
  Alias: IAlias;
  Descriptor: TSingletonDependencyDescriptor;
  Consumer: TConsumer;
begin
  Root := NewContainer;
  try
    Service := TService.Create;
    Root.RegisterInstance(TypeInfo(IPrimary), Service);
    Root.AddAlias<IAlias, IPrimary>;
    Root.AddAlias<IOther, IPrimary>;
    Root.AddTransient<TConsumer, TConsumer>;
    Root.AddTransient<TIncompatibleConsumer, TIncompatibleConsumer>;
    // Bootstrap-only fixture for the typed singleton shortcut used by options.
    Check(Supports(Service, IPrimary, Primary), 'Primary interface fixture');
    Descriptor := TSingletonDependencyDescriptor(Root.GetDescriptor(TypeInfo(IPrimary)));
    Descriptor.InstanceValue := TValue.From<IPrimary>(Primary);
    Descriptor.HasInstanceValue := True;
    Primary := nil;
    Root.Prepare;
    Primary := Root.Resolve<IPrimary>;
    Alias := Root.Resolve<IAlias>;
    Check(Primary.PrimaryValue = 17, 'Generic matching InstanceValue contract');
    Check(Alias.AliasValue = 29, 'Generic alias must not reuse principal InstanceValue');
    Check(Descriptor.InstanceValue.TypeInfo = TypeInfo(IPrimary),
      'Generic alias must preserve principal InstanceValue type');
    ExpectFailure(procedure begin Root.Resolve<IOther>; end,
      'Generic incompatible alias must not use InstanceValue shortcut');
    Scope := Root.CreateScope;
    try
      Consumer := TConsumer(Scope.Resolve(TypeInfo(TConsumer)));
      Check(Consumer.Primary.PrimaryValue = 17, 'Matching InstanceValue contract');
      Check(Consumer.Alias.AliasValue = 29, 'Alias must not reuse principal-typed TValue');
      ExpectFailure(procedure begin Scope.Resolve(TypeInfo(TIncompatibleConsumer)); end,
        'Typed singleton shortcut must not bypass Supports for an alias');
    finally
      Scope.Free;
    end;
  finally
    Alias := nil;
    Primary := nil;
    Root.Free;
  end;
end;

procedure TestGenericClassAndInvalidTypes;
var
  Root: TAppContainer;
  Service: TService;
begin
  Root := NewContainer;
  try
    Root.AddSingleton<TService, TService>;
    // Factory implementations are not constrained to return the advertised class.
    Root.AddSingletonFactory<TConsumer, TService>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        Result := TService.Create;
      end);
    Root.Prepare;
    Service := Root.Resolve<TService>;
    Check(Service <> nil, 'Registered class must resolve');
    Check(Service = Root.Resolve(TypeInfo(TService)), 'Generic class identity');
    Check(Service.PrimaryValue = 17, 'Generic class methods');
    ExpectFailure(procedure begin Root.Resolve<TConsumer>; end,
      'Generic class must validate actual instance type');
    ExpectFailure(procedure begin Root.Resolve<Integer>; end,
      'Generic resolution must reject unsupported types');
    ExpectFailure(procedure begin Root.Resolve<IMissing>; end,
      'Generic resolution must reject missing interface');
  finally
    Root.Free;
  end;
end;

procedure TestScoped;
var
  Root: TAppContainer;
  First, Second: TContainerScope;
  A, B: TObject;
  Calls: Integer;
begin
  Calls := 0;
  TService.Destroyed := 0;
  Root := NewContainer;
  try
    Root.AddScopedFactory<IPrimary, TService>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        Inc(Calls);
        Result := TService.Create;
      end);
    Root.AddAlias(TypeInfo(IAlias), TypeInfo(IPrimary));
    Root.Prepare;
    First := Root.CreateScope;
    try
      Second := Root.CreateScope;
      try
        A := First.Resolve(TypeInfo(IAlias));
        Check(A = First.Resolve(TypeInfo(IPrimary)), 'Alias-first scoped cache');
        B := Second.Resolve(TypeInfo(IPrimary));
        Check(B = Second.Resolve(TypeInfo(IAlias)), 'Principal-first scoped cache');
        Check(A <> B, 'Different scopes must have different instances');
        Check(Calls = 2, 'Only one construction per scope');
        ExpectFailure(procedure begin Root.Resolve<IPrimary>; end,
          'Generic root must reject scoped principal resolution');
        ExpectFailure(procedure begin Root.Resolve<IAlias>; end,
          'Generic root must reject scoped alias resolution');
        ExpectFailure(procedure begin Root.Resolve(TypeInfo(IAlias)); end,
          'Root must reject scoped alias resolution');
      finally
        Second.Free;
      end;
      Check(TService.Destroyed = 1, 'Second scope must destroy only its instance');
    finally
      First.Free;
    end;
    Check(TService.Destroyed = 2, 'Scoped aliases must not double free');
  finally
    Root.Free;
  end;
  Check(TService.Destroyed = 2, 'Root must not own scoped instances');
end;

procedure TestTransient;
var
  Root: TAppContainer;
  Scope: TContainerScope;
  A, B, C: TObject;
  Calls: Integer;
begin
  Calls := 0;
  TService.Destroyed := 0;
  Root := NewContainer;
  try
    Root.AddTransientFactory<IPrimary, TService>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        Inc(Calls);
        Result := TService.Create;
      end);
    Root.AddAlias<IAlias, IPrimary>;
    Root.Prepare;
    Scope := Root.CreateScope;
    try
      A := Scope.Resolve(TypeInfo(IAlias));
      B := Scope.Resolve(TypeInfo(IPrimary));
      C := Scope.Resolve(TypeInfo(IAlias));
      Check((A <> B) and (A <> C) and (B <> C), 'Transient aliases must not cache');
      Check(Calls = 3, 'Transient factory must run on every resolution');
      Check(TService.Destroyed = 0, 'Scope must retain transients until disposal');
    finally
      Scope.Free;
    end;
    Check(TService.Destroyed = 3, 'Scope must track every transient alias result');
  finally
    Root.Free;
  end;
  Check(TService.Destroyed = 3, 'Root must not free scoped transients again');
end;

procedure TestInvalidAndFreeze;
var
  Root: TAppContainer;
begin
  Root := NewContainer;
  try
    ExpectFailure(procedure begin Root.AddAlias<IAlias, IPrimary>; end, 'Missing target');
    Root.AddSingleton<IPrimary, TService>;
    ExpectFailure(procedure begin Root.AddAlias<IPrimary, IPrimary>; end, 'Self alias');
    ExpectFailure(procedure begin Root.AddAlias(nil, TypeInfo(IPrimary)); end, 'Nil alias');
    ExpectFailure(procedure begin Root.AddAlias(TypeInfo(IAlias), nil); end, 'Nil target');
    ExpectFailure(procedure begin Root.AddAlias(TypeInfo(TService), TypeInfo(IPrimary)); end,
      'Class alias is forbidden');
    ExpectFailure(procedure begin Root.AddAlias(TypeInfo(IAlias), TypeInfo(Integer)); end,
      'Noninterface target is forbidden');
    Root.AddSingleton<TService, TService>;
    ExpectFailure(procedure begin Root.AddAlias(TypeInfo(IAlias), TypeInfo(TService)); end,
      'Existing class target is forbidden');
    ExpectFailure(procedure begin Root.AddAlias(TypeInfo(Integer), TypeInfo(IPrimary)); end,
      'Noninterface alias is forbidden');
    Root.AddAlias<IAlias, IPrimary>;
    ExpectFailure(procedure begin Root.AddAlias<IOther, IAlias>; end, 'Alias chains forbidden');
    ExpectFailure(procedure begin Root.AddAlias<IAlias, IPrimary>; end, 'Duplicate alias');
    ExpectFailure(procedure begin Root.AddAlias<IPrimary, IAlias>; end, 'Existing principal key');
    ExpectFailure(procedure begin Root.AddSingleton<IAlias, TService>; end, 'Singleton overwrite');
    ExpectFailure(procedure begin Root.AddScoped<IAlias, TService>; end, 'Scoped overwrite');
    ExpectFailure(procedure begin Root.AddTransient<IAlias, TService>; end, 'Transient overwrite');
    ExpectFailure(procedure begin
      Root.AddFactory(TypeInfo(IAlias),
        function(const Resolve: TDependencyResolver): TObject
        begin Result := TService.Create; end, dlTransient);
    end, 'Factory overwrite');
    Check(Root.GetDescriptor(TypeInfo(IAlias)) = Root.GetDescriptor(TypeInfo(IPrimary)),
      'Rejected registrations must preserve alias');
    Root.Prepare;
    ExpectFailure(procedure begin Root.AddAlias<IOther, IPrimary>; end, 'Generic alias freeze');
    ExpectFailure(procedure begin Root.AddAlias(TypeInfo(IMissing), TypeInfo(IPrimary)); end,
      'PTypeInfo alias freeze');
  finally
    Root.Free;
  end;
end;

procedure TestIncompatibleInjection;
var
  Root: TAppContainer;
  Scope: TContainerScope;
begin
  Root := NewContainer;
  try
    Root.AddSingleton<IPrimary, TService>;
    Root.AddAlias<IOther, IPrimary>;
    Root.AddTransient<TIncompatibleConsumer, TIncompatibleConsumer>;
    Root.Prepare;
    Check(Root.Resolve(TypeInfo(IOther)) = Root.Resolve(TypeInfo(IPrimary)),
      'Low-level Resolve returns TObject, not a checked interface');
    ExpectFailure(procedure begin Root.Resolve<IOther>; end,
      'Generic Resolve must reject incompatible alias GUID');
    Scope := Root.CreateScope;
    try
      ExpectFailure(procedure begin Scope.Resolve(TypeInfo(TIncompatibleConsumer)); end,
        'Supports must reject incompatible interface before constructor invocation');
    finally
      Scope.Free;
    end;
  finally
    Root.Free;
  end;
end;

procedure TestCycleRetry;
var
  Root: TAppContainer;
  Cycle: Boolean;
  Calls: Integer;
  Service: TObject;
begin
  Cycle := True;
  Calls := 0;
  Root := NewContainer;
  try
    Root.AddSingletonFactory<IPrimary, TService>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        Inc(Calls);
        if Cycle then Resolve(TypeInfo(IAlias));
        Result := TService.Create;
      end);
    Root.AddAlias<IAlias, IPrimary>;
    Root.Prepare;
    ExpectFailure(procedure begin Root.Resolve(TypeInfo(IPrimary)); end, 'Cycle via alias');
    ExpectFailure(procedure begin Root.Resolve(TypeInfo(IAlias)); end, 'Repeated alias cycle');
    Cycle := False;
    Service := Root.Resolve(TypeInfo(IAlias));
    Check(Service = Root.Resolve(TypeInfo(IPrimary)), 'Cycle cleanup must allow cached retry');
    Check(Calls = 3, 'Failed cycle must not cache or leave resolution frames');
  finally
    Root.Free;
  end;
end;

procedure TestPrincipalReplacement;
var
  Root: TAppContainer;
  Calls: Integer;
begin
  Calls := 0;
  Root := NewContainer;
  try
    Root.AddSingleton<IPrimary, TService>;
    Root.AddAlias<IAlias, IPrimary>;
    Root.AddSingletonFactory<IPrimary, TService>(
      function(const Resolve: TDependencyResolver): TObject
      begin
        Inc(Calls);
        Result := TService.Create;
      end);
    Check(Root.GetDescriptor(TypeInfo(IAlias)) = Root.GetDescriptor(TypeInfo(IPrimary)),
      'Alias must follow replaced principal descriptor');
    Root.Prepare;
    Check(Root.Resolve(TypeInfo(IAlias)) = Root.Resolve(TypeInfo(IPrimary)),
      'Alias must resolve replacement');
    Check(Calls = 1, 'Replacement factory must be used');
  finally
    Root.Free;
  end;
end;

begin
  try
    TestSingletonAndInjection;
    TestTypedSingletonValue;
    TestGenericClassAndInvalidTypes;
    TestScoped;
    TestTransient;
    TestInvalidAndFreeze;
    TestIncompatibleInjection;
    TestCycleRetry;
    TestPrincipalReplacement;
    Writeln('Container alias tests passed.');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
