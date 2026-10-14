program HttpErrorResponseTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.JSON,
  AppExceptions,
  HttpExceptions,
  Http.Core,
  Http.ErrorResponse;

procedure Check(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure TestRender(const AError: Exception; const AStatus: Integer;
  const AExpectedMessage: string; const AHideOriginal: Boolean;
  const AEnvironment: string = 'production');
var
  Response: TResponse;
  SecondResponse: TResponse;
begin
  try
    Response := TDefaultErrorResponseRenderer.Render(AError, AEnvironment);
    try
      Check(Response.StatusCode = AStatus, 'Unexpected status code');
      Check(Response.ContentType = 'application/json; charset=utf-8', 'Expected JSON content type');
      Check(Pos(AExpectedMessage, Response.Body) > 0, 'Expected error message');
      if AHideOriginal then
        Check(Pos(AError.Message, Response.Body) = 0, 'Internal details must not be exposed');

      SecondResponse := TDefaultErrorResponseRenderer.Render(AError, AEnvironment);
      try
        Check(SecondResponse <> Response, 'Each call must return a separate response');
        Check(SecondResponse.Body = Response.Body, 'Repeated rendering must be consistent');
      finally
        SecondResponse.Free;
      end;
    finally
      Response.Free;
    end;
  finally
    AError.Free;
  end;
end;

procedure TestAppException(const AExceptionClass: ExceptClass;
  const AStatus: Integer; const AGenericMessage: string = '');
const
  Environments: array[0..2] of string = ('production', 'beta', 'development');
var
  Environment: string;
  Context: string;
  OriginalMessage: string;
  ExpectedMessages: TArray<string>;
  Error: Exception;
  Response: TResponse;
  Json: TJSONValue;
  MessageValue: TJSONValue;
  Messages: TJSONArray;
  Index: Integer;
begin
  for Environment in Environments do
  begin
    Context := AExceptionClass.ClassName + ' / ' + Environment + ': ';
    OriginalMessage := 'Exact ' + AExceptionClass.ClassName + ' detail, with "quotes"';
    if AExceptionClass = EBadRequestAppException then
      Error := EBadRequestAppException.Create(
        TArray<string>.Create('First validation error', 'Second "quoted" validation error'))
    else
      Error := AExceptionClass.Create(OriginalMessage);
    try
      if AExceptionClass = EBadRequestAppException then
        ExpectedMessages := EBadRequestAppException(Error).Messages
      else if (AStatus = 500) and (Environment <> 'development') then
        ExpectedMessages := TArray<string>.Create(AGenericMessage)
      else
        ExpectedMessages := TArray<string>.Create(Error.Message);

      Response := TDefaultErrorResponseRenderer.Render(Error, Environment);
      try
        Check(Response.StatusCode = AStatus, Context + 'Unexpected status code');
        Check(Response.ContentType = 'application/json; charset=utf-8',
          Context + 'Expected JSON content type');
        Json := TJSONObject.ParseJSONValue(Response.Body);
        try
          Check(Json is TJSONObject, Context + 'Expected JSON object');
          MessageValue := TJSONObject(Json).GetValue('message');
          Check(MessageValue <> nil, Context + 'Missing message');
          if Length(ExpectedMessages) = 1 then
          begin
            Check(MessageValue is TJSONString, Context + 'Expected string message');
            Check(MessageValue.Value = ExpectedMessages[0],
              Context + 'Expected exact error message');
          end
          else
          begin
            Check(MessageValue is TJSONArray, Context + 'Expected message array');
            Messages := TJSONArray(MessageValue);
            Check(Messages.Count = Length(ExpectedMessages),
              Context + 'Unexpected message count');
            for Index := 0 to High(ExpectedMessages) do
            begin
              Check(Messages.Items[Index] is TJSONString,
                Context + 'Expected string array item');
              Check(Messages.Items[Index].Value = ExpectedMessages[Index],
                Context + 'Expected exact message at index ' + IntToStr(Index));
            end;
          end;
          if (AStatus = 500) and (Environment <> 'development') then
            Check(Pos(Error.ClassName, Response.Body) = 0,
              Context + 'Internal details must not be exposed');
        finally
          Json.Free;
        end;
      finally
        Response.Free;
      end;
    finally
      Error.Free;
    end;
  end;
end;

procedure TestAllAppExceptions;
begin
  TestAppException(EAppException, 500, 'Unexpected server error.');
  TestAppException(EDependencyException, 500,
    'Server dependency is not properly configured.');
  TestAppException(EServiceException, 500, 'Unexpected service error.');
  TestAppException(EMetadataException, 500,
    'Server metadata is not properly configured.');
  TestAppException(EMissingDependencyException, 500,
    'Server dependency is not properly configured.');
  TestAppException(EInvalidDependencyException, 500,
    'Server dependency is not properly configured.');
  TestAppException(EInvalidDependencyPropertyException, 500,
    'Server dependency property is not properly configured.');
  TestAppException(EInfrastructureUnavailableException, 503);
  TestAppException(EControllerException, 500, 'Unexpected service error.');
  TestAppException(EUnauthorizedAppException, 401);
  TestAppException(EForbiddenAppException, 403);
  TestAppException(ENotFoundAppException, 404);
  TestAppException(EConflictAppException, 409);
  TestAppException(EBadGatewayAppException, 502);
  TestAppException(EBadRequestAppException, 400);
  TestAppException(EMissingAttributeException, 400);
  TestAppException(EInvalidAttributeException, 400);
  TestAppException(EUnexpectedAttributeException, 400);
  TestAppException(EOutOfRangeAttributeException, 400);
  TestAppException(EActionNotAssignedException, 500,
    'Server metadata is not properly configured.');
end;

begin
  try
    TestRender(EUnauthorizedAppException.Create('Authentication required'),
      401, 'Authentication required', False);
    TestRender(EDependencyException.Create('Private dependency detail'),
      500, 'Server dependency is not properly configured.', True);
    TestRender(Exception.Create('Private internal detail'),
      500, 'Unexpected server error.', True);
    TestRender(EDependencyException.Create('Exact dependency detail'),
      500, 'Exact dependency detail', False, 'development');
    TestRender(EActionNotAssignedException.Create('Exact metadata detail'),
      500, 'Exact metadata detail', False, ' DEVELOPMENT ');
    TestRender(EControllerException.Create('Private controller detail'),
      500, 'Unexpected service error.', True, 'beta');
    TestRender(Exception.Create('Private detail'),
      500, 'Unexpected server error.', True, '');
    TestRender(Exception.Create('Private detail'),
      500, 'Unexpected server error.', True, 'develop');
    TestRender(EInfrastructureUnavailableException.Create('Service offline'),
      503, 'Service offline', False);
    TestRender(EBadGatewayAppException.Create('Upstream failed'),
      502, 'Upstream failed', False, 'beta');
    TestRender(EInvalidDependencyPropertyException.Create('Invalid property detail'),
      500, 'Server dependency property is not properly configured.', True);
    TestRender(EHttpException.Create(500, 'Private error title', 'Private HTTP detail'),
      500, 'Unexpected server error.', True);
    TestRender(EHttpException.Create(500, 'Internal Server Error', 'Exact HTTP detail'),
      500, 'Exact HTTP detail', False, 'development');
    TestAllAppExceptions;
    Writeln('Static error response tests passed.');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
