program HttpContextMetadataTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Rtti,
  Http.RouteDescriptor,
  Http.Context;

type
  PolicyAttribute = class(TCustomAttribute);
  ProtectedAttribute = class(PolicyAttribute);
  PublicAttribute = class(PolicyAttribute);
  OtherAttribute = class(TCustomAttribute);

  TrackedPolicyAttribute = class(PolicyAttribute)
  public
    class var Destroyed: Boolean;
    destructor Destroy; override;
  end;

  [TrackedPolicy]
  TAttributedController = class
  end;

destructor TrackedPolicyAttribute.Destroy;
begin
  Destroyed := True;
  inherited;
end;

procedure Check(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure TestRttiLifetime;
var
  RttiContext: TRttiContext;
  Attributes: TArray<TCustomAttribute>;
  Route: TRouteDescriptor;
  Context: TContext;
  Attribute: PolicyAttribute;
begin
  Route := nil;
  TrackedPolicyAttribute.Destroyed := False;
  try
    RttiContext := TRttiContext.Create;
    try
      Attributes := RttiContext.GetType(TAttributedController).GetAttributes;
      Check(Length(Attributes) = 1, 'RTTI must expose the controller attribute');
      Route := TRouteDescriptor.Create('GET', '/', TAttributedController, '',
        nil, nil, Attributes, nil, Attributes);
    finally
      RttiContext.Free;
    end;

    // Simulate releasing the scanner before constructing the request context.
    Check(not TrackedPolicyAttribute.Destroyed, 'Route must retain RTTI attributes after scanner release');
    Context := TContext.Create(nil, nil, Route.ActionAttributes, Route.ControllerAttributes);
    try
      Check(Context.TryGetAttribute<PolicyAttribute>(Attribute), 'RTTI lookup must survive scanner release');
      Check(Attribute = Attributes[0], 'Lookup must return the original RTTI instance');
    finally
      Context.Free;
    end;
  finally
    Route.Free;
  end;
end;

procedure RunTests;
var
  Context: TContext;
  ActionPolicy: ProtectedAttribute;
  ControllerPolicy: PublicAttribute;
  Attribute: PolicyAttribute;
  Other: OtherAttribute;
begin
  ActionPolicy := ProtectedAttribute.Create;
  ControllerPolicy := PublicAttribute.Create;
  try
    Context := TContext.Create(nil, nil,
      TArray<TCustomAttribute>.Create(ActionPolicy),
      TArray<TCustomAttribute>.Create(ControllerPolicy));
    try
      Check(Context.TryGetAttribute<PolicyAttribute>(Attribute), 'Base type must match descendants');
      Check(Attribute = ActionPolicy, 'Action must override controller');
      Check(not Context.TryGetAttribute<OtherAttribute>(Other), 'Unrelated type must not match');
      Check(Other = nil, 'Missing attribute must return nil');
    finally
      Context.Free;
    end;

    Context := TContext.Create(nil, nil, nil,
      TArray<TCustomAttribute>.Create(ControllerPolicy));
    try
      Check(Context.TryGetAttribute<PolicyAttribute>(Attribute), 'Controller fallback must match');
      Check(Attribute = ControllerPolicy, 'Controller attribute must be returned');
    finally
      Context.Free;
    end;

    Context := TContext.Create(nil, nil);
    try
      Attribute := ActionPolicy;
      Check(not Context.TryGetAttribute<PolicyAttribute>(Attribute), 'Empty context must not match');
      Check(Attribute = nil, 'Missing lookup must clear a previous value');
    finally
      Context.Free;
    end;
  finally
    // These test attributes are constructed manually, rather than owned by RTTI.
    ControllerPolicy.Free;
    ActionPolicy.Free;
  end;
end;

begin
  try
    TestRttiLifetime;
    RunTests;
    Writeln('Context metadata tests passed.');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
