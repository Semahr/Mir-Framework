program MirExample;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Horse,
  Container.App,
  Http.Composition,
  Http.Server;

var
  App: TAppContainer;
  Server: THttpServer;
begin
  try
    App := TAppContainer.Create;
    Server := nil;

    try
      Server := THttpComposition.CreateDefaultServer(App);
      Server.Start;

      Writeln('Press Enter to stop...');
      Readln;
    finally
      Server.Free;
      App.Free;
    end;
  except
    on Error: Exception do
      Writeln(Error.ClassName, ': ', Error.Message);
  end;
end.
