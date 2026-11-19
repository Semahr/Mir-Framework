unit Dto.Binder;

interface

uses
  System.Rtti,
  System.JSON,
  Dto.Binder.Context,
  Dto.Binder.Port,
  Dto.Port;

type
  TDtoBinder = class(TInterfacedObject, IDtoBinder)
  private
    procedure BindObject(
      const AJsonObject: TJSONObject;
      const AInstance: TObject;
      var ABindingContext: TDtoBindingContext
    );

    function TryParseJsonValue(
      const AJsonValue: TJSONValue;
      const ATargetType: TRttiType;
      const APropertyPath: string;
      var ABindingContext: TDtoBindingContext;
      out AParsedValue: TValue;
      out AErrorMessage: string
    ): Boolean;

    function TryParseScalarJsonValue(
      const AJsonValue: TJSONValue;
      const ATargetType: TRttiType;
      const APropertyPath: string;
      out AParsedValue: TValue;
      out AErrorMessage: string
    ): Boolean;

    function TryParseJsonArray(
      const AJsonArray: TJSONArray;
      const ATargetType: TRttiType;
      const APropertyPath: string;
      var ABindingContext: TDtoBindingContext;
      out AParsedValue: TValue;
      out AErrorMessage: string
    ): Boolean;

    function TryParseJsonObject(
      const AJsonObject: TJSONObject;
      const ATargetType: TRttiType;
      const APropertyPath: string;
      var ABindingContext: TDtoBindingContext;
      out AParsedValue: TValue;
      out AErrorMessage: string
    ): Boolean;
  public
    constructor Create;

    procedure ParseDto(
      const ARawBody: string;
      const ADtoClass: TClass;
      out ADto: TObject
    ); overload;

    function ParseDto<T: IDto>(const ARawBody: string): T; overload;
  end;

implementation

uses
  System.SysUtils,
  System.TypInfo,
  AppExceptions,
  HttpExceptions,
  Dto.Metadata,
  Dto.Attributes,
  Dto.Validation.Context,
  Dto.TypeInspector,
  Dto.Validation.RequiredValidator,
  Dto.Validation.StringValidator,
  Dto.Validation.BooleanValidator,
  Dto.Validation.NumberValidator,
  Dto.Validation.DateValidator;

{ TDtoBinder }

constructor TDtoBinder.Create;
begin
  inherited Create;
end;

procedure TDtoBinder.BindObject(
  const AJsonObject: TJSONObject;
  const AInstance: TObject;
  var ABindingContext: TDtoBindingContext
);
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  ParsedValue: TValue;
  ErrorMessage: string;
  ErrorMessages: TArray<string>;
  PresenceErrorMessage: string;
  JsonFieldName: string;
  JsonValue: TJSONValue;
  ValidationContext: TDtoValidationContext;
begin
  if (AJsonObject = nil) or (AInstance = nil) then
    Exit;

  RttiContext := TRttiContext.Create;
  RttiType := RttiContext.GetType(AInstance.ClassType);

  for var PropertyItem in RttiType.GetProperties do
  begin
    if not PropertyItem.IsWritable then
      Continue;

    JsonFieldName := TDtoMetadata.GetJsonFieldName(PropertyItem);
    JsonValue := AJsonObject.Values[JsonFieldName];

    if not TDtoRequiredValidator.TryValidate(
      PropertyItem,
      JsonValue,
      PresenceErrorMessage
    ) then
    begin
      ABindingContext.AddError(JsonFieldName, PresenceErrorMessage);
      Continue;
    end;

    if JsonValue = nil then
      Continue;

    ValidationContext := TDtoValidationContext.Create(
      PropertyItem,
      JsonFieldName,
      JsonValue
    );
    try
      if TDtoTypeInspector.IsDateLikeType(PropertyItem) then
      begin
        if TDtoDateValidator.TryValidate(ValidationContext, ParsedValue, ErrorMessages) then
          PropertyItem.SetValue(AInstance, ParsedValue)
        else
          ABindingContext.AddErrors(JsonFieldName, ErrorMessages);
      end
      else if TDtoTypeInspector.IsBooleanType(PropertyItem) then
      begin
        if TDtoBooleanValidator.TryValidate(ValidationContext, ParsedValue, ErrorMessages) then
          PropertyItem.SetValue(AInstance, ParsedValue)
        else
          ABindingContext.AddErrors(JsonFieldName, ErrorMessages);
      end
      else if TDtoTypeInspector.IsStringType(PropertyItem) then
      begin
        if TDtoStringValidator.TryValidate(ValidationContext, ParsedValue, ErrorMessages) then
          PropertyItem.SetValue(AInstance, ParsedValue)
        else
          ABindingContext.AddErrors(JsonFieldName, ErrorMessages);
      end
      else if TDtoTypeInspector.IsNumericType(PropertyItem) then
      begin
        if TDtoNumberValidator.TryValidate(ValidationContext, ParsedValue, ErrorMessages) then
          PropertyItem.SetValue(AInstance, ParsedValue)
        else
          ABindingContext.AddErrors(JsonFieldName, ErrorMessages);
      end
      else
      begin
        if TryParseJsonValue(
          JsonValue,
          PropertyItem.PropertyType,
          JsonFieldName,
          ABindingContext,
          ParsedValue,
          ErrorMessage
        ) then
        begin
          if not ParsedValue.IsEmpty then
            PropertyItem.SetValue(AInstance, ParsedValue);
        end
        else
          ABindingContext.AddError(JsonFieldName, ErrorMessage);
      end;
    finally
      ValidationContext.Free;
    end;
  end;
