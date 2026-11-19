unit Http.Parameter.Attributes;

interface

uses
  System.SysUtils;

type
  FromContextAttribute = class(TCustomAttribute);

  FromRouteAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const AName: string = '');
    property Name: string read FName;
  end;

  FromCookieAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const AName: string = '');
    property Name: string read FName;
  end;

  FromQueryAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const AName: string = '');
    property Name: string read FName;
  end;

  FromHeaderAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const AName: string = '');
    property Name: string read FName;
  end;

  FromBodyAttribute = class(TCustomAttribute);

implementation

{ FromRouteAttribute }

constructor FromRouteAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName.Trim;
end;

{ FromCookieAttribute }

constructor FromCookieAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName.Trim;
end;

{ FromQueryAttribute }

constructor FromQueryAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName.Trim;
end;

{ FromHeaderAttribute }

constructor FromHeaderAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName.Trim.ToLower
end;
end.
