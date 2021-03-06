! Copyright (C) 2006 Chris Double.
! See http://factorcode.org/license.txt for BSD license.
!
USING: 
    accessors
    alien.c-types
    alien.data
    arrays
    byte-arrays
    calendar
    combinators
    cpu.8080 
    cpu.8080.emulator
    io.files
    io.pathnames
    kernel 
    locals
    math
    math.order
    openal
    openal.alut
    opengl.gl
    sequences
    ui
    ui.gadgets
    ui.gestures
    ui.render
    specialized-arrays
;
QUALIFIED: threads
QUALIFIED: system
SPECIALIZED-ARRAY: uchar
IN: space-invaders

TUPLE: space-invaders < cpu port1 port2i port2o port3o port4lo port4hi port5o bitmap sounds looping? ;
CONSTANT: game-width 224
CONSTANT: game-height 256

: make-opengl-bitmap ( -- array )
  game-height game-width 3 * * uchar <c-array> ;

: bitmap-index ( point -- index )
  #! Point is a {x y}.
  first2 game-width 3 * * swap 3 * + ;

:: set-bitmap-pixel ( bitmap point color -- )
    point bitmap-index :> index
    color first  index     bitmap set-nth
    color second index 1 + bitmap set-nth
    color third  index 2 + bitmap set-nth ;

: get-bitmap-pixel ( point array -- color )
  #! Point is a {x y}. color is a {r g b} 
  [ bitmap-index ] dip
  [ nth ] 2keep
  [ [ 1 + ] dip nth ] 2keep
  [ 2 + ] dip nth 3array ;
  
CONSTANT: SOUND-SHOT         0 
CONSTANT: SOUND-UFO          1 
CONSTANT: SOUND-BASE-HIT     2 
CONSTANT: SOUND-INVADER-HIT  3 
CONSTANT: SOUND-WALK1        4 
CONSTANT: SOUND-WALK2        5
CONSTANT: SOUND-WALK3        6 
CONSTANT: SOUND-WALK4        7 
CONSTANT: SOUND-UFO-HIT      8 

: init-sound ( index cpu filename  -- )
  absolute-path swapd [ sounds>> nth AL_BUFFER ] dip
  create-buffer-from-wav set-source-param ; 

: init-sounds ( cpu -- )
  init-openal
  [ 9 gen-sources swap sounds<< ] keep
  [ SOUND-SHOT        "vocab:space-invaders/resources/Shot.wav" init-sound ] keep 
  [ SOUND-UFO         "vocab:space-invaders/resources/Ufo.wav" init-sound ] keep 
  [ sounds>> SOUND-UFO swap nth AL_LOOPING AL_TRUE set-source-param ] keep
  [ SOUND-BASE-HIT    "vocab:space-invaders/resources/BaseHit.wav" init-sound ] keep 
  [ SOUND-INVADER-HIT "vocab:space-invaders/resources/InvHit.Wav" init-sound ] keep 
  [ SOUND-WALK1       "vocab:space-invaders/resources/Walk1.wav" init-sound ] keep 
  [ SOUND-WALK2       "vocab:space-invaders/resources/Walk2.wav" init-sound ] keep 
  [ SOUND-WALK3       "vocab:space-invaders/resources/Walk3.wav" init-sound ] keep 
  [ SOUND-WALK4       "vocab:space-invaders/resources/Walk4.wav" init-sound ] keep 
  [ SOUND-UFO-HIT    "vocab:space-invaders/resources/UfoHit.wav" init-sound ] keep
  f swap looping?<< ;

: cpu-init ( cpu -- cpu )
  make-opengl-bitmap over bitmap<<
  [ init-sounds ] keep
  [ reset ] keep ;

: <space-invaders> ( -- cpu )
  space-invaders new cpu-init ;

: play-invaders-sound ( cpu sound -- )
  swap sounds>> nth source-play ;

: stop-invaders-sound ( cpu sound -- )
  swap sounds>> nth source-stop ;

