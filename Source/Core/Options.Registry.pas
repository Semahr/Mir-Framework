unit Options.Registry;

interface

uses
  System.TypInfo,
  System.Rtti,
  System.JSON,
  System.Generics.Collections,
  Options.Port;

type
  TOptionsValueLoader = reference to function: TJSONObject;
  TOptionsDescriptorRegister = reference to procedure(const ATypeInfo: PTypeInfo; const AInstance: TObject; const AInstanceValue: TValue);
  TOptionsSectionMaterializer = reference to procedure;

  TOptionsRegistry = class
  private
    FSectionMaterializers: TList<TOptionsSectionMaterializer>;
    FInstances: TObjectDictionary<PTypeInfo, TObject>;
    FRootLoader: TOptionsValueLoader;
    FRootValue: TJSONObject;
    FLoaded: Boolean;
    FDescriptorRegister: TOptionsDescriptorRegister;

    function Extract<T: TOptionsSection, constructor>(const ARootOptions: TJSONObject): T;
    procedure RegisterOptionsInstance(const ATypeInfo: PTypeInfo; const AOptionsTypeInfo: PTypeInfo; const AInstance: TObject; const AInstanceValue: TValue);
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetRootLoader(const ALoader: TOptionsValueLoader; const ADescriptorRegistrar: TOptionsDescriptorRegister);
    procedure Add<T: TOptionsSection, constructor>;
    procedure EnsureLoaded;

    function GetGlobal: TJSONObject;
    function Get<T: TOptionsSection, constructor>: T;
  end;

implementation

uses
  System.SysUtils,
  AppExceptions,
  Json.Helpers;

constructor TOptionsRegistry.Create;
begin
  inherited Create;
  FSectionMaterializers := TList<TOptionsSectionMaterializer>.Create;
  FInstances := TObjectDictionary<PTypeInfo, TObject>.Create([doOwnsValues]);
  FLoaded := False;
end;

destructor TOptionsRegistry.Destroy;
begin
  FInstances.Free;
  FSectionMaterializers.Free;
  inherited;
end;

function TOptionsRegistry.Extract<T>(const ARootOptions: TJSONObject): T;
var
  SectionName: string;
  SectionJson: TJSONValue;
  SectionProbe: T;
  OptionsTypeName: string;
begin
  if ARootOptions = nil then
    raise EMissingDependencyException.Create('Root options must be a JSON object.');

  OptionsTypeName := TRttiContext.Create.GetType(TypeInfo(T)).Name;

  SectionProbe := T.Create;
  try
    SectionName := SectionProbe.SectionName.Trim;
  finally
    SectionProbe.Free;
  end;

  if SectionName.IsEmpty then
    raise EMissingDependencyException.CreateFmt(
      'Options class "%s" returned an empty section name.',
      [OptionsTypeName]
    );

  SectionJson := ARootOptions.GetValue(SectionName);

  if SectionJson = nil then
    raise EMissingDependencyException.CreateFmt(
      'Options section "%s" was not found in root options JSON.',
      [SectionName]
    );

  if not (SectionJson is TJSONObject) then
    raise EMissingDependencyException.CreateFmt(
      'Options section "%s" must be a JSON object.',
      [SectionName]
    );

  Result := TJsonHelpers.ToObject<T>(SectionJson);
end;

procedure TOptionsRegistry.RegisterOptionsInstance(
  const ATypeInfo: PTypeInfo;
  const AOptionsTypeInfo: PTypeInfo;
  const AInstance: TObject;
  const AInstanceValue: TValue
);
begin
  if AInstance = nil then
    raise EMissingDependencyException.Create('Options instance is required.');

  FInstances.AddOrSetValue(AOptionsTypeInfo, AInstance);

  if Assigned(FDescriptorRegister) then
    FDescriptorRegister(ATypeInfo, AInstance, AInstanceValue);
end;

procedure TOptionsRegistry.SetRootLoader(
  const ALoader: TOptionsValueLoader;
  const ADescriptorRegistrar: TOptionsDescriptorRegister
);
begin
  if not Assigned(ALoader) then
    raise EMissingDependencyException.Create('Options loader is required.');

  FRootLoader := ALoader;
  FDescriptorRegister := ADescriptorRegistrar;
  FLoaded := False;

  EnsureLoaded;
end;

procedure TOptionsRegistry.Add<T>;
var
  Materializer: TOptionsSectionMaterializer;
  ExtractedValue: T;
  OptionsInstance: TOptions<T>;
  OptionsInterface: IOptions<T>;
begin
  Materializer :=
    procedure
    begin
      ExtractedValue := Extract<T>(FRootValue);
      OptionsInstance := TOptions<T>.From(ExtractedValue);
      OptionsInterface := OptionsInstance;
      RegisterOptionsInstance(
        TypeInfo(IOptions<T>),
        TypeInfo(T),
        OptionsInstance,
        TValue.From<IOptions<T>>(OptionsInterface)
      );
    end;

  FSectionMaterializers.Add(Materializer);

  if FLoaded then
    Materializer();
end;

procedure TOptionsRegistry.EnsureLoaded;
var
  OptionsInstance: TOptions<TJSONObject>;
  OptionsInterface: IOptions<TJSONObject>;
begin
  if FLoaded then
    Exit;

  if not Assigned(FRootLoader) then
    Exit;

  FRootValue := FRootLoader();

  if FRootValue = nil then
    raise EMissingDependencyException.Create('Root options loader must return a JSON object.');

  OptionsInstance := TOptions<TJSONObject>.Create(FRootValue);
  OptionsInterface := OptionsInstance;
  RegisterOptionsInstance(
    TypeInfo(IOptions<TJSONObject>),
    TypeInfo(TJSONObject),
    OptionsInstance,
    TValue.From<IOptions<TJSONObject>>(OptionsInterface)
  );

  for var Materializer in FSectionMaterializers do
    Materializer();

  FLoaded := True;
end;

function TOptionsRegistry.GetGlobal: TJSONObject;
begin
  EnsureLoaded;
  Result := FRootValue;
end;

function TOptionsRegistry.Get<T>: T;
begin
  EnsureLoaded;
  Result := Extract<T>(FRootValue);
end;

end.
