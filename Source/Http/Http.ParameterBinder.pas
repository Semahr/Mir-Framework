unit Http.ParameterBinder;

interface

uses
  System.SysUtils,
  System.Rtti,
  Http.Context,
  Http.ParameterDescriptor,
  Http.BodyBinder.Port,
  Http.ParameterBinder.Port,
  Dto.Port;

type
  TParameterBinder = class(TInterfacedObject, IParameterBinder)
  private
    FBodyBinder: IBodyBinder;
    FRttiContext: TRttiContext;

    function GetParameterRttiType(const ADescriptor: TParameterDescriptor): TRttiType;

    function FromContext(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
    function FromRoute(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
    function FromCookie(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
    function FromQuery(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
    function FromHeader(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
    function FromBody(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
  public
    constructor Create(const ABodyBinder: IBodyBinder);

    function Execute(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
  end;

implementation

uses
  Http.Parameter.Binding,
  Http.ValueConverter,
  AppExceptions,
  HttpExceptions;

function TParameterBinder.GetParameterRttiType(const ADescriptor: TParameterDescriptor): TRttiType;
begin
  Result := FRttiContext.GetType(ADescriptor.ParameterType);

  if Result = nil then
    raise EBadRequestException.Create(Format(
      'Parameter "%s" does not have RTTI type information.',
      [ADescriptor.Name]
    ));
end;

constructor TParameterBinder.Create(const ABodyBinder: IBodyBinder);
begin
  inherited Create;

  if ABodyBinder = nil then
    raise EMissingDependencyException.Create('Body binder is required.');

  FRttiContext := TRttiContext.Create;
  FBodyBinder := ABodyBinder;
end;

function TParameterBinder.Execute(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
begin
  case ADescriptor.Source of
    psContext:
      Exit(FromContext(AContext, ADescriptor));

    psRoute:
      Exit(FromRoute(AContext, ADescriptor));

    psCookie:
      Exit(FromCookie(AContext, ADescriptor));

    psQuery:
      Exit(FromQuery(AContext, ADescriptor));

    psHeader:
      Exit(FromHeader(AContext, ADescriptor));

    psBody:
      Exit(FromBody(AContext, ADescriptor));
  end;

  raise EBadRequestException.Create(Format(
    'Unsupported binding source for parameter "%s".',
    [ADescriptor.Name]
  ));
end;

function TParameterBinder.FromContext(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
begin
  if ADescriptor.ParameterType <> TypeInfo(TContext) then
    raise EBadRequestException.Create(Format(
      'Parameter "%s" marked as FromContext must be THttpContext.',
      [ADescriptor.Name]
    ));

  Result := TValue.From<TContext>(AContext);
end;

function TParameterBinder.FromRoute(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
var
  RawValue: string;
  ErrorMessage: string;
  ParameterType: TRttiType;
begin
  if not AContext.Request.RouteParams.TryGetValue(ADescriptor.SourceName.ToLower, RawValue) then
    raise EBadRequestException.Create(Format(
      'Route parameter "%s" is required.',
      [ADescriptor.SourceName]
    ));

  ParameterType := GetParameterRttiType(ADescriptor);

  if not TValueConverter.TryConvertString(
    RawValue,
    ParameterType,
    Result,
    ErrorMessage
  ) then
    raise EBadRequestException.Create(Format(
      'Route parameter "%s" %s.',
      [ADescriptor.SourceName, ErrorMessage]
    ));
end;

function TParameterBinder.FromCookie(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
var
  RawValue: string;
  ErrorMessage: string;
  ParameterType: TRttiType;
begin
  AContext.Request.Cookies.TryGetValue(ADescriptor.SourceName, RawValue);

{  if not AContext.Request.Cookies.TryGetValue(ADescriptor.SourceName, RawValue) then
    raise EBadRequestException.Create(Format(
      'Cookie "%s" is required.',
      [ADescriptor.SourceName]
    ));}

  ParameterType := GetParameterRttiType(ADescriptor);

  if not TValueConverter.TryConvertString(
    RawValue,
    ParameterType,
    Result,
    ErrorMessage
  ) then
    raise EBadRequestException.Create(Format(
      'Cookie "%s" %s.',
      [ADescriptor.SourceName, ErrorMessage]
    ));
end;

function TParameterBinder.FromQuery(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
var
  RawValue: string;
  ErrorMessage: string;
  ParameterType: TRttiType;
begin
  AContext.Request.QueryParams.TryGetValue(ADescriptor.SourceName, RawValue);

{ if not AContext.Request.QueryParams.TryGetValue(ADescriptor.SourceName.ToLower, RawValue) then
   raise EBadRequestException.Create(Format(
     'Query parameter "%s" is required.',
     [ADescriptor.SourceName]
   ));}

  ParameterType := GetParameterRttiType(ADescriptor);

  if not TValueConverter.TryConvertString(
    RawValue,
    ParameterType,
    Result,
    ErrorMessage
  ) then
    raise EBadRequestException.Create(Format(
      'Query parameter "%s" %s.',
      [ADescriptor.SourceName, ErrorMessage]
    ));
end;

function TParameterBinder.FromHeader(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
var
  RawValue: string;
  ErrorMessage: string;
  ParameterType: TRttiType;
begin
  var HeaderName := ADescriptor.SourceName.ToLower;

  AContext.Request.Headers.TryGetValue(HeaderName, RawValue);

{ if not AContext.Request.Headers.TryGetValue(HeaderName.ToLower, RawValue) then
   raise EBadRequestException.Create(Format(
     'Header "%s" is required.',
     [ADescriptor.SourceName]
   ));}

  ParameterType := GetParameterRttiType(ADescriptor);

  if not TValueConverter.TryConvertString(
    RawValue,
    ParameterType,
    Result,
    ErrorMessage
  ) then
    raise EBadRequestException.Create(Format(
      'Header "%s" %s.',
      [ADescriptor.SourceName, ErrorMessage]
    ));
end;

function TParameterBinder.FromBody(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
var
  Dto: TObject;
  ParameterType: TRttiType;
begin
  ParameterType := GetParameterRttiType(ADescriptor);
  Dto := FBodyBinder.Execute(AContext.Request.Body, ParameterType);
  TValue.Make(@Dto, ADescriptor.ParameterType, Result);
end;

end.
