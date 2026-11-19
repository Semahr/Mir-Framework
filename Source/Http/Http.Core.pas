unit Http.Core;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Http.Cookies;

type
  TRequest = class
  private
    FMethod: string;
    FPath: string;
    FCookies: TDictionary<string, string>;
    FHeaders: TDictionary<string, string>;
    FRouteParams: TDictionary<string, string>;
    FQueryParams: TDictionary<string, string>;
    FBody: string;
  public
    constructor Create;
    destructor Destroy; override;

    property Method: string read FMethod write FMethod;
    property Path: string read FPath write FPath;
    property Cookies: TDictionary<string, string> read FCookies;
    property Headers: TDictionary<string, string> read FHeaders;
    property RouteParams: TDictionary<string, string> read FRouteParams;
    property QueryParams: TDictionary<string, string> read FQueryParams;
    property Body: string read FBody write FBody;
  end;

  TResponse = class
  private
    FStatusCode: Integer;
    FContentType: string;
    FBody: string;
    FCookies: TList<TCookieOptions>;
  public
    constructor Create;
    destructor Destroy; override;

    class function Json(const ABody: string; const AStatusCode: Integer = 200): TResponse; static;

    class function NoContent: TResponse; static;

    procedure SetCookie(const ACookie: TCookieOptions); overload;
    procedure SetCookie(const AName: string; const AValue: string); overload;
    procedure ClearCookie(const AName: string; const APath: string = '/');
    function GetCookies: TArray<TCookieOptions>;

    property StatusCode: Integer read FStatusCode write FStatusCode;
    property ContentType: string read FContentType write FContentType;
    property Body: string read FBody write FBody;
  end;

implementation

{ THttpRequest }

constructor TRequest.Create;
begin
  inherited Create;

  FCookies := TDictionary<string, string>.Create;
  FHeaders := TDictionary<string, string>.Create;
  FRouteParams := TDictionary<string, string>.Create;
  FQueryParams := TDictionary<string, string>.Create;
end;

destructor TRequest.Destroy;
begin
  FCookies.Free;
  FHeaders.Free;
  FRouteParams.Free;
  FQueryParams.Free;

  inherited;
end;

{ THttpResponse }

constructor TResponse.Create;
begin
  inherited Create;

  FStatusCode := 200;
  FContentType := 'application/json; charset=utf-8';
  FCookies := TList<TCookieOptions>.Create;
end;

destructor TResponse.Destroy;
begin
  FCookies.Free;
  inherited;
end;

procedure TResponse.SetCookie(const ACookie: TCookieOptions);
begin
  FCookies.Add(ACookie);
end;

procedure TResponse.SetCookie(const AName: string; const AValue: string);
begin
  SetCookie(TCookieOptions.Create(AName, AValue));
end;

procedure TResponse.ClearCookie(const AName: string; const APath: string);
begin
  SetCookie(TCookieOptions.Expired(AName, APath));
end;

function TResponse.GetCookies: TArray<TCookieOptions>;
begin
  Result := FCookies.ToArray;
end;

class function TResponse.Json(const ABody: string; const AStatusCode: Integer): TResponse;
begin
  Result := TResponse.Create;
  Result.StatusCode := AStatusCode;
  Result.ContentType := 'application/json; charset=utf-8';
  Result.Body := ABody;
end;

class function TResponse.NoContent: TResponse;
begin
  Result := TResponse.Create;
  Result.StatusCode := 204;
  Result.Body := '';
end;

end.
