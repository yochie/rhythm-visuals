import themidibus.*;
import javax.sound.midi.MidiMessage; 
import java.util.Arrays; 
import java.util.List;
import java.util.Iterator; 
import java.util.Properties;
import java.io.FileInputStream; 
import java.io.FileNotFoundException;

////////CONSTANTS////////

//list of Mode implementing instances to switch between
final Mode[] MODES = new Mode[] {new CircleMode()};

//ordering here is arbitrary and simply establishes an index number for the named pads
final String[] NAMED_PADS = {"BOTTOM_RIGHT_NOTE", "BOTTOM_LEFT_NOTE", "TOP_LEFT_NOTE", "TOP_RIGHT_NOTE"};

////////FROM CONFIG////////

//list of other pad notes read in from config
final ArrayList<Integer> AUX_PAD_NOTES = new ArrayList<Integer>(); 

//sum of named and aux pads
//calculated from config, so not technically a constant, but shouldn't change once set
int NUM_PADS;

////////GLOBALS/////////

Mode currentMode;
int currentModeIndex = 0;

//static pad data and helper methods
ArrayList<Pad> pads = new ArrayList<Pad>();

//flags indicating a pad was pressed, set by midi callback and unset after each draw()
ArrayList<Boolean> padWasPressed;

//number of consecutive presses for each pad
//pressing any pad resets the count on all the others
//switching mode resets the count on all pads
ArrayList<Integer> pressCounter; 

//background image
PGraphics pg;

Properties configProps;

MidiBus myBus;

void setup() {
  size(800, 600, P2D);
  //fullScreen(P2D);
  frameRate(60);

  //read config file
  configProps = new Properties();
  InputStream is = null;
  try {
    is = createInput("config.properties");
    configProps.load(is);
  } 
  catch (IOException ex) {
    println("Error reading config file.");
  }
  
  //get aux notes from config
  List<String> string_aux_pad_notes = Arrays.asList(configProps.getProperty("AUX_PAD_NOTES").split("\\s*,\\s*"));
  Iterator<String> iter = string_aux_pad_notes.iterator();
  while (iter.hasNext()){
    AUX_PAD_NOTES.add(Integer.parseInt(iter.next()));
  }
 
  //create pad list
  for(int i = 0; i < NAMED_PADS.length; i++){
    int note = Integer.parseInt(configProps.getProperty(NAMED_PADS[i]));
    println(NAMED_PADS[i] + " : " + note);
    pads.add(new Pad(NAMED_PADS[i], note, false));
  }
  for(int i = 0; i < AUX_PAD_NOTES.size(); i++){
    int note = AUX_PAD_NOTES.get(i);
    println("AUX_" + i + " : " + note);
    pads.add(new Pad(NAMED_PADS[i], note, true));
  }
  
  NUM_PADS = pads.size(); 
  
  //setup midi
  MidiBus.list(); 
  myBus = new MidiBus(this, Integer.parseInt(configProps.getProperty("MIDI_DEVICE")), 1); 

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

  //global state init
  padWasPressed = new ArrayList<Boolean>();
  pressCounter = new ArrayList<Integer>();  
  for ( int pad = 0; pad < NUM_PADS; pad++) {
    padWasPressed.add(false);
    pressCounter.add(0);
  }

  //Create modes and initialize currentMode
  currentModeIndex = 0;
  currentMode = MODES[currentModeIndex];
  currentMode.setup();

  //easier to scale
  colorMode(HSB, 255);
}

void draw() {
  //Redraw bg to erase previous frame
  background(pg);
  
  //Increment presses and check for mode switch
  for (int padIndex = 0; padIndex < NUM_PADS; padIndex++) {
    Pad pad = pads.get(padIndex);
    if (padWasPressed.get(padIndex)) {
      //reset pressCounter on other pads
      for (int otherpad = 0; otherpad<NUM_PADS; otherpad++) {
        if (otherpad != padIndex) {
          pressCounter.set(otherpad, 0);
        }
      }

      //increment own presscounter
      pressCounter.set(padIndex, pressCounter.get(padIndex) + 1);

      //switch modes
      if (pad.name == "TOP_LEFT_NOTE" && pressCounter.get(padIndex) >= Integer.parseInt(configProps.getProperty("PRESSES_FOR_MODE_SWITCH"))) {
        currentModeIndex++;
        if (currentModeIndex >= MODES.length) {          
          currentModeIndex = 0;
        }        
        currentMode = MODES[currentModeIndex];
        pressCounter.set(padIndex, 0);
        currentMode.setup();
        //reset pressed flag before drawing new mode
        padWasPressed.set(padIndex, false);
      }
    }
  }

  currentMode.draw();

  //reset pressed flag
  for (int padIndex = 0; padIndex < NUM_PADS; padIndex++) {
    padWasPressed.set(padIndex, false);
  }
}

//Called by MidiBus library whenever a new midi message is received
void midiMessage(MidiMessage message) {
  int note = (int)(message.getMessage()[1] & 0xFF) ;
  int vel = (int)(message.getMessage()[2] & 0xFF);
  println("note: " + note + " vel: "+ vel);

  int padIndex = Pad.noteToPad(note);
  if (padIndex >= 0 && (vel > 0)) {
    padWasPressed.set(padIndex, true);
    currentMode.handleMidi(pads.get(padIndex), note, vel);
  }
}