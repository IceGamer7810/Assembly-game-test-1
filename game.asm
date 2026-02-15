format PE GUI 4.0
entry start

include 'tools\INCLUDE\win32ax.inc'

WM_MOUSEMOVE = 0200h

; OpenGL constants
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

VK_W = 57
VK_A = 65
VK_S = 83
VK_D = 68

section '.data' data readable writeable
  className db 'AsmFps3DClass',0
  windowTitle db 'Assembly FPS 3D - Win10',0

  hWnd dd 0
  hDC dd 0
  hRC dd 0
  running dd 1

  lastTick dd 0
  deltaT dd 0.016

  camX dd 0.0
  camZ dd 0.0
  camYaw dd 0.0            ; degrees
  camPitch dd -2.0         ; degrees
  jumpOffset dd 0.0
  velY dd 0.0

  baseEyeY dd 1.65
  crouchEyeY dd 1.05
  eyeY dd 1.65

  walkSpeed dd 4.3
  runMult dd 1.9
  crouchMult dd 0.52
  gravity dd 26.0
  jumpVel dd 8.6

  mouseSensYaw dd 0.12
  mouseSensPitch dd 0.09

  deg2rad dd 0.0174532925

  tmpForward dd 0
  tmpStrafe dd 0
  tmpPitchI dd 0
  tmpSpeed dd 0.0
  tmpFloat dd 0.0
  sinYaw dd 0.0
  cosYaw dd 0.0

  centerX dd 0
  centerY dd 0

  msg MSG
  wc WNDCLASSEX
  pfd PIXELFORMATDESCRIPTOR

  floorRange dd 22
  floorY dd 0.0

  colDarkR dd 0.22
  colDarkG dd 0.35
  colDarkB dd 0.58
  colLightR dd 0.92
  colLightG dd 0.92
  colLightB dd 0.92

  fNegOne dd -1.0
  fZero dd 0.0
  fOne dd 1.0
  fLineGap dd 0.02
  fLineLen dd 0.05
  fCrossZ dd 0.0
  fCrossColor dd 1.0
  thousand dd 1000
  f80 dd 80.0
  fNeg80 dd -80.0
  fHalf dd 0.5

  keyState dd 0

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

  invoke CreateWindowEx,0,className,windowTitle,WS_OVERLAPPEDWINDOW + WS_VISIBLE,120,80,1280,720,NULL,NULL,ebx,NULL
  test eax,eax
  jz .exit
  mov [hWnd],eax

  invoke GetDC,eax
  mov [hDC],eax

  ; Pixel format setup for OpenGL
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
  jz .destroy
  mov esi,eax
  invoke SetPixelFormat,[hDC],esi,pfd
  test eax,eax
  jz .destroy

  invoke wglCreateContext,[hDC]
  test eax,eax
  jz .destroy
  mov [hRC],eax

  invoke wglMakeCurrent,[hDC],[hRC]
  test eax,eax
  jz .destroy

  invoke ShowWindow,[hWnd],SW_SHOW
  invoke UpdateWindow,[hWnd]

  invoke glClearColor,0.0,0.0,0.0,1.0
  invoke glEnable,GL_DEPTH_TEST

  invoke GetTickCount
  mov [lastTick],eax

.main_loop:
  cmp [running],0
  je .cleanup

.msg_loop:
  invoke PeekMessage,msg,NULL,0,0,PM_REMOVE
  test eax,eax
  jz .update
  cmp [msg.message],WM_QUIT
  je .quit
  invoke TranslateMessage,msg
  invoke DispatchMessage,msg
  jmp .msg_loop

.update:
  call UpdateDelta
  call UpdateMouseLook
  call UpdateMovement
  call RenderFrame
  invoke SwapBuffers,[hDC]
  invoke Sleep,1
  jmp .main_loop

.quit:
  mov [running],0

.cleanup:
  invoke wglMakeCurrent,0,0
  cmp [hRC],0
  je @f
  invoke wglDeleteContext,[hRC]
@@:
  cmp [hWnd],0
  je .exit
  cmp [hDC],0
  je @f
  invoke ReleaseDC,[hWnd],[hDC]
