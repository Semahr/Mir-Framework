unit Env.Helpers;

interface

uses
  System.SysUtils,
  System.Classes;

type
  IEnvProvider = interface
    ['{79dee930-87a5-4244-b9ab-36a38c852cc8}']
    function GetValue(const Name: string): string;
  end;

  TSystemEnvProvider = class(TInterfacedObject, IEnvProvider)
  public
    function GetValue(const Name: string): string;
  end;

  TEnv = record
  public
    class function Provider: IEnvProvider; static;
    class procedure SetProvider(const AProvider: IEnvProvider); static;

    class function Has(const Name: string): Boolean; static;

    class function GetString(const Name: string; const Default: string = ''): string; static;
    class function GetInt(const Name: string; const Default: Integer = 0): Integer; static;
    class function GetInt64(const Name: string; const Default: Int64 = 0): Int64; static;
    class function GetFloat(const Name: string; const Default: Double = 0): Double; static;
    class function GetCurrency(const Name: string; const Default: Currency = 0): Currency; static;
    class function GetBool(const Name: string; const Default: Boolean = False): Boolean; static;

    class function TryGetString(const Name: string; out Value: string): Boolean; static;
    class function TryGetInt(const Name: string; out Value: Integer): Boolean; static;
    class function TryGetBool(const Name: string; out Value: Boolean): Boolean; static;

    class function RequireString(const Name: string): string; static;
    class function RequireInt(const Name: string): Integer; static;
    class function RequireBool(const Name: string): Boolean; static;
  end;

implementation

uses
  AppExceptions;

var
  GProvider: IEnvProvider;

{ TSystemEnvProvider }

function TSystemEnvProvider.GetValue(const Name: string): string;
begin
  Result := GetEnvironmentVariable(Name);
end;

{ Helpers internos }

function Normalize(const S: string): string;
begin
  Result := Trim(S);
end;

function ParseBool(const S: string; out Value: Boolean): Boolean;
begin
  var L := S.Trim.ToLower;

  if (L = '1') or (L = 'true') or (L = 'yes') or (L = 'y') or (L = 'on') then
  begin
    Value := True;
    Exit(True);
  end;

  if (L = '0') or (L = 'false') or (L = 'no') or (L = 'n') or (L = 'off') then
  begin
    Value := False;
    Exit(True);
  end;

  Result := False;
end;

function MustNotBeEmpty(const Name, Value: string): string;
begin
  if Value = '' then
    raise EInvalidDependencyException.CreateFmt('Required env: %s', [Name]);
  Result := Value;
end;

{ TEnv }

class function TEnv.Provider: IEnvProvider;
begin
  if GProvider = nil then
    GProvider := TSystemEnvProvider.Create;
  Result := GProvider;
end;

class procedure TEnv.SetProvider(const AProvider: IEnvProvider);
begin
  GProvider := AProvider;
end;

class function TEnv.Has(const Name: string): Boolean;
begin
  Result := Normalize(Provider.GetValue(Name)) <> '';
end;

class function TEnv.GetString(const Name, Default: string): string;
begin
  Result := Normalize(Provider.GetValue(Name));
  if Result = '' then
    Result := Default;
end;

class function TEnv.GetInt(const Name: string; const Default: Integer): Integer;
begin
  var S := Normalize(Provider.GetValue(Name));
  if (S = '') or (not TryStrToInt(S, Result)) then
    Result := Default;
end;

class function TEnv.GetInt64(const Name: string; const Default: Int64): Int64;
begin
  var S := Normalize(Provider.GetValue(Name));
  if (S = '') or (not TryStrToInt64(S, Result)) then
    Result := Default;
end;

class function TEnv.GetFloat(const Name: string; const Default: Double): Double;
begin
  var S := Normalize(Provider.GetValue(Name));
  if (S = '') or (not TryStrToFloat(S, Result, TFormatSettings.Invariant)) then
    Result := Default;
end;

class function TEnv.GetCurrency(const Name: string; const Default: Currency): Currency;
var
  D: Double;
begin
  var S := Normalize(Provider.GetValue(Name));
  if (S = '') or (not TryStrToFloat(S, D, TFormatSettings.Invariant)) then
    Exit(Default);
  Result := D;
end;

class function TEnv.GetBool(const Name: string; const Default: Boolean): Boolean;
begin
  var S := Normalize(Provider.GetValue(Name));
  if (S = '') or (not ParseBool(S, Result)) then
    Result := Default;
end;

class function TEnv.TryGetString(const Name: string; out Value: string): Boolean;
begin
  Value := Normalize(Provider.GetValue(Name));
  Result := Value <> '';
end;

class function TEnv.TryGetInt(const Name: string; out Value: Integer): Boolean;
begin
  var S := Normalize(Provider.GetValue(Name));
  Result := (S <> '') and TryStrToInt(S, Value);
end;

class function TEnv.TryGetBool(const Name: string; out Value: Boolean): Boolean;
begin
  var S := Normalize(Provider.GetValue(Name));
  Result := (S <> '') and ParseBool(S, Value);
end;

class function TEnv.RequireString(const Name: string): string;
begin
  Result := MustNotBeEmpty(Name, Normalize(Provider.GetValue(Name)));
end;

class function TEnv.RequireInt(const Name: string): Integer;
begin
  var S := MustNotBeEmpty(Name, Normalize(Provider.GetValue(Name)));
  if not TryStrToInt(S, Result) then
    raise EInvalidDependencyException.CreateFmt('Variable %s must be int. Value: "%s"', [Name, S]);
end;

class function TEnv.RequireBool(const Name: string): Boolean;
begin
  var S := MustNotBeEmpty(Name, Normalize(Provider.GetValue(Name)));
  if not ParseBool(S, Result) then
    raise EInvalidDependencyException.CreateFmt('Variable %s debe ser boolean. Valor: "%s"', [Name, S]);
end;

end.