end;

function TDtoBinder.TryParseJsonValue(
  const AJsonValue: TJSONValue;
  const ATargetType: TRttiType;
  const APropertyPath: string;
  var ABindingContext: TDtoBindingContext;
  out AParsedValue: TValue;
  out AErrorMessage: string
): Boolean;
begin
  Result := False;
  AParsedValue := TValue.Empty;
  AErrorMessage := '';

  if AJsonValue = nil then
  begin
    AErrorMessage := 'is required';
    Exit;
  end;

  if ATargetType = nil then
  begin
    AErrorMessage := 'has unsupported target type';
    Exit;
  end;

  case ATargetType.TypeKind of
    tkClass:
      begin
        if not (AJsonValue is TJSONObject) then
        begin
          AErrorMessage := 'must be a JSON object';
          Exit;
        end;

        Exit(TryParseJsonObject(
          TJSONObject(AJsonValue),
          ATargetType,
          APropertyPath,
          ABindingContext,
          AParsedValue,
          AErrorMessage
        ));
      end;

    tkDynArray:
      begin
        if not (AJsonValue is TJSONArray) then
        begin
          AErrorMessage := 'must be a JSON array';
          Exit;
        end;

        Exit(TryParseJsonArray(
          TJSONArray(AJsonValue),
          ATargetType,
          APropertyPath,
          ABindingContext,
          AParsedValue,
          AErrorMessage
        ));
      end;

    tkString, tkLString, tkWString, tkUString,
    tkInteger, tkInt64, tkFloat, tkEnumeration:
      begin
        Exit(TryParseScalarJsonValue(
          AJsonValue,
          ATargetType,
          APropertyPath,
          AParsedValue,
          AErrorMessage
        ));
      end;
  end;

  AErrorMessage := 'has an unsupported type for strict binding';
end;

function TDtoBinder.TryParseScalarJsonValue(
  const AJsonValue: TJSONValue;
  const ATargetType: TRttiType;
  const APropertyPath: string;
  out AParsedValue: TValue;
  out AErrorMessage: string
): Boolean;
var
  NumericText: string;
  IntegerValue: Integer;
  Int64Value: Int64;
  EnumValue: Integer;
  FormatSettings: TFormatSettings;
  CurrencyValue: Currency;
  FloatValue: Double;
