/* ──────────────────────────────────────────────────────────────────────────
   MakerBreaker reference list
   A curated guide to common electronics found at home: what's likely inside,
   what each part can be repurposed for, and whether it's safe for kids to open.

   level:  'safe'    — low voltage / battery, fine to open with care
           'caution' — has a part to respect (lithium battery, small capacitor, laser)
           'danger'  — DO NOT open: mains capacitors / high voltage / hazardous
   Keep names lowercase-friendly; `aliases` catch the words kids actually type.
   ────────────────────────────────────────────────────────────────────────── */
window.MAKERBREAKER = [
  { name:"Old radio", icon:"📻", level:"safe", aliases:["radio","fm radio","transistor radio","boombox"],
    note:"Great first teardown — all low voltage.",
    parts:[
      {p:"Speaker", use:"The star part — reuse in a homemade Bluetooth speaker or doorbell"},
      {p:"Tuning dial / variable capacitor", use:"A satisfying knob for a control panel"},
      {p:"Antenna wire", use:"Jumper wires, or a long aerial for another radio"},
      {p:"Circuit board", use:"Harvest resistors, LEDs and the headphone socket"}],
    projects:["Mini Bluetooth speaker","Classroom doorbell","Junk-robot body"] },

  { name:"Electronic toy", icon:"🧸", level:"safe", aliases:["toy","kids toy","talking toy","musical toy","noisy toy"],
    note:"Check for button-cell batteries and remove them first.",
    parts:[
      {p:"Small DC motor", use:"Power a bristlebot or a mini fan"},
      {p:"Speaker / buzzer", use:"Add sound to your own build"},
      {p:"LEDs", use:"Lights for a robot or a night-light"},
      {p:"Push buttons & switches", use:"Inputs for a cardboard game controller"}],
    projects:["Bristlebot","Light-up badge","Simple alarm"] },

  { name:"Remote control", icon:"🎮", level:"safe", aliases:["remote","tv remote","controller"],
    note:"Battery powered — easy and safe.",
    parts:[
      {p:"Rubber button pad", use:"Tactile buttons for a DIY keypad"},
      {p:"Infrared LED", use:"Build an IR signal sender"},
      {p:"Circuit board + contacts", use:"Study how a keypad matrix works"}],
    projects:["DIY keypad","IR tester","Secret-code gadget"] },

  { name:"Computer mouse", icon:"🖱️", level:"safe", aliases:["mouse","optical mouse"],
    note:"USB powered, totally safe.",
    parts:[
      {p:"Micro switches (clicks)", use:"Crisp buttons for any project"},
      {p:"Scroll wheel + encoder", use:"A rotary input for a game"},
      {p:"Red/IR LED + lens", use:"Light source experiments"},
      {p:"USB cable", use:"Power or data lead for other builds"}],
    projects:["Game button box","Reaction-timer game"] },

  { name:"Keyboard", icon:"⌨️", level:"safe", aliases:["computer keyboard","usb keyboard"],
    note:"Lots of identical parts to harvest.",
    parts:[
      {p:"Keycaps & switches", use:"Buttons galore for builds and art"},
      {p:"Ribbon circuit", use:"See how a key matrix is wired"},
      {p:"USB controller + cable", use:"Reuse the lead"}],
    projects:["Custom button panel","Keycap mosaic art"] },

  { name:"Headphones", icon:"🎧", level:"safe", aliases:["earphones","earbuds","ear phones"],
    note:"Tiny but mighty speakers inside.",
    parts:[
      {p:"Mini speakers (drivers)", use:"Make a tiny amplifier or paper-cup speaker"},
      {p:"Thin wire", use:"Great for coils and electromagnets"},
      {p:"3.5mm jack", use:"Audio input for other projects"}],
    projects:["Paper-cup speakers","Electromagnet"] },

  { name:"Toy car", icon:"🚗", level:"safe", aliases:["rc car","remote car","car toy","race car"],
    note:"A goldmine of motion parts.",
    parts:[
      {p:"DC motor", use:"Drive a robot's wheels"},
      {p:"Gears & axles", use:"Build a gearbox"},
      {p:"Wheels", use:"Reuse on your own robot chassis"},
      {p:"Battery holder", use:"Power your next build"}],
    projects:["Line-following robot base","Wind-up racer","Drawing bot"] },

  { name:"Alarm clock", icon:"⏰", level:"safe", aliases:["clock","digital clock","bedside clock"],
    note:"Mostly safe — battery or low-voltage adapter.",
    parts:[
      {p:"LCD or LED display", use:"Reuse a seven-segment display"},
      {p:"Buzzer", use:"Alarm sound for your own gadget"},
      {p:"Buttons", use:"Set-time inputs become project inputs"}],
    projects:["Countdown timer","Morning alarm gadget"] },

  { name:"Calculator", icon:"🔢", level:"safe", aliases:["calc","pocket calculator"],
    note:"Solar + button cell; gentle teardown.",
    parts:[
      {p:"Solar cell", use:"Power a tiny LED in the sun"},
      {p:"LCD screen", use:"Explore how a segment display works"},
      {p:"Button pad", use:"Inputs for a mini console"}],
    projects:["Solar LED","Button game pad"] },

  { name:"Old speakers", icon:"🔊", level:"safe", aliases:["speaker","pc speakers","desk speakers"],
    note:"Unplug from mains first; the speaker itself is safe.",
    parts:[
      {p:"Speaker cone + magnet", use:"Strong magnet for experiments; cone for a new build"},
      {p:"Volume knob (potentiometer)", use:"Analog control for a project"},
      {p:"Wire", use:"Reusable hook-up wire"}],
    projects:["Bluetooth speaker","Magnet science kit"] },

  { name:"Small fan", icon:"🌀", level:"safe", aliases:["usb fan","desk fan","mini fan"],
    note:"USB/battery fans are safe to open.",
    parts:[
      {p:"DC motor", use:"Reuse for a bristlebot or a boat"},
      {p:"Fan blade", use:"A propeller for a toy boat or car"},
      {p:"Switch", use:"On/off for your build"}],
    projects:["Toy fan-boat","Air-powered racer"] },

  { name:"DVD or CD player", icon:"💿", level:"caution", aliases:["dvd player","cd player","disc player"],
    note:"Unplug first. The laser diode is delicate — don't stare into it when powered.",
    parts:[
      {p:"Stepper & DC motors", use:"Precise motion for a mini plotter"},
      {p:"Laser lens & sled", use:"Study optics (handle gently, never power it at your eyes)"},
      {p:"Gears and rails", use:"Linear motion for a camera slider"}],
    projects:["Mini drawing plotter","Motorised camera slider"] },

  { name:"Game controller", icon:"🎮", level:"safe", aliases:["gamepad","joystick","console controller"],
    note:"Battery or USB — safe.",
    parts:[
      {p:"Joystick (thumbstick)", use:"Analog steering for a robot"},
      {p:"Buttons & triggers", use:"Inputs for your own game"},
      {p:"Vibration motor", use:"Perfect for a bristlebot"}],
    projects:["Robot joystick","Rumble bristlebot"] },

  { name:"Wired telephone", icon:"☎️", level:"safe", aliases:["phone","landline","telephone","desk phone"],
    note:"Old landline handsets are low voltage and safe.",
    parts:[
      {p:"Speaker & microphone", use:"Build an intercom between two rooms"},
      {p:"Keypad", use:"A ready-made number pad"},
      {p:"Coiled cord", use:"Stretchy wire for fun builds"}],
    projects:["Two-room intercom","Tin-can phone upgrade"] },

  { name:"Printer", icon:"🖨️", level:"caution", aliases:["inkjet printer","old printer","scanner"],
    note:"Unplug first. Watch for the sharp paper cutter and ink; the power supply stays closed.",
    parts:[
      {p:"Stepper motors", use:"Precise motors for a CNC or plotter"},
      {p:"Metal rods & belts", use:"Smooth linear rails"},
      {p:"Rollers & gears", use:"Mechanisms for a marble machine"}],
    projects:["Pen plotter","Marble run machine"] },

  { name:"Old mobile phone", icon:"📱", level:"caution", aliases:["phone","feature phone","cell phone","smartphone","mobile"],
    note:"The lithium battery can catch fire if bent or punctured — have an adult remove it and never pierce it.",
    parts:[
      {p:"Vibration motor", use:"The classic bristlebot motor"},
      {p:"Tiny speaker & mic", use:"Sound for small builds"},
      {p:"Camera module", use:"Explore a lens and sensor"},
      {p:"Screen", use:"Study an LCD/OLED (reuse is advanced)"}],
    projects:["Bristlebot","Mini vibrating art machine"] },

  { name:"Power bank", icon:"🔋", level:"caution", aliases:["power bank","battery pack","portable charger"],
    note:"Holds a lithium cell — do NOT puncture or short it. Adult supervision for the battery.",
    parts:[
      {p:"USB circuit board", use:"Learn how charging and boost circuits work"},
      {p:"Lithium cell", use:"Keep sealed; recycle safely — don't repurpose at home"}],
    projects:["Study a charging circuit (board only)"] },

  { name:"Hair dryer", icon:"💨", level:"caution", aliases:["hairdryer","blow dryer","hair drier"],
    note:"Unplug first. The heating element and mains plug are not for reuse — harvest only the motor and fan.",
    parts:[
      {p:"DC motor + fan", use:"Air for a hovercraft or fan-boat"},
      {p:"Switch", use:"Speed selector for a build"}],
    projects:["Balloon hovercraft","Fan-boat"] },

  { name:"Electric toothbrush", icon:"🪥", level:"safe", aliases:["toothbrush","electric toothbrush"],
    note:"Battery powered — a neat little motor inside.",
    parts:[
      {p:"Vibration/DC motor", use:"Drive a scrub-bot or bristlebot"},
      {p:"Rechargeable cell", use:"Keep sealed; recycle"}],
    projects:["Scrub-bot","Vibrating drawing bot"] },

  { name:"Microwave oven", icon:"⚠️", level:"danger", aliases:["microwave","micro wave"],
    note:"DO NOT OPEN. The capacitor can hold a lethal charge even when unplugged. This one is for grown-up e-waste recycling only.",
    parts:[], projects:[] },

  { name:"Old TV or monitor", icon:"⚠️", level:"danger", aliases:["tv","television","crt","monitor","screen"],
    note:"DO NOT OPEN a CRT (tube) TV or monitor — it stores dangerous high voltage. Take it to e-waste recycling.",
    parts:[], projects:[] },

  { name:"CFL / fluorescent bulb", icon:"⚠️", level:"danger", aliases:["cfl","fluorescent","energy bulb","tube light"],
    note:"DO NOT break — these contain a little mercury. Recycle them whole at a proper drop-off.",
    parts:[], projects:[] }
];
