unit Http.ActionInvoker;

interface

uses
  System.SysUtils,
  System.Rtti,
  Container.App,
  Http.Context,
  Http.RouteDescriptor,
  Http.ParameterBinder.Port,
  Http.ActionInvoker.Port;

type
  TActionInvoker = class(TInterfacedObject, IActionInvoker)
  private
    FContainer: TAppContainer;
    FParameterBinder: IParameterBinder;

    function FindActionMethod(
      const AControllerType: TClass;
      const AActionName: string;
      const AParameterCount: Integer;
      const ARttiContext: TRttiContext
    ): TRttiMethod;
  public
    constructor Create(const AContainer: TAppContainer; const AParameterBinder: IParameterBinder);

    function Execute(const ARoute: TRouteDescriptor; const AContext: TContext): TObject;
  end;

implementation

uses
  System.TypInfo,
  AppExceptions,
  Http.Parameter.Binding;

constructor TActionInvoker.Create(const AContainer: TAppContainer; const AParameterBinder: IParameterBinder);
begin
  inherited Create;

  if AContainer = nil then
    raise EMissingDependencyException.Create('Container is required.');

  if AParameterBinder = nil then
    raise EMissingDependencyException.Create('Parameter binder is required.');

  FContainer := AContainer;
  FParameterBinder := AParameterBinder;
end;

function TActionInvoker.FindActionMethod(
  const AControllerType: TClass;
  const AActionName: string;
  const AParameterCount: Integer;
  const ARttiContext: TRttiContext
): TRttiMethod;
begin
  Result := nil;

  var RttiType := ARttiContext.GetType(AControllerType);

  if RttiType = nil then
    Exit;

  for var Method in RttiType.GetMethods do
  begin
    if not SameText(Method.Name, AActionName) then
      Continue;

    if Length(Method.GetParameters) <> AParameterCount then
      Continue;

    Exit(Method);
  end;
end;

function TActionInvoker.Execute(const ARoute: TRouteDescriptor; const AContext: TContext): TObject;
var
  Arguments: TArray<TValue>;
  RttiContext: TRttiContext;
  ReturnValue: TValue;
begin
  var Resolver: TObject := AContext.Dependencies;

  if Resolver = nil then
    Resolver := FContainer;

  var Controller := FContainer.CreateComponentInstance(ARoute.ControllerType, Resolver);

  if Controller = nil then
    raise EMissingDependencyException.CreateFmt(
      'Controller "%s" could not be created.',
      [ARoute.ControllerType.ClassName]
    );

  try
    SetLength(Arguments, Length(ARoute.Parameters));

    for var Index := 0 to High(ARoute.Parameters) do
      Arguments[Index] := FParameterBinder.Execute(AContext, ARoute.Parameters[Index]);

    RttiContext := TRttiContext.Create;
    var MethodInfo := FindActionMethod(
      ARoute.ControllerType,
      ARoute.ActionName,
      Length(ARoute.Parameters),
      RttiContext
    );

    if MethodInfo = nil then
      raise EMissingDependencyException.CreateFmt(
        'Action "%s" was not found in controller "%s".',
        [ARoute.ActionName, ARoute.ControllerType.ClassName]
      );

    try
      ReturnValue := MethodInfo.Invoke(Controller, Arguments);
    finally
      for var Index := 0 to High(ARoute.Parameters) do
        if (ARoute.Parameters[Index].Source = psBody) and (not Arguments[Index].IsEmpty) and (Arguments[Index].Kind = tkClass) then
          Arguments[Index].AsObject.Free;
    end;

    if MethodInfo.ReturnType = nil then
      Exit(nil);

    if ReturnValue.IsEmpty then
      raise EInvalidAttributeException.CreateFmt(
        'Action "%s" in controller "%s" declares return type "%s" but returned an empty RTTI value.',
        [
          ARoute.ActionName,
          ARoute.ControllerType.ClassName,
          MethodInfo.ReturnType.Name
        ]
      );

    if ReturnValue.Kind <> tkClass then
      raise EInvalidAttributeException.CreateFmt(
        'Invalid route return type. Expected object return type, received "%s".',
        [ReturnValue.TypeInfo.Name]
      );

    Result := ReturnValue.AsObject;
  finally
    Controller.Free;
  end;
end;

end.
