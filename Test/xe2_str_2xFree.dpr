program xe2_str_2xFree;

{$APPTYPE CONSOLE}

{$O+} // actually, irrelevant if on or off

{$R *.res}

{.$Define XE2_String_2xFree_Crash_WorkAround_1}
{.$Define XE2_String_2xFree_Crash_WorkAround_2}
{.$Define XE2_String_2xFree_Crash_WorkAround_3}
{.$Define XE2_String_2xFree_Crash_WorkAround_4}

uses
  SysUtils, StrUtils, IOUtils;

type iDummy = interface
        procedure Event(const EventKind: Byte; const FileName: string);
end;

type TDummy = class (TInterfacedObject, iDummy)
     strict private
        IDE_Call, Simulated_Call: string;
     strict protected
        procedure Event(const EventKind: Byte; const FileName: string);
end;

{ TDummy }

procedure TDummy.Event(const EventKind: Byte; const FileName: string);
var data: string;
begin
  if EventKind = 2 then begin
     if (IDE_Call > '') and (Simulated_Call > '') then
        if FileName = IDE_Call then
        begin
          IDE_Call := '';
{$IfNDef XE2_String_2xFree_Crash_WorkAround_1}
          Event(1, Simulated_Call);   // Simulate the missing IDE event
{$Else}
          data := Simulated_Call; // turn the const-string into a volatile var
          Simulated_Call := '';
          Event(1, data);              // Simulate the missing IDE event
{$EndIf}
          exit;
        end;
  end;

  if EventKind = 1 then begin

{$IfDef XE2_String_2xFree_Crash_WorkAround_3}
    if not TFile.Exists(FileName) then exit; // the mere presence of this call seems to fix it
{$EndIf}
    if not FileExists(FileName) then exit;
{$IfDef XE2_String_2xFree_Crash_WorkAround_4}
    if not TFile.Exists(FileName) then exit;
{$EndIf}

{$IfNDef XE2_String_2xFree_Crash_WorkAround_2}
    if Simulated_Call > '' then
      if FileName = Simulated_Call then // if IDE somehow got called us - do unregister the call simulation
      begin
        IDE_Call := '';
        Simulated_Call := '';  // the filename shared string var actually gets cleared here!!!
      end;
{$EndIf}

     // register late-call simulation of a missed event
     if EndsText('.dproj', FileName) then begin
        IDE_Call := FileName;
        Simulated_Call := ChangeFileExt(FileName,'.dpr');
        Exit;
     end;

     data := TFile.ReadAllText(FileName);

{$IfDef XE2_String_2xFree_Crash_WorkAround_2}
    if Simulated_Call > '' then
      if FileName = Simulated_Call then
      begin
        IDE_Call := '';
        Simulated_Call := '';  // here the shared string becomes safe to clear
      end;
{$EndIf}

     (* some processing of the text: searching for custom tags for example *)
     data := ReplaceStr(data, 'e', 'E');
     data := LeftStr(data, Pos(#13, data)-1);
     Writeln(FileName);
     Writeln(#9, data, '  - OK');
  end;
end;

var obj: iDummy;

procedure RunExpert;
var fn: string;
begin
  fn := ParamStr(0);
  fn := ReplaceText(fn, '\Win32\Debug\', '\');
  fn := ReplaceText(fn, '\Win32\Release\', '\');
  fn := ChangeFileExt(fn,'.DProj');

  obj.Event(0, fn);
  obj.Event(1, fn);
  obj.Event(2, fn);
end;

begin
  try
    try
      obj := TDummy.Create;
      RunExpert;
      obj := nil;

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
