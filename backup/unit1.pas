unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  OpenGLContext, SynEdit, SynHighlighterCpp, gl, glu, glext, {openglprocs,}
  {$ifdef Windows} Windows {$endif}
  {$ifdef linux} baseunix, unix {$endif}
  , Types;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Memo1: TMemo;
    OpenDialog1: TOpenDialog;
    openglcontrol1:TOpenGlcontrol;
    SaveDialog1: TSaveDialog;
    SynCppSyn1: TSynCppSyn;
    SynEdit1: TSynEdit;
    procedure Button1Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure FormResize(Sender: TObject);
    procedure OpenGLControl1Click(Sender: TObject);
    procedure OpenGLControl1DblClick(Sender: TObject);
    procedure OpenGLControl1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure OpenGLControl1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
//    procedure OpenGLControl1MouseWheel(Sender: TObject; Shift: TShiftState;
    //  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure OpenGLControl1Paint(Sender: TObject);
 //   procedure OpenGLControl1Paint2(Sender: TObject);
    procedure OnAppIdle(Sender: TObject; var Done: Boolean);
    procedure OpenGLControl1Resize(Sender: TObject);
    procedure SynEdit1Change(Sender: TObject);
  private

  public

  end;


  TGLThread = class(TThread)
  private
  protected
    procedure Execute; override;
  public
    Constructor Create(CreateSuspended : boolean);
  end;

var
  Form1: TForm1;
  cube_rotationx: GLFloat;
  cube_rotationy: GLFloat;
  cube_rotationz: GLFloat;


var programID, vertexID, renderbufferID,
    framebufferID, texcoordID, positionLoc:GLuint;
    frames:integer;
    texture0:gluint;
    u_texture:GLint;
    a_texcoord:GLint;
    u_itime:GLint;
    u_iResolution:GLint;
    acanvas:array[0..2559,0..1439] of cardinal;
    pixels:array[0..800*600-1] of cardinal;
    basetime:int64;

    {$ifdef Windows}    type kwas= function(interval: GLint): BOOL; stdcall ;  {$endif}
var
{$ifdef Windows} wglSwapIntervalEXT: kwas = nil;    {$endif}
clicked:boolean=false;
resized:boolean=false;
updating1:boolean=false;
glthread:TGlThread;

VertexShader: TGLUint;
FragmentShader: TGLUint;

implementation

uses keyboard,mouse;
{$R *.lfm}

procedure gl_draw;  forward;
procedure fullscreen;  forward;

constructor TGLThread.Create(CreateSuspended : boolean);

begin
  FreeOnTerminate := True;
  inherited Create(CreateSuspended);
end;

// ----------------------------------------------------------------------
// THIS IS THE MAIN RETROMACHINE THREAD
// - convert retromachine screen to raspberry screen
// - display sprites
// - get hardware events from sdl and put them to system variable
// ----------------------------------------------------------------------



// linux gettime
{$ifdef Linux}
function gettime:int64; inline;

var
  tv: TTimeVal;
  tz: TTimeZone;

begin
  fpgettimeofday(@tv, @tz);
  Result := tv.tv_sec * 1000000 + tv.tv_usec;
end;
{$endif}

{$ifdef Windows}
function gettime:int64; inline;

var pf,tm:int64;

begin
QueryPerformanceFrequency(pf);
QueryPerformanceCounter(tm);
gettime:=round(1000000*tm/pf);
end;

{$endif}


procedure TGLThread.Execute;
            var tttt:int64;
begin
  repeat
  if not updating1 then form1.OpenGLControl1.Invalidate;
  sleep(1);
  until terminated;
end;

const VertexSource:String =

 'attribute vec4 a_position; ' +
 'attribute vec2 a_texcoord; ' +
 'varying vec2 v_texcoord; '+
 'void main() ' +
 '{' +
 '    gl_Position = a_position; ' +
 '    v_texcoord = a_texcoord;  '+
 '}';

FragmentSource:String =
 'varying vec2 v_texcoord; '+ #13+#10+
 'uniform sampler2D u_texture; '+ #13+#10+
 'uniform float iTime; '+    #13+#10+
 'uniform vec2 iResolution; '+#13+#10;