: read-port1 ( cpu -- byte )
  #! Port 1 maps the keys for space invaders
  #! Bit 0 = coin slot
  #! Bit 1 = two players button
  #! Bit 2 = one player button
  #! Bit 4 = player one fire
  #! Bit 5 = player one left
  #! Bit 6 = player one right
  [ port1>> dup 0xFE bitand ] keep 
 port1<< ;

: read-port2 ( cpu -- byte )
  #! Port 2 maps player 2 controls and dip switches
  #! Bit 0,1 = number of ships
  #! Bit 2   = mode (1=easy, 0=hard)
  #! Bit 4   = player two fire
  #! Bit 5   = player two left
  #! Bit 6   = player two right
  #! Bit 7   = show or hide coin info
  [ port2i>> 0x8F bitand ] keep 
  port1>> 0x70 bitand bitor ;

: read-port3 ( cpu -- byte )
  #! Used to compute a special formula
  [ port4hi>> 8 shift ] keep 
  [ port4lo>> bitor ] keep 
  port2o>> shift -8 shift 0xFF bitand ;

M: space-invaders read-port ( port cpu -- byte )
  #! Read a byte from the hardware port. 'port' should
  #! be an 8-bit value.
  swap {
    { 1 [ read-port1 ] }
    { 2 [ read-port2 ] }
    { 3 [ read-port3 ] }
    [ 2drop 0 ]
  } case ;

: write-port2 ( value cpu -- )
  #! Setting this value affects the value read from port 3
  port2o<< ;

:: bit-newly-set? ( old-value new-value bit -- bool )
  new-value bit bit? [ old-value bit bit? not ] dip and ;

: port3-newly-set? ( new-value cpu bit -- bool )
  [ port3o>> swap ] dip bit-newly-set? ;

: port5-newly-set? ( new-value cpu bit -- bool )
  [ port5o>> swap ] dip bit-newly-set? ;

: write-port3 ( value cpu -- )
  #! Connected to the sound hardware
  #! Bit 0 = spaceship sound (looped)
  #! Bit 1 = Shot 
  #! Bit 2 = Your ship hit
  #! Bit 3 = Invader hit
  #! Bit 4 = Extended play sound
  over 0 bit? over looping?>> not and [ 
    dup SOUND-UFO play-invaders-sound 
    t over looping?<<
  ] when 
  over 0 bit? not over looping?>> and [ 
    dup SOUND-UFO stop-invaders-sound 
    f over looping?<<
  ] when 
  2dup 0 port3-newly-set? [ dup SOUND-UFO  play-invaders-sound ] when
  2dup 1 port3-newly-set? [ dup SOUND-SHOT play-invaders-sound ] when
  2dup 2 port3-newly-set? [ dup SOUND-BASE-HIT play-invaders-sound ] when
  2dup 3 port3-newly-set? [ dup SOUND-INVADER-HIT play-invaders-sound ] when
  port3o<< ;

: write-port4 ( value cpu -- )
  #! Affects the value returned by reading port 3
  [ port4hi>> ] keep 
  [ port4lo<< ] keep 
  port4hi<< ;

: write-port5 ( value cpu -- )
  #! Plays sounds
  #! Bit 0 = invaders sound 1
  #! Bit 1 = invaders sound 2
  #! Bit 2 = invaders sound 3
  #! Bit 3 = invaders sound 4
  #! Bit 4 = spaceship hit 
  #! Bit 5 = amplifier enabled/disabled
  2dup 0 port5-newly-set? [ dup SOUND-WALK1 play-invaders-sound ] when
  2dup 1 port5-newly-set? [ dup SOUND-WALK2 play-invaders-sound ] when
  2dup 2 port5-newly-set? [ dup SOUND-WALK3 play-invaders-sound ] when
  2dup 3 port5-newly-set? [ dup SOUND-WALK4 play-invaders-sound ] when
  2dup 4 port5-newly-set? [ dup SOUND-UFO-HIT play-invaders-sound ] when
  port5o<< ;

