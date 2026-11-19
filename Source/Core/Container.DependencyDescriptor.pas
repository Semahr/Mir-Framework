unit Container.DependencyDescriptor;

interface

uses
  System.TypInfo,
  System.Rtti;

type
  TDependencyLifetime = (
    dlSingleton,
    dlTransient,
    dlScoped
  );


  /// <summary>
  /// Base descriptor for a dependency registration.
  /// </summary>
  /// <remarks>
  /// The base descriptor only stores metadata that applies to every lifetime. Lifetime-specific
  /// state, such as a cached singleton instance, belongs to specialized descriptor classes.
  /// </remarks>
  TDependencyDescriptor = class abstract
  private
    FDependencyType: PTypeInfo;
    FImplementationType: TClass;

  public
    /// <summary>
    /// Creates the common metadata for a dependency registration.
    /// </summary>
    /// <param name="ADependencyType">
    /// The type requested by consumers and used as the container lookup key.
    /// </param>
    /// <param name="AImplementationType">
    /// Concrete class to instantiate.
    /// </param>
    constructor Create(const ADependencyType: PTypeInfo; const AImplementationType: TClass);

    /// <summary>
    /// Returns the lifecycle represented by the concrete descriptor type.
    /// </summary>
    function GetLifetime: TDependencyLifetime; virtual; abstract;

    /// <summary>
    /// Type requested by consumers and used as the lookup key in the container.
    /// </summary>
    property DependencyType: PTypeInfo read FDependencyType;

    /// <summary>
    /// Concrete class to instantiate when the dependency is resolved.
    /// </summary>
    property ImplementationType: TClass read FImplementationType;

  end;

  /// <summary>
  /// Descriptor for dependencies that live for the whole application lifetime.
  /// </summary>
  /// <remarks>
  /// Singleton-specific state is stored here because only singleton dependencies cache their
  /// instance inside the root container.
  /// </remarks>
  TSingletonDependencyDescriptor = class(TDependencyDescriptor)
  private
    FInstance: TObject;
    FKeepAlive: IInterface;
    FOwnsInstance: Boolean;
    FHasInstanceValue: Boolean;
    FInstanceValue: TValue;

    procedure SetInstance(const AInstance: TObject);
    procedure SetOwnsInstance(const AValue: Boolean);
  public
    /// <summary>
    /// Creates a singleton descriptor without an already-created instance.
    /// </summary>
    constructor Create(const ADependencyType: PTypeInfo; const AImplementationType: TClass);
    destructor Destroy; override;

    /// <summary>
    /// Returns dlSingleton for this descriptor type.
    /// </summary>
    function GetLifetime: TDependencyLifetime; override;

    /// <summary>
    /// Cached singleton instance. It is normally created lazily on the first Resolve call.
    /// </summary>
    property Instance: TObject read FInstance write SetInstance;

    /// <summary>
    /// Indicates whether InstanceValue contains an exact RTTI value for the dependency type.
    /// </summary>
    property HasInstanceValue: Boolean read FHasInstanceValue write FHasInstanceValue;

    /// <summary>
    /// Exact RTTI value for already-created dependencies, useful for generic interface instances.
    /// </summary>
    property InstanceValue: TValue read FInstanceValue write FInstanceValue;

    /// <summary>
    /// Indicates whether this descriptor owns and should free Instance when destroyed.
    /// </summary>
    property OwnsInstance: Boolean read FOwnsInstance write SetOwnsInstance;
  end;

  /// <summary>
  /// Descriptor for dependencies that must be created every time they are resolved.
  /// </summary>
  TTransientDependencyDescriptor = class(TDependencyDescriptor)
  public
    /// <summary>
    /// Returns dlTransient for this descriptor type.
    /// </summary>
    function GetLifetime: TDependencyLifetime; override;
  end;

  /// <summary>
  /// Descriptor for dependencies that are reused within a single request/scope.
  /// </summary>
  /// <remarks>
  /// Scoped instances are intentionally not stored here. They live in TContainerScope because each
  /// request/scope must have its own instance cache.
  /// </remarks>
  TScopedDependencyDescriptor = class(TDependencyDescriptor)
  public
    /// <summary>
    /// Returns dlScoped for this descriptor type.
    /// </summary>
    function GetLifetime: TDependencyLifetime; override;
  end;

implementation

uses
  AppExceptions;

constructor TDependencyDescriptor.Create(const ADependencyType: PTypeInfo; const AImplementationType: TClass);
begin
  inherited Create;
  FDependencyType := ADependencyType;
  FImplementationType := AImplementationType;
end;

constructor TSingletonDependencyDescriptor.Create(const ADependencyType: PTypeInfo; const AImplementationType: TClass);
begin
  inherited Create(ADependencyType, AImplementationType);
  FOwnsInstance := True;
end;

destructor TSingletonDependencyDescriptor.Destroy;
var
  Instance: TObject;
begin
  Instance := FInstance;
  FInstance := nil;

  FInstanceValue := TValue.Empty;
  FHasInstanceValue := False;

  if FOwnsInstance then
  begin
    if FKeepAlive <> nil then
      FKeepAlive := nil
    else
      Instance.Free;
  end
  else
    FKeepAlive := nil;

  inherited;
end;

procedure TSingletonDependencyDescriptor.SetInstance(const AInstance: TObject);
var
  KeepAlive: IInterface;
  Contract: IInterface;
begin
  if AInstance = nil then
    raise EInvalidDependencyException.Create('Singleton instance cannot be nil.');

  if FInstance <> nil then
    raise EInvalidDependencyException.Create('Singleton instance is already initialized.');

  if DependencyType = nil then
    raise EInvalidDependencyException.Create('Singleton dependency type cannot be nil.');

  case DependencyType.Kind of
    tkInterface:
      begin
        if not Supports(AInstance, GetTypeData(DependencyType).Guid, Contract) then
          raise EInvalidDependencyException.CreateFmt(
            'Singleton "%s" does not implement the registered interface "%s".',
            [AInstance.ClassName, DependencyType.Name]
          );
      end;

    tkClass:
      begin
        if not AInstance.InheritsFrom(GetTypeData(DependencyType).ClassType) then
          raise EInvalidDependencyException.CreateFmt(
            'Singleton "%s" is not compatible with registered class "%s".',
            [AInstance.ClassName, DependencyType.Name]
          );
      end;
  else
    raise EInvalidDependencyException.Create('Singleton dependencies require a class or interface contract.');
  end;

  if FOwnsInstance and (AInstance is TInterfacedObject) then
  begin
    if Contract <> nil then
      KeepAlive := Contract
    else if not Supports(AInstance, IInterface, KeepAlive) then
      raise EInvalidDependencyException.Create('Unable to retain singleton interface.');
  end;

  FKeepAlive := KeepAlive;
  FInstance := AInstance;
end;

procedure TSingletonDependencyDescriptor.SetOwnsInstance(const AValue: Boolean);
begin
  if FInstance <> nil then
    raise EInvalidDependencyException.Create('Singleton ownership cannot change after initialization.');

  FOwnsInstance := AValue;
end;

function TSingletonDependencyDescriptor.GetLifetime: TDependencyLifetime;
begin
  Result := dlSingleton;
end;

function TTransientDependencyDescriptor.GetLifetime: TDependencyLifetime;
begin
  Result := dlTransient;
end;

function TScopedDependencyDescriptor.GetLifetime: TDependencyLifetime;
begin
  Result := dlScoped;
end;

end.
