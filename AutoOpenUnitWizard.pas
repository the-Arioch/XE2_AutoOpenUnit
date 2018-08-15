// -------------------------------------------------------------------------
//
//                         Automatically open units
//       Initial version on Borland CodeCentral - by Yoav Abrahami
//
// This wizard automatically opens units when before a unit is opened.
// It is used to open units that are base units for inherited forms.
// The syntax is simply to add a comment in the file like
// { A utoOpenUnit someunitname}
//
// -------------------------------------------------------------------------
// changes by Arioch:
//  * some updates for XE2 Delphi
//  * support for the comment in DPR/DPK files
//  * support for paths in the comment, not merely unit names
//  **  still .pas extension is always added, should not be put into the comment
//  * support for (* ... *) comments - if the aforementioned paths contain "}"

{$T+}
{$PointerMath ON}
{$WARN SYMBOL_PLATFORM OFF}

unit AutoOpenUnitWizard;

interface

Uses
  SysUtils, Classes, ToolsAPI,
//  menus, dialogs, consts, contnrs, registry, windows,
  Forms, // Application
  StrUtils;

Type
  TAutoOpenUnitExpert = class(TNotifierObject, IOTAWizard)
  Private
    OpenFileNotifier: IOTAIDENotifier;
    NotifierIndex: Integer;
  Public
    Constructor Create;
    Destructor Destroy; Override;
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  End;

Procedure Register;

implementation
uses IOUtils;

Procedure Register;
Begin
  RegisterPackageWizard(TAutoOpenUnitExpert.Create);
End;


function ScanFF(const Source, Search:String; const Start: Integer; const SkipTag: boolean):Integer;
Var
  p: PChar;
Begin
  if SkipTag
     then Result := Length( Search )
     else Result := 0;
  p := SearchBuf(PChar(Source), Length(Source), 0, Start-1, Search);
  if p = Nil
     then Result := 0 // regardless of Skip flag
     else Inc( Result, p-PChar(Source) + 1);
end;


function CurrentProjectGroup: IOTAProjectGroup;
var
  I: Integer;
  ModSvc: IOTAModuleServices;
begin
  ModSvc:=BorlandIDEServices as IOTAModuleServices;
  for I:=0 to ModSvc.ModuleCount-1 do
    if ModSvc.Modules[I].QueryInterface(IOTAProjectGroup,Result)=0 then
      Exit;
  Result:=nil;
end;

Type

  TOpenFileIDENotifier = Class(TInterfacedObject, IOTAIDENotifier)
  Private
    DPROJ_Opening, DPROJ_ProjSource: string;

    Function FindUnit(UnitName: string; FirstPaths: string = ''): string;
  Public
    procedure FileNotification(NotifyCode: TOTAFileNotification;
      const FileName: string; var Cancel: Boolean);
    procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean); overload;
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;
  End;


{ TAutoOpenUnitExpert }

constructor TAutoOpenUnitExpert.Create;
begin
  inherited;
  OpenFileNotifier := TOpenFileIDENotifier.Create;
  NotifierIndex := (BorlandIDEServices as IOTAServices).AddNotifier(OpenFileNotifier)
end;

destructor TAutoOpenUnitExpert.Destroy;
begin
  (BorlandIDEServices as IOTAServices).RemoveNotifier(NotifierIndex);
  inherited;
end;

procedure TAutoOpenUnitExpert.Execute;
begin

end;

function TAutoOpenUnitExpert.GetIDString: string;
begin
  Result := 'TAutoOpenUnitExpert';
end;

function TAutoOpenUnitExpert.GetName: string;
begin
  Result := 'Auto Open Units';
end;

function TAutoOpenUnitExpert.GetState: TWizardState;
begin
  Result := [];
end;

{ TOpenFileIDENotifier }

procedure TOpenFileIDENotifier.AfterCompile(Succeeded: Boolean);
begin

end;

procedure TOpenFileIDENotifier.AfterSave;
begin

end;

procedure TOpenFileIDENotifier.BeforeCompile(const Project: IOTAProject;
  var Cancel: Boolean);
begin

end;

procedure TOpenFileIDENotifier.BeforeSave;
begin

end;

procedure TOpenFileIDENotifier.Destroyed;
begin

end;

function AOU_Tag(const Cmt:Byte): string; inline;
Const CmtTag = 'AutoOpenUnit';
begin
  case Cmt of
    1:   Result := '{' + CmtTag + ' ';
    2:   Result := '(*' + CmtTag + ' ';
    else Result := '';
  end;
