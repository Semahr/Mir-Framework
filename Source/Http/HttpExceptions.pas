unit HttpExceptions;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  EHttpException = class(Exception)
  private
    FStatusCode: Integer;
    FErrorName: string;
    FMessages: TArray<string>;
    FCause: Exception;
  public
    constructor Create(
      const AStatusCode: Integer;
      const AErrorName: string;
      const AMessageText: string;
      const ACause: Exception = nil
    ); overload;
    
    constructor Create(
      const AStatusCode: Integer;
      const AErrorName: string;
      const AMessageList: TArray<string>;
      const ACause: Exception = nil
    ); overload;
    
    property StatusCode: Integer read FStatusCode;
    property ErrorName: string read FErrorName;
    property Messages: TArray<string> read FMessages;
    property Cause: Exception read FCause;
  end;

  EBadRequestException = class(EHttpException)
  public
    constructor Create(
      const AMessageText: string = 'Bad Request';
      const ACause: Exception = nil;
      const AErrorName: string = 'Bad Request'
    ); overload;
    
    constructor Create(
      const AMessages: TArray<string>;
      const ACause: Exception = nil;
      const AErrorName: string = 'Bad Request'
    ); overload;
  end;

  EUnauthorizedException = class(EHttpException)
  public
    constructor Create(
      const AMessageText: string = 'Unauthorized';
      const ACause: Exception = nil;
      const AErrorName: string = 'Unauthorized'
    );
  end;

  EForbiddenException = class(EHttpException)
  public
    constructor Create(
      const AMessageText: string = 'Forbidden';
      const ACause: Exception = nil;
      const AErrorName: string = 'Forbidden'
    );
  end;

  ENotFoundException = class(EHttpException)
  public
    constructor Create(
      const AMessageText: string = 'Not Found';
      const ACause: Exception = nil;
      const AErrorName: string = 'Not Found'
    );
  end;

  EConflictException = class(EHttpException)
  public
    constructor Create(
      const AMessageText: string = 'Conflict';
      const ACause: Exception = nil;
      const AErrorName: string = 'Conflict'
    );
  end;

  EInternalServerErrorException = class(EHttpException)
  public
    constructor Create(
      const AMessageText: string = 'Internal Server Error';
      const ACause: Exception = nil;
      const AErrorName: string = 'Internal Server Error'
    );
  end;

  EBadGatewayException = class(EHttpException)
  public
    constructor Create(
      const AMessageText: string = 'Bad Gateway';
      const ACause: Exception = nil;
      const AErrorName: string = 'Bad Gateway'
    );
  end;

  EServiceUnavailableException = class(EHttpException)
  public
    constructor Create(
      const AMessageText: string = 'Service Unavailable';
      const ACause: Exception = nil;
      const AErrorName: string = 'Service Unavailable'
    );
  end;

function BuildHttpExceptionJson(
  const AStatusCode: Integer;
  const AErrorName: string;
  const AMessages: TArray<string>
): string;

implementation

uses
  System.JSON,
  System.StrUtils;

function BuildHttpExceptionJson(
  const AStatusCode: Integer;
  const AErrorName: string;
  const AMessages: TArray<string>
): string;
var
  ResponseMessages: TArray<string>;
  JsonObject: TJSONObject;
  JsonMessages: TJSONArray;
begin
  JsonObject := TJSONObject.Create;
  try
    JsonObject.AddPair('statusCode', TJSONNumber.Create(AStatusCode));
    JsonObject.AddPair('error', AErrorName);

    ResponseMessages := AMessages;

    if Length(ResponseMessages) = 1 then
    begin
      JsonObject.AddPair('message', ResponseMessages[0]);
      Exit(JsonObject.ToJSON);
    end;

    JsonMessages := TJSONArray.Create;
    try
      for var Index := 0 to High(ResponseMessages) do
        JsonMessages.Add(ResponseMessages[Index]);

      JsonObject.AddPair('message', JsonMessages);
      JsonMessages := nil;
    finally
      JsonMessages.Free;
    end;

    Result := JsonObject.ToJSON;
  finally
    JsonObject.Free;
  end;
end;

{ EHttpException }

constructor EHttpException.Create(
  const AStatusCode: Integer;
  const AErrorName: string;
  const AMessageText: string;
  const ACause: Exception
);
begin
  inherited Create(AMessageText);
  FStatusCode := AStatusCode;
  FErrorName := AErrorName;
  FMessages := [AMessageText];
  FCause := ACause;
end;

constructor EHttpException.Create(
  const AStatusCode: Integer;
  const AErrorName: string;
  const AMessageList: TArray<string>;
  const ACause: Exception
);
begin
  inherited Create(AErrorName);
  FStatusCode := AStatusCode;
  FErrorName := AErrorName;
  FMessages := AMessageList;
  FCause := ACause;
end;

{ Derived }

constructor EBadRequestException.Create(
  const AMessageText: string;
  const ACause: Exception;
  const AErrorName: string
);
begin
  inherited Create(400, AErrorName, AMessageText, ACause);
end;

constructor EBadRequestException.Create(
  const AMessages: TArray<string>;
  const ACause: Exception;
  const AErrorName: string
);
begin
  inherited Create(400, AErrorName, AMessages, ACause);
end;

constructor EUnauthorizedException.Create(
  const AMessageText: string;
  const ACause: Exception;
  const AErrorName: string
);
begin
  inherited Create(401, AErrorName, AMessageText, ACause);
end;

constructor EForbiddenException.Create(
  const AMessageText: string;
  const ACause: Exception;
  const AErrorName: string
);
begin
  inherited Create(403, AErrorName, AMessageText, ACause);
end;

constructor ENotFoundException.Create(
  const AMessageText: string;
  const ACause: Exception;
  const AErrorName: string
);
begin
  inherited Create(404, AErrorName, AMessageText, ACause);
end;

constructor EConflictException.Create(
  const AMessageText: string;
  const ACause: Exception;
  const AErrorName: string
);
begin
  inherited Create(409, AErrorName, AMessageText, ACause);
end;

constructor EInternalServerErrorException.Create(
  const AMessageText: string;
  const ACause: Exception;
  const AErrorName: string
);
begin
  inherited Create(500, AErrorName, AMessageText, ACause);
end;

constructor EBadGatewayException.Create(
  const AMessageText: string;
  const ACause: Exception;
  const AErrorName: string
);
begin
  inherited Create(502, AErrorName, AMessageText, ACause);
end;

constructor EServiceUnavailableException.Create(
  const AMessageText: string;
  const ACause: Exception;
  const AErrorName: string
);
begin
  inherited Create(503, AErrorName, AMessageText, ACause);
end;

end.
