import themidibus.*;
import javax.sound.midi.MidiMessage; 
import java.util.Arrays; 
import java.util.Map;
import java.util.Properties;
import java.io.FileInputStream; 
import java.io.FileNotFoundException;

//Midi config
//Look at console to see available midi inputs and set
//the index of your midi device here
//TODO:  use gui to select midi input device
final int MIDI_DEVICE = 0;

//ordering here is arbitrary and simply establishes an index number for the named pads
final String[] PAD_ORDER = {"BOTTOM_RIGHT","BOTTOM_LEFT","TOP_LEFT", "TOP_RIGHT"}; 

final int NUM_PADS = PAD_ORDER.length;
final int PRESSES_FOR_MODE_SWITCH = 3;

Map PAD_NOTES = new HashMap();
PGraphics pg; //bg images graphic
ArrayList<Boolean> padWasPressed; //flags indicating a pad was pressed, also updated by callback
ArrayList<Integer> pressCounter; 
int currentModeIndex = 0;
Mode[] modeList;
Mode currentMode;

MidiBus myBus;

void setup() {
  size(800, 600, P2D);
  //fullScreen(P2D);
  frameRate(60);
  
  //pad config based on firmware settings
  PAD_NOTES.put(85, "BOTTOM_RIGHT");
  PAD_NOTES.put(84, "BOTTOM_LEFT");
  PAD_NOTES.put(80, "TOP_LEFT");
  PAD_NOTES.put(82, "TOP_RIGHT");

  Properties configProps = new Properties();
  InputStream is = null;
  try {
    is = createInput("config.properties");
    configProps.load(is);
     
  } catch (IOException ex) {
    println("Error reading config file.");
  }
  
  //setup midi
  MidiBus.list(); 
  myBus = new MidiBus(this, MIDI_DEVICE, 1); 

  //Create background static image (PGraphic)
  noFill();
  stroke(255, 0, 0);
  pg = createGraphics(width, height);
  PImage logo;
  logo = loadImage("bitmap.png");
  println();
  pg.beginDraw();
  pg.background(25);
  int newWidth = (int)(logo.width * LOGO_SCALING);
  int newHeight = (int) (logo.height * LOGO_SCALING);
  pg.image(logo, width/2-(newWidth/2), height/2-(newHeight/2), newWidth, newHeight);
  pg.endDraw();

  //global state
  padWasPressed = new ArrayList<Boolean>();
  pressCounter = new ArrayList<Integer>();  
  for ( int pad = 0; pad < NUM_PADS; pad++) {
    padWasPressed.add(false);
    pressCounter.add(0);
  }
  
  //Create modes and initialize currentMode
  currentModeIndex = 0;
  modeList = new Mode[] {new CircleMode(configProps)};
  currentMode = modeList[currentModeIndex];
  currentMode.setup();

  //easier to scale
  colorMode(HSB, 255);
}

void draw() {
  //Redraw bg to erase previous frame
  background(pg);
  for (int pad = 0; pad < NUM_PADS; pad++) {
    
    if (padWasPressed.get(pad)) {
      //reset pressCounter on other pads
      for (int otherpad = 0; otherpad<NUM_PADS; otherpad++) {
        if (otherpad != pad) {
          pressCounter.set(otherpad, 0);
        }
      }
      
      //increment own presscounter
      pressCounter.set(pad, pressCounter.get(pad) + 1);

      //MODE SWITCH
      if (pressCounter.get(pad) >= PRESSES_FOR_MODE_SWITCH && pad == Arrays.asList(PAD_ORDER).indexOf("TOP_LEFT")){
        currentModeIndex++;
        if (currentModeIndex >= modeList.length){          
          currentModeIndex = 0;
        }        
        currentMode = modeList[currentModeIndex];
        pressCounter.set(pad, 0);
        currentMode.setup();
        //reset pressed flag before drawing new mode
        padWasPressed.set(pad, false);
      }      
    }
  }
  
  currentMode.draw();
  
  //reset pressed flag
  for (int pad = 0; pad < NUM_PADS; pad++) {
    padWasPressed.set(pad, false);
  }
}

//Called by MidiBus library whenever a new midi message is received
void midiMessage(MidiMessage message) {
  int note = (int)(message.getMessage()[1] & 0xFF) ;
  int vel = (int)(message.getMessage()[2] & 0xFF);
  println("note: " + note + " vel: "+ vel);

  int pad = noteToPadIndex(note);
  if (pad >= 0 && (vel > 0)) {
    padWasPressed.set(pad, true);
    currentMode.handleMidi(pad, note, vel);
  }
}

int noteToPadIndex (int note) {
  return Arrays.asList(PAD_ORDER).indexOf(PAD_NOTES.get(note));
}