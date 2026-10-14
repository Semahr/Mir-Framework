unit Http.Composition;

interface

uses
  System.Generics.Collections,
  Container.App,
  Http.RouteDescriptor,
  Http.Router.Port,
  Http.Server,
  Http.ErrorResponse.Port;

type
  THttpComposition = class sealed
  public
    class function CreateDefaultRouter(const ARoutes: TObjectList<TRouteDescriptor>; const AContainer: TAppContainer): IRouter; static;

    class function CreateDefaultServer(
      const ARoutes: TObjectList<TRouteDescriptor>;
      const AContainer: TAppContainer;
      const AErrorRenderer: IErrorResponseRenderer = nil
    ): THttpServer; overload; static;

    class function CreateDefaultServer(
      const AContainer: TAppContainer;
      const AErrorRenderer: IErrorResponseRenderer = nil
    ): THttpServer; overload; static;
  end;

implementation

uses
  System.SysUtils,
  AppExceptions,
  Dto.Binder,
  Dto.Binder.Port,
  Http.ActionInvoker,
  Http.ActionInvoker.Port,
  Http.ControllerScanner,
  Http.Router,
  Http.BodyBinder,
  Http.BodyBinder.Port,
  Http.ParameterBinder,
  Http.ParameterBinder.Port,
  Http.Server.Options,
  App.Options;

class function THttpComposition.CreateDefaultRouter(const ARoutes: TObjectList<TRouteDescriptor>; const AContainer: TAppContainer): IRouter;
begin
  var DtoBinder := TDtoBinder.Create;
  var BodyBinder := TBodyBinder.Create(DtoBinder);
  var ParameterBinder := TParameterBinder.Create(BodyBinder);

  var ActionInvoker := TActionInvoker.Create(AContainer, ParameterBinder);

  Result := TRouter.Create(ARoutes, ActionInvoker, AContainer);
end;

class function THttpComposition.CreateDefaultServer(
  const ARoutes: TObjectList<TRouteDescriptor>;
  const AContainer: TAppContainer;
  const AErrorRenderer: IErrorResponseRenderer
): THttpServer;
var
  Port: Integer;
  Environment: string;
begin
  var HttpOptions := AContainer.GetOptions<THttpServerOptions>;
  var AppOptions := AContainer.GetOptions<TApplicationOptions>;

  try
    Port := HttpOptions.Port;
    Environment := AppOptions.Environment;
    if (Port < 1) or (Port > 65535) then
      raise EInvalidDependencyException.Create(
        'HttpServer.Port is required and must be an integer between 1 and 65535.'
      );
  finally
    HttpOptions.Free;
    AppOptions.Free;
end;

  Result := THttpServer.Create(
    Port,
    THttpComposition.CreateDefaultRouter(ARoutes, AContainer),
    AErrorRenderer,
    Environment
  );
end;

class function THttpComposition.CreateDefaultServer(
  const AContainer: TAppContainer;
  const AErrorRenderer: IErrorResponseRenderer
): THttpServer;
var
  Scanner: TControllerScanner;
  Routes: TObjectList<TRouteDescriptor>;
begin
  if AContainer = nil then
    raise EMissingDependencyException.Create('Container is required.');

  Scanner := TControllerScanner.Create;
  try
    Routes := Scanner.Execute(AContainer.GetControllerTypes);

    if Routes.Count > 0 then
    begin
      Writeln('HTTP Routes:');

      for var Route in Routes do
        Writeln(Format(
          '%s  %-5s %s %s %s',
          [#27'[32m', Route.Method, #27'[36m', Route.Path, #27'[0m']
        ));
    end;
  finally
    Scanner.Free;
  end;

  try
    Result := THttpComposition.CreateDefaultServer(
      Routes,
      AContainer,
      AErrorRenderer
    );
  except
    Routes.Free;
    raise;
  end;
end;

end.
