unit Dto.Validation.StringValidator;

interface

uses
  System.Rtti,
  Dto.Validation.Context;

type
  TDtoStringValidator = class
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
  System.Generics.Collections,
  System.JSON,
  System.Variants,
  System.Classes,
  RttiAttribute.Helpers,
  Dto.Attributes;

class function TDtoStringValidator.TryValidate(
  const AContext: TDtoValidationContext;
  out AParsedValue: TValue;
  out AErrorMessages: TArray<string>
): Boolean;
var
  StringValue: string;
  LengthRule: LengthAttribute;
  IsInRule: IsInAttribute;
  LocalErrors: TList<string>;
  HasAllowedValue: Boolean;
  AllowedValuesText: TStringList;
begin
  Result := False;
  AParsedValue := TValue.Empty;
  SetLength(AErrorMessages, 0);

  LocalErrors := TList<string>.Create;
  try
    if not (AContext.JsonValue is TJSONString) then
    begin
      AErrorMessages := ['must be a string'];
      Exit;
    end;

    StringValue := TJSONString(AContext.JsonValue).Value;

    if TRttiAttributeHelpers.HasAttribute<RequiredAttribute>(AContext.PropertyInfo) and
       (Trim(StringValue) = '') then
      LocalErrors.Add('cannot be empty');

    if TRttiAttributeHelpers.TryGetAttribute<LengthAttribute>(AContext.PropertyInfo, LengthRule) then
    begin
      if (LengthRule.MinLength >= 0) and
         (LengthRule.MinLength = LengthRule.MaxLength) then
      begin
        if LengthRule.MinLength <> StringValue.Length then
          LocalErrors.Add('length must be ' + LengthRule.MinLength.ToString);
      end
      else
      begin
        if (LengthRule.MinLength >= 0) and
           (StringValue.Length < LengthRule.MinLength) then
          LocalErrors.Add('length must be >= ' + LengthRule.MinLength.ToString);

        if (LengthRule.MaxLength >= 0) and
           (StringValue.Length > LengthRule.MaxLength) then
          LocalErrors.Add('length must be <= ' + LengthRule.MaxLength.ToString);
      end;
    end;

    if TRttiAttributeHelpers.HasAttribute<IsNumberStringAttribute>(AContext.PropertyInfo) then
    begin
      for var Index := 1 to Length(StringValue) do
      begin
        if not (StringValue[Index] in ['0'..'9']) then
        begin
          LocalErrors.Add('must contain only digits');
          Break;
        end;
      end;
    end;

    if TRttiAttributeHelpers.TryGetAttribute<IsInAttribute>(AContext.PropertyInfo, IsInRule) then
    begin
      HasAllowedValue := False;
      AllowedValuesText := TStringList.Create;
      try
        AllowedValuesText.StrictDelimiter := True;
        AllowedValuesText.Delimiter := ',';

        for var AllowedValue in IsInRule.Values do
        begin
          AllowedValuesText.Add(VarToStr(AllowedValue));

          if SameText(StringValue, VarToStr(AllowedValue)) then
            HasAllowedValue := True;
        end;

        if not HasAllowedValue then
          LocalErrors.Add('must be one of: ' + AllowedValuesText.DelimitedText);
      finally
        AllowedValuesText.Free;
      end;
    end;

    if LocalErrors.Count > 0 then
    begin
      AErrorMessages := LocalErrors.ToArray;
      Exit;
    end;

    AParsedValue := TValue.From<string>(StringValue);
    Result := True;
  finally
    LocalErrors.Free;
  end;
end;

end.
