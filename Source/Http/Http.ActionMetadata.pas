unit Http.ActionMetadata;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  Http.Parameter.Binding,
  Http.ParameterDescriptor;

type
  /// <summary>
  /// Aggregates the metadata needed to invoke a controller action.
  /// </summary>
  /// <remarks>
  /// This object is an intermediate result produced while scanning a controller method. The route
  /// scanner copies its parameter descriptors into TRouteDescriptor so the router can bind arguments
  /// efficiently at request time.
  /// </remarks>
  TActionMetadata = class
  private
    FMethod: TRttiMethod;
    FParameters: TArray<TParameterDescriptor>;
  public
    /// <summary>
    /// Creates action metadata for a controller method.
    /// </summary>
    /// <param name="AMethod">RTTI method metadata for the controller action.</param>
    /// <param name="AParameters">Binding metadata generated for every action parameter.</param>
    constructor Create(const AMethod: TRttiMethod; const AParameters: TArray<TParameterDescriptor>);

    /// <summary>
    /// RTTI method metadata of the controller action.
    /// </summary>
    property MethodInfo: TRttiMethod read FMethod;

    /// <summary>
    /// Parameter binding descriptors associated with MethodInfo.
    /// </summary>
    property Parameters: TArray<TParameterDescriptor> read FParameters;
  end;

  /// <summary>
  /// Builds action metadata from RTTI by reading binding attributes on method parameters.
  /// </summary>
  TActionMetadataFactory = class
  private
    /// <summary>
    /// Reads the binding attribute assigned to a parameter and returns the source to bind from.
    /// </summary>
    /// <param name="AParameter">RTTI parameter metadata to inspect.</param>
    /// <param name="ASourceName">Optional external name declared by the binding attribute.</param>
    function GetParameterSource(const AParameter: TRttiParameter; out ASourceName: string): TParameterSource;
  public
    /// <summary>
    /// Creates metadata for a controller action and validates that every parameter has a binding attribute.
    /// </summary>
    /// <param name="AMethodInfo">RTTI method metadata for the controller action.</param>
    function CreateMetadata(const AMethodInfo: TRttiMethod): TActionMetadata;
  end;

implementation

uses
  AppExceptions,
  Http.Parameter.Attributes;

constructor TActionMetadata.Create(const AMethod: TRttiMethod; const AParameters: TArray<TParameterDescriptor>);
begin
  inherited Create;
  FMethod := AMethod;
  FParameters := AParameters;
end;

function TActionMetadataFactory.GetParameterSource(const AParameter: TRttiParameter; out ASourceName: string): TParameterSource;
begin
  Result := psUnknown;
  ASourceName := '';

  for var Attribute in AParameter.GetAttributes do
  begin
    if Attribute is FromContextAttribute then
      Exit(psContext);

    if Attribute is FromRouteAttribute then
    begin
      ASourceName := FromRouteAttribute(Attribute).Name;
      Exit(psRoute);
    end;

    if Attribute is FromCookieAttribute then
    begin
      ASourceName := FromCookieAttribute(Attribute).Name;
      Exit(psCookie);
    end;

    if Attribute is FromQueryAttribute then
    begin
      ASourceName := FromQueryAttribute(Attribute).Name;
      Exit(psQuery);
    end;

    if Attribute is FromHeaderAttribute then
    begin
      ASourceName := FromHeaderAttribute(Attribute).Name;
      Exit(psHeader);
    end;

    if Attribute is FromBodyAttribute then
      Exit(psBody);
  end;
end;

function TActionMetadataFactory.CreateMetadata(const AMethodInfo: TRttiMethod): TActionMetadata;
var
  Descriptors: TArray<TParameterDescriptor>;
  SourceName: string;
begin
  var RttiParams := AMethodInfo.GetParameters;
  SetLength(Descriptors, Length(RttiParams));

  for var Index := 0 to High(RttiParams) do
  begin
    var Source := GetParameterSource(RttiParams[Index], SourceName);

    if Source = psUnknown then
      raise EInvalidAttributeException.CreateFmt(
        'Parameter "%s" in method "%s" must have a binding attribute.',
        [RttiParams[Index].Name, AMethodInfo.Name]
      );

    if SourceName = '' then
      SourceName := RttiParams[Index].Name;

    Descriptors[Index].Name := RttiParams[Index].Name;
    Descriptors[Index].Source := Source;
    Descriptors[Index].SourceName := SourceName;
    Descriptors[Index].ParameterType := RttiParams[Index].ParamType.Handle;
  end;

  Result := TActionMetadata.Create(AMethodInfo, Descriptors);
end;

end.