//+
// 'void main()' +
// '{' +
//   ' vec2 p=(3.0*gl_FragCoord.xy-iResolution.xy)/max(iResolution.x,iResolution.y);  '+
//   'float f = cos(iTime/30.);                                                     '+
//   'float s = sin(iTime/30.);                                                     '+
//   'p = vec2(p.x*f-p.y*s, p.x*s+p.y*f);                                         '+
//
//   'for(float i=3.0;i<30.;i++) '+
//'	{           '+
//    '    p+= .30/i * sqrt(abs(cos(i*p.yx+iTime*vec2(.30,.30)  + vec2(.30,3.0)))); '+
//'	}                                                                           '+
//'	vec3 col=vec3(.30*sin(3.0*p.x)+.30,.30*sin(3.0*p.y)+.30,sin(3.0*p.x+3.0*p.y)); '+
//'	gl_FragColor=(3.0/(3.0-(3.0/3.0)))*vec4(col, 3.0);                               '+
// '} ';





// -----------------  test square ------------------------------------------------

var vertices:array[0..17] of GLfloat = (               // 6*6*3-1
 -1.0, 1.0, 0.0,-1.0,-1.0, 0.0, 1.0, 1.0, 0.0,          // Front
  1.0, 1.0, 0.0,-1.0,-1.0, 0.0, 1.0,-1.0, 0.0);

//    uvs:array[0..11] of GLfloat=( 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1);
    uvs:array[0..11] of GLfloat=( 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0);

//---------------- end of the square definition --------------------------------

procedure gl_draw;


begin

glUniform1f(u_itime,(gettime-basetime)/1000000);
glUniform2f(u_iresolution,form1.openglcontrol1.width,form1.openglcontrol1.height);

//glBindFramebuffer(GL_FRAMEBUFFER,0);

glTexSubImage2D(GL_TEXTURE_2D, 0, 0,0 ,2560  , 1440 , gl_rgba, GL_UNSIGNED_BYTE, @acanvas);
glViewport(0,0,form1.openglcontrol1.width,form1.openglcontrol1.Height);
glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
glDrawArrays(GL_TRIANGLES,0,6);

//glReadPixels(0,00,800,600, GL_rgba, GL_UNSIGNED_BYTE, @pixels);
//glCopyTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 0, 1, 800, 600);  // texturex,texturey, fbx,fby, w,h)
//glTexsubImage2D(GL_TEXTURE_2D,0,000,001,800,600,gl_rgba, GL_UNSIGNED_BYTE,@pixels);

form1.OpenGLControl1.SwapBuffers;

end;

{ TForm1 }

procedure TForm1.OpenGLControl1Paint(Sender: TObject);

begin
gl_draw;
frames+=1;
end;


procedure initgl;
var

    ShaderValid: GLInt;
    source:Pchar;
    ssource:string;
    ErrorLength: GLInt;
    ErrorText: String;
    i,j:integer;
    t:int64;

begin

//
// initmouse;
// a test texture

for i:=0 to 2047 do for j:=0 to 2047 do acanvas[i,j]:=$FFFFFF;
for i:=0 to 399 do for j:=0 to 299 do acanvas[j,i]:=$FF0000;
for i:=400 to 799 do for j:=0 to 299 do acanvas[j,i]:=$00FF00;
for i:=0 to 399 do for j:=300 to 599 do acanvas[j,i]:=$00FFFF;
for i:=400 to 799 do for j:=300 to 599 do acanvas[j,i]:=$0000FF;


Application.AddOnIdleHandler(@form1.OnAppIdle);
form1.OpenGLControl1.MakeCurrent;
Load_GL_VERSION_4_3;

glClearDepth(1.0);
glClearColor(0.0,0.4,0.6,0.6);
glEnable(GL_CULL_FACE);
glEnable(GL_DEPTH_TEST);
glEnable(GL_ALPHA_TEST);
glEnable(GL_BLEND);

VertexShader:= glCreateShader(GL_VERTEX_SHADER);
Source:=PChar(vertexSource);
glShaderSource(VertexShader, 1, @Source, Nil);
glCompileShader(VertexShader);

