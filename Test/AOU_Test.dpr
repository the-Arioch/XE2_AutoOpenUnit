program AOU_Test;

{$APPTYPE CONSOLE}

{$R *.res}

// close all units and save project.
// close project and reopen.
// see if other units would get auto-opened

{AutoOpenUnit Unit1 }

uses
  System.SysUtils,
  Unit1 in 'Unit1.pas',
  Unit2 in 'Unit2.pas';

begin
  try
    { TODO -oUser -cConsole Main : Insert code here }
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
