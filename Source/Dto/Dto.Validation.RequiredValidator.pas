unit Dto.Validation.RequiredValidator;

interface

uses
  System.Rtti,
  System.JSON;

type
  TDtoRequiredValidator = class
  public
    class function TryValidate(
      const APropertyInfo: TRttiProperty;
      const AJsonValue: TJSONValue;
      out AErrorMessage: string
    ): Boolean; static;
  end;

implementation

uses
  RttiAttribute.Helpers,
  Dto.Attributes;

class function TDtoRequiredValidator.TryValidate(
  const APropertyInfo: TRttiProperty;
  const AJsonValue: TJSONValue;
  out AErrorMessage: string
): Boolean;
begin
  Result := True;
  AErrorMessage := '';

  if AJsonValue <> nil then
    Exit;

  if TRttiAttributeHelpers.HasAttribute<RequiredAttribute>(APropertyInfo) then
  begin
    AErrorMessage := 'is required';
    Exit(False);
  end;
end;

end.
