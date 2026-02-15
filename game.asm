format PE GUI 4.0
entry start

include 'tools\INCLUDE\win32ax.inc'

WM_TIMER = 113h

GL_COLOR_BUFFER_BIT = 00004000h
GL_DEPTH_BUFFER_BIT = 00000100h
GL_QUADS = 0007h
GL_LINES = 0001h
GL_MODELVIEW = 1700h
GL_PROJECTION = 1701h
GL_DEPTH_TEST = 0B71h

PFD_DRAW_TO_WINDOW = 00000004h
PFD_SUPPORT_OPENGL = 00000020h
PFD_DOUBLEBUFFER = 00000001h
PFD_TYPE_RGBA = 0
PFD_MAIN_PLANE = 0

VK_W = 57h
VK_A = 41h
VK_S = 53h
VK_D = 44h

section '.data' data readable writeable
  className db 'AsmFps3DClass',0
  windowTitle db 'Assembly FPS 3D - Win10',0

  hWnd dd 0
  hDC dd 0
  hRC dd 0

  lastTick dd 0
  deltaT dd 0.016
  msTemp dd 16

  camX dd 0.0
  camZ dd 0.0
  camYaw dd 0.0
  camPitch dd 0.0

  jumpOffset dd 0.0
  velY dd 0.0

  baseEyeY dd 1.65
  crouchEyeY dd 1.05
  eyeY dd 1.65

  walkSpeed dd 4.2
  runMult dd 1.85
  crouchMult dd 0.52
  turnSpeed dd 110.0
  lookSpeed dd 85.0
  mouseSensYaw dd 0.10
  mouseSensPitch dd 0.08
  gravity dd 24.0
  jumpVel dd 8.6

  deg2rad dd 0.0174532925

  tmpForward dd 0
  tmpStrafe dd 0
  tmpPitchI dd 0

  tmpSpeed dd 0.0
  tmpAngle dd 0.0
  sinYaw dd 0.0
  cosYaw dd 1.0
  tmpX dd 0.0
  tmpZ dd 0.0
  tmpEye dd 0.0

  fZero dd 0.0
  fOne dd 1.0
  fNegOne dd -1.0
  fTen dd 10.0
  fNegTen dd -10.0
  fLineA dd -0.05
  fLineB dd 0.05
  fCrossZero dd 0.0
  fLineColor dd 1.0
  fBgR dd 0.08
  fBgG dd 0.08
  fBgB dd 0.18
  fDbgZ dd -4.0
  fDbgLeft dd -1.2
  fDbgRight dd 1.2
  fDbgTop dd 0.8
  fDbgBottom dd -0.8
  f80 dd 80.0
  fNeg80 dd -80.0

  colDarkR dd 0.18
  colDarkG dd 0.30
  colDarkB dd 0.55
  colLightR dd 0.90
  colLightG dd 0.90
  colLightB dd 0.90

  ; Perspective frustum
  projLeft dq -0.75
  projRight dq 0.75
  projBottom dq -0.42
  projTop dq 0.42
  projNear dq 0.7
  projFar dq 200.0

  fAxisX dd 1.0
  fAxisY dd 0.0
  fAxisZ dd 0.0
  fUpX dd 0.0
  fUpY dd 1.0
  fUpZ dd 0.0

  keyTmp dw 0

  msg MSG
  wc WNDCLASSEX
  pfd PIXELFORMATDESCRIPTOR
  ps PAINTSTRUCT
  rc RECT
  lockRect RECT
  lockTL POINT
  lockBR POINT
  centerPt POINT

