unit Http.Router;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  Container.App,
  Http.Core,
  Http.Context,
  Http.RouteDescriptor,
  Http.Router.Port,
  Http.ActionInvoker.Port,
  Http.Middleware.Descriptor,
  Http.Middleware.Pipeline;

type
  TRouter = class(TInterfacedObject, IRouter)
  private
    FRoutes: TObjectList<TRouteDescriptor>;
    FActionInvoker: IActionInvoker;
    FContainer: TAppContainer;
    FMiddlewarePipeline: TMiddlewarePipeline;

    function SplitPath(const AValue: string): TArray<string>;

    function MatchPath(
      const APattern: string;
      const APath: string;
      const AParams: TDictionary<string, string>
    ): Boolean;

    function CombineMiddlewares(
      const AGlobalMiddlewares: TArray<TMiddlewareDescriptor>;
      const ARouteMiddlewares: TArray<TMiddlewareDescriptor>
    ): TArray<TMiddlewareDescriptor>;

    function GetRouteStatusCode(const ARoute: TRouteDescriptor): Integer;

    function InvokeEndpoint(const ARoute: TRouteDescriptor; const AContext: TContext): TResponse;

    function InvokeRoute(const ARoute: TRouteDescriptor; const ARequest: TRequest): TResponse;
  public
    constructor Create(
      const ARoutes: TObjectList<TRouteDescriptor>;
      const AActionInvoker: IActionInvoker;
      const AContainer: TAppContainer
    );
    destructor Destroy; override;

    function Dispatch(const ARequest: TRequest): TResponse;
  end;

implementation

uses
  AppExceptions,
  HttpExceptions,
  Http.Attributes,
  Dto.Port,
  Json.Helpers;

constructor TRouter.Create(
  const ARoutes: TObjectList<TRouteDescriptor>;
  const AActionInvoker: IActionInvoker;
  const AContainer: TAppContainer
);
begin
  inherited Create;

  if ARoutes = nil then
    raise EMissingDependencyException.Create('Routes are required.');

  if AActionInvoker = nil then
    raise EMissingDependencyException.Create('Action invoker is required.');

  if AContainer = nil then
    raise EMissingDependencyException.Create('Container is required.');

  FRoutes := ARoutes;
  FActionInvoker := AActionInvoker;
  FContainer := AContainer;
  FMiddlewarePipeline := TMiddlewarePipeline.Create(AContainer);
end;

destructor TRouter.Destroy;
begin
  FMiddlewarePipeline.Free;
  FRoutes.Free;
  inherited;
end;

function TRouter.SplitPath(const AValue: string): TArray<string>;
var
  CleanValue: string;
begin
  CleanValue := AValue.Trim(['/']);

  if CleanValue = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  Result := CleanValue.Split(['/']);
end;

function TRouter.MatchPath(
  const APattern: string;
  const APath: string;
  const AParams: TDictionary<string, string>
): Boolean;
var
  PatternParts: TArray<string>;
  PathParts: TArray<string>;
  I: Integer;
  PatternPart: string;
  ParamName: string;
begin
  AParams.Clear;

  PatternParts := SplitPath(APattern);
  PathParts := SplitPath(APath);

  if Length(PatternParts) <> Length(PathParts) then
    Exit(False);

  for I := 0 to High(PatternParts) do
  begin
    PatternPart := PatternParts[I];

    if PatternPart.StartsWith(':') then
    begin
      ParamName := PatternPart.Substring(1);

      if ParamName = '' then
        raise EInvalidAttributeException.CreateFmt(
          'Invalid route parameter in pattern "%s".',
          [APattern]
        );

      AParams.AddOrSetValue(ParamName, PathParts[I]);
      Continue;
    end;

    if not SameText(PatternPart, PathParts[I]) then
      Exit(False);
  end;

  Result := True;
end;

function TRouter.CombineMiddlewares(
  const AGlobalMiddlewares: TArray<TMiddlewareDescriptor>;
  const ARouteMiddlewares: TArray<TMiddlewareDescriptor>
): TArray<TMiddlewareDescriptor>;
begin
  SetLength(Result, Length(AGlobalMiddlewares) + Length(ARouteMiddlewares));

  for var Index := 0 to High(AGlobalMiddlewares) do
    Result[Index] := AGlobalMiddlewares[Index];

  for var Index := 0 to High(ARouteMiddlewares) do
    Result[Length(AGlobalMiddlewares) + Index] := ARouteMiddlewares[Index];
end;

function TRouter.GetRouteStatusCode(const ARoute: TRouteDescriptor): Integer;
begin
  Result := 200;

  var RttiContext := TRttiContext.Create;
  var RttiType := RttiContext.GetType(ARoute.ControllerType);

  if RttiType = nil then
    Exit;

  for var MethodInfo in RttiType.GetMethods do
  begin
    if not SameText(MethodInfo.Name, ARoute.ActionName) then
      Continue;

    if Length(MethodInfo.GetParameters) <> Length(ARoute.Parameters) then
      Continue;

    for var Attribute in MethodInfo.GetAttributes do
    begin
      if Attribute is StatusCodeAttribute then
        Exit(StatusCodeAttribute(Attribute).StatusCode);
    end;

    Exit;
  end;
end;

function TRouter.InvokeEndpoint(const ARoute: TRouteDescriptor; const AContext: TContext): TResponse;
var
  ReturnedObject: TObject;
  Response: TResponse;
  StatusCode: Integer;
  Dto: IDto;
begin
  StatusCode := GetRouteStatusCode(ARoute);

  ReturnedObject := FActionInvoker.Execute(ARoute, AContext);

  if ReturnedObject = nil then
  begin
    Response := TResponse.NoContent;

    if StatusCode > 0 then
      Response.StatusCode := StatusCode;

    Exit(Response);
  end;

  if ReturnedObject is TResponse then
    Response := TResponse(ReturnedObject)
  else if Supports(ReturnedObject, IDto, Dto) then
    Response := TResponse.Json(TJsonHelpers.ToString(ReturnedObject))
  else
    raise EInvalidAttributeException.CreateFmt(
      'Invalid route return type. Expected %s or an object implementing IDto, received %s.',
      [
        TResponse.ClassName,
        ReturnedObject.ClassName
      ]
    );

  if StatusCode > 0 then
    Response.StatusCode := StatusCode;

  Result := Response;
end;

function TRouter.InvokeRoute(const ARoute: TRouteDescriptor; const ARequest: TRequest): TResponse;
begin
  var Scope := FContainer.CreateScope;
  var Context := TContext.Create(ARequest, Scope, ARoute.ActionAttributes, ARoute.ControllerAttributes);
  try
    Result := FMiddlewarePipeline.Execute(
      Context,
      CombineMiddlewares(FContainer.GetGlobalMiddlewares, ARoute.Middlewares),
      ARoute.Attributes,
      FContainer.GetAttributeHandlerTypes,
      function: TResponse
      begin
        Result := InvokeEndpoint(ARoute, Context);
      end
    );
  finally
    Context.Free;
  end;
end;

function TRouter.Dispatch(const ARequest: TRequest): TResponse;
begin
  for var Route in FRoutes do
  begin
    if not SameText(Route.Method, ARequest.Method) then
      Continue;

    if MatchPath(Route.Path, ARequest.Path, ARequest.RouteParams) then
      Exit(InvokeRoute(Route, ARequest));
  end;

  raise ENotFoundException.Create('Route not found');
end;

end.
