unit Json.Helpers;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.JSON,
  System.Rtti,
  System.TypInfo,
  System.DateUtils,
  System.Variants;

type
  TJsonHelpers = class
  public
    { Public serialization entry points }
    class function ToJson<T>(const Value: T): TJSONValue; overload; static;
    class function ToJson<T>(const Value: T; const AOmitEmpty: Boolean): TJSONValue; overload; static;
    class function ToJson(const Value: TObject): TJSONValue; overload; static;
    class function ToJson(const Value: TObject; const AOmitEmpty: Boolean): TJSONValue; overload; static;

    class function ToString<T>(const Value: T): string; overload; static;
    class function ToString<T>(const Value: T; const AOmitEmpty: Boolean): string; overload; static;
    class function ToString(const Value: TObject): string; overload; static;
    class function ToString(const Value: TObject; const AOmitEmpty: Boolean): string; overload; static;

    { Public deserialization entry points }
    class function ToValue<T>(const Json: TJSONValue): T; overload; static;
    class function ToValue<T>(const Json: string): T; overload; static;

    class function ToRecord<T: record>(const Json: TJSONValue): T; overload; static;
    class function ToRecord<T: record>(const Json: string): T; overload; static;

    class function ToObject<T: class, constructor>(const Json: TJSONValue): T; overload; static;
    class function ToObject<T: class, constructor>(const Json: string): T; overload; static;

    class function ToArray<T>(const Json: TJSONValue): TArray<T>; overload; static;
    class function ToArray<T>(const Json: string): TArray<T>; overload; static;

    class function IsArray<T>: Boolean; static;
    class function IsObject<T>: Boolean; static;
    class function IsRecord<T>: Boolean; static;

  private
    { Shared low-level utilities }
    class function InvariantFormatSettings: TFormatSettings; static;
    class function DefaultValue(const RttiType: TRttiType): TValue; static;
    class function DefaultObjectValue(const RttiType: TRttiType): TValue; static;
    class function AreCompatibleArrayElementKinds(const ElementType: TRttiType): Boolean; static;
    class function IsInterfaceGeneratedProperty(const Prop: TRttiProperty): Boolean; static;
    class function IsEmptyJsonValue(const Value: TJSONValue): Boolean; static;

    { Core serialization pipeline }
    class function TValueToJson(const Value: TValue; const AOmitEmpty: Boolean = False): TJSONValue; static;
    class function RecordValueToJsonObject(const Value: TValue; const AOmitEmpty: Boolean = False): TJSONObject; static;
    class function ObjectToJsonObject(const Obj: TObject; const AOmitEmpty: Boolean = False): TJSONObject; static;

    { Core deserialization pipeline }
    class function JsonToTValue(const RttiType: TRttiType; const Json: TJSONValue): TValue; static;
    class function JsonObjectToRecordValue(const RttiType: TRttiType; const JsonObject: TJSONObject): TValue; static;
    class function JsonObjectToObjectValue(const RttiType: TRttiType; const JsonObject: TJSONObject): TValue; static;
    class function JsonArrayToDynamicArrayValue(const RttiType: TRttiType; const JsonArray: TJSONArray): TValue; static;

    class function GetJsonPropertyName(const Prop: TRttiProperty): string; static;
    class function GetJsonFieldName(const Field: TRttiField): string; static;
  end;

implementation

uses
  System.NetEncoding,
  System.TimeSpan,
  AppExceptions,
  Dto.Attributes;

{ ----------------------------------------------------------------------------- }
{ Shared low-level utilities                                                    }
{ ----------------------------------------------------------------------------- }

class function TJsonHelpers.IsInterfaceGeneratedProperty(const Prop: TRttiProperty): Boolean;
begin
  Result := False;

  if (Prop = nil) or (Prop.Parent = nil) then
    Exit;

  if Prop.Parent.TypeKind = tkInterface then
    Exit(True);

  Result := Prop.Parent.Handle = TypeInfo(TInterfacedObject);
end;

class function TJsonHelpers.InvariantFormatSettings: TFormatSettings;
begin
  Result := TFormatSettings.Create;
  Result.DecimalSeparator := '.';
  Result.DateSeparator := '-';
  Result.TimeSeparator := ':';
end;

class function TJsonHelpers.DefaultValue(const RttiType: TRttiType): TValue;
var
  Buffer: Pointer;
begin
  GetMem(Buffer, RttiType.TypeSize);
  try
    FillChar(Buffer^, RttiType.TypeSize, 0);
    TValue.Make(Buffer, RttiType.Handle, Result);
  finally
    FreeMem(Buffer);
  end;
end;

