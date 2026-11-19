unit Options.Port;

interface

uses
  System.Rtti;

type
  TOptionsLoader<T> = reference to function: T;
  TOptionsLoaderFromFile<T> = reference to function(const AFilePath: string): T;

  TOptionsSection = class abstract
  protected
    function GetSectionName: string; virtual; abstract;
  public
    property SectionName: string read GetSectionName;
  end;

  IOptions<T: class> = interface
    ['{9761434b-af2e-44ff-9996-a778beae920a}']
    function GetValue: T;

    property Value: T read GetValue;
  end;

  TOptions<T: class> = class(TInterfacedObject, IOptions<T>)
  private
    FValue: T;
  protected
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    constructor Create(const Value: T);
    destructor Destroy; override;

    class function From(const Value: T): TOptions<T>; static;

    function GetValue: T;
    property Value: T read GetValue;
  end;

implementation

function TOptions<T>._AddRef: Integer;
begin
  Result := -1;
end;

function TOptions<T>._Release: Integer;
begin
  Result := -1;
end;

constructor TOptions<T>.Create(const Value: T);
begin
  inherited Create;
  FValue := Value;
end;

destructor TOptions<T>.Destroy;
var
  Value: TValue;
begin
  Value := TValue.From<T>(FValue);

  if (not Value.IsEmpty) and (Value.Kind = tkClass) then
    Value.AsObject.Free;

  inherited;
end;

class function TOptions<T>.From(const Value: T): TOptions<T>;
begin
  Result := TOptions<T>.Create(Value);
end;

function TOptions<T>.GetValue: T;
begin
  Result := FValue;
end;

end.