M: space-invaders write-port ( value port cpu -- )
  #! Write a byte to the hardware port, where 'port' is
  #! an 8-bit value.  
  swap {
    { 2 [ write-port2 ] }
    { 3 [ write-port3 ] }
    { 4 [ write-port4 ] }
    { 5 [ write-port5 ] }
    [ 3drop ]
  } case ;

M: space-invaders reset ( cpu -- )
  dup call-next-method
  0 >>port1
  0 >>port2i
  0 >>port2o
  0 >>port3o
  0 >>port4lo
  0 >>port4hi
  0 >>port5o 
  drop ;

: gui-step ( cpu -- )
  [ read-instruction ] keep ! n cpu
  over get-cycles over inc-cycles
  [ swap instructions nth call( cpu -- ) ] keep  
  [ pc>> 0xFFFF bitand ] keep 
  pc<< ;

: gui-frame/2 ( cpu -- )
  [ gui-step ] keep
  [ cycles>> ] keep
  over 16667 < [ ! cycles cpu
    nip gui-frame/2
  ] [
    [ [ 16667 - ] dip cycles<< ] keep
    dup last-interrupt>> 0x10 = [
      0x08 over last-interrupt<< 0x08 swap interrupt
    ] [
      0x10 over last-interrupt<< 0x10 swap interrupt
    ] if     
  ] if ;

: gui-frame ( cpu -- )
  dup gui-frame/2 gui-frame/2 ;

: coin-down ( cpu -- )
  [ port1>> 1 bitor ] keep port1<< ;

: coin-up ( cpu --  )
  [ port1>> 255 1 - bitand ] keep port1<< ;

: player1-down ( cpu -- )
  [ port1>> 4 bitor ] keep port1<< ;

: player1-up ( cpu -- )
  [ port1>> 255 4 - bitand ] keep port1<< ;

: player2-down ( cpu -- )
  [ port1>> 2 bitor ] keep port1<< ;

: player2-up ( cpu -- )
  [ port1>> 255 2 - bitand ] keep port1<< ;

: fire-down ( cpu -- )
  [ port1>> 0x10 bitor ] keep port1<< ;

: fire-up ( cpu -- )
  [ port1>> 255 0x10 - bitand ] keep port1<< ;

: left-down ( cpu -- )
  [ port1>> 0x20 bitor ] keep port1<< ;

: left-up ( cpu -- )
  [ port1>> 255 0x20 - bitand ] keep port1<< ;

: right-down ( cpu -- )
  [ port1>> 0x40 bitor ] keep port1<< ;

: right-up ( cpu -- )
  [ port1>> 255 0x40 - bitand ] keep port1<< ;


TUPLE: invaders-gadget < gadget cpu quit? windowed? ;

invaders-gadget H{
    { T{ key-down f f "ESC" }    [ t over quit?<< dup windowed?>> [ close-window ] [ drop ] if ] }
    { T{ key-down f f "BACKSPACE" } [ cpu>> coin-down ] }
    { T{ key-up   f f "BACKSPACE" } [ cpu>> coin-up ] }
    { T{ key-down f f "1" }         [ cpu>> player1-down ] }
    { T{ key-up   f f "1" }         [ cpu>> player1-up ] }
    { T{ key-down f f "2" }         [ cpu>> player2-down ] }
    { T{ key-up   f f "2" }         [ cpu>> player2-up ] }
    { T{ key-down f f "UP" }        [ cpu>> fire-down ] }
    { T{ key-up   f f "UP" }        [ cpu>> fire-up ] }
    { T{ key-down f f "LEFT" }      [ cpu>> left-down ] }
    { T{ key-up   f f "LEFT" }      [ cpu>> left-up ] }
    { T{ key-down f f "RIGHT" }     [ cpu>> right-down ] }
    { T{ key-up   f f "RIGHT" }     [ cpu>> right-up ] }
  } set-gestures 