section '.code' code readable executable
start:
  invoke GetModuleHandle,0
  mov ebx,eax

  mov [wc.cbSize],sizeof.WNDCLASSEX
  mov [wc.style],CS_HREDRAW + CS_VREDRAW + CS_OWNDC
  mov [wc.lpfnWndProc],WndProc
  mov [wc.cbClsExtra],0
  mov [wc.cbWndExtra],0
  mov [wc.hInstance],ebx
  invoke LoadIcon,0,IDI_APPLICATION
  mov [wc.hIcon],eax
  mov [wc.hIconSm],eax
  invoke LoadCursor,0,IDC_ARROW
  mov [wc.hCursor],eax
  mov [wc.hbrBackground],0
  mov [wc.lpszMenuName],0
  mov [wc.lpszClassName],className
  invoke RegisterClassEx,wc
  test eax,eax
  jz .exit

  invoke CreateWindowEx,0,className,windowTitle,WS_OVERLAPPEDWINDOW + WS_VISIBLE + WS_CLIPCHILDREN + WS_CLIPSIBLINGS,100,60,1280,720,NULL,NULL,ebx,NULL
  test eax,eax
  jz .exit

.msg_loop:
  invoke GetMessage,msg,NULL,0,0
  test eax,eax
  jz .exit
  invoke TranslateMessage,msg
  invoke DispatchMessage,msg
  jmp .msg_loop

.exit:
  invoke ExitProcess,0

proc InitGL
  invoke GetDC,[hWnd]
  mov [hDC],eax

  mov edi,pfd
  mov ecx,sizeof.PIXELFORMATDESCRIPTOR/4
  xor eax,eax
  rep stosd

  mov [pfd.nSize],sizeof.PIXELFORMATDESCRIPTOR
  mov [pfd.nVersion],1
  mov [pfd.dwFlags],PFD_DRAW_TO_WINDOW + PFD_SUPPORT_OPENGL + PFD_DOUBLEBUFFER
  mov [pfd.iPixelType],PFD_TYPE_RGBA
  mov [pfd.cColorBits],32
  mov [pfd.cDepthBits],24
  mov [pfd.cStencilBits],8
  mov [pfd.iLayerType],PFD_MAIN_PLANE

  invoke ChoosePixelFormat,[hDC],pfd
  test eax,eax
  jz .fail
  mov esi,eax

  invoke SetPixelFormat,[hDC],esi,pfd
  test eax,eax
  jz .fail

  invoke wglCreateContext,[hDC]
  test eax,eax
  jz .fail
  mov [hRC],eax

  invoke wglMakeCurrent,[hDC],[hRC]
  test eax,eax
  jz .fail

  invoke glClearColor,[fBgR],[fBgG],[fBgB],[fOne]
  invoke glEnable,GL_DEPTH_TEST

  invoke GetTickCount
  mov [lastTick],eax

  invoke SetTimer,[hWnd],1,16,0
  call LockCursor
  mov eax,1
  ret

.fail:
  xor eax,eax
  ret
endp

proc ShutdownGL
  invoke KillTimer,[hWnd],1
  call UnlockCursor
  invoke wglMakeCurrent,0,0
  cmp [hRC],0
  je @f
  invoke wglDeleteContext,[hRC]
@@:
  cmp [hDC],0
  je @f
  invoke ReleaseDC,[hWnd],[hDC]
@@:
  ret
endp

proc LockCursor
  invoke GetClientRect,[hWnd],lockRect
  mov eax,[lockRect.left]
  mov [lockTL.x],eax
  mov eax,[lockRect.top]
  mov [lockTL.y],eax
  mov eax,[lockRect.right]
  mov [lockBR.x],eax
  mov eax,[lockRect.bottom]
  mov [lockBR.y],eax

  invoke ClientToScreen,[hWnd],lockTL
  invoke ClientToScreen,[hWnd],lockBR

  mov eax,[lockTL.x]
  mov [lockRect.left],eax
  mov eax,[lockTL.y]
  mov [lockRect.top],eax
  mov eax,[lockBR.x]
  mov [lockRect.right],eax
  mov eax,[lockBR.y]
  mov [lockRect.bottom],eax

  ; center cursor into client area
  mov eax,[lockRect.left]
  add eax,[lockRect.right]
  shr eax,1
  mov [centerPt.x],eax
  mov eax,[lockRect.top]
  add eax,[lockRect.bottom]
  shr eax,1
  mov [centerPt.y],eax
  invoke SetCursorPos,[centerPt.x],[centerPt.y]

  invoke ClipCursor,lockRect
  invoke ShowCursor,FALSE
  ret
endp

