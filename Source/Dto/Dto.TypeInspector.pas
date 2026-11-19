unit Dto.TypeInspector;

interface

uses
  System.Rtti,
  System.TypInfo;

type
  TDtoTypeInspector = class
  public
    class function IsStringType(const APropertyInfo: TRttiProperty): Boolean; static;
    class function IsBooleanType(const APropertyInfo: TRttiProperty): Boolean; static;
    class function IsIntegerType(const APropertyInfo: TRttiProperty): Boolean; static;
    class function IsInt64Type(const APropertyInfo: TRttiProperty): Boolean; static;
    class function IsCurrencyType(const APropertyInfo: TRttiProperty): Boolean; static;
    class function IsDateOnlyType(const APropertyInfo: TRttiProperty): Boolean; static;
    class function IsDateLikeType(const APropertyInfo: TRttiProperty): Boolean; static;
    class function IsNumericType(const APropertyInfo: TRttiProperty): Boolean; static;
    class function GetDateTypeMessage(const APropertyInfo: TRttiProperty): string; static;
  end;

implementation

uses
  System.SysUtils,
  RttiAttribute.Helpers,
  Dto.Attributes;

class function TDtoTypeInspector.IsStringType(const APropertyInfo: TRttiProperty): Boolean;
begin
  Result := APropertyInfo.PropertyType.TypeKind in [
    tkString,
    tkLString,
    tkWString,
    tkUString
  ];
end;

class function TDtoTypeInspector.IsBooleanType(const APropertyInfo: TRttiProperty): Boolean;
begin
  Result :=
    (APropertyInfo.PropertyType.TypeKind = tkEnumeration) and
    (APropertyInfo.PropertyType.Handle = TypeInfo(Boolean));
end;

class function TDtoTypeInspector.IsIntegerType(const APropertyInfo: TRttiProperty): Boolean;
begin
  Result := APropertyInfo.PropertyType.TypeKind = tkInteger;
end;

class function TDtoTypeInspector.IsInt64Type(const APropertyInfo: TRttiProperty): Boolean;
begin
  Result := APropertyInfo.PropertyType.TypeKind = tkInt64;
end;

class function TDtoTypeInspector.IsCurrencyType(const APropertyInfo: TRttiProperty): Boolean;
begin
  Result := APropertyInfo.PropertyType.Handle = TypeInfo(Currency);
end;

class function TDtoTypeInspector.IsDateOnlyType(const APropertyInfo: TRttiProperty): Boolean;
begin
  Result :=
    TRttiAttributeHelpers.HasAttribute<IsDateAttribute>(APropertyInfo) or
    (APropertyInfo.PropertyType.Handle = TypeInfo(TDate));
end;

class function TDtoTypeInspector.IsDateLikeType(const APropertyInfo: TRttiProperty): Boolean;
begin
  Result :=
    (APropertyInfo.PropertyType.TypeKind = tkFloat) and
    (
      TRttiAttributeHelpers.HasAttribute<IsDateAttribute>(APropertyInfo) or
      TRttiAttributeHelpers.HasAttribute<IsDateTimeAttribute>(APropertyInfo) or
      (APropertyInfo.PropertyType.Handle = TypeInfo(TDate)) or
      (APropertyInfo.PropertyType.Handle = TypeInfo(TTime)) or
      (APropertyInfo.PropertyType.Handle = TypeInfo(TDateTime))
    );
end;

class function TDtoTypeInspector.IsNumericType(const APropertyInfo: TRttiProperty): Boolean;
begin
  Result :=
    IsIntegerType(APropertyInfo) or
    IsInt64Type(APropertyInfo) or
    IsCurrencyType(APropertyInfo) or
    (
      (APropertyInfo.PropertyType.TypeKind = tkFloat) and
      not IsDateLikeType(APropertyInfo)
    );
end;

class function TDtoTypeInspector.GetDateTypeMessage(const APropertyInfo: TRttiProperty): string;
begin
  if IsDateOnlyType(APropertyInfo) then
    Exit('must be a date');

  Result := 'must be a datetime';
end;

end.
