unit Http.ControllerScanner;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  Http.Attributes,
  Http.Controller.Port,
  Http.RouteDescriptor,
  Http.Middleware.Descriptor;

type
  TControllerScanner = class
  private
    FRttiContext: TRttiContext;

    function GetControllerBasePath(const ARttiType: TRttiType): string;
    function CombinePaths(const ABasePath, AMethodPath: string): string;
    function ImplementsController(const ARttiType: TRttiType): Boolean;
    function ImplementsMiddleware(const AMiddlewareType: TClass): Boolean;
    function GetMiddlewares(const AAttributes: TArray<TCustomAttribute>): TArray<TMiddlewareDescriptor>;
    function CombineMiddlewares(
      const AControllerMiddlewares: TArray<TMiddlewareDescriptor>;
      const AActionMiddlewares: TArray<TMiddlewareDescriptor>
    ): TArray<TMiddlewareDescriptor>;
    function CombineAttributes(
      const AControllerAttributes: TArray<TCustomAttribute>;
      const AActionAttributes: TArray<TCustomAttribute>
    ): TArray<TCustomAttribute>;
  public
    constructor Create;

    function Execute(const AControllerClasses: array of TClass): TObjectList<TRouteDescriptor>;
  end;

implementation

uses
  AppExceptions,
  Http.ActionMetadata,
  Http.Middleware.Attributes,
  Http.Middleware.Port;

constructor TControllerScanner.Create;
begin
  inherited Create;
  FRttiContext := TRttiContext.Create;
end;

function TControllerScanner.GetControllerBasePath(const ARttiType: TRttiType): string;
begin
  Result := '';

  for var Attribute in ARttiType.GetAttributes do
  begin
    if Attribute is RouteAttribute then
      Exit(RouteAttribute(Attribute).Path);
  end;
end;

function TControllerScanner.CombinePaths(const ABasePath, AMethodPath: string): string;
begin
  var BasePath := ABasePath.Trim;
  var MethodPath := AMethodPath.Trim;

  if BasePath = '' then
    BasePath := '/';

  if not BasePath.StartsWith('/') then
    BasePath := '/' + BasePath;

  BasePath := BasePath.TrimRight(['/']);

  if MethodPath = '' then
    Exit(BasePath);

  if not MethodPath.StartsWith('/') then
    MethodPath := '/' + MethodPath;

  Result := BasePath + MethodPath;
end;

function TControllerScanner.ImplementsController(const ARttiType: TRttiType): Boolean;
begin
  Result := False;

  if not (ARttiType is TRttiInstanceType) then
    Exit;

  var InstanceType := TRttiInstanceType(ARttiType);

  for var InterfaceType in InstanceType.GetImplementedInterfaces do
  begin
    if InterfaceType.Handle = TypeInfo(IController) then
      Exit(True);
  end;
end;

function TControllerScanner.ImplementsMiddleware(const AMiddlewareType: TClass): Boolean;
begin
  Result := False;

  if AMiddlewareType = nil then
    Exit;

  var RttiType := FRttiContext.GetType(AMiddlewareType);

  if not (RttiType is TRttiInstanceType) then
    Exit;

  for var InterfaceType in TRttiInstanceType(RttiType).GetImplementedInterfaces do
  begin
    if InterfaceType.Handle = TypeInfo(IMiddleware) then
      Exit(True);
  end;
end;

function TControllerScanner.GetMiddlewares(const AAttributes: TArray<TCustomAttribute>): TArray<TMiddlewareDescriptor>;
var
  Middlewares: TList<TMiddlewareDescriptor>;
begin
  Middlewares := TList<TMiddlewareDescriptor>.Create;
  try
    for var Attribute in AAttributes do
    begin
      if not (Attribute is UseMiddlewareAttribute) then
        Continue;

      var MiddlewareAttribute := UseMiddlewareAttribute(Attribute);

      if not ImplementsMiddleware(MiddlewareAttribute.MiddlewareType) then
        raise EInvalidAttributeException.CreateFmt(
          'Middleware "%s" must implement IMiddleware.',
          [MiddlewareAttribute.MiddlewareType.ClassName]
        );

      Middlewares.Add(TMiddlewareDescriptor.Create(
        MiddlewareAttribute.MiddlewareType,
        MiddlewareAttribute.Order
      ));
    end;

    Result := Middlewares.ToArray;
  finally
    Middlewares.Free;
  end;
end;

function TControllerScanner.CombineMiddlewares(
  const AControllerMiddlewares: TArray<TMiddlewareDescriptor>;
  const AActionMiddlewares: TArray<TMiddlewareDescriptor>
): TArray<TMiddlewareDescriptor>;
begin
  SetLength(Result, Length(AControllerMiddlewares) + Length(AActionMiddlewares));

  for var Index := 0 to High(AControllerMiddlewares) do
    Result[Index] := AControllerMiddlewares[Index];

  for var Index := 0 to High(AActionMiddlewares) do
    Result[Length(AControllerMiddlewares) + Index] := AActionMiddlewares[Index];
end;

function TControllerScanner.CombineAttributes(
  const AControllerAttributes: TArray<TCustomAttribute>;
  const AActionAttributes: TArray<TCustomAttribute>
): TArray<TCustomAttribute>;
begin
  SetLength(Result, Length(AControllerAttributes) + Length(AActionAttributes));

  for var Index := 0 to High(AControllerAttributes) do
    Result[Index] := AControllerAttributes[Index];

  for var Index := 0 to High(AActionAttributes) do
    Result[Length(AControllerAttributes) + Index] := AActionAttributes[Index];
end;

function TControllerScanner.Execute(const AControllerClasses: array of TClass): TObjectList<TRouteDescriptor>;
begin
  Result := TObjectList<TRouteDescriptor>.Create(True);
  var MetadataFactory := TActionMetadataFactory.Create;

  try
    try
      for var ControllerClass in AControllerClasses do
      begin
        var ControllerType := FRttiContext.GetType(ControllerClass);

        if not ImplementsController(ControllerType) then
          raise EControllerException.CreateFmt(
            'Controller "%s" must implement IController.',
            [ControllerClass.ClassName]
          );

        if not (ControllerType is TRttiInstanceType) then
          Continue;

        var InstanceType := TRttiInstanceType(ControllerType);
        var BasePath := GetControllerBasePath(ControllerType);
        var ControllerAttributes := ControllerType.GetAttributes;
        var ControllerMiddlewares := GetMiddlewares(ControllerAttributes);

        for var MethodInfo in ControllerType.GetMethods do
        begin
          for var Attribute in MethodInfo.GetAttributes do
          begin
            if Attribute is HttpMethodAttribute then
            begin
              var HttpAttribute := HttpMethodAttribute(Attribute);
              var FullPath := CombinePaths(BasePath, HttpAttribute.Path);
              var Metadata := MetadataFactory.CreateMetadata(MethodInfo);
              var ActionAttributes := MethodInfo.GetAttributes;
              var RouteMiddlewares := CombineMiddlewares(ControllerMiddlewares, GetMiddlewares(ActionAttributes));
              var RouteAttributes := CombineAttributes(ControllerAttributes, ActionAttributes);

              try
                Result.Add(
                  TRouteDescriptor.Create(
                    HttpAttribute.Method,
                    FullPath,
                    ControllerClass,
                    MethodInfo.Name,
                    Metadata.Parameters,
                    RouteMiddlewares,
                    RouteAttributes,
                    ActionAttributes,
                    ControllerAttributes
                  )
                );
              finally
                Metadata.Free;
              end;
            end;
          end;
        end;
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    MetadataFactory.Free;
  end;
end;

end.
