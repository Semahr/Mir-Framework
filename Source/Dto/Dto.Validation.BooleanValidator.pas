unit Dto.Validation.BooleanValidator;

interface

uses
  System.Rtti,
  Dto.Validation.Context;

type
  TDtoBooleanValidator = class
  public
    class function TryValidate(
      const AContext: TDtoValidationContext;
      out AParsedValue: TValue;
      out AErrorMessages: TArray<string>
    ): Boolean; static;
  end;

implementation

uses
  System.JSON;

class function TDtoBooleanValidator.TryValidate(
  const AContext: TDtoValidationContext;
  out AParsedValue: TValue;
  out AErrorMessages: TArray<string>
): Boolean;
var
  BooleanValue: Boolean;
begin
  Result := False;
  AParsedValue := TValue.Empty;
  SetLength(AErrorMessages, 0);

  if AContext.JsonValue is TJSONTrue then
    BooleanValue := True
  else if AContext.JsonValue is TJSONFalse then
    BooleanValue := False
  else
  begin
    AErrorMessages := ['must be a boolean'];
    Exit;
  end;

  AParsedValue := TValue.From<Boolean>(BooleanValue);
  Result := True;
end;

end.
