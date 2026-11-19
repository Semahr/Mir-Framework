unit RttiAttribute.Helpers;

interface

uses
  System.Rtti,
  System.Generics.Collections;

type
  TRttiAttributeHelpers = class
  public
    class function HasAttribute<T: TCustomAttribute>(const ARttiObject: TRttiObject): Boolean; static;
    class function TryGetAttribute<T: TCustomAttribute>(const ARttiObject: TRttiObject; out AAttributeValue: T): Boolean; static;
    class function GetAttributes<T: TCustomAttribute>(const ARttiObject: TRttiObject): TObjectList<T>; static;
  end;

implementation

class function TRttiAttributeHelpers.HasAttribute<T>(const ARttiObject: TRttiObject): Boolean;
var
  AttributeItem: TCustomAttribute;
begin
  if ARttiObject = nil then
    Exit(False);

  for AttributeItem in ARttiObject.GetAttributes do
    if AttributeItem is T then
      Exit(True);

  Result := False;
end;

class function TRttiAttributeHelpers.TryGetAttribute<T>(const ARttiObject: TRttiObject; out AAttributeValue: T): Boolean;
var
  AttributeItem: TCustomAttribute;
begin
  AAttributeValue := nil;

  if ARttiObject = nil then
    Exit(False);

  for AttributeItem in ARttiObject.GetAttributes do
  begin
    if AttributeItem is T then
    begin
      AAttributeValue := T(AttributeItem);
      Exit(True);
    end;
  end;

  Result := False;
end;

class function TRttiAttributeHelpers.GetAttributes<T >(const ARttiObject: TRttiObject): TObjectList<T>;
var
  AttributeItem: TCustomAttribute;
  Values: TObjectList<T>;
begin
  if ARttiObject = nil then
    Exit(nil);

  Values := TObjectList<T>.Create;
  try
    for AttributeItem in ARttiObject.GetAttributes do
    begin
      if AttributeItem is T then
        Values.Add(T(AttributeItem));
    end;

    Result := Values;
    Values := nil;
  finally
    Values.Free;
  end;
end;

end.
