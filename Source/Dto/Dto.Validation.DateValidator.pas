unit Dto.Validation.DateValidator;

interface

uses
  System.Rtti,
  Dto.Validation.Context;

type
  TDtoDateValidator = class
  public
    class function TryValidate(
      const AContext: TDtoValidationContext;
      out AParsedValue: TValue;
      out AErrorMessages: TArray<string>
    ): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.JSON,
  Dto.TypeInspector;

class function TDtoDateValidator.TryValidate(
  const AContext: TDtoValidationContext;
  out AParsedValue: TValue;
  out AErrorMessages: TArray<string>
): Boolean;
var
  DateValue: TDateTime;
  DateTypeMessage: string;
begin
  Result := False;
  AParsedValue := TValue.Empty;
  SetLength(AErrorMessages, 0);

  DateTypeMessage := TDtoTypeInspector.GetDateTypeMessage(AContext.PropertyInfo);

  if not (AContext.JsonValue is TJSONString) then
  begin
    AErrorMessages := [DateTypeMessage];
    Exit;
  end;

  try
    DateValue := ISO8601ToDate(TJSONString(AContext.JsonValue).Value, False);

    if TDtoTypeInspector.IsDateOnlyType(AContext.PropertyInfo) then
      DateValue := Trunc(DateValue);

    AParsedValue := TValue.From<TDateTime>(DateValue);
    Result := True;
  except
    AErrorMessages := [DateTypeMessage];
  end;
end;

end.
