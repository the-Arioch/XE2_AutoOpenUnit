program Delphi_str_2xFree_Minimized;

{$APPTYPE CONSOLE}

{.$Define String_2xFree_Crash_WorkAround}

(************************

Delphi Classic compilers bug demonstration: LongString double-free.

Discovered: Arioch on Delphi XE2 Win32

Minimized: nicholaos @ http://www.sql.ru/forum/actualutils.aspx?action=gotomsg&tid=1300873&msg=21640617

Tested by nicholoas: Embarcadero® Delphi 10.2 Version 25.0.26309.314, Win32 & Win64
Reportedly fails with "Illegal Pointer Operator".

Tested by Arioch on XE2 - does not trigger strings de-alloc bug, fails with proper "file not found".

************************)


uses
  IOUtils, SysUtils;

var
  VolatileFN: string;

Const TextFileReadable = 'c:\Windows\win.ini';
// Const TextFileReadable = 'c:\autoexec.bat';

{$IfNDef String_2xFree_Crash_WorkAround}  

procedure Test(const ConstFN: string); // Hulk crash!
begin
  VolatileFN := copy(ConstFN, 1, 12);
  TFile.ReadAllText(ConstFN);
end;

{$Else}

procedure Test(const ConstFN: string);  // does not crash: order matters
begin
  TFile.ReadAllText(ConstFN);
  VolatileFN := copy(ConstFN, 1, 12);
end;

{$EndIf}

procedure Test2(const ConstFN: string);
begin
  Test(ConstFN);
end;

begin
  try
    try

      Test( TextFileReadable );
      Test2(VolatileFN);

      Writeln('Finished w/o Illegal Pointer Operation');

    except
      on E: Exception do
        Writeln(E.ClassName, ': ', E.Message);
    end;
  finally
    Writeln;
    Writeln('Read the output. Press ENTER to terminate the program.');
    Readln;
  end;
end.