glGetShaderiv(VertexShader, GL_COMPILE_STATUS, @ShaderValid);
If ShaderValid=GL_FALSE then
  begin
  glGetShaderiv(VertexShader, GL_INFO_LOG_LENGTH, @ErrorLength);
  SetLength(ErrorText, ErrorLength);
  glGetShaderInfoLog(VertexShader, ErrorLength, @ErrorLength, @ErrorText[1]);
  If VertexShader<>0 Then
    begin
    glDeleteShader(VertexShader);
    VertexShader:= 0;
    end;
  end
else errortext:='Vertex shader compiled';
form1.memo1.lines.add(errortext);

FragmentShader:=glCreateShader(GL_FRAGMENT_SHADER);
SSource:=FragmentSource;
for i:=0 to form1.synedit1.lines.count do
  begin
    ssource+=form1.synedit1.lines[i];
    ssource+=#13;
    ssource+=#10;
    end;
Source:=PChar(SSource);
glShaderSource(FragmentShader,1,@Source,nil);
glCompileShader(FragmentShader);

glGetShaderiv(FragmentShader, GL_COMPILE_STATUS, @ShaderValid);
If ShaderValid=GL_FALSE then
  begin
  glGetShaderiv(FragmentShader, GL_INFO_LOG_LENGTH, @ErrorLength);
  SetLength(ErrorText, ErrorLength);
  glGetShaderInfoLog(FragmentShader, ErrorLength, @ErrorLength, @ErrorText[1]);
  If FragmentShader<>0 Then
    begin
    glDeleteShader(FragmentShader);
    FragmentShader:= 0;
    end;
  end
else errortext:='Fragment shader compiled';
form1.memo1.lines.add(errortext);

programID:=glCreateProgram();
glAttachShader(programID,VertexShader);
glAttachShader(programID,FragmentShader);
glLinkProgram(programID);

glDeleteShader(FragmentShader);
glDeleteShader(VertexShader);

positionLoc:=glGetAttribLocation(programID,'a_position');
glEnableVertexAttribArray(positionLoc);
u_texture:=glGetUniformLocation(programID,'u_texture');
a_texcoord:=glGetAttribLocation(programID,'a_texcoord');
u_itime:=glGetUniformLocation(programID,'iTime');
u_iresolution:=glGetUniformLocation(programID,'iResolution');

glGenBuffers(1,@vertexID);
glBindBuffer(GL_ARRAY_BUFFER,vertexID);
glVertexAttribPointer(positionLoc,3,GL_FLOAT,GL_FALSE,3 * SizeOf(GLfloat),nil);
glBindBuffer(GL_ARRAY_BUFFER,vertexID);
glBufferData(GL_ARRAY_BUFFER,SizeOf(Vertices),@Vertices,GL_DYNAMIC_DRAW);

glGenBuffers(1,@texcoordID);
glBindBuffer(GL_ARRAY_BUFFER,texcoordID);
glVertexAttribPointer(a_texcoord, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), nil);
glEnableVertexAttribArray(a_texcoord);
glBufferData(GL_ARRAY_BUFFER, sizeof(uvs), @uvs[0], GL_STATIC_DRAW);

glGenRenderbuffers(1, @renderbufferID);
glBindRenderbuffer(GL_RENDERBUFFER, renderbufferID);
glRenderbufferStorage (GL_RENDERBUFFER, GL_RGBA8, 800, 600);

glGenFramebuffers(1, @framebufferID);
//glBindFramebuffer(GL_FRAMEBUFFER,framebufferID);

glGenTextures(1, @texture0);
glActiveTexture(GL_TEXTURE0);
glBindTexture(GL_TEXTURE_2D, texture0);

t:=gettime;
glTexImage2D(GL_TEXTURE_2D, 0, gl_rgba, 2560  , 1440 , 0, gl_rgba, GL_UNSIGNED_BYTE, @acanvas); // glwindow.canvas);
t:=gettime-t;
form1.memo1.lines.add('Texture upload time: '+inttostr(t));

glUniform1i(u_texture,0);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_nearest);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_nearest);