end;

// PROBLEM: when i save&close the test project while having
//   .dprfile as the only tab in the editor
//   and then re-open the project
//   there are notifications for .dproj, .dsk, .groupproj
//   but there is just NO notifications for auto-loaded .dpr !!!

// PROBLEM: at least in XE2 when you open .DPROJ file there comes
//   NO notification about opening .DPR or .DPK file at all!!!

// PROBLEM: at least in XE2 there is no Project -> View Source notification

{$Define XE2_String_2xFree_Crash_WorkAround_1}
{.$Define XE2_String_2xFree_Crash_WorkAround_2}

procedure TOpenFileIDENotifier.FileNotification(
  NotifyCode: TOTAFileNotification; const FileName: string;
  var Cancel: Boolean);
Var
  FileContent: string;
  TagStart, TagStart2: Integer;
  TagEnd: Integer;
  UnitName: string;
  FileNameToOpen: string;
  EndTag: string;
begin
  // Problem #2 hack
  if NotifyCode = ofnFileOpened then
     if (DPROJ_Opening > '') and (DPROJ_ProjSource > '') then
       if FileName = DPROJ_Opening then
       begin
          DPROJ_Opening := '';
{$IfNDef XE2_String_2xFree_Crash_WorkAround_1}
          FileNotification(ofnFileOpening, DPROJ_ProjSource, Cancel);
{$Else}
          UnitName := DPROJ_ProjSource;
          DPROJ_ProjSource := '';
          FileNotification(ofnFileOpening, UnitName, Cancel);
{$EndIf}
          exit;
       end;

  If NotifyCode <> ofnFileOpening then
     Exit;
  If Not FileExists(FileName) Then
    Exit;

{$IfNDef XE2_String_2xFree_Crash_WorkAround_2}
  // no Problem #2 -> no hack needed
  // or either hack is engaged - no second hack being needed either
  if DPROJ_ProjSource > '' then
    if FileName = DPROJ_ProjSource then
    begin
      DPROJ_Opening := '';
      DPROJ_ProjSource := '';  // the filename shared string var actually gets cleared here!!!
    end;
{$EndIf}

  TagEnd := 0;
  FileContent := TFile.ReadAllText(FileName);  // <=== Here: CRASH! on the nested call for DPR in XE2
    // _UstrClr was called to wipe the string, shared with FileName, without checking the sharing
    // TPath.HasPathValidColon ( Self.DPK-File ) -> _UStrArrayClr

  // re-reading file into TStringList on every REPEAT-UNTIL iteration was crazy
  // calling TStringList.GetText thrice on every iteration was crazy
  // also TStringList is slow and heavy (heap fragmentation)

