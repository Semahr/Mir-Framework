unit Http.ValueConverter;

interface

uses
  System.SysUtils,
  System.Rtti;

type
  TValueConverter = class
  public
    class function TryConvertString(
      const ARawValue: string;
      const ATargetType: TRttiType;
      out AValue: TValue;
      out AErrorMessage: string
    ): Boolean; static;
end;

implementation

uses
  System.DateUtils,
  System.TypInfo;

class function TValueConverter.TryConvertString(
  const ARawValue: string;
  const ATargetType: TRttiType;
  out AValue: TValue;
  out AErrorMessage: string
): Boolean;
var
  IntValue: Integer;
  Int64Value: Int64;
  DoubleValue: Double;
  BoolValue: Boolean;
  EnumValue: Integer;
  FormatSettings: TFormatSettings;
begin
  Result := False;
  AValue := TValue.Empty;
  AErrorMessage := '';

  if ATargetType = nil then
  begin
    AErrorMessage := 'target type is not available';
    Exit;
end;

  FormatSettings := TFormatSettings.Create;
  FormatSettings.DecimalSeparator := '.';

  case ATargetType.TypeKind of
    tkString, tkLString, tkWString, tkUString:
      begin
        AValue := TValue.From<string>(ARawValue);
        Exit(True);
end;

    tkInteger:
      begin
        if not TryStrToInt(ARawValue, IntValue) then
        begin
          AErrorMessage := 'must be a valid integer';
          Exit;
end;

        AValue := TValue.From<Integer>(IntValue);
        Exit(True);
end;

    tkInt64:
      begin
        if not TryStrToInt64(ARawValue, Int64Value) then
        begin
          AErrorMessage := 'must be a valid int64';
          Exit;
end;

        AValue := TValue.From<Int64>(Int64Value);
        Exit(True);
end;

    tkFloat:
      begin
        if ATargetType.Handle = TypeInfo(TDateTime) then
        begin
          var DateValue: TDateTime;

          if not TryISO8601ToDate(ARawValue, DateValue, False) then
          begin
            AErrorMessage := 'must be a valid ISO-8601 datetime';
            Exit;
end;

          AValue := TValue.From<TDateTime>(DateValue);
          Exit(True);
end;

        if not TryStrToFloat(ARawValue, DoubleValue, FormatSettings) then
        begin
          AErrorMessage := 'must be a valid number';
          Exit;
end;

        if ATargetType.Handle = TypeInfo(Single) then
          AValue := TValue.From<Single>(DoubleValue)
        else if ATargetType.Handle = TypeInfo(Extended) then
          AValue := TValue.From<Extended>(DoubleValue)
        else if ATargetType.Handle = TypeInfo(Currency) then
          AValue := TValue.From<Currency>(DoubleValue)
        else
          AValue := TValue.From<Double>(DoubleValue);

        Exit(True);
end;

    tkEnumeration:
      begin
        if ATargetType.Handle = TypeInfo(Boolean) then
        begin
          if SameText(ARawValue, 'true') or (ARawValue = '1') then
          begin
            AValue := TValue.From<Boolean>(True);
            Exit(True);
end;

          if SameText(ARawValue, 'false') or (ARawValue = '0') then
          begin
            AValue := TValue.From<Boolean>(False);
            Exit(True);
end;

          AErrorMessage := 'must be a valid boolean';
          Exit;
end;

        EnumValue := GetEnumValue(ATargetType.Handle, ARawValue);

        if EnumValue < 0 then
        begin
          AErrorMessage := 'must be a valid enum value';
          Exit;
end;

        AValue := TValue.FromOrdinal(ATargetType.Handle, EnumValue);
        Exit(True);
end;
end;

  AErrorMessage := 'unsupported scalar parameter type';
end;
end.
