unit Dto.Validation.Context;

interface

uses
  System.Rtti,
  System.JSON;

type
  TDtoValidationContext = class
  private
    FPropertyInfo: TRttiProperty;
    FJsonFieldName: string;
    FJsonValue: TJSONValue;
public
    constructor Create(
      const APropertyInfo: TRttiProperty;
      const AJsonFieldName: string;
      const AJsonValue: TJSONValue
    );
property PropertyInfo: TRttiProperty read FPropertyInfo;
property JsonFieldName: string read FJsonFieldName;
property JsonValue: TJSONValue read FJsonValue;
end;

implementation

constructor TDtoValidationContext.Create(
  const APropertyInfo: TRttiProperty;
  const AJsonFieldName: string;
  const AJsonValue: TJSONValue
);
begin
  inherited Create;

  FPropertyInfo := APropertyInfo;
  FJsonFieldName := AJsonFieldName;
  FJsonValue := AJsonValue;
end;
end.
