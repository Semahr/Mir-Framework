unit Http.Attributes;

interface

uses
  System.SysUtils;

type
  RouteAttribute = class(TCustomAttribute)
  private
    FPath: string;
  public
    constructor Create(const APath: string);

    property Path: string read FPath;
  end;

  HttpMethodAttribute = class(TCustomAttribute)
  private
    FMethod: string;
    FPath: string;
  public
    constructor Create(const AMethod: string; const APath: string);
    property Method: string read FMethod;
    property Path: string read FPath;
  end;

  GetAttribute = class(HttpMethodAttribute)
  public
    constructor Create(const APath: string = '');
  end;

  PostAttribute = class(HttpMethodAttribute)
  public
    constructor Create(const APath: string = '');
  end;

  PutAttribute = class(HttpMethodAttribute)
  public
    constructor Create(const APath: string = '');
  end;

  PatchAttribute = class(HttpMethodAttribute)
  public
    constructor Create(const APath: string = '');
  end;

  DeleteAttribute = class(HttpMethodAttribute)
  public
    constructor Create(const APath: string = '');
  end;

  StatusCodeAttribute = class(TCustomAttribute)
  private
    FStatusCode: Integer;
  public
    constructor Create(const AStatusCode: Integer);
    property StatusCode: Integer read FStatusCode;
  end;

implementation

{ RouteAttribute }

constructor RouteAttribute.Create(const APath: string);
begin
  inherited Create;
  FPath := APath;
end;

{ HttpMethodAttribute }

constructor HttpMethodAttribute.Create(const AMethod: string; const APath: string);
begin
  inherited Create;
  FMethod := UpperCase(AMethod);
  FPath := APath;
end;

{ GetAttribute }

constructor GetAttribute.Create(const APath: string);
begin
  inherited Create('GET', APath);
end;

{ PostAttribute }

constructor PostAttribute.Create(const APath: string);
begin
  inherited Create('POST', APath);
end;

{ PutAttribute }

constructor PutAttribute.Create(const APath: string);
begin
  inherited Create('PUT', APath);
end;

{ PatchAttribute }

constructor PatchAttribute.Create(const APath: string = '');
begin
  inherited Create('PATCH', APath);
end;

{ DeleteAttribute }

constructor DeleteAttribute.Create(const APath: string);
begin
  inherited Create('DELETE', APath);
end;

{ StatusCodeAttribute }

constructor StatusCodeAttribute.Create(const AStatusCode: Integer);
begin
  inherited Create;
  FStatusCode := AStatusCode;
end;

end.
