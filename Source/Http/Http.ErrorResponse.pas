unit Http.ErrorResponse;

interface

uses
  System.SysUtils,
  Http.Core;

type
  TDefaultErrorResponseRenderer = class sealed
  public
    class function Render(const AError: Exception; const AEnvironment: string = 'production'): TResponse; static;
  end;

implementation

uses
  HttpExceptions,
  AppExceptions;

class function TDefaultErrorResponseRenderer.Render(const AError: Exception; const AEnvironment: string): TResponse;
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
    Messages := [AError.Message];
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
  else if AError is EInvalidDependencyPropertyException then
  begin
    StatusCode := 500;
    ErrorName := 'Internal Server Error';
    Messages := ['Server dependency property is not properly configured.'];
  end
  else if AError is EMissingDependencyException then
  begin
    StatusCode := 500;
    ErrorName := 'Internal Server Error';
    Messages := ['Server dependency is not properly configured.'];
  end
  else if AError is EInvalidDependencyException then
  begin
    StatusCode := 500;
    ErrorName := 'Internal Server Error';
    Messages := ['Server dependency is not properly configured.'];
  end
  else if AError is EDependencyException then
  begin
    StatusCode := 500;
    ErrorName := 'Internal Server Error';
    Messages := ['Server dependency is not properly configured.'];
  end
  else if AError is EActionNotAssignedException then
  begin
    StatusCode := 500;
    ErrorName := 'Internal Server Error';
    Messages := ['Server metadata is not properly configured.'];
  end
  else if AError is EMetadataException then
  begin
    StatusCode := 500;
    ErrorName := 'Internal Server Error';
    Messages := ['Server metadata is not properly configured.'];
  end
  else if AError is EControllerException then
  begin
    StatusCode := 500;
    ErrorName := 'Internal Server Error';
    Messages := ['Unexpected service error.'];
  end
  else if AError is EServiceException then
  begin
    StatusCode := 500;
    ErrorName := 'Internal Server Error';
    Messages := ['Unexpected service error.'];
  end
  else if AError is EAppException then
  begin
    StatusCode := 500;
    ErrorName := 'Internal Server Error';
    Messages := ['Unexpected server error.'];
  end
  else
  begin
    StatusCode := 500;
    ErrorName := 'Internal Server Error';
    Messages := ['Unexpected server error.'];
  end;

  if StatusCode = 500 then
  begin
    if SameText(AEnvironment.Trim, 'development') then
      Messages := [AError.Message]
    else if AError is EHttpException then
    begin
      // Explicit HTTP 500 errors must not bypass production sanitization.
      ErrorName := 'Internal Server Error';
      Messages := ['Unexpected server error.'];
    end;
  end;

  Result := TResponse.Create;
  Result.StatusCode := StatusCode;
  Result.ContentType := 'application/json; charset=utf-8';
  Result.Body := BuildHttpExceptionJson(StatusCode, ErrorName, Messages);
end;

end.