class function TJsonHelpers.DefaultObjectValue(const RttiType: TRttiType): TValue;
var
  InstanceType: TRttiInstanceType;
  Instance: TObject;
begin
  if (RttiType = nil) or not (RttiType is TRttiInstanceType) then
    raise EMetadataException.Create('RttiType must be a class type.');

  InstanceType := TRttiInstanceType(RttiType);
  Instance := InstanceType.MetaclassType.Create;
  Result := Instance;
end;

class function TJsonHelpers.AreCompatibleArrayElementKinds(const ElementType: TRttiType): Boolean;
begin
  if ElementType = nil then
    Exit(False);

  case ElementType.TypeKind of
    tkInteger,
    tkInt64,
    tkFloat,
    tkString,
    tkLString,
    tkWString,
    tkUString,
    tkChar,
    tkWChar,
    tkEnumeration,
    tkRecord,
    tkClass,
    tkDynArray:
      Exit(True);
  else
    Exit(False);
  end;
end;

class function TJsonHelpers.IsEmptyJsonValue(const Value: TJSONValue): Boolean;
begin
  Result := True;

  if Value = nil then
    Exit;

  if Value is TJSONNull then
    Exit;

  if Value is TJSONString then
    Exit(TJSONString(Value).Value.Trim.IsEmpty);

  if Value is TJSONObject then
    Exit(TJSONObject(Value).Count = 0);

  if Value is TJSONArray then
    Exit(TJSONArray(Value).Count = 0);

  Result := False;
end;

{ ----------------------------------------------------------------------------- }
{ Public serialization entry points                                             }
{ ----------------------------------------------------------------------------- }

class function TJsonHelpers.ToJson<T>(const Value: T): TJSONValue;
begin
  Result := ToJson<T>(Value, False);
end;

class function TJsonHelpers.ToJson<T>(const Value: T; const AOmitEmpty: Boolean): TJSONValue;
var
  TypedValue: TValue;
begin
  TypedValue := TValue.From<T>(Value);

  if TypedValue.Kind = tkClass then
    Exit(ToJson(TypedValue.AsObject, AOmitEmpty));

  Result := TValueToJson(TypedValue, AOmitEmpty);
end;

class function TJsonHelpers.ToJson(const Value: TObject): TJSONValue;
begin
  Result := ToJson(Value, False);
end;

class function TJsonHelpers.ToJson(const Value: TObject; const AOmitEmpty: Boolean): TJSONValue;
begin
  if Value = nil then
    Exit(TJSONNull.Create);

  Result := ObjectToJsonObject(Value, AOmitEmpty);
end;

class function TJsonHelpers.ToString<T>(const Value: T): string;
begin
  Result := ToString<T>(Value, False);
end;

class function TJsonHelpers.ToString<T>(const Value: T; const AOmitEmpty: Boolean): string;
var
  JsonValue: TJSONValue;
begin
  JsonValue := ToJson<T>(Value, AOmitEmpty);
  try
    Result := JsonValue.ToJSON;
  finally
    JsonValue.Free;
  end;
end;

class function TJsonHelpers.ToString(const Value: TObject): string;
begin
  Result := ToString(Value, False);
end;

class function TJsonHelpers.ToString(const Value: TObject; const AOmitEmpty: Boolean): string;
var
  JsonValue: TJSONValue;
begin
  if Value = nil then
    Exit('null');

  JsonValue := ToJson(Value, AOmitEmpty);
  try
    Result := JsonValue.ToJSON;
  finally
    JsonValue.Free;
  end;
end;

{ ----------------------------------------------------------------------------- }
{ Public deserialization entry points                                           }
{ ----------------------------------------------------------------------------- }

class function TJsonHelpers.ToValue<T>(const Json: TJSONValue): T;
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  TypedValue: TValue;
begin
  RttiType := RttiContext.GetType(TypeInfo(T));

  if RttiType = nil then
    raise EMetadataException.Create('T RTTI could not be resolved.');

  case RttiType.TypeKind of
    tkRecord:
      begin
        if not (Json is TJSONObject) then
          raise EMetadataException.CreateFmt('Expected JSON object for record "%s".', [RttiType.Name]);

        TypedValue := JsonObjectToRecordValue(RttiType, TJSONObject(Json));
      end;

    tkClass:
      begin
        if (Json = nil) or (Json is TJSONNull) then
          TypedValue := DefaultObjectValue(RttiType)
        else
        begin
          if not (Json is TJSONObject) then
            raise EMetadataException.CreateFmt('Expected JSON object for class "%s".', [RttiType.Name]);

          TypedValue := JsonObjectToObjectValue(RttiType, TJSONObject(Json));
        end;
      end;

    tkDynArray:
      begin
        if not (Json is TJSONArray) then
          raise EMetadataException.CreateFmt('Expected JSON array for dynamic array "%s".', [RttiType.Name]);

        TypedValue := JsonArrayToDynamicArrayValue(RttiType, TJSONArray(Json));
      end;
  else
    TypedValue := JsonToTValue(RttiType, Json);
  end;

  Result := TypedValue.AsType<T>;