proc UnlockCursor
  invoke ClipCursor,0
  invoke ShowCursor,TRUE
  ret
endp

proc UpdateDelta
  invoke GetTickCount
  mov ecx,[lastTick]
  mov [lastTick],eax
  sub eax,ecx
  cmp eax,50
  jbe @f
  mov eax,50
@@:
  mov [msTemp],eax
  fild [msTemp]
  fidiv [thousand]
  fstp [deltaT]
  ret
endp

proc UpdatePlayer
  ; mouse look (cursor is clipped to window and re-centered)
  invoke GetCursorPos,lockTL
  mov eax,[lockTL.x]
  sub eax,[centerPt.x]
  mov [tmpForward],eax
  mov eax,[lockTL.y]
  sub eax,[centerPt.y]
  mov [tmpStrafe],eax

  cmp dword [tmpForward],0
  jne .mouse_apply
  cmp dword [tmpStrafe],0
  je .keyboard_look

.mouse_apply:
  fild [tmpForward]
  fmul [mouseSensYaw]
  fadd [camYaw]
  fstp [camYaw]

  fild [tmpStrafe]
  fmul [mouseSensPitch]
  fsubr [camPitch]
  fstp [camPitch]

  invoke SetCursorPos,[centerPt.x],[centerPt.y]

.keyboard_look:
  ; look left/right
  invoke GetAsyncKeyState,VK_LEFT
  mov [keyTmp],ax
  test word [keyTmp],8000h
  jz @f
  fld [turnSpeed]
  fmul [deltaT]
  fsub [camYaw]
  fstp [camYaw]
@@:
  invoke GetAsyncKeyState,VK_RIGHT
  mov [keyTmp],ax
  test word [keyTmp],8000h
  jz @f
  fld [turnSpeed]
  fmul [deltaT]
  fadd [camYaw]
  fstp [camYaw]
@@:

  ; look up/down
  invoke GetAsyncKeyState,VK_UP
  mov [keyTmp],ax
  test word [keyTmp],8000h
  jz @f
  fld [lookSpeed]
  fmul [deltaT]
  fsub [camPitch]
  fstp [camPitch]
@@:
  invoke GetAsyncKeyState,VK_DOWN
  mov [keyTmp],ax
  test word [keyTmp],8000h
  jz @f
  fld [lookSpeed]
  fmul [deltaT]
  fadd [camPitch]
  fstp [camPitch]
@@:

  ; clamp pitch
  fld [camPitch]
  fistp [tmpPitchI]
  mov eax,[tmpPitchI]
  cmp eax,80
  jle @f
  mov eax,[f80]
  mov [camPitch],eax
@@:
  cmp eax,-80
  jge @f
  mov eax,[fNeg80]
  mov [camPitch],eax
@@:

  ; movement input
  xor ecx,ecx
  invoke GetAsyncKeyState,VK_W
  mov [keyTmp],ax
  test word [keyTmp],8000h
  jz @f
  inc ecx
@@:
  invoke GetAsyncKeyState,VK_S
  mov [keyTmp],ax
  test word [keyTmp],8000h
  jz @f
  dec ecx
@@:
  mov [tmpForward],ecx

  xor ecx,ecx
  invoke GetAsyncKeyState,VK_D
  mov [keyTmp],ax
  test word [keyTmp],8000h
  jz @f
  inc ecx
@@:
  invoke GetAsyncKeyState,VK_A
  mov [keyTmp],ax
  test word [keyTmp],8000h
  jz @f
  dec ecx
@@:
  mov [tmpStrafe],ecx

  ; speed
  fld [walkSpeed]
  invoke GetAsyncKeyState,VK_SHIFT
  mov [keyTmp],ax
  test word [keyTmp],8000h
  jz @f
  fmul [runMult]
@@:
  invoke GetAsyncKeyState,VK_CONTROL
  mov [keyTmp],ax
  test word [keyTmp],8000h
  jz .not_crouch
  fmul [crouchMult]
  fld [crouchEyeY]
  fstp [eyeY]
  jmp .speed_done
.not_crouch:
  fld [baseEyeY]
  fstp [eyeY]