@@:
  invoke DestroyWindow,[hWnd]

.exit:
  invoke ExitProcess,0

.destroy:
  mov [running],0
  jmp .cleanup

proc UpdateDelta
  invoke GetTickCount
  mov ecx,[lastTick]
  mov [lastTick],eax
  sub eax,ecx
  cmp eax,50
  jbe @f
  mov eax,50
@@:
  mov [tmpForward],eax
  fild [tmpForward]
  fidiv [thousand]
  fstp [deltaT]
  ret
endp

proc UpdateMouseLook
  invoke GetClientRect,[hWnd],clientRect
  mov eax,[clientRect.right]
  shr eax,1
  mov [centerX],eax
  mov eax,[clientRect.bottom]
  shr eax,1
  mov [centerY],eax

  mov eax,[centerX]
  mov [mousePoint.x],eax
  mov eax,[centerY]
  mov [mousePoint.y],eax
  invoke ClientToScreen,[hWnd],mousePoint

  invoke GetCursorPos,cursorPoint

  mov eax,[cursorPoint.x]
  sub eax,[mousePoint.x]
  mov [tmpForward],eax

  mov eax,[cursorPoint.y]
  sub eax,[mousePoint.y]
  mov [tmpStrafe],eax

  cmp [tmpForward],0
  jne .apply
  cmp [tmpStrafe],0
  je .recenter

.apply:
  ; yaw += dx * sens
  fild [tmpForward]
  fmul [mouseSensYaw]
  fadd [camYaw]
  fstp [camYaw]

  ; pitch -= dy * sens
  fild [tmpStrafe]
  fmul [mouseSensPitch]
  fsubr [camPitch]
  fstp [camPitch]

  ; clamp pitch [-80,80]
  fld [camPitch]
  fistp [tmpPitchI]
  mov eax,[tmpPitchI]
  cmp eax,80
  jg .set_hi
  cmp eax,-80
  jl .set_lo
  jmp .recenter

.set_hi:
  fstp st0
  mov eax,[f80]
  mov [camPitch],eax
  jmp .recenter

.set_lo:
  fstp st0
  mov eax,[fNeg80]
  mov [camPitch],eax

.recenter:
  invoke SetCursorPos,[mousePoint.x],[mousePoint.y]
  ret
endp

proc UpdateMovement
  ; forward input
  xor ecx,ecx
  invoke GetAsyncKeyState,VK_W
  test ax,8000h
  jz @f
  inc ecx
@@:
  invoke GetAsyncKeyState,VK_S
  test ax,8000h
  jz @f
  dec ecx
@@:
  mov [tmpForward],ecx

  ; strafe input
  xor ecx,ecx
  invoke GetAsyncKeyState,VK_D
  test ax,8000h
  jz @f
  inc ecx
@@:
  invoke GetAsyncKeyState,VK_A
  test ax,8000h
  jz @f
  dec ecx
@@:
  mov [tmpStrafe],ecx

  ; speed
  fld [walkSpeed]
  invoke GetAsyncKeyState,VK_SHIFT
  test ax,8000h
  jz @f
  fmul [runMult]
@@:
  invoke GetAsyncKeyState,VK_CONTROL
  test ax,8000h
  jz @f
  fmul [crouchMult]
  fld [crouchEyeY]
  fstp [eyeY]
  jmp .speed_done
@@:
  fld [baseEyeY]
  fstp [eyeY]
.speed_done:
  fstp [tmpSpeed]

  ; jump
  invoke GetAsyncKeyState,VK_SPACE
  test ax,8000h
  jz .physics
  fld [jumpOffset]
  fldz
  fcomip st0,st1
  jne @f
  fstp st0
  fld [jumpVel]
  fstp [velY]
  jmp .physics
@@:
  fstp st0