end;

class function TJsonHelpers.ToValue<T>(const Json: string): T;
var
  JsonValue: TJSONValue;
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  DefaultTypedValue: TValue;
begin
  RttiType := RttiContext.GetType(TypeInfo(T));

  if RttiType = nil then
    raise EMetadataException.Create('T RTTI could not be resolved.');

  if Json.Trim = '' then
  begin
    if RttiType.TypeKind = tkClass then
      DefaultTypedValue := DefaultObjectValue(RttiType)
    else
      DefaultTypedValue := DefaultValue(RttiType);

    Exit(DefaultTypedValue.AsType<T>);
  end;

  JsonValue := TJSONObject.ParseJSONValue(Json);
  if JsonValue = nil then
    raise EMetadataException.Create('Invalid JSON.');

  try
    Result := ToValue<T>(JsonValue);
  finally
    JsonValue.Free;
  end;
end;

class function TJsonHelpers.ToRecord<T>(const Json: TJSONValue): T;
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  RecordValue: TValue;
begin
  if not (Json is TJSONObject) then
    raise EMetadataException.Create('Expected a JSON object.');

  RttiType := RttiContext.GetType(TypeInfo(T));
  if (RttiType = nil) or (RttiType.TypeKind <> tkRecord) then
    raise EMetadataException.Create('T must be a record.');

  RecordValue := JsonObjectToRecordValue(RttiType, TJSONObject(Json));
  Result := RecordValue.AsType<T>;
end;

class function TJsonHelpers.ToRecord<T>(const Json: string): T;
var
  JsonValue: TJSONValue;
begin
  JsonValue := TJSONObject.ParseJSONValue(Json);
  if JsonValue = nil then
    raise EMetadataException.Create('Invalid JSON.');

  try
    Result := ToRecord<T>(JsonValue);
  finally
    JsonValue.Free;
  end;
end;

class function TJsonHelpers.ToObject<T>(const Json: TJSONValue): T;
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  ObjectValue: TValue;
begin
  RttiType := RttiContext.GetType(TypeInfo(T));
  if (RttiType = nil) or not (RttiType is TRttiInstanceType) then
    raise EMetadataException.Create('T must be a class.');

  if (Json = nil) or (Json is TJSONNull) then
  begin
    ObjectValue := DefaultObjectValue(RttiType);
    Exit(ObjectValue.AsType<T>);
  end;

  if (Json is TJSONString) and (Json.Value.Trim = '') then
  begin
    ObjectValue := DefaultObjectValue(RttiType);
    Exit(ObjectValue.AsType<T>);
  end;

  if not (Json is TJSONObject) then
    raise EMetadataException.Create('Expected a JSON object.');

  ObjectValue := JsonObjectToObjectValue(RttiType, TJSONObject(Json));
  Result := ObjectValue.AsType<T>;
end;

class function TJsonHelpers.ToObject<T>(const Json: string): T;
var
  JsonValue: TJSONValue;
begin
  if Json.Trim = '' then
    Exit(T.Create);

  JsonValue := TJSONObject.ParseJSONValue(Json);
  if JsonValue = nil then
    raise EMetadataException.Create('Invalid JSON.');

  try
    Result := ToObject<T>(JsonValue);
  finally
    JsonValue.Free;
  end;
end;

class function TJsonHelpers.ToArray<T>(const Json: TJSONValue): TArray<T>;
var
  RttiContext: TRttiContext;
  ArrayRttiType: TRttiType;
  ArrayValue: TValue;
begin
  if not (Json is TJSONArray) then
    raise EMetadataException.Create('Expected a JSON array.');

  ArrayRttiType := RttiContext.GetType(TypeInfo(TArray<T>));
  if (ArrayRttiType = nil) or (ArrayRttiType.TypeKind <> tkDynArray) then
    raise EMetadataException.Create('TArray<T> RTTI could not be resolved.');

  ArrayValue := JsonArrayToDynamicArrayValue(ArrayRttiType, TJSONArray(Json));
  Result := ArrayValue.AsType<TArray<T>>;
end;

class function TJsonHelpers.ToArray<T>(const Json: string): TArray<T>;
var
  JsonValue: TJSONValue;
begin
  JsonValue := TJSONObject.ParseJSONValue(Json);
  if JsonValue = nil then
    raise EMetadataException.Create('Invalid JSON.');

  try
    Result := ToArray<T>(JsonValue);
  finally
    JsonValue.Free;
  end;
