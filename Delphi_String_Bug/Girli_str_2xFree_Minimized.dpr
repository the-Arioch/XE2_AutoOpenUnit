program Girli_str_2xFree_Minimized;

{$APPTYPE CONSOLE}

// initial mini-demo by Гирлионайльдо - http://www.sql.ru/forum/memberinfo.aspx?mid=249076
// variance IfDef's re-added by Arioch (orginal reporter)

uses
  SysUtils;

{.$Define TestBug_Impl_Exit}
{.$Define TestBug_Impl_AsIs}

{.$Define NewStr_Unique}

var
  rFile: string;

{$IfNDef TestBug_Impl_Exit}  {$IfNDef TestBug_Impl_AsIs}
function TestBUG(const S: string): string;
begin
  Result := S;
end;
{$EndIf}{$EndIf}

{$IfDef TestBug_Impl_AsIs}
procedure TestBUG(const S: string; var Result: string);
begin
  Result := S;
end;
{$EndIf}

{$IfDef TestBug_Impl_Exit}
function TestBUG(const S: string): string;
begin
  Exit(S);
end;
{$EndIf}


procedure Test(const FileName: string);
{$IfDef TestBug_Impl_AsIs} var unnamed_temp: string; {$EndIf}
begin

// rFile := FileName.SubString(0, Length(FileName)); // Получим новую строку
// unavail in XE2

{$IfNDef NewStr_Unique}
  rFile := Copy(FileName, 1, Length(FileName));
  // reference-counting broken, de facto writes into const-string (destroys it)
{$Else}
  rFile := FileName;    // no bug, reference-counting proceeded normally!
  UniqueString(rFile);
{$EndIf}

{$IfNDef TestBug_Impl_AsIs}
  TestBUG(FileName); // try to use the const-pointer to the old string
{$Else}
  TestBUG(FileName, unnamed_temp);
{$EndIf}
end; // <== Fatality here

begin
  try
    try
      rFile := ParamStr(0);
      Test(rFile);

      Writeln('Safely returned from the hazardous function without memory dislocations.');

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