.physics:
  ; velY -= gravity*dt
  fld [gravity]
  fmul [deltaT]
  fsubr [velY]
  fstp [velY]

  ; jumpOffset += velY*dt
  fld [velY]
  fmul [deltaT]
  fadd [jumpOffset]
  fstp [jumpOffset]

  ; ground clamp
  fld [jumpOffset]
  fldz
  fcomip st0,st1
  jae @f
  fstp st0
  fldz
  fstp [jumpOffset]
  fstp [velY]
@@:
  fstp st0

  ; yaw in rad
  fld [camYaw]
  fmul [deg2rad]
  fsincos
  fstp [cosYaw]
  fstp [sinYaw]

  ; move if input
  cmp [tmpForward],0
  jne .move
  cmp [tmpStrafe],0
  jne .move
  ret

.move:
  ; deltaX = (sinYaw*forward + cosYaw*strafe)*speed*dt
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

  ; deltaZ = (cosYaw*forward - sinYaw*strafe)*speed*dt
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

proc RenderFrame
  local i:DWORD
  local j:DWORD
  local parity:DWORD

  invoke glViewport,0,0,[clientW],[clientH]
  invoke glClear,GL_COLOR_BUFFER_BIT + GL_DEPTH_BUFFER_BIT

  invoke glMatrixMode,GL_PROJECTION
  invoke glLoadIdentity
  call gluPerspectiveCompat

  invoke glMatrixMode,GL_MODELVIEW
  invoke glLoadIdentity

  ; Camera transform
  fld [camPitch]
  fchs
  fstp [tmpFloat]
  invoke glRotatef,[tmpFloat],1.0,0.0,0.0

  fld [camYaw]
  fchs
  fstp [tmpFloat]
  invoke glRotatef,[tmpFloat],0.0,1.0,0.0

  fld [camX]
  fchs
  fstp [tmpFloat]
  fld [eyeY]
  fadd [jumpOffset]
  fchs
  fstp [tmpSpeed]
  fld [camZ]
  fchs
  fstp [sinYaw]
  invoke glTranslatef,[tmpFloat],[tmpSpeed],[sinYaw]

  ; Floor checker quads
  mov [i],-22
.y_loop:
  mov eax,[i]
  cmp eax,22
  jg .floor_done

  mov [j],-22
.x_loop:
  mov eax,[j]
  cmp eax,22
  jg .next_row

  mov eax,[i]
  add eax,[j]
  and eax,1
  mov [parity],eax
  cmp eax,0
  jne .dark

  invoke glColor3f,[colLightR],[colLightG],[colLightB]
  jmp .draw_tile

.dark:
  invoke glColor3f,[colDarkR],[colDarkG],[colDarkB]

.draw_tile:
  invoke glBegin,GL_QUADS

  fild [j]
  fstp [tmpFloat]
  fild [i]
  fstp [tmpSpeed]
  invoke glVertex3f,[tmpFloat],[floorY],[tmpSpeed]

  fild [j]
  fadd [fOne]
  fstp [tmpFloat]
  fild [i]
  fstp [tmpSpeed]
  invoke glVertex3f,[tmpFloat],[floorY],[tmpSpeed]

  fild [j]
  fadd [fOne]
  fstp [tmpFloat]
  fild [i]
  fadd [fOne]
  fstp [tmpSpeed]
  invoke glVertex3f,[tmpFloat],[floorY],[tmpSpeed]

  fild [j]
  fstp [tmpFloat]
  fild [i]
  fadd [fOne]
  fstp [tmpSpeed]
  invoke glVertex3f,[tmpFloat],[floorY],[tmpSpeed]

  invoke glEnd

  inc [j]
  jmp .x_loop

.next_row:
  inc [i]
  jmp .y_loop