{$IfDef XE2_String_2xFree_Crash_WorkAround_2}
  if DPROJ_ProjSource > '' then
    if FileName = DPROJ_ProjSource then
    begin
      DPROJ_Opening := '';
      DPROJ_ProjSource := '';  // Here after the ReadAllText call it is safe
    end;
{$EndIf}


  // Problem #2 hack registering
  if EndsText('.dproj', FileName) then begin
     DPROJ_Opening := FileName;
     DPROJ_ProjSource := '';

     TagStart := ScanFF(FileContent, '<MainSource>', TagEnd + 1, True);
     If TagStart > 0 then
     Begin
       TagEnd := ScanFF(FileContent, '</MainSource>', TagStart + 1, False);
       UnitName := Trim(Copy(FileContent, TagStart, TagEnd - TagStart));
       UnitName := ExtractFilePath(FileName) + UnitName;
       DPROJ_ProjSource := UnitName;
     end;

     exit;   // no Pascal comments in XML anyway
  end;

  Repeat
    TagStart := ScanFF(FileContent, AOU_Tag(1), TagEnd + 1, True);
    TagStart2 := ScanFF(FileContent, AOU_Tag(2), TagEnd + 1, True);
    if (TagStart2 > 0) and
       ((TagStart2 < TagStart) or (TagStart <= 0)) then begin
      TagStart := TagStart2;
      EndTag := '*)';
    end else
      EndTag := '}';

    If TagStart > 0 then
    Begin
      TagEnd := ScanFF(FileContent, EndTag, TagStart + 1, False);
      UnitName := Trim(Copy(FileContent, TagStart, TagEnd - TagStart));

      if UnitName = ''
      then FileNameToOpen := ''
      else begin
        if (UnitName[1] = '"') or (UnitName[1] = '''') then
           UnitName := AnsiDequotedStr(UnitName, UnitName[1]);
        if EndsText('.pas', UnitName) then // always added later
           SetLength(UnitName, Length(UnitName)-Length('.pas'));

        FileNameToOpen := FindUnit(UnitName, ExtractFilePath(FileName));
      end;

      If FileNameToOpen <> '' then
        (BorlandIDEServices as IOTAActionServices).OpenFile(FileNameToOpen);
    End;
  Until TagStart = 0;
end;

// TO DO: search through all the files (folders of files?) in the current Project,
//    and then in the current Project Group
// TO DO: custom config files to add extra projgroups/folders to search

// FirstPaths should be a ;-separated list of folders, initially only being
//   the current file being opened, then perhaps to add more (custom settings, etc).
// This should provide for relative paths in the "unit name" (unless those paths contain "}")
function TOpenFileIDENotifier.FindUnit(UnitName, FirstPaths: string): string;
Var
  DelphiPath: string;

  procedure GetSearchDirs(Dirs: TStrings);
  var
    Env: IOTAEnvironmentOptions;
    Path,LibPath,BrowsePath,SearchPath: string;
    Grp: IOTAProjectGroup;
    Proj: IOTAProject;
    Curr,Next: PChar;
    Dir: string;
  begin
    Env:=(BorlandIDEServices as IOTAServices).GetEnvironmentOptions;
    LibPath:=Env.GetOptionValue('LibraryPath');
    BrowsePath:=Env.GetOptionValue('BrowsingPath');
    Grp:=CurrentProjectGroup;
    if Grp<>nil then
    begin
      Proj:=Grp.GetActiveProject;
      if Proj<>nil then
        SearchPath:=Proj.GetProjectOptions.GetOptionValue('UnitDir');
    end;
    if FirstPaths > '' then
       if FirstPaths[Length(FirstPaths)] <> ';' then
          FirstPaths := FirstPaths + ';';
    Path:=FirstPaths + LibPath+';'+BrowsePath+';'+SearchPath;
    if Proj<>nil then
      Path:=ExtractFileDir(Proj.FileName)+';'+Path;

    Path:=StringReplace(Path,'$(DELPHI)',DelphiPath,[rfReplaceAll,rfIgnoreCase]);
    Path:=StringReplace(Path,'$(BDS)',DelphiPath,[rfReplaceAll,rfIgnoreCase]);
//TODO: Use OTA to get environment vars (built-in ones are not stored in the Registry)

    Curr:=PChar(Path);
    Next:=Curr;
    while Next<>nil do
    begin
      Next:=StrScan(Curr,';');
      if Next<>nil then
        Dir:=Copy(Curr,1,Next-Curr)
      else
        Dir:=Curr;
      if Dir<>'' then
      begin
        Dir := IncludeTrailingBackslash(ExpandFileName(Dir));
//        Dir:=ExpandFileName(Dir);
//        if AnsiLastChar(Dir)^<>'\' then
//          Dir:=Dir+'\';
        Dirs.Add(Dir);
      end;
      Curr:=Next+1;
    end;
  End;
Var
  Dirs: TStringList;
  DirName, UnitFileName: string;
//  I: Integer;
begin
  Result := '';

  UnitName := UnitName + '.pas';
  if not IsRelativePath(UnitName) then
  begin
    if FileExists(UnitName) then
       Result := UnitName;
    exit;
  end;

  DelphiPath:=ExtractFileDir(ExtractFileDir(Application.ExeName));
  Dirs := TStringList.Create;
  Try
    GetSearchDirs(Dirs);
//    For I := 0 to Dirs.Count - 1 do
    for DirName in Dirs do
    begin
      UnitFileName := TPath.Combine(DirName, UnitName);
      // ExpandFileName - remove things like xxx\..\yyyy
      //    that makes Delphi IDE open one file many times
      //    delusioning those were DIFFERENT files!
      UnitFileName := TPath.GetFullPath(UnitFileName);
      If FileExists(UnitFileName) then
      Begin
        Result := UnitFileName;
        Exit;
      End;
    end;  
  Finally
    Dirs.Free;
  End;
end;

procedure TOpenFileIDENotifier.Modified;
begin

end;

end.