end;

class function TJsonHelpers.IsArray<T>: Boolean;
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
begin
  RttiType := RttiContext.GetType(TypeInfo(T));
  Result := (RttiType <> nil) and (RttiType.TypeKind = tkDynArray);
end;

class function TJsonHelpers.IsObject<T>: Boolean;
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
begin
  RttiType := RttiContext.GetType(TypeInfo(T));
  Result := (RttiType <> nil) and (RttiType.TypeKind = tkClass);
end;

class function TJsonHelpers.IsRecord<T>: Boolean;
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
begin
  RttiType := RttiContext.GetType(TypeInfo(T));
  Result := (RttiType <> nil) and (RttiType.TypeKind = tkRecord);
end;

{ ----------------------------------------------------------------------------- }
{ Core serialization pipeline                                                   }
{ ----------------------------------------------------------------------------- }

class function TJsonHelpers.RecordValueToJsonObject(const Value: TValue; const AOmitEmpty: Boolean): TJSONObject;
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  Field: TRttiField;
  Prop: TRttiProperty;
  FieldValue: TValue;
  PropValue: TValue;
  JsonMemberName: string;
  JsonMemberValue: TJSONValue;
  RecordPointer: Pointer;
begin
  Result := TJSONObject.Create;

  RttiType := RttiContext.GetType(Value.TypeInfo);
  if (RttiType = nil) or (RttiType.TypeKind <> tkRecord) then
    raise EMetadataException.Create('The supplied value is not a record.');

  RecordPointer := Value.GetReferenceToRawData;
  if RecordPointer = nil then
    raise EMetadataException.Create('Could not get a raw reference to the record.');

  for Field in RttiType.GetFields do
  begin
    if not (Field.Visibility in [mvPublic, mvPublished]) then
      Continue;

    FieldValue := Field.GetValue(RecordPointer);
    JsonMemberName := GetJsonFieldName(Field);
    JsonMemberValue := TValueToJson(FieldValue, AOmitEmpty);

    if AOmitEmpty and IsEmptyJsonValue(JsonMemberValue) then
    begin
      JsonMemberValue.Free;
      Continue;
    end;

    Result.AddPair(JsonMemberName, JsonMemberValue);
  end;

  for Prop in RttiType.GetProperties do
  begin
    if not Prop.IsReadable then
      Continue;

    if not (Prop.Visibility in [mvPublic, mvPublished]) then
      Continue;

    PropValue := Prop.GetValue(RecordPointer);
    JsonMemberName := GetJsonPropertyName(Prop);
    JsonMemberValue := TValueToJson(PropValue, AOmitEmpty);

    if AOmitEmpty and IsEmptyJsonValue(JsonMemberValue) then
    begin
      JsonMemberValue.Free;
      Continue;
    end;

    Result.AddPair(JsonMemberName, JsonMemberValue);
  end;
end;

class function TJsonHelpers.ObjectToJsonObject(const Obj: TObject; const AOmitEmpty: Boolean): TJSONObject;
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  Prop: TRttiProperty;
  Field: TRttiField;
  PropValue: TValue;
  FieldValue: TValue;
  JsonMemberName: string;
  JsonMemberValue: TJSONValue;
begin
  if Obj = nil then
    Exit(nil);

  Result := TJSONObject.Create;

  RttiType := RttiContext.GetType(Obj.ClassType);
  if RttiType = nil then
    raise EMetadataException.Create('Could not resolve RTTI for object.');

  for Field in RttiType.GetFields do
  begin
    if not (Field.Visibility in [mvPublic, mvPublished]) then
      Continue;

    FieldValue := Field.GetValue(Obj);
    JsonMemberName := GetJsonFieldName(Field);
    JsonMemberValue := TValueToJson(FieldValue, AOmitEmpty);

    if AOmitEmpty and IsEmptyJsonValue(JsonMemberValue) then
    begin
      JsonMemberValue.Free;
      Continue;
    end;
    Result.AddPair(JsonMemberName, JsonMemberValue);
  end;

  for Prop in RttiType.GetProperties do
  begin
    if IsInterfaceGeneratedProperty(Prop) then
      Continue;

    if not Prop.IsReadable then
      Continue;

    if not (Prop.Visibility in [mvPublic, mvPublished]) then
      Continue;

    PropValue := Prop.GetValue(Obj);
    JsonMemberName := GetJsonPropertyName(Prop);
    JsonMemberValue := TValueToJson(PropValue, AOmitEmpty);

    if AOmitEmpty and IsEmptyJsonValue(JsonMemberValue) then
    begin
      JsonMemberValue.Free;
      Continue;
    end;
    Result.AddPair(JsonMemberName, JsonMemberValue);
  end;
