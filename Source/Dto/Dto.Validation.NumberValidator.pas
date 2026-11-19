unit Dto.Validation.NumberValidator;

interface

uses
  System.Rtti,
  Dto.Validation.Context;

type
  TDtoNumberValidator = class
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
  System.Math,
  System.JSON,
  System.Classes,
  System.Variants,
  RttiAttribute.Helpers,
  Dto.Attributes,
  Dto.TypeInspector;

class function TDtoNumberValidator.TryValidate(
  const AContext: TDtoValidationContext;
  out AParsedValue: TValue;
  out AErrorMessages: TArray<string>
): Boolean;
var
  NumberValue: Double;
  MinRule: MinAttribute;
  MaxRule: MaxAttribute;
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
    if not (AContext.JsonValue is TJSONNumber) then
    begin
      if TDtoTypeInspector.IsIntegerType(AContext.PropertyInfo) or
         TDtoTypeInspector.IsInt64Type(AContext.PropertyInfo) then
        AErrorMessages := ['must be an integer']
      else
        AErrorMessages := ['must be a number'];

      Exit;
    end;

    NumberValue := TJSONNumber(AContext.JsonValue).AsDouble;

    if (TDtoTypeInspector.IsIntegerType(AContext.PropertyInfo) or
        TDtoTypeInspector.IsInt64Type(AContext.PropertyInfo)) and
       (Frac(NumberValue) <> 0) then
    begin
      AErrorMessages := ['must be an integer'];
      Exit;
    end;

    if TRttiAttributeHelpers.TryGetAttribute<MinAttribute>(AContext.PropertyInfo, MinRule) and
       (NumberValue < MinRule.Value) then
    begin
      if TDtoTypeInspector.IsIntegerType(AContext.PropertyInfo) or
         TDtoTypeInspector.IsInt64Type(AContext.PropertyInfo) then
        LocalErrors.Add('must be >= ' + Trunc(MinRule.Value).ToString)
      else
        LocalErrors.Add('must be >= ' + FloatToStr(MinRule.Value));
    end;

    if TRttiAttributeHelpers.TryGetAttribute<MaxAttribute>(AContext.PropertyInfo, MaxRule) and
       (NumberValue > MaxRule.Value) then
    begin
      if TDtoTypeInspector.IsIntegerType(AContext.PropertyInfo) or
         TDtoTypeInspector.IsInt64Type(AContext.PropertyInfo) then
        LocalErrors.Add('must be <= ' + Trunc(MaxRule.Value).ToString)
      else
        LocalErrors.Add('must be <= ' + FloatToStr(MaxRule.Value));
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

          if VarIsNumeric(AllowedValue) and SameValue(NumberValue, Double(AllowedValue)) then
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

    if TDtoTypeInspector.IsCurrencyType(AContext.PropertyInfo) then
    begin
      AParsedValue := TValue.From<Currency>(Currency(NumberValue));
      Exit(True);
    end;

    case AContext.PropertyInfo.PropertyType.TypeKind of
      tkInteger:
        AParsedValue := TValue.From<Integer>(Trunc(NumberValue));

      tkInt64:
        AParsedValue := TValue.From<Int64>(Int64(Trunc(NumberValue)));

      tkFloat:
        AParsedValue := TValue.From<Double>(NumberValue);
    else
      AParsedValue := TValue.From<Double>(NumberValue);
    end;

    Result := True;
  finally
    LocalErrors.Free;
  end;
end;

end.
