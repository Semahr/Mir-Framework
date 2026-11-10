unit Container.Scope;

interface

uses
  System.TypInfo,
  System.Generics.Collections;

type
  /// <summary>
  /// Request/operation container scope used to resolve scoped and transient dependencies safely.
  /// </summary>
  /// <remarks>
  /// A scope references the root TAppContainer for registrations and construction logic, but stores
  /// scoped instances locally. This prevents request-specific dependencies from being reused by
  /// other requests.
  /// </remarks>
  TContainerScope = class
  private
    FRoot: TObject;
    FScopedInstances: TDictionary<PTypeInfo, TObject>;
    FTransientInstances: TObjectList<TObject>;
  public
    /// <summary>
    /// Creates a scope linked to the root application container.
    /// </summary>
    constructor Create(const ARoot: TObject);

    /// <summary>
    /// Releases transient instances first, then scoped instances owned by this scope.
    /// </summary>
    /// <remarks>
    /// Transients are released first because transient objects, such as controllers, may hold
    /// references to scoped dependencies injected through their constructors.
    /// </remarks>
    destructor Destroy; override;



    /// <summary>
    /// Resolves a dependency using the root registration table and this scope's instance cache.
    /// </summary>
    /// <remarks>
    /// Singleton dependencies are delegated to the root container. Transient dependencies are created
    /// every time and tracked for disposal. Scoped dependencies are created once and reused until the
    /// scope is destroyed.
    /// </remarks>
    function Resolve(const ATypeInfo: PTypeInfo): TObject;

    /// <summary>
    /// Creates another scope linked to the same root container.
    /// </summary>
    function CreateScope: TContainerScope;
  end;

implementation

uses
  AppExceptions,
  Container.App,
  Container.DependencyDescriptor;

constructor TContainerScope.Create(const ARoot: TObject);
begin
  inherited Create;

  if ARoot = nil then
    raise EMissingDependencyException.Create('Root container is required.');

  FRoot := ARoot;
  FScopedInstances := TDictionary<PTypeInfo, TObject>.Create;
  FTransientInstances := TObjectList<TObject>.Create(True);
end;

destructor TContainerScope.Destroy;
begin
  FTransientInstances.Free;

  for var Instance in FScopedInstances.Values do
    Instance.Free;

  FScopedInstances.Free;

  inherited;
end;



function TContainerScope.Resolve(const ATypeInfo: PTypeInfo): TObject;
var
  Descriptor: TDependencyDescriptor;
begin
  Descriptor := TAppContainer(FRoot).GetDescriptor(ATypeInfo);

  case Descriptor.GetLifetime of
    dlSingleton:
      Exit(TAppContainer(FRoot).Resolve(ATypeInfo));

    dlTransient:
      begin
        Result := TAppContainer(FRoot).CreateInstance(Descriptor, Self);
        FTransientInstances.Add(Result);
        Exit;
      end;

    dlScoped:
      begin
        TAppContainer(FRoot).CheckScopedResolution(ATypeInfo);
        if not FScopedInstances.TryGetValue(Descriptor.DependencyType, Result) then
        begin
          Result := TAppContainer(FRoot).CreateInstance(Descriptor, Self);
          FScopedInstances.Add(Descriptor.DependencyType, Result);
        end;

        Exit;
      end;
  end;

  raise EMissingDependencyException.CreateFmt(
    'Unsupported lifetime for dependency "%s".',
    [ATypeInfo.Name]
  );
end;

function TContainerScope.CreateScope: TContainerScope;
begin
  Result := TContainerScope.Create(FRoot);
end;

end.