end;

class function TJsonHelpers.TValueToJson(const Value: TValue; const AOmitEmpty: Boolean): TJSONValue;
var
  JsonArray: TJSONArray;
  Index: Integer;
  VariantValue: Variant;
  VariantType: Integer;
  TimeSpanValue: TTimeSpan;
begin
  if Value.IsEmpty then
    Exit(TJSONNull.Create);

  if Value.TypeInfo = TypeInfo(TTimeSpan) then
  begin
    TimeSpanValue := Value.AsType<TTimeSpan>;
    Exit(TJSONString.Create(TimeSpanValue.ToString));
  end;

  case Value.Kind of
    tkUnknown,
    tkSet,
    tkClassRef,
    tkPointer,
    tkProcedure,
    tkMethod,
    tkInterface,
    tkArray:
      Exit(TJSONNull.Create);

    tkInteger, tkInt64:
      Exit(TJSONNumber.Create(Value.AsInt64));

    tkFloat:
      begin
        if Value.TypeInfo = TypeInfo(TDateTime) then
          Exit(TJSONString.Create(DateToISO8601(Value.AsType<TDateTime>, False)));

        if Value.TypeInfo = TypeInfo(TDate) then
          Exit(TJSONString.Create(DateToISO8601(Value.AsType<TDate>, False)));

        if Value.TypeInfo = TypeInfo(TTime) then
          Exit(TJSONString.Create(DateToISO8601(Value.AsType<TTime>, False)));

        if Value.TypeInfo = TypeInfo(Currency) then
          Exit(TJSONNumber.Create(Value.AsCurrency));

        Exit(TJSONNumber.Create(Value.AsExtended));
      end;

    tkString, tkLString, tkWString, tkUString, tkChar, tkWChar:
      Exit(TJSONString.Create(Value.AsString));

    tkEnumeration:
      begin
        if Value.TypeInfo = TypeInfo(Boolean) then
          Exit(TJSONBool.Create(Value.AsBoolean));

        Exit(TJSONString.Create(GetEnumName(Value.TypeInfo, Value.AsOrdinal)));
      end;

    tkRecord:
      Exit(RecordValueToJsonObject(Value, AOmitEmpty));

    tkDynArray:
      begin
        JsonArray := TJSONArray.Create;
        for Index := 0 to Value.GetArrayLength - 1 do
        begin
          var JsonElement := TValueToJson(Value.GetArrayElement(Index), AOmitEmpty);

          if AOmitEmpty and IsEmptyJsonValue(JsonElement) then
          begin
            JsonElement.Free;
            Continue;
          end;

          JsonArray.AddElement(JsonElement);
        end;
        Exit(JsonArray);
      end;

    tkVariant:
      begin
        VariantValue := Value.AsVariant;

        if VarIsNull(VariantValue) or VarIsEmpty(VariantValue) then
          Exit(TJSONNull.Create);

        VariantType := VarType(VariantValue) and varTypeMask;

        case VariantType of
          varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord, varInt64:
            Exit(TJSONNumber.Create(Int64(VarAsType(VariantValue, varInt64))));

          varSingle, varDouble:
            Exit(TJSONNumber.Create(Double(VarAsType(VariantValue, varDouble))));

          varCurrency:
            Exit(TJSONNumber.Create(Currency(VarAsType(VariantValue, varCurrency))));

          varBoolean:
            Exit(TJSONBool.Create(VarAsType(VariantValue, varBoolean)));

          varDate:
            Exit(TJSONString.Create(DateToISO8601(VarToDateTime(VariantValue), False)));

        else
          Exit(TJSONString.Create(VarToStr(VariantValue)));
        end;
      end;

    tkClass:
      begin
        if Value.AsObject = nil then
          Exit(TJSONNull.Create);

        Exit(ObjectToJsonObject(Value.AsObject, AOmitEmpty));
      end;
  end;

  raise EMetadataException.CreateFmt(
    'Unsupported kind "%s" for JSON serialization.',
    [GetEnumName(TypeInfo(TTypeKind), Ord(Value.Kind))]
  );
end;

{ ----------------------------------------------------------------------------- }
{ Core deserialization pipeline                                                 }
{ ----------------------------------------------------------------------------- }

class function TJsonHelpers.JsonObjectToRecordValue(const RttiType: TRttiType; const JsonObject: TJSONObject): TValue;
var
  Buffer: Pointer;
  Field: TRttiField;
  Prop: TRttiProperty;
  JsonMemberValue: TJSONValue;