begin
  Result := False;
  AParsedValue := TValue.Empty;
  AErrorMessage := '';

  if AJsonValue = nil then
  begin
    AErrorMessage := 'is required';
    Exit;
  end;

  if ATargetType = nil then
  begin
    AErrorMessage := 'has unsupported target type';
    Exit;
  end;

  FormatSettings := TFormatSettings.Create;
  FormatSettings.DecimalSeparator := '.';

  case ATargetType.TypeKind of
    tkString, tkLString, tkWString, tkUString:
      begin
        if not (AJsonValue is TJSONString) then
        begin
          AErrorMessage := 'must be a string';
          Exit;
        end;

        AParsedValue := TValue.From<string>(AJsonValue.Value);
        Exit(True);
      end;

    tkInteger:
      begin
        if not (AJsonValue is TJSONNumber) then
        begin
          AErrorMessage := 'must be an integer';
          Exit;
        end;

        if not TryStrToInt(AJsonValue.Value, IntegerValue) then
        begin
          AErrorMessage := 'must be a valid integer';
          Exit;
        end;

        AParsedValue := TValue.From<Integer>(IntegerValue);
        Exit(True);
      end;

    tkInt64:
      begin
        if not (AJsonValue is TJSONNumber) then
        begin
          AErrorMessage := 'must be an int64';
          Exit;
        end;

        if not TryStrToInt64(AJsonValue.Value, Int64Value) then
        begin
          AErrorMessage := 'must be a valid int64';
          Exit;
        end;

        AParsedValue := TValue.From<Int64>(Int64Value);
        Exit(True);
      end;

    tkFloat:
      begin
        if not (AJsonValue is TJSONNumber) then
        begin
          AErrorMessage := 'must be a number';
          Exit;
        end;

        NumericText := AJsonValue.Value;

        if ATargetType.Handle = TypeInfo(Currency) then
        begin
          if not TryStrToCurr(NumericText, CurrencyValue, FormatSettings) then
          begin
            AErrorMessage := 'must be a valid currency';
            Exit;
          end;

          AParsedValue := TValue.From<Currency>(CurrencyValue);
          Exit(True);
        end;

        if not TryStrToFloat(NumericText, FloatValue, FormatSettings) then
        begin
          AErrorMessage := 'must be a valid number';
          Exit;
        end;

        if ATargetType.Handle = TypeInfo(Double) then
          AParsedValue := TValue.From<Double>(FloatValue)
        else if ATargetType.Handle = TypeInfo(Single) then
          AParsedValue := TValue.From<Single>(FloatValue)
        else if ATargetType.Handle = TypeInfo(Extended) then
          AParsedValue := TValue.From<Extended>(FloatValue)
        else
          AParsedValue := TValue.From<Double>(FloatValue);

        Exit(True);
      end;

    tkEnumeration:
      begin
        if ATargetType.Handle = TypeInfo(Boolean) then
        begin
          if AJsonValue is TJSONBool then
          begin
            AParsedValue := TValue.From<Boolean>(SameText(AJsonValue.Value, 'true'));
            Exit(True);
          end;

          AErrorMessage := 'must be a boolean';
          Exit;
        end;

        if not (AJsonValue is TJSONString) then
        begin
          AErrorMessage := 'must be a string enum value';
          Exit;
        end;

        EnumValue := GetEnumValue(ATargetType.Handle, AJsonValue.Value);

        if EnumValue < 0 then
        begin
          AErrorMessage := 'has an invalid enum value';
          Exit;
        end;

        AParsedValue := TValue.FromOrdinal(ATargetType.Handle, EnumValue);
        Exit(True);
      end;
  end;

  AErrorMessage := 'has unsupported scalar type';
end;

function TDtoBinder.TryParseJsonObject(
  const AJsonObject: TJSONObject;
  const ATargetType: TRttiType;
  const APropertyPath: string;
  var ABindingContext: TDtoBindingContext;
  out AParsedValue: TValue;
  out AErrorMessage: string
): Boolean;
var
  InstanceType: TRttiInstanceType;
  NestedInstance: TObject;
  ErrorCountBeforeBind: Integer;
begin
  Result := False;
  AParsedValue := TValue.Empty;
  AErrorMessage := '';

  if not (ATargetType is TRttiInstanceType) then
  begin
    AErrorMessage := 'must be a class type';
    Exit;
  end;

  InstanceType := TRttiInstanceType(ATargetType);
  NestedInstance := InstanceType.MetaclassType.Create;

  try
    ErrorCountBeforeBind := ABindingContext.ErrorCount;

    BindObject(
      AJsonObject,
      NestedInstance,
      ABindingContext
    );

    if ABindingContext.ErrorCount > ErrorCountBeforeBind then
    begin
      NestedInstance.Free;
      Exit(True);
    end;

    AParsedValue := NestedInstance;
    Result := True;
  except
    NestedInstance.Free;
    raise;
  end;
end;

