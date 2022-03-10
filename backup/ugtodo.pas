unit ugtodo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Grids, process, LCLType;

type

  { TForm1 }

  TForm1 = class(TForm)
    edTarefa: TLabeledEdit;
    Panel1: TPanel;
    sgTarefas: TStringGrid;
    procedure edTarefaKeyPress(Sender: TObject; var Key: char);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure sgTarefasColRowMoved(Sender: TObject; IsColumn: Boolean; sIndex,
      tIndex: Integer);
    procedure sgTarefasDblClick(Sender: TObject);
    procedure sgTarefasKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState
      );
    procedure sgTarefasPrepareCanvas(sender: TObject; aCol, aRow: Integer;
      aState: TGridDrawState);
    procedure sgTarefasSelection(Sender: TObject; aCol, aRow: Integer);
  private
    tDir,
    cDir : string;
    chgfn,
    todofn:string;
    edtMode,
    notGit:Boolean;

  public

  end;

var
  Form1: TForm1;
const
  todoname = 'gtodo.txt';
  changelog = 'changelog.txt';

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormShow(Sender: TObject);
var
  sOut: string;
begin
  cDir:=IncludeTrailingPathDelimiter(GetCurrentDir);
  todofn:=cDir+todoname;
  chgfn:=cDir+changelog;
  notGit:=True;
  sgTarefas.SaveOptions:=soAll;
  if FileExists(todofn) then begin
    sgTarefas.LoadFromFile(todofn);
  end else
    sgTarefas.RowCount:=1;
  sgTarefas.Options:=sgTarefas.Options+[goFixedRowNumbering,goRowSelect];
  if not RunCommandIndir(cDir,'git',['rev-parse','--show-toplevel'],sOut,[poWaitOnExit,poStderrToOutPut,poNoConsole]) then begin
    Caption := 'gtodo : (LOCAL) - '+cDir;
    exit;
  end;
  notGit:=False;
  tDir := Trim(sOut);
  Caption := 'gtodo : (GIT) - '+tDir;
end;

procedure TForm1.sgTarefasColRowMoved(Sender: TObject; IsColumn: Boolean;
  sIndex, tIndex: Integer);
begin
  sgTarefas.SaveToFile(todofn);
end;

procedure TForm1.sgTarefasDblClick(Sender: TObject);
var
  lst: TStringList;
  sOut: string;
   s: String;
begin
  if sgTarefas.RowCount=1 then exit;
  s:=sgTarefas.Cells[1,sgTarefas.Row];
  if MessageDlg('Commit', s+#10#13#10#13'Deseja informar como concluída a tarefa?', mtConfirmation, [mbYes, mbNo],0) = mrYes then begin
    lst := TStringList.Create();
    if FileExists(chgfn) then
      lst.LoadFromFile(chgfn);
    lst.Insert(0,FormatDateTime('YYYY.MM.DD : ',now)+s);
    lst.SaveToFile(chgfn);
    lst.Free;
  end else exit;
  sgTarefas.DeleteRow(sgTarefas.Row);
  sgTarefas.SaveToFile(todofn);
  if notGit then exit;
  if not RunCommandInDir(cDir,'git',['add','.'],sOut,[poWaitOnExit,poStderrToOutPut,poNoConsole]) then begin
    ShowMessage('ERROR : git add .'+sOut);
    exit;
  end;
  if not RunCommandInDir(cDir,'git',['commit','-m',s],sOut,[poWaitOnExit,poStderrToOutPut,poNoConsole]) then begin
    ShowMessage('ERROR : git commit -m '+QuotedStr(s)+sOut);
    exit;
  end;
  ShowMessage('COMMIT OK'#10#13+sOut);
end;

procedure TForm1.sgTarefasKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
end;

procedure TForm1.sgTarefasPrepareCanvas(sender: TObject; aCol, aRow: Integer;
  aState: TGridDrawState);
begin
  if (aRow < 1) or (aCol < 1) then exit;
  if gdSelected in aState then exit;
  case sgTarefas.Cells[1,aRow][1] of
    '-' : sgTarefas.Canvas.Font.Color:=clGreen;
    '+' : sgTarefas.Canvas.Font.Color:=clRed;
  end;
end;

procedure TForm1.sgTarefasSelection(Sender: TObject; aCol, aRow: Integer);
begin
  if aCol=0 then exit;
  edtMode:=True;
  edTarefa.Text:=sgTarefas.Cells[1,sgTarefas.Row];
  edTarefa.SetFocus;
end;

procedure TForm1.edTarefaKeyPress(Sender: TObject; var Key: char);
var
  s: string;
begin
  if Key <> #13 then exit;
  s:=Trim(edTarefa.Text);
  if s='' then exit;
  if edtMode then begin
    sgTarefas.Cells[1,sgTarefas.Row]:=s;
    edtMode:=False;
  end else begin
    sgTarefas.RowCount:=sgTarefas.RowCount+1;
    sgTarefas.Cells[1,sgTarefas.RowCount-1]:=s;
  end;
  sgTarefas.SaveToFile(todofn);
  edTarefa.Text:='';
end;

procedure TForm1.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    case Key of
      VK_ESCAPE: begin edtMode:=False; edTarefa.Text:=''; end;
      VK_UP: begin if sgTarefas.Row>1 then sgTarefas.Row:=sgTarefas.Row-1; end;
      VK_DOWN: begin if sgTarefas.Row<sgTarefas.RowCount then sgTarefas.Row:=sgTarefas.Row+1; end;
      VK_X:
        begin
          if not (ssCtrl in Shift) then exit;
          if sgTarefas.Row<1 then exit;
          if MessageDlg('Commit', sgTarefas.Cells[1,sgTarefas.Row]+#10#13#10#13'Deseja excluir a tarefa?', mtConfirmation, [mbYes, mbNo],0) = mrYes then begin
            sgTarefas.DeleteRow(sgTarefas.Row);
            sgTarefas.SaveToFile(todofn);
          end;
      end;
    end;
end;

end.