begin
  GetMem(Buffer, RttiType.TypeSize);
  try
    FillChar(Buffer^, RttiType.TypeSize, 0);

    for Field in RttiType.GetFields do
    begin
      if not (Field.Visibility in [mvPublic, mvPublished]) then
        Continue;

      JsonMemberValue := JsonObject.GetValue(GetJsonFieldName(Field));
      if JsonMemberValue <> nil then
        Field.SetValue(Buffer, JsonToTValue(Field.FieldType, JsonMemberValue));
    end;

    for Prop in RttiType.GetProperties do
    begin
      if not Prop.IsWritable then
        Continue;

      if not (Prop.Visibility in [mvPublic, mvPublished]) then
        Continue;

      JsonMemberValue := JsonObject.GetValue(GetJsonPropertyName(Prop));
      if JsonMemberValue <> nil then
        Prop.SetValue(Buffer, JsonToTValue(Prop.PropertyType, JsonMemberValue));
    end;

    TValue.Make(Buffer, RttiType.Handle, Result);
  finally
    FreeMem(Buffer);
  end;
end;

class function TJsonHelpers.JsonObjectToObjectValue(const RttiType: TRttiType; const JsonObject: TJSONObject): TValue;
var
  InstanceType: TRttiInstanceType;
  Instance: TObject;
  Prop: TRttiProperty;
  Field: TRttiField;
  JsonMemberValue: TJSONValue;
  PropValue: TValue;
  FieldValue: TValue;
begin
  if not (RttiType is TRttiInstanceType) then
    raise EMetadataException.CreateFmt('Type "%s" is not a class type.', [RttiType.Name]);

  InstanceType := TRttiInstanceType(RttiType);
  Instance := InstanceType.MetaclassType.Create;
  try
    for Field in RttiType.GetFields do
    begin
      if not (Field.Visibility in [mvPublic, mvPublished]) then
        Continue;

      JsonMemberValue := JsonObject.GetValue(GetJsonFieldName(Field));
      if JsonMemberValue <> nil then
      begin
        FieldValue := JsonToTValue(Field.FieldType, JsonMemberValue);
        Field.SetValue(Instance, FieldValue);
      end;
    end;

    for Prop in RttiType.GetProperties do
    begin
      if IsInterfaceGeneratedProperty(Prop) then
        Continue;

      if not Prop.IsWritable then
        Continue;

      if not (Prop.Visibility in [mvPublic, mvPublished]) then
        Continue;

      JsonMemberValue := JsonObject.GetValue(GetJsonPropertyName(Prop));
      if JsonMemberValue <> nil then
      begin
        PropValue := JsonToTValue(Prop.PropertyType, JsonMemberValue);
        Prop.SetValue(Instance, PropValue);
      end;
    end;

    Result := Instance;
  except
    Instance.Free;
    raise;
  end;
end;

class function TJsonHelpers.JsonArrayToDynamicArrayValue(const RttiType: TRttiType; const JsonArray: TJSONArray): TValue;
var
  DynamicArrayType: TRttiDynamicArrayType;
  ElementType: TRttiType;
  ElementValues: TArray<TValue>;
  ElementIndex: Integer;
begin
  if not (RttiType is TRttiDynamicArrayType) then
    raise EMetadataException.CreateFmt(
      'Type "%s" is not a dynamic array type.',
      [RttiType.Name]
    );

  DynamicArrayType := TRttiDynamicArrayType(RttiType);
  ElementType := DynamicArrayType.ElementType;

  if not AreCompatibleArrayElementKinds(ElementType) then
    raise EMetadataException.CreateFmt(
      'Unsupported dynamic array element kind "%s" in "%s".',
      [
        GetEnumName(TypeInfo(TTypeKind), Ord(ElementType.TypeKind)),
        RttiType.Name
      ]
    );

  SetLength(ElementValues, JsonArray.Count);

  for ElementIndex := 0 to JsonArray.Count - 1 do
    ElementValues[ElementIndex] := JsonToTValue(
      ElementType,
      JsonArray.Items[ElementIndex]
    );

  Result := TValue.FromArray(RttiType.Handle, ElementValues);
end;

class function TJsonHelpers.JsonToTValue(const RttiType: TRttiType; const Json: TJSONValue): TValue;
var
  EnumValue: Integer;
  NumericText: string;
  IntValue: Int64;
  OrdinalType: TRttiOrdinalType;

  function JsonAsString(const ExpectedTypeName: string): string;
  begin
    if not (Json is TJSONString) then
      raise EMetadataException.CreateFmt(
        'Expected JSON string for "%s".',
        [ExpectedTypeName]
      );

    Result := TJSONString(Json).Value;
  end;

  function JsonAsNumberText(const ExpectedTypeName: string): string;
  begin
    if not (Json is TJSONNumber) then
      raise EMetadataException.CreateFmt(
        'Expected JSON number for "%s".',
        [ExpectedTypeName]
      );

    Result := Json.Value;
  end;