function TDtoBinder.TryParseJsonArray(
  const AJsonArray: TJSONArray;
  const ATargetType: TRttiType;
  const APropertyPath: string;
  var ABindingContext: TDtoBindingContext;
  out AParsedValue: TValue;
  out AErrorMessage: string
): Boolean;
var
  DynamicArrayType: TRttiDynamicArrayType;
  ElementType: TRttiType;
  ElementValues: TArray<TValue>;
  ElementJson: TJSONValue;
  ElementValue: TValue;
  ElementErrorMessage: string;
  ElementPath: string;
  ErrorCountBeforeParse: Integer;
begin
  Result := False;
  AParsedValue := TValue.Empty;
  AErrorMessage := '';

  if not (ATargetType is TRttiDynamicArrayType) then
  begin
    AErrorMessage := 'is not a dynamic array type';
    Exit;
  end;

  DynamicArrayType := TRttiDynamicArrayType(ATargetType);
  ElementType := DynamicArrayType.ElementType;

  SetLength(ElementValues, AJsonArray.Count);

  ErrorCountBeforeParse := ABindingContext.ErrorCount;

  for var Index := 0 to AJsonArray.Count - 1 do
  begin
    ElementJson := AJsonArray.Items[Index];
    ElementPath := Format('%s[%d]', [APropertyPath, Index]);

    if TryParseJsonValue(
      ElementJson,
      ElementType,
      ElementPath,
      ABindingContext,
      ElementValue,
      ElementErrorMessage
    ) then
    begin
      if not ElementValue.IsEmpty then
        ElementValues[Index] := ElementValue;
    end
    else
      ABindingContext.AddError(ElementPath, ElementErrorMessage);
  end;

  if ABindingContext.ErrorCount > ErrorCountBeforeParse then
    Exit(True);

  AParsedValue := TValue.FromArray(ATargetType.Handle, ElementValues);
  Result := True;
end;

procedure TDtoBinder.ParseDto(
  const ARawBody: string;
  const ADtoClass: TClass;
  out ADto: TObject
);
var
  RootValue: TJSONValue;
  RootObject: TJSONObject;
  BindingContext: TDtoBindingContext;
  DtoInstance: TObject;
begin
  ADto := nil;

  if ADtoClass = nil then
    raise EMissingDependencyException.Create('DTO class is required.');

  if ARawBody.Trim.IsEmpty then
    raise EBadRequestException.Create('body must be a JSON object');

  RootValue := nil;
  DtoInstance := nil;
  BindingContext := TDtoBindingContext.Create;

  try
    RootValue := TJSONObject.ParseJSONValue(ARawBody);

    if (RootValue = nil) or not (RootValue is TJSONObject) then
      raise EBadRequestException.Create('body must be a JSON object');

    RootObject := TJSONObject(RootValue);
    DtoInstance := ADtoClass.Create;

    try
      if ADtoClass.GetInterfaceEntry(IDto) = nil then
        raise EInvalidAttributeException.CreateFmt(
          'DTO class "%s" must implement IDto.',
          [ADtoClass.ClassName]
        );

      BindObject(
        RootObject,
        DtoInstance,
        BindingContext
      );

      BindingContext.RaiseIfHasErrors;
      ADto := DtoInstance;
      DtoInstance := nil;
    except
      DtoInstance.Free;
      raise;
    end;
  finally
    RootValue.Free;
    BindingContext.Release;
  end;
end;

function TDtoBinder.ParseDto<T>(const ARawBody: string): T;
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  InstanceType: TRttiInstanceType;
  DtoObject: TObject;
  Dto: IDto;
begin
  RttiContext := TRttiContext.Create;
  RttiType := RttiContext.GetType(TypeInfo(T));

  if not (RttiType is TRttiInstanceType) then
    raise EInvalidAttributeException.Create('Generic type must be a concrete class that implements IDto');

  InstanceType := TRttiInstanceType(RttiType);

  DtoObject := nil;
  ParseDto(ARawBody, InstanceType.MetaclassType, DtoObject);

  if not Supports(DtoObject, IDto, Dto) then
  begin
    DtoObject.Free;
    raise EInvalidAttributeException.CreateFmt(
      'DTO class "%s" must implement IDto.',
      [InstanceType.MetaclassType.ClassName]
    );
  end;

  Result := Dto;
end;

end.