.speed_done:
  fstp [tmpSpeed]

  ; jump input
  invoke GetAsyncKeyState,VK_SPACE
  mov [keyTmp],ax
  test word [keyTmp],8000h
  jz .physics
  fld [jumpOffset]
  fistp [tmpPitchI]
  cmp dword [tmpPitchI],0
  jne .physics
  fld [jumpVel]
  fstp [velY]

.physics:
  ; velY -= gravity * dt
  fld [gravity]
  fmul [deltaT]
  fsubr [velY]
  fstp [velY]

  ; jumpOffset += velY * dt
  fld [velY]
  fmul [deltaT]
  fadd [jumpOffset]
  fstp [jumpOffset]

  ; clamp ground
  fld [jumpOffset]
  fistp [tmpPitchI]
  cmp dword [tmpPitchI],0
  jge @f
  fldz
  fstp [jumpOffset]
  fldz
  fstp [velY]
@@:

  ; sin/cos yaw
  fld [camYaw]
  fmul [deg2rad]
  fst [tmpAngle]
  fsin
  fstp [sinYaw]
  fld [tmpAngle]
  fcos
  fstp [cosYaw]

  ; if no move, done
  cmp dword [tmpForward],0
  jne .do_move
  cmp dword [tmpStrafe],0
  jne .do_move
  ret

.do_move:
  ; camX += (sin*forward + cos*strafe) * speed * dt
  fld [sinYaw]
  fild [tmpForward]
  fmulp st1,st0
  fld [cosYaw]
  fild [tmpStrafe]
  fmulp st1,st0
  faddp st1,st0
  fmul [tmpSpeed]
  fmul [deltaT]
  fadd [camX]
  fstp [camX]

  ; camZ += (cos*forward - sin*strafe) * speed * dt
  fld [cosYaw]
  fild [tmpForward]
  fmulp st1,st0
  fld [sinYaw]
  fild [tmpStrafe]
  fmulp st1,st0
  fsubp st1,st0
  fmul [tmpSpeed]
  fmul [deltaT]
  fadd [camZ]
  fstp [camZ]

  ret
endp

proc RenderScene
  local i:DWORD
  local j:DWORD
  local parity:DWORD

  invoke GetClientRect,[hWnd],rc
  invoke glViewport,0,0,[rc.right],[rc.bottom]
  invoke glClear,GL_COLOR_BUFFER_BIT + GL_DEPTH_BUFFER_BIT

  ; projection
  invoke glMatrixMode,GL_PROJECTION
  invoke glLoadIdentity
  call ApplyProjection

  ; view transform (FPS camera)
  invoke glMatrixMode,GL_MODELVIEW
  invoke glLoadIdentity

  ; always-visible reference slab (camera-local), so orientation is never fully black
  invoke glPushMatrix
  invoke glTranslatef,[fZero],[fZero],[fDbgZ]
  invoke glBegin,GL_QUADS
  invoke glColor3f,[colLightR],[colLightG],[colLightB]
  invoke glVertex3f,[fDbgLeft],[fDbgBottom],[fZero]
  invoke glVertex3f,[fDbgRight],[fDbgBottom],[fZero]
  invoke glVertex3f,[fDbgRight],[fDbgTop],[fZero]
  invoke glVertex3f,[fDbgLeft],[fDbgTop],[fZero]
  invoke glEnd
  invoke glBegin,GL_LINES
  invoke glColor3f,[fZero],[fZero],[fZero]
  invoke glVertex3f,[fDbgLeft],[fCrossZero],[fZero]
  invoke glVertex3f,[fDbgRight],[fCrossZero],[fZero]
  invoke glVertex3f,[fCrossZero],[fDbgBottom],[fZero]
  invoke glVertex3f,[fCrossZero],[fDbgTop],[fZero]
  invoke glEnd
  invoke glPopMatrix

  ; keep pitch neutral for stability for now; yaw still active
  ; fld [camPitch]
  ; fstp [tmpX]
  ; invoke glRotatef,[tmpX],[fAxisX],[fAxisY],[fAxisZ]

  fld [camYaw]
  fchs
  fstp [tmpX]
  invoke glRotatef,[tmpX],[fUpX],[fUpY],[fUpZ]

  fld [camX]
  fchs
  fstp [tmpX]
  fld [eyeY]
  fadd [jumpOffset]
  fchs
  fstp [tmpEye]
  fld [camZ]
  fchs
  fstp [tmpZ]
  invoke glTranslatef,[tmpX],[tmpEye],[tmpZ]

  ; world axes for orientation
  invoke glBegin,GL_LINES
  invoke glColor3f,[fOne],[fZero],[fZero]
  invoke glVertex3f,[fNegTen],[fZero],[fZero]
  invoke glVertex3f,[fTen],[fZero],[fZero]
  invoke glColor3f,[fZero],[fOne],[fZero]
  invoke glVertex3f,[fZero],[fZero],[fNegTen]
  invoke glVertex3f,[fZero],[fZero],[fTen]
  invoke glEnd

  ; checker floor y=0, x/z range [-30..30]
  mov [i],-30
