unit Http.ErrorResponse;

interface

uses
  System.SysUtils,
  Http.Core,
  Http.ErrorResponse.Port;

type
  TDefaultErrorResponseRenderer = class(TInterfacedObject, IErrorResponseRenderer)
  private
    function ParseError(const AError: Exception): TResponse;
  public
    function Render(const AError: Exception): TResponse;
  end;

implementation

uses
  HttpExceptions,
  AppExceptions;

function TDefaultErrorResponseRenderer.Render(const AError: Exception): TResponse;
begin
  Result := ParseError(AError);
end;

function TDefaultErrorResponseRenderer.ParseError(const AError: Exception): TResponse;
var
  StatusCode: Integer;
  ErrorName: string;
  Messages: TArray<string>;
begin
  if AError is EHttpException then
  begin
    var HttpError := EHttpException(AError);

    StatusCode := HttpError.StatusCode;
    ErrorName := HttpError.ErrorName;
    Messages := HttpError.Messages;
  end
  else if AError is EBadRequestAppException then
  begin
    StatusCode := 400;
    ErrorName := 'Bad Request';
    Messages := EBadRequestAppException(AError).Messages;
  end
  else if AError is EUnauthorizedAppException then
  begin
    StatusCode := 401;
    ErrorName := 'Unauthorized';
    Messages := [AError.Message];
  end
  else if AError is EForbiddenAppException then
  begin
    StatusCode := 403;
    ErrorName := 'Forbidden';
    Messages := [AError.Message];
  end
  else if AError is ENotFoundAppException then
  begin
    StatusCode := 404;
    ErrorName := 'Not Found';
    Messages := [AError.Message];
  end
  else if AError is EConflictAppException then
  begin
    StatusCode := 409;
    ErrorName := 'Conflict';
    Messages := [AError.Message];
  end
  else if AError is EBadGatewayAppException then
  begin
    StatusCode := 502;
    ErrorName := 'Bad Gateway';
    Messages := [AError.Message];
  end
  else if AError is EInfrastructureUnavailableException then
  begin
    StatusCode := 503;
    ErrorName := 'Service Unavailable';
    Messages := ['A required service is temporarily unavailable.'];
  end
  else if
    (AError is EMissingAttributeException) or
    (AError is EInvalidAttributeException) or
    (AError is EUnexpectedAttributeException) or
    (AError is EOutOfRangeAttributeException)
  then
  begin
    StatusCode := 400;
    ErrorName := 'Bad Request';
    Messages := [AError.Message];
  end
  else if AError is EDependencyException then
  begin
    StatusCode := 500;
    ErrorName := 'Internal Server Error';
    Messages := ['Server dependency is not properly configured.'];
  end
  else if AError is EMetadataException then
  begin
    StatusCode := 500;
    ErrorName := 'Internal Server Error';
    Messages := ['Server metadata is not properly configured.'];
  end
  else if AError is EServiceException then
  begin
    StatusCode := 500;
    ErrorName := 'Internal Server Error';
    Messages := ['Unexpected service error.'];
  end
  else
  begin
    StatusCode := 500;
    ErrorName := 'Internal Server Error';
    Messages := ['Unexpected server error.'];
  end;

  Result := TResponse.Create;
  Result.StatusCode := StatusCode;
  Result.ContentType := 'application/json; charset=utf-8';
  Result.Body := BuildHttpExceptionJson(StatusCode, ErrorName, Messages);
end;

end.
