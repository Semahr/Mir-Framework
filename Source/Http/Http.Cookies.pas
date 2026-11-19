unit Http.Cookies;

interface

uses
  System.SysUtils;

type
  TCookieSameSite = (
    cssUnspecified,
    cssStrict,
    cssLax,
    cssNone
  );

  TCookieOptions = record
  private
    FName: string;
    FValue: string;
    FPath: string;
    FDomain: string;
    FExpires: TDateTime;
    FMaxAge: Integer;
    FHasExpires: Boolean;
    FHasMaxAge: Boolean;
    FHttpOnly: Boolean;
    FSecure: Boolean;
    FSameSite: TCookieSameSite;
  public
    class function Create(const AName: string; const AValue: string): TCookieOptions; static;
    class function Expired(const AName: string; const APath: string = '/'): TCookieOptions; static;

    function WithPath(const APath: string): TCookieOptions;
    function WithDomain(const ADomain: string): TCookieOptions;
    function WithExpires(const AExpires: TDateTime): TCookieOptions;
    function WithMaxAge(const AMaxAge: Integer): TCookieOptions;
    function WithHttpOnly(const AHttpOnly: Boolean = True): TCookieOptions;
    function WithSecure(const ASecure: Boolean = True): TCookieOptions;
    function WithSameSite(const ASameSite: TCookieSameSite): TCookieOptions;

    property Name: string read FName;
    property Value: string read FValue;
    property Path: string read FPath;
    property Domain: string read FDomain;
    property Expires: TDateTime read FExpires;
    property MaxAge: Integer read FMaxAge;
    property HasExpires: Boolean read FHasExpires;
    property HasMaxAge: Boolean read FHasMaxAge;
    property HttpOnly: Boolean read FHttpOnly;
    property Secure: Boolean read FSecure;
    property SameSite: TCookieSameSite read FSameSite;
  end;

  TCookieSerializer = class sealed
  private
    class function FormatHttpDate(const AValue: TDateTime): string; static;
    class function SameSiteToString(const AValue: TCookieSameSite): string; static;
  public
    class function Serialize(const ACookie: TCookieOptions): string; static;
  end;

implementation

{ TCookieOptions }

class function TCookieOptions.Create(const AName: string; const AValue: string): TCookieOptions;
begin
  Result.FName := AName.Trim;
  Result.FValue := AValue;
  Result.FPath := '/';
  Result.FDomain := '';
  Result.FExpires := 0;
  Result.FMaxAge := 0;
  Result.FHasExpires := False;
  Result.FHasMaxAge := False;
  Result.FHttpOnly := False;
  Result.FSecure := False;
  Result.FSameSite := cssUnspecified;
end;

class function TCookieOptions.Expired(const AName: string; const APath: string): TCookieOptions;
begin
  Result := TCookieOptions.Create(AName, '');
  Result.FPath := APath;
  Result.FMaxAge := 0;
  Result.FHasMaxAge := True;
  Result.FExpires := EncodeDate(1970, 1, 1);
  Result.FHasExpires := True;
end;

function TCookieOptions.WithPath(const APath: string): TCookieOptions;
begin
  Result := Self;
  Result.FPath := APath;
end;

function TCookieOptions.WithDomain(const ADomain: string): TCookieOptions;
begin
  Result := Self;
  Result.FDomain := ADomain.Trim;
end;

function TCookieOptions.WithExpires(const AExpires: TDateTime): TCookieOptions;
begin
  Result := Self;
  Result.FExpires := AExpires;
  Result.FHasExpires := True;
end;

function TCookieOptions.WithMaxAge(const AMaxAge: Integer): TCookieOptions;
begin
  Result := Self;
  Result.FMaxAge := AMaxAge;
  Result.FHasMaxAge := True;
end;

function TCookieOptions.WithHttpOnly(const AHttpOnly: Boolean): TCookieOptions;
begin
  Result := Self;
  Result.FHttpOnly := AHttpOnly;
end;

function TCookieOptions.WithSecure(const ASecure: Boolean): TCookieOptions;
begin
  Result := Self;
  Result.FSecure := ASecure;
end;

function TCookieOptions.WithSameSite(const ASameSite: TCookieSameSite): TCookieOptions;
begin
  Result := Self;
  Result.FSameSite := ASameSite;
end;

{ TCookieSerializer }

class function TCookieSerializer.FormatHttpDate(const AValue: TDateTime): string;
const
  Days: array[1..7] of string = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
  Months: array[1..12] of string = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
var
  Year: Word;
  Month: Word;
  Day: Word;
  Hour: Word;
  Minute: Word;
  Second: Word;
  Millisecond: Word;
begin
  DecodeDate(AValue, Year, Month, Day);
  DecodeTime(AValue, Hour, Minute, Second, Millisecond);

  Result := Format(
    '%s, %.2d %s %.4d %.2d:%.2d:%.2d GMT',
    [Days[DayOfWeek(AValue)], Day, Months[Month], Year, Hour, Minute, Second]
  );
end;

class function TCookieSerializer.SameSiteToString(const AValue: TCookieSameSite): string;
begin
  case AValue of
    cssStrict:
      Exit('Strict');

    cssLax:
      Exit('Lax');

    cssNone:
      Exit('None');
  end;

  Result := '';
end;

class function TCookieSerializer.Serialize(const ACookie: TCookieOptions): string;
var
  SameSiteValue: string;
begin
  if ACookie.Name.Trim.IsEmpty then
    raise EArgumentException.Create('Cookie name is required.');

  Result := ACookie.Name + '=' + ACookie.Value;

  if not ACookie.Path.Trim.IsEmpty then
    Result := Result + '; Path=' + ACookie.Path;

  if not ACookie.Domain.Trim.IsEmpty then
    Result := Result + '; Domain=' + ACookie.Domain;

  if ACookie.HasMaxAge then
    Result := Result + '; Max-Age=' + ACookie.MaxAge.ToString;

  if ACookie.HasExpires then
    Result := Result + '; Expires=' + FormatHttpDate(ACookie.Expires);

  if ACookie.HttpOnly then
    Result := Result + '; HttpOnly';

  if ACookie.Secure then
    Result := Result + '; Secure';

  SameSiteValue := SameSiteToString(ACookie.SameSite);
  if not SameSiteValue.IsEmpty then
    Result := Result + '; SameSite=' + SameSiteValue;
end;

end.