.y_loop:
  mov eax,[i]
  cmp eax,30
  jg .draw_cross

  mov [j],-30
.x_loop:
  mov eax,[j]
  cmp eax,30
  jg .next_row

  mov eax,[i]
  add eax,[j]
  and eax,1
  mov [parity],eax
  cmp eax,0
  jne .dark
  invoke glColor3f,[colLightR],[colLightG],[colLightB]
  jmp .tile
.dark:
  invoke glColor3f,[colDarkR],[colDarkG],[colDarkB]

.tile:
  invoke glBegin,GL_QUADS

  fild [j]
  fstp [tmpX]
  fild [i]
  fstp [tmpZ]
  invoke glVertex3f,[tmpX],[fZero],[tmpZ]

  fild [j]
  fadd [fOne]
  fstp [tmpX]
  fild [i]
  fstp [tmpZ]
  invoke glVertex3f,[tmpX],[fZero],[tmpZ]

  fild [j]
  fadd [fOne]
  fstp [tmpX]
  fild [i]
  fadd [fOne]
  fstp [tmpZ]
  invoke glVertex3f,[tmpX],[fZero],[tmpZ]

  fild [j]
  fstp [tmpX]
  fild [i]
  fadd [fOne]
  fstp [tmpZ]
  invoke glVertex3f,[tmpX],[fZero],[tmpZ]

  invoke glEnd

  inc [j]
  jmp .x_loop

.next_row:
  inc [i]
  jmp .y_loop

.draw_cross:
  ; 2D crosshair overlay
  invoke glMatrixMode,GL_PROJECTION
  invoke glPushMatrix
  invoke glLoadIdentity
  invoke glMatrixMode,GL_MODELVIEW
  invoke glPushMatrix
  invoke glLoadIdentity

  invoke glDisable,GL_DEPTH_TEST
  invoke glColor3f,[fLineColor],[fLineColor],[fLineColor]
  invoke glBegin,GL_LINES
  invoke glVertex3f,[fLineA],[fCrossZero],[fCrossZero]
  invoke glVertex3f,[fLineB],[fCrossZero],[fCrossZero]
  invoke glVertex3f,[fCrossZero],[fLineA],[fCrossZero]
  invoke glVertex3f,[fCrossZero],[fLineB],[fCrossZero]
  invoke glEnd
  invoke glEnable,GL_DEPTH_TEST

  invoke glPopMatrix
  invoke glMatrixMode,GL_PROJECTION
  invoke glPopMatrix
  invoke glMatrixMode,GL_MODELVIEW

  invoke SwapBuffers,[hDC]
  ret
endp

proc ApplyProjection
  ; glFrustum(left,right,bottom,top,near,far) with qword args
  push dword [projFar+4]
  push dword [projFar]
  push dword [projNear+4]
  push dword [projNear]
  push dword [projTop+4]
  push dword [projTop]
  push dword [projBottom+4]
  push dword [projBottom]
  push dword [projRight+4]
  push dword [projRight]
  push dword [projLeft+4]
  push dword [projLeft]
  call [glFrustum]
  ret
