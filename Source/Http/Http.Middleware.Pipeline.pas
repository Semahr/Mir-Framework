unit Http.Middleware.Pipeline;

interface

uses
  System.SysUtils,
  Container.App,
  Http.Context,
  Http.Core,
  Http.Middleware.Descriptor,
  Http.Middleware.Port;

type
  TMiddlewarePipeline = class
  private
    FContainer: TAppContainer;

    function ExecuteMiddleware(
      const AContext: TContext;
      const AMiddlewares: TArray<TMiddlewareDescriptor>;
      const AAttributes: TArray<TCustomAttribute>;
      const AAttributeHandlerTypes: TArray<TClass>;
      const AEndpoint: TNextDelegate;
      const AIndex: Integer
    ): TResponse;

    function ExecuteAttributeHandler(
      const AContext: TContext;
      const AAttributes: TArray<TCustomAttribute>;
      const AAttributeHandlerTypes: TArray<TClass>;
      const AEndpoint: TNextDelegate;
      const AIndex: Integer
    ): TResponse;
  public
    constructor Create(const AContainer: TAppContainer);

    function Execute(
      const AContext: TContext;
      const AMiddlewares: TArray<TMiddlewareDescriptor>;
      const AAttributes: TArray<TCustomAttribute>;
      const AAttributeHandlerTypes: TArray<TClass>;
      const AEndpoint: TNextDelegate
    ): TResponse;
  end;

implementation

uses
  AppExceptions,
  Http.EndpointAttributeHandler.Port;

constructor TMiddlewarePipeline.Create(const AContainer: TAppContainer);
begin
  inherited Create;

  if AContainer = nil then
    raise EMissingDependencyException.Create('Container is required.');

  FContainer := AContainer;
end;

function TMiddlewarePipeline.Execute(
  const AContext: TContext;
  const AMiddlewares: TArray<TMiddlewareDescriptor>;
  const AAttributes: TArray<TCustomAttribute>;
  const AAttributeHandlerTypes: TArray<TClass>;
  const AEndpoint: TNextDelegate
): TResponse;
begin
  if not Assigned(AEndpoint) then
    raise EMissingDependencyException.Create('Endpoint delegate is required.');

  Result := ExecuteMiddleware(
    AContext,
    AMiddlewares,
    AAttributes,
    AAttributeHandlerTypes,
    AEndpoint,
    0
  );
end;

function TMiddlewarePipeline.ExecuteMiddleware(
  const AContext: TContext;
  const AMiddlewares: TArray<TMiddlewareDescriptor>;
  const AAttributes: TArray<TCustomAttribute>;
  const AAttributeHandlerTypes: TArray<TClass>;
  const AEndpoint: TNextDelegate;
  const AIndex: Integer
): TResponse;
var
  Instance: TObject;
  Middleware: IMiddleware;
begin
  if AIndex > High(AMiddlewares) then
    Exit(ExecuteAttributeHandler(AContext, AAttributes, AAttributeHandlerTypes, AEndpoint, 0));

  Instance := FContainer.CreateComponentInstance(AMiddlewares[AIndex].MiddlewareType, AContext.Dependencies);

  if (Instance = nil) or not Supports(Instance, IMiddleware, Middleware) then
    raise EInvalidAttributeException.CreateFmt(
      'Middleware "%s" must implement IMiddleware.',
      [AMiddlewares[AIndex].MiddlewareType.ClassName]
    );

  Result := Middleware.Invoke(
    AContext,
    function: TResponse
    begin
      Result := ExecuteMiddleware(
        AContext,
        AMiddlewares,
        AAttributes,
        AAttributeHandlerTypes,
        AEndpoint,
        AIndex + 1
      );
    end
  );
end;

function TMiddlewarePipeline.ExecuteAttributeHandler(
  const AContext: TContext;
  const AAttributes: TArray<TCustomAttribute>;
  const AAttributeHandlerTypes: TArray<TClass>;
  const AEndpoint: TNextDelegate;
  const AIndex: Integer
): TResponse;
var
  Attribute: TCustomAttribute;
  HandlerType: TClass;
  Instance: TObject;
  Handler: IEndpointAttributeHandler;
begin
  if AIndex > High(AAttributes) then
    Exit(AEndpoint());

  Attribute := AAttributes[AIndex];

  for HandlerType in AAttributeHandlerTypes do
  begin
    Instance := FContainer.CreateComponentInstance(HandlerType, AContext.Dependencies);

    if (Instance = nil) or not Supports(Instance, IEndpointAttributeHandler, Handler) then
      raise EInvalidAttributeException.CreateFmt(
        'Attribute handler "%s" must implement IEndpointAttributeHandler.',
        [HandlerType.ClassName]
      );

    if Handler.Supports(Attribute) then
      Exit(
        Handler.Invoke(
          Attribute,
          AContext,
          function: TResponse
          begin
            Result := ExecuteAttributeHandler(
              AContext,
              AAttributes,
              AAttributeHandlerTypes,
              AEndpoint,
              AIndex + 1
            );
          end
        )
      );
  end;

  Result := ExecuteAttributeHandler(AContext, AAttributes, AAttributeHandlerTypes, AEndpoint, AIndex + 1);
end;

end.