.floor_done:
  ; Crosshair overlay in screen center
  invoke glMatrixMode,GL_PROJECTION
  invoke glPushMatrix
  invoke glLoadIdentity
  invoke glMatrixMode,GL_MODELVIEW
  invoke glPushMatrix
  invoke glLoadIdentity

  invoke glDisable,GL_DEPTH_TEST
  invoke glColor3f,[fCrossColor],[fCrossColor],[fCrossColor]
  invoke glBegin,GL_LINES

  invoke glVertex3f,[fNegOne],[fZero],[fCrossZ] ; dummy to prime fp stack stable behavior

  ; left
  invoke glVertex3f,-0.05,0.0,0.0
  invoke glVertex3f,-0.02,0.0,0.0
  ; right
  invoke glVertex3f,0.02,0.0,0.0
  invoke glVertex3f,0.05,0.0,0.0
  ; top
  invoke glVertex3f,0.0,0.05,0.0
  invoke glVertex3f,0.0,0.02,0.0
  ; bottom
  invoke glVertex3f,0.0,-0.02,0.0
  invoke glVertex3f,0.0,-0.05,0.0

  invoke glEnd
  invoke glEnable,GL_DEPTH_TEST

  invoke glPopMatrix
  invoke glMatrixMode,GL_PROJECTION
  invoke glPopMatrix
  invoke glMatrixMode,GL_MODELVIEW

  ret
endp

proc gluPerspectiveCompat
  ; cheap perspective frustum via glFrustum(-a,a,-1,1,1,200)
  local aspect:DWORD
  fild [clientW]
  fild [clientH]
  fdivp st1,st0
  fstp [tmpFloat]

  ; left/right based on aspect and fov-ish scale
  fld [tmpFloat]
  fmul [fHalf]
  fstp [tmpSpeed]

  fld [tmpSpeed]
  fchs
  fstp [sinYaw]   ; left
  fld [tmpSpeed]
  fstp [cosYaw]   ; right

  invoke glFrustum,[sinYaw],[cosYaw],-0.5,0.5,1.0,200.0
  ret
endp

proc WndProc hwnd,wmsg,wparam,lparam
  cmp [wmsg],WM_DESTROY
  je .wmdestroy
  cmp [wmsg],WM_SIZE
  je .wmsize
  cmp [wmsg],WM_SETFOCUS
  je .focus
  cmp [wmsg],WM_KILLFOCUS
  je .killfocus
  invoke DefWindowProc,[hwnd],[wmsg],[wparam],[lparam]
  ret

.wmsize:
  mov eax,[lparam]
  and eax,0FFFFh
  mov [clientW],eax
  mov eax,[lparam]
  shr eax,16
  test eax,eax
  jnz @f
  mov eax,1
@@:
  mov [clientH],eax
  xor eax,eax
  ret

.focus:
  invoke ShowCursor,FALSE
  xor eax,eax
  ret

.killfocus:
  invoke ShowCursor,TRUE
  xor eax,eax
  ret

.wmdestroy:
  mov [running],0
  invoke PostQuitMessage,0
  xor eax,eax
  ret
endp

section '.bss' readable writeable
  mousePoint POINT
  cursorPoint POINT
  clientRect RECT
  clientW dd 1280
  clientH dd 720

section '.idata' import data readable writeable
  library kernel,'KERNEL32.DLL',\
          user,'USER32.DLL',\
          gdi,'GDI32.DLL',\
          opengl,'OPENGL32.DLL'

  import kernel,\
         GetModuleHandle,'GetModuleHandleA',\
         GetTickCount,'GetTickCount',\
         Sleep,'Sleep',\
         ExitProcess,'ExitProcess'

  import user,\
         RegisterClassEx,'RegisterClassExA',\
         CreateWindowEx,'CreateWindowExA',\
         DefWindowProc,'DefWindowProcA',\
         ShowWindow,'ShowWindow',\
         UpdateWindow,'UpdateWindow',\
         PeekMessage,'PeekMessageA',\
         TranslateMessage,'TranslateMessage',\
         DispatchMessage,'DispatchMessageA',\
         PostQuitMessage,'PostQuitMessage',\
         LoadIcon,'LoadIconA',\
         LoadCursor,'LoadCursorA',\
         DestroyWindow,'DestroyWindow',\
         GetClientRect,'GetClientRect',\
         ClientToScreen,'ClientToScreen',\
         GetCursorPos,'GetCursorPos',\
         SetCursorPos,'SetCursorPos',\
         GetAsyncKeyState,'GetAsyncKeyState',\
         ShowCursor,'ShowCursor',\
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
