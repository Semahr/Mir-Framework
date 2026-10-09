unit Http.Server;

interface

uses
  System.SysUtils,
  IdHTTPServer,
  IdContext,
  IdCustomHTTPServer,
  Http.Core,
  Http.Router.Port;

type
  THttpServer = class
  private
    FServer: TIdHTTPServer;
    FRouter: IRouter;
    FErrorRenderer: IErrorResponseRenderer;
    FDefaultErrorRenderer: IErrorResponseRenderer;

    function RenderError(const AError: Exception): TResponse;
    function IsJsonContentType(const AContentType: string): Boolean;
    procedure EnsureSupportedContentType(const ARequestInfo: TIdHTTPRequestInfo);

    procedure HandleCommand(
      AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo
    );

    function BuildRequest(const ARequestInfo: TIdHTTPRequestInfo): TRequest;

    procedure WriteResponse(const AResponse: TResponse; const AResponseInfo: TIdHTTPResponseInfo);
  public
    constructor Create(
      const APort: Integer;
      const ARouter: IRouter;
      const AErrorRenderer: IErrorResponseRenderer = nil
    );
    destructor Destroy; override;

    procedure Start;
    procedure Stop;

    property Server: TIdHTTPServer read FServer;
  end;

implementation

uses
  System.Classes,
  System.StrUtils,
  System.Math,
  Http.Cookies,
  HttpExceptions,
  AppExceptions,
  Http.ErrorResponse,
  Http.ErrorResponse.Port;

constructor THttpServer.Create(
  const APort: Integer;
  const ARouter: IRouter;
  const AErrorRenderer: IErrorResponseRenderer
);
begin
  inherited Create;

  if ARouter = nil then
    raise EMissingDependencyException.Create('Router is required.');

  FRouter := ARouter;
  FDefaultErrorRenderer := TDefaultErrorResponseRenderer.Create;

  if AErrorRenderer <> nil then
    FErrorRenderer := AErrorRenderer
  else
    FErrorRenderer := FDefaultErrorRenderer;

  FServer := TIdHTTPServer.Create(nil);
  FServer.DefaultPort := APort;
  FServer.OnCommandGet := HandleCommand;
  FServer.OnCommandOther := HandleCommand;

  Writeln(Format('HTTP server listening on port %d.', [APort]));
end;

destructor THttpServer.Destroy;
begin
  Stop;
  FServer.Free;
  FRouter := nil;

  inherited;
end;

procedure THttpServer.Start;
begin
  FServer.Active := True;
end;

procedure THttpServer.Stop;
begin
  if FServer.Active then
    FServer.Active := False;
end;

function THttpServer.BuildRequest(const ARequestInfo: TIdHTTPRequestInfo): TRequest;
begin
  Result := TRequest.Create;

  Result.Method := UpperCase(ARequestInfo.Command);
  Result.Path := ARequestInfo.Document;

  for var I := 0 to ARequestInfo.Cookies.Count - 1 do
  begin
    var Cookie := ARequestInfo.Cookies[I];
    if Cookie = nil then
      Continue;

    var Name := Cookie.CookieName;
    if Name.Trim.IsEmpty then
      Continue;

    var Value := Cookie.Value;
    Result.Cookies.AddOrSetValue(Name, Value);
  end;

  for var I := 0 to ARequestInfo.RawHeaders.Count - 1 do
  begin
    var Name := ARequestInfo.RawHeaders.Names[I].ToLower;
    if Name.Trim.IsEmpty then
      Continue;

    var Value := ARequestInfo.RawHeaders.Values[Name];
    Result.Headers.AddOrSetValue(Name, Value);
  end;

  for var I := 0 to ARequestInfo.Params.Count - 1 do
  begin
    var Name := ARequestInfo.Params.Names[I];
    if Name.Trim.IsEmpty then
      Continue;

    var Value := ARequestInfo.Params.ValueFromIndex[I];
    Result.QueryParams.AddOrSetValue(Name, Value);
  end;

  if Assigned(ARequestInfo.PostStream) then
  begin
    ARequestInfo.PostStream.Position := 0;

    with TStringStream.Create('', TEncoding.UTF8) do
    try
      CopyFrom(ARequestInfo.PostStream, ARequestInfo.PostStream.Size);
      Result.Body := DataString;
    finally
      Free;
    end;
  end;
end;

function THttpServer.IsJsonContentType(const AContentType: string): Boolean;
var
  ContentType: string;
  SeparatorIndex: Integer;
begin
  ContentType := AContentType.Trim.ToLower;

  SeparatorIndex := Pos(';', ContentType);
  if SeparatorIndex > 0 then
    ContentType := Copy(ContentType, 1, SeparatorIndex - 1).Trim;

  Result := SameText(ContentType, 'application/json');
end;

procedure THttpServer.EnsureSupportedContentType(const ARequestInfo: TIdHTTPRequestInfo);
begin
  if not Assigned(ARequestInfo.PostStream) or (ARequestInfo.PostStream.Size = 0) then
    Exit;

  if IsJsonContentType(ARequestInfo.ContentType) then
    Exit;

  raise EHttpException.Create(
    415,
    'Unsupported Media Type',
    'Only application/json content type is supported.'
  );
end;

procedure THttpServer.WriteResponse(const AResponse: TResponse; const AResponseInfo: TIdHTTPResponseInfo);
begin
  var ContentType := IfThen(
    AResponse.ContentType.Trim.IsEmpty,
    'application/json; charset=utf-8',
    AResponse.ContentType
  );

  var StatusCode := IfThen(
    AResponse.StatusCode <= 0,
    200,
    AResponse.StatusCode
  );

  AResponseInfo.ResponseNo := StatusCode;
  AResponseInfo.ContentType := ContentType;
  AResponseInfo.ContentText := AResponse.Body;

  for var Cookie in AResponse.GetCookies do
    AResponseInfo.CustomHeaders.AddValue('Set-Cookie', TCookieSerializer.Serialize(Cookie));
end;

function THttpServer.RenderError(const AError: Exception): TResponse;
begin
  try
    Result := FErrorRenderer.Render(AError);
  except
    on Exception do
      Result := FDefaultErrorRenderer.Render(AError);
  end;
end;

procedure THttpServer.HandleCommand(
  AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo
);
var
  Request: TRequest;
  Response: TResponse;
begin
  Request := nil;
  Response := nil;

  try
    try
      EnsureSupportedContentType(ARequestInfo);
      Request := BuildRequest(ARequestInfo);
      Response := FRouter.Dispatch(Request);
    except
      on Error: Exception do
        Response := RenderError(Error);
    end;

    WriteResponse(Response, AResponseInfo);
  finally
    Response.Free;
    Request.Free;
  end;
end;

end.