: <invaders-gadget> ( cpu -- gadget ) 
  invaders-gadget  new
      swap >>cpu
      f >>quit? ;

M: invaders-gadget pref-dim* drop { 224 256 } ;

M: invaders-gadget draw-gadget* ( gadget -- )
  0 0 glRasterPos2i
  1.0 -1.0 glPixelZoom
  [ 224 256 GL_RGB GL_UNSIGNED_BYTE ] dip
  cpu>> bitmap>> glDrawPixels ;

CONSTANT: black { 0 0 0 } 
CONSTANT: white { 255 255 255 } 
CONSTANT: green { 0 255 0 } 
CONSTANT: red   { 255 0 0 } 

: addr>xy ( addr -- point )
  #! Convert video RAM address to base X Y value. point is a {x y}.
  0x2400 - ! n
  dup 0x1f bitand 8 * 255 swap - ! n y
  swap -5 shift swap 2array ;

: plot-bitmap-pixel ( bitmap point color -- )
  #! point is a {x y}. color is a {r g b}.
  set-bitmap-pixel ;

: get-point-color ( point -- color )
  #! Return the color to use for the given x/y position.
  first2
  {
    { [ dup 184 238 between? pick 0 223 between? and ] [ 2drop green ] }
    { [ dup 240 247 between? pick 16 133 between? and ] [ 2drop green ] }
    { [ dup 247 215 - 247 184 - between? pick 0 223 between? and ] [ 2drop red ] }
    [ 2drop white ]
  } cond ;

: plot-bitmap-bits ( bitmap point byte bit -- )
  #! point is a {x y}.
  [ first2 ] 2dip
  dup swapd -1 * shift 1 bitand 0 =
  [ - 2array ] dip
  [ black ] [ dup get-point-color ] if
  plot-bitmap-pixel ;

: do-bitmap-update ( bitmap value addr -- )
  addr>xy swap 
  [ 0 plot-bitmap-bits ] 3keep
  [ 1 plot-bitmap-bits ] 3keep
  [ 2 plot-bitmap-bits ] 3keep
  [ 3 plot-bitmap-bits ] 3keep
  [ 4 plot-bitmap-bits ] 3keep
  [ 5 plot-bitmap-bits ] 3keep
  [ 6 plot-bitmap-bits ] 3keep
  7 plot-bitmap-bits ;

M: space-invaders update-video ( value addr cpu -- )  
  over 0x2400 >= [
    bitmap>> -rot do-bitmap-update
  ] [
    3drop
  ] if ;

: sync-frame ( micros -- micros )
  #! Sleep until the time for the next frame arrives.
  1000 60 / >fixnum + gmt timestamp>micros - dup 0 >
  [ milliseconds threads:sleep ] [ drop threads:yield ] if gmt timestamp>micros ;

: invaders-process ( micros gadget -- )
  #! Run a space invaders gadget inside a 
  #! concurrent process. Messages can be sent to
  #! signal key presses, etc.
  dup quit?>> [
    2drop
  ] [
    [ sync-frame ] dip
    [ cpu>> gui-frame ] keep
    [ relayout-1 ] keep
    invaders-process 
  ] if ;

M: invaders-gadget graft* ( gadget -- )
  dup cpu>> init-sounds
  f over quit?<<
  [ gmt timestamp>micros swap invaders-process ] curry
  "Space invaders" threads:spawn drop ;

M: invaders-gadget ungraft* ( gadget -- )
 t swap quit?<< ;

: (run) ( title cpu rom-info -- )
  over load-rom* <invaders-gadget> t >>windowed? swap open-window ;

CONSTANT: rom-info {
      { 0x0000 "invaders/invaders.h" }
      { 0x0800 "invaders/invaders.g" }
      { 0x1000 "invaders/invaders.f" }
      { 0x1800 "invaders/invaders.e" }
   }

: run-invaders ( -- )  
  [
    "Space Invaders" <space-invaders> rom-info (run)
  ] with-ui ;

MAIN: run-invaders