begin
  if (Json = nil) or (Json is TJSONNull) then
  begin
    if RttiType.TypeKind = tkClass then
      Exit(DefaultObjectValue(RttiType));

    Exit(DefaultValue(RttiType));
  end;

  if RttiType.Handle = TypeInfo(TTimeSpan) then
  begin
    try
      Exit(TValue.From<TTimeSpan>(
        TTimeSpan.Parse(JsonAsString(RttiType.Name))
      ));
    except
      on Error: Exception do
        raise EMetadataException.CreateFmt('Invalid TimeSpan value for "%s".', [RttiType.Name]);
    end;
  end;

  if RttiType.Handle = TypeInfo(TGUID) then
  begin
    try
      Exit(TValue.From<TGUID>(
        StringToGUID(JsonAsString(RttiType.Name))
      ));
    except
      on Error: Exception do
        raise EMetadataException.CreateFmt('Invalid GUID value for "%s".', [RttiType.Name]);
    end;
  end;

  if RttiType.Handle = TypeInfo(TBytes) then
  begin
    Exit(TValue.From<TBytes>(
      TNetEncoding.Base64.DecodeStringToBytes(JsonAsString(RttiType.Name))
    ));
  end;

  case RttiType.TypeKind of
    tkInteger, tkInt64:
      begin
        NumericText := JsonAsNumberText(RttiType.Name);

        if not TryStrToInt64(NumericText, IntValue) then
          raise EMetadataException.CreateFmt('Invalid integer value for "%s".', [RttiType.Name]);

        OrdinalType := RttiType as TRttiOrdinalType;

        if (IntValue < OrdinalType.MinValue) or
           (IntValue > OrdinalType.MaxValue) then
          raise EMetadataException.CreateFmt(
            'Integer value "%d" out of range for "%s".',
            [IntValue, RttiType.Name]
          );

        Exit(TValue.FromOrdinal(RttiType.Handle, IntValue));
      end;

    tkFloat:
      begin
        if RttiType.Handle = TypeInfo(TDateTime) then
        begin
          try
            Exit(TValue.From<TDateTime>(
              ISO8601ToDate(JsonAsString(RttiType.Name), False)
            ));
          except
            on Error: Exception do
              raise EMetadataException.CreateFmt('Invalid DateTime value for "%s".', [RttiType.Name]);
          end;
        end;

        if RttiType.Handle = TypeInfo(TDate) then
        begin
          try
            Exit(TValue.From<TDate>(
              TDate(ISO8601ToDate(JsonAsString(RttiType.Name), False))
            ));
          except
            on Error: Exception do
              raise EMetadataException.CreateFmt('Invalid Date value for "%s".', [RttiType.Name]);
          end;
        end;

        if RttiType.Handle = TypeInfo(TTime) then
        begin
          NumericText := JsonAsString(RttiType.Name);

          try
            if NumericText.Contains('T') then
              Exit(TValue.From<TTime>(
                TTime(ISO8601ToDate(NumericText, False))
              ));

            Exit(TValue.From<TTime>(
              StrToTime(NumericText, InvariantFormatSettings)
            ));
          except
            on Error: Exception do
              raise EMetadataException.CreateFmt('Invalid Time value for "%s".', [RttiType.Name]);
          end;
        end;

        NumericText := JsonAsNumberText(RttiType.Name);

        if RttiType.Handle = TypeInfo(Currency) then
        begin
          var CurrencyValue: Currency;
          if not TryStrToCurr(NumericText, CurrencyValue, InvariantFormatSettings) then
            raise EMetadataException.CreateFmt('Invalid currency value for "%s".', [RttiType.Name]);

          Exit(TValue.From<Currency>(CurrencyValue));
        end;

        if RttiType.Handle = TypeInfo(Single) then
        begin
          var SingleValue: Single;
          if not TryStrToFloat(NumericText, SingleValue, InvariantFormatSettings) then
            raise EMetadataException.CreateFmt('Invalid single value for "%s".', [RttiType.Name]);

          Exit(TValue.From<Single>(SingleValue));
        end;

        if RttiType.Handle = TypeInfo(Double) then
        begin
          var DoubleValue: Double;
          if not TryStrToFloat(NumericText, DoubleValue, InvariantFormatSettings) then
            raise EMetadataException.CreateFmt('Invalid double value for "%s".', [RttiType.Name]);

          Exit(TValue.From<Double>(DoubleValue));
        end;

        if RttiType.Handle = TypeInfo(Extended) then
        begin
          var ExtendedValue: Extended;
          if not TryStrToFloat(NumericText, ExtendedValue, InvariantFormatSettings) then
            raise EMetadataException.CreateFmt('Invalid extended value for "%s".', [RttiType.Name]);

          Exit(TValue.From<Extended>(ExtendedValue));
        end;

        raise EMetadataException.CreateFmt(
          'Unsupported float type "%s" for JSON deserialization.',
          [RttiType.Name]
        );
      end;

    tkString, tkLString, tkWString, tkUString:
      begin
        Exit(TValue.From<string>(
          JsonAsString(RttiType.Name)
        ));
      end;

    tkChar, tkWChar:
      begin
        NumericText := JsonAsString(RttiType.Name);

        if NumericText = '' then
          Exit(TValue.From<Char>(#0));

        if NumericText.Length <> 1 then
          raise EMetadataException.CreateFmt(
            'Expected single character for "%s", got "%s".',
            [RttiType.Name, NumericText]
          );

        Exit(TValue.From<Char>(NumericText[1]));
      end;

    tkEnumeration:
      begin
        if RttiType.Handle = TypeInfo(Boolean) then
        begin
          if Json is TJSONTrue then
            Exit(TValue.From<Boolean>(True));

          if Json is TJSONFalse then
            Exit(TValue.From<Boolean>(False));

          if Json is TJSONString then
          begin
            if SameText(TJSONString(Json).Value, 'true') then
              Exit(TValue.From<Boolean>(True));

            if SameText(TJSONString(Json).Value, 'false') then
              Exit(TValue.From<Boolean>(False));
          end;

          raise EMetadataException.CreateFmt(
            'Invalid boolean value "%s" for "%s".',
            [Json.Value, RttiType.Name]
          );
        end;

        if not (Json is TJSONString) then
          raise EMetadataException.CreateFmt(
            'Expected JSON string for enum "%s".',
            [RttiType.Name]
          );

        EnumValue := GetEnumValue(RttiType.Handle, TJSONString(Json).Value);

        if EnumValue < 0 then
          raise EMetadataException.CreateFmt(
            'Invalid enum value "%s" for "%s".',
            [TJSONString(Json).Value, RttiType.Name]
          );

        Exit(TValue.FromOrdinal(RttiType.Handle, EnumValue));
      end;

    tkRecord:
      begin
        if not (Json is TJSONObject) then
          raise EMetadataException.CreateFmt(
            'Expected JSON object for record "%s".',
            [RttiType.Name]
          );

        Exit(JsonObjectToRecordValue(RttiType, TJSONObject(Json)));
      end;

    tkDynArray:
      begin
        if not (Json is TJSONArray) then
          raise EMetadataException.CreateFmt(
            'Expected JSON array for dynamic array "%s".',
            [RttiType.Name]
          );

        Exit(JsonArrayToDynamicArrayValue(RttiType, TJSONArray(Json)));
      end;

    tkClass:
      begin
        if (Json is TJSONString) and (TJSONString(Json).Value.Trim = '') then
          Exit(DefaultObjectValue(RttiType));

        if not (Json is TJSONObject) then
          raise EMetadataException.CreateFmt(
            'Expected JSON object for class "%s".',
            [RttiType.Name]
          );

        Exit(JsonObjectToObjectValue(RttiType, TJSONObject(Json)));
      end;
  end;

  raise EMetadataException.CreateFmt(
    'Unsupported kind "%s" for JSON deserialization.',
    [GetEnumName(TypeInfo(TTypeKind), Ord(RttiType.TypeKind))]
  );
end;

class function TJsonHelpers.GetJsonPropertyName(const Prop: TRttiProperty): string;
var
  Attribute: TCustomAttribute;
  JsonName: JsonNameAttribute;
begin
  Result := Prop.Name;

  for Attribute in Prop.GetAttributes do
  begin
    if Attribute is JsonNameAttribute then
    begin
      JsonName := JsonNameAttribute(Attribute);

      if not JsonName.Name.Trim.IsEmpty then
        Exit(JsonName.Name);

      Exit(Prop.Name);
    end;
  end;
end;

class function TJsonHelpers.GetJsonFieldName(const Field: TRttiField): string;
var
  Attribute: TCustomAttribute;
  JsonName: JsonNameAttribute;
begin
  Result := Field.Name;

  for Attribute in Field.GetAttributes do
  begin
    if Attribute is JsonNameAttribute then
    begin
      JsonName := JsonNameAttribute(Attribute);

      if not JsonName.Name.Trim.IsEmpty then
        Exit(JsonName.Name);

      Exit(Field.Name);
    end;
  end;
end;

end.
