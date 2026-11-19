unit Dto.Attributes;

interface

uses
  System.SysUtils,
  System.Variants;

type
  JsonNameAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const AName: string);
    property Name: string read FName;
  end;

  RequiredAttribute = class(TCustomAttribute);

  IsDateAttribute = class(TCustomAttribute);
  IsDateTimeAttribute = class(TCustomAttribute);
  IsNumberStringAttribute = class(TCustomAttribute);

  LengthAttribute = class(TCustomAttribute)
  private
    FMinLength: Integer;
    FMaxLength: Integer;
  public
    constructor Create(const ALength: Integer); overload;
    constructor Create(const AMinLength, AMaxLength: Integer); overload;
    property MinLength: Integer read FMinLength;
    property MaxLength: Integer read FMaxLength;
  end;

  MinAttribute = class(TCustomAttribute)
  private
    FValue: Double;
  public
    constructor Create(const AValue: Double);
    property Value: Double read FValue;
  end;

  MaxAttribute = class(TCustomAttribute)
  private
    FValue: Double;
  public
    constructor Create(const AValue: Double);
    property Value: Double read FValue;
  end;

  MinItemsAttribute = class(TCustomAttribute)
  private
    FValue: Integer;
  public
    constructor Create(const AValue: Integer);
    property Value: Integer read FValue;
  end;

  MaxItemsAttribute = class(TCustomAttribute)
  private
    FValue: Integer;
  public
    constructor Create(const AValue: Integer);
    property Value: Integer read FValue;
  end;

  IsInAttribute = class(TCustomAttribute)
  private
    FValues: TArray<Variant>;
  public
    constructor Create(const AValues: TArray<Double>); overload;
    constructor Create(const AValues: TArray<string>); overload;
    property Values: TArray<Variant> read FValues;
  end;

//  CurrenciesRuleAttribute = class(TCustomAttribute);
//  MaxOperationAmountRuleAttribute = class(TCustomAttribute);

implementation

uses
  AppExceptions,
  System.Math;

constructor JsonNameAttribute.Create(const AName: string);
var
  NormalizedName: string;
begin
  inherited Create;

  NormalizedName := AName.Trim;

  if NormalizedName.IsEmpty then
    raise EInvalidAttributeException.Create('JsonNameAttribute name cannot be empty.');

  FName := NormalizedName;
end;

constructor LengthAttribute.Create(const ALength: Integer);
begin
  inherited Create;

  if ALength <= 0 then
    raise EOutOfRangeAttributeException.Create('LengthAttribute length must be greater than zero.');

  FMinLength := ALength;
  FMaxLength := ALength;
end;

constructor LengthAttribute.Create(const AMinLength, AMaxLength: Integer);
begin
  inherited Create;

  if AMinLength < 0 then
    raise EOutOfRangeAttributeException.Create('LengthAttribute min length cannot be less than zero.');

  if AMaxLength <= 0 then
    raise EOutOfRangeAttributeException.Create('LengthAttribute max length must be greater than zero.');

  if AMinLength > AMaxLength then
    raise EInvalidAttributeException.Create('LengthAttribute min length cannot be greater than max length.');

  FMinLength := AMinLength;
  FMaxLength := AMaxLength;
end;

constructor MinAttribute.Create(const AValue: Double);
begin
  inherited Create;

  if IsNan(AValue) or IsInfinite(AValue) then
    raise EInvalidAttributeException.Create('MinAttribute value must be a finite number.');

  FValue := AValue;
end;

constructor MaxAttribute.Create(const AValue: Double);
begin
  inherited Create;

  if IsNan(AValue) or IsInfinite(AValue) then
    raise EInvalidAttributeException.Create('MaxAttribute value must be a finite number.');

  FValue := AValue;
end;

constructor MinItemsAttribute.Create(const AValue: Integer);
begin
  inherited Create;

  if AValue < 0 then
    raise EOutOfRangeAttributeException.Create('MinItemsAttribute value cannot be less than zero.');

  FValue := AValue;
end;

constructor MaxItemsAttribute.Create(const AValue: Integer);
begin
  inherited Create;

  if AValue <= 0 then
    raise EOutOfRangeAttributeException.Create('MaxItemsAttribute value must be greater than zero.');

  FValue := AValue;
end;

constructor IsInAttribute.Create(const AValues: TArray<Double>);
begin
  inherited Create;

  if Length(AValues) = 0 then
    raise EInvalidAttributeException.Create('IsInAttribute values cannot be empty.');

  SetLength(FValues, Length(AValues));

  for var Index := 0 to High(AValues) do
  begin
    if IsNan(AValues[Index]) or IsInfinite(AValues[Index]) then
      raise EInvalidAttributeException.Create(
        Format('IsInAttribute value at index %d must be a finite number.', [Index])
      );

    FValues[Index] := AValues[Index];
  end;
end;

constructor IsInAttribute.Create(const AValues: TArray<string>);
var
  NormalizedValue: string;
begin
  inherited Create;

  if Length(AValues) = 0 then
    raise EInvalidAttributeException.Create('IsInAttribute values cannot be empty.');

  SetLength(FValues, Length(AValues));

  for var Index := 0 to High(AValues) do
  begin
    NormalizedValue := AValues[Index].Trim;

    if NormalizedValue.IsEmpty then
      raise EInvalidAttributeException.Create(
        Format('IsInAttribute value at index %d cannot be empty.', [Index])
      );

    FValues[Index] := NormalizedValue;
  end;
end;

end.
