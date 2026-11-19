unit Http.BodyBinder;

interface

uses
  System.Rtti,
  Http.BodyBinder.Port,
  Dto.Binder.Port;

type
  TBodyBinder = class(TInterfacedObject, IBodyBinder)
  private
    FDtoBinder: IDtoBinder;
  public
    constructor Create(const ADtoBinder: IDtoBinder);

    function Execute(const ARawBody: string; const ATargetType: TRttiType): TObject;
  end;

implementation

uses
  AppExceptions,
  HttpExceptions;

constructor TBodyBinder.Create(const ADtoBinder: IDtoBinder);
begin
  inherited Create;

  if ADtoBinder = nil then
    raise EMissingDependencyException.Create('DTO binder is required.');

  FDtoBinder := ADtoBinder;
end;

function TBodyBinder.Execute(const ARawBody: string; const ATargetType: TRttiType): TObject;
begin
  if not (ATargetType is TRttiInstanceType) then
    raise EBadRequestException.Create('Body parameter must be a class DTO that implements IDto.');

  FDtoBinder.ParseDto(
    ARawBody,
    TRttiInstanceType(ATargetType).MetaclassType,
    Result
  );
end;

end.