endp

proc WndProc hwnd,wmsg,wparam,lparam
  cmp [wmsg],WM_CREATE
  je .wmcreate
  cmp [wmsg],WM_SETFOCUS
  je .wmsetfocus
  cmp [wmsg],WM_KILLFOCUS
  je .wmkillfocus
  cmp [wmsg],WM_TIMER
  je .wmtimer
  cmp [wmsg],WM_PAINT
  je .wmpaint
  cmp [wmsg],WM_DESTROY
  je .wmdestroy

  invoke DefWindowProc,[hwnd],[wmsg],[wparam],[lparam]
  ret

.wmcreate:
  mov eax,[hwnd]
  mov [hWnd],eax
  call InitGL
  test eax,eax
  jnz @f
  invoke PostQuitMessage,1
@@:
  xor eax,eax
  ret

.wmsetfocus:
  call LockCursor
  xor eax,eax
  ret

.wmkillfocus:
  call UnlockCursor
  xor eax,eax
  ret

.wmtimer:
  invoke InvalidateRect,[hWnd],0,FALSE
  xor eax,eax
  ret

.wmpaint:
  invoke BeginPaint,[hWnd],ps
  call UpdateDelta
  call UpdatePlayer
  call RenderScene
  invoke EndPaint,[hWnd],ps
  xor eax,eax
  ret

.wmdestroy:
  call ShutdownGL
  invoke PostQuitMessage,0
  xor eax,eax
  ret
endp

section '.bss' readable writeable
  thousand dd 1000

section '.idata' import data readable writeable
  library kernel,'KERNEL32.DLL',\
          user,'USER32.DLL',\
          gdi,'GDI32.DLL',\
          opengl,'OPENGL32.DLL'

  import kernel,\
         GetModuleHandle,'GetModuleHandleA',\
         GetTickCount,'GetTickCount',\
         ExitProcess,'ExitProcess'

  import user,\
         RegisterClassEx,'RegisterClassExA',\
         CreateWindowEx,'CreateWindowExA',\
         DefWindowProc,'DefWindowProcA',\
         GetMessage,'GetMessageA',\
         TranslateMessage,'TranslateMessage',\
         DispatchMessage,'DispatchMessageA',\
         LoadCursor,'LoadCursorA',\
         LoadIcon,'LoadIconA',\
         GetClientRect,'GetClientRect',\
         BeginPaint,'BeginPaint',\
         EndPaint,'EndPaint',\
         InvalidateRect,'InvalidateRect',\
         SetTimer,'SetTimer',\
         KillTimer,'KillTimer',\
         ClientToScreen,'ClientToScreen',\
         GetCursorPos,'GetCursorPos',\
         SetCursorPos,'SetCursorPos',\
         ClipCursor,'ClipCursor',\
         ShowCursor,'ShowCursor',\
         GetAsyncKeyState,'GetAsyncKeyState',\
         PostQuitMessage,'PostQuitMessage',\
         GetDC,'GetDC',\
         ReleaseDC,'ReleaseDC'

  import gdi,\
         ChoosePixelFormat,'ChoosePixelFormat',\
         SetPixelFormat,'SetPixelFormat',\
         SwapBuffers,'SwapBuffers'

  import opengl,\
         wglCreateContext,'wglCreateContext',\
         wglMakeCurrent,'wglMakeCurrent',\
         wglDeleteContext,'wglDeleteContext',\
         glViewport,'glViewport',\
         glClearColor,'glClearColor',\
         glClear,'glClear',\
         glEnable,'glEnable',\
         glDisable,'glDisable',\
         glMatrixMode,'glMatrixMode',\
         glLoadIdentity,'glLoadIdentity',\
         glFrustum,'glFrustum',\
         glRotatef,'glRotatef',\
         glTranslatef,'glTranslatef',\
         glColor3f,'glColor3f',\
         glBegin,'glBegin',\
         glVertex3f,'glVertex3f',\
         glEnd,'glEnd',\
         glPushMatrix,'glPushMatrix',\
         glPopMatrix,'glPopMatrix'

section '.reloc' fixups data readable discardable
