unit Dto.Binder.Context;

interface

uses
  System.Generics.Collections;

type
  TDtoBindingContext = record
  private
    FErrors: TList<string>;
  public
    class function Create: TDtoBindingContext; static;

    procedure Release;

    function ErrorCount: Integer;
    procedure AddError(const APropertyPath: string; const AMessage: string);
    procedure AddErrors(const APropertyPath: string; const AMessages: TArray<string>);
    procedure RaiseIfHasErrors;
  end;

implementation

uses
  HttpExceptions;


{ TDtoBindingContext }

class function TDtoBindingContext.Create: TDtoBindingContext;
begin
  Result.FErrors := TList<string>.Create;
end;

procedure TDtoBindingContext.Release;
begin
  FErrors.Free;
  FErrors := nil;
end;

function TDtoBindingContext.ErrorCount: Integer;
begin
  if FErrors = nil then
    Exit(0);

  Result := FErrors.Count;
end;

procedure TDtoBindingContext.AddError(const APropertyPath: string; const AMessage: string);
begin
  if FErrors = nil then
    FErrors := TList<string>.Create;

  FErrors.Add(APropertyPath + ' ' + AMessage);
end;

procedure TDtoBindingContext.AddErrors(const APropertyPath: string; const AMessages: TArray<string>);
begin
  for var Message in AMessages do
    AddError(APropertyPath, Message);
end;

procedure TDtoBindingContext.RaiseIfHasErrors;
begin
  if ErrorCount = 0 then
    Exit;

  raise EBadRequestException.Create(FErrors.ToArray);
end;

end.
