unit Dto.Metadata;

interface

uses
  System.Rtti,
  Dto.Attributes;

type
  TDtoMetadata = class
  public
    class function GetJsonFieldName(const APropertyInfo: TRttiProperty): string; static;
  end;

implementation

class function TDtoMetadata.GetJsonFieldName(const APropertyInfo: TRttiProperty): string;
begin
  Result := APropertyInfo.Name;

  for var AttributeItem in APropertyInfo.GetAttributes do
    if AttributeItem is JsonNameAttribute then
      Exit(JsonNameAttribute(AttributeItem).Name);
end;

end.