glViewport(0,0,form1.openglcontrol1.width,form1.openglcontrol1.Height);
glUseProgram(programID);
glUniform1i(u_texture,0);
{$ifdef Windows}
glext_loadextension('wglSwapIntervalEXT');
wglSwapIntervalEXT:=kwas(wglGetProcAddress('wglSwapIntervalEXT'));
wglSwapIntervalEXT(1);
{$endif}
end;


procedure TForm1.FormCreate(Sender: TObject);

begin
form1.memo1.lines.clear;
initgl;
glthread:=TGLthread.create(true);
glthread.Start;
basetime:=gettime;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState
  );
begin
           if key=121 then fullscreen;
end;

procedure TForm1.FormKeyPress(Sender: TObject; var Key: char);
begin
 //  memo1.lines.add((key));
end;

procedure TForm1.FormResize(Sender: TObject);
begin

end;

procedure TForm1.OpenGLControl1Click(Sender: TObject);
begin

end;

procedure TForm1.OpenGLControl1DblClick(Sender: TObject);
begin

end;

procedure TForm1.OpenGLControl1MouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin

end;

procedure TForm1.OpenGLControl1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin

end;


procedure fullscreen;

label p999;

const d:integer=0;
      oldw:integer=0;
      oldh:integer=0;
      oldt:integer=0;
      oldl:integer=0;


begin
//if not clicked then goto p999;
if d=0 then
  begin
  d:=1;
  form1.openglcontrol1.OnPaint:=nil;
  form1.openglcontrol1.Onclick:=nil;
  updating1:=true;
  sleep(20);
  form1.openglcontrol1.releasecontext;
  form1.openglcontrol1.destroy;
  form1.openglcontrol1:=nil;

  form1.borderstyle:=bsnone;
  form1.openglcontrol1:=TOpenglcontrol.create(form1);
  with form1.OpenGLControl1 do
    begin
    Name:='OpenGLControl1';
    Parent:=form1;
    OnPaint:=@form1.OpenGLControl1Paint;
    OnClick:=@form1.OpenGLControl1Click;
    OndblClick:=@form1.OpenGLControl1dblClick;
    Onmouseup:=@form1.OpenGLControl1mouseup;
    end;

  initgl;

  oldl:=form1.left; oldt:=form1.top; oldw:=form1.width; oldh:=form1.height;
  form1.windowstate:=wsfullscreen;
  form1.openglcontrol1.SetBounds(0,0,screen.width,screen.height);
  updating1:=false;
  end
else
  begin
  d:=0;
  form1.openglcontrol1.OnPaint:=nil;
  form1.openglcontrol1.Onclick:=nil;
  updating1:=true;
  sleep(20);
  form1.openglcontrol1.releasecontext;
  form1.openglcontrol1.destroy;
  form1.openglcontrol1:=nil;

  form1.borderstyle:=bssingle;
  form1.openglcontrol1:=TOpenglcontrol.create(form1);
  with form1.OpenGLControl1 do
    begin
    Name:='OpenGLControl1';
    Parent:=form1;
    OnPaint:=@form1.OpenGLControl1Paint;
    OnClick:=@form1.OpenGLControl1Click;
    OndblClick:=@form1.OpenGLControl1dblClick;
    Onmouseup:=@form1.OpenGLControl1mouseup;
    end;

  initgl;

  form1.windowstate:=wsnormal;
  form1.setbounds(oldl,oldt,oldw,oldh);
  form1.openglcontrol1.SetBounds(0,0,1024,600);
  updating1:=false;



  end;
//clicked:=false;
p999:
end;

procedure TForm1.Button1Click(Sender: TObject);
begin

end;

procedure TForm1.Button3Click(Sender: TObject);
begin
frames:=0;
basetime:=gettime;
end;

procedure TForm1.Button6Click(Sender: TObject);
begin
  if savedialog1.execute then synedit1.lines.savetofile(savedialog1.filename);
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
glthread.terminate;
sleep(100);
openglcontext1.releasecontext;
openglcontext1.destroy;
end;

procedure TForm1.OnAppIdle(Sender: TObject; var Done: Boolean);
begin
//  Done:=false;
//  OpenGLControl1.Invalidate;
end;

procedure TForm1.OpenGLControl1Resize(Sender: TObject);
begin

end;

procedure TForm1.SynEdit1Change(Sender: TObject);
begin

end;

end.

