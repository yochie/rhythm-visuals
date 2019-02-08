import themidibus.*;
import javax.sound.midi.MidiMessage; 
import java.util.Arrays; 
import java.util.List;
import java.util.Iterator; 
import java.util.Properties;
import java.io.InputStream; 
import java.io.IOException;
import java.lang.IllegalArgumentException;

//Main script for this app
//Handles initial midi signal parsing, background drawing and mode switching

////////CONSTANT GLOBALS (don't change after setup) ////////

//list of Mode implementing instances to switch between
final ArrayList<Mode> modes = new ArrayList<Mode>();

//list of named config parameters that can have a note assigned
final String[] namedPads = {"BOTTOM_RIGHT_NOTE", "BOTTOM_LEFT_NOTE", "TOP_LEFT_NOTE", "TOP_RIGHT_NOTE"};

//list of other pad notes read in from config
final ArrayList<Integer> auxPadNotes = new ArrayList<Integer>(); 

//static (non-changing) pad data and helper methods
final ArrayList<Pad> pads = new ArrayList<Pad>();

//sum of named and auxiliary pads
int numPads;

//Should fill this with its default config vars before calling loadGlobalConfigFrom()
//Properties are stored as strings
//e.g. this.globalDefaultConfig.setProperty("SHRINK_FACTOR", "0.95");
//TODO: refactor config loading so that modes and main script can use same code (e.g. ConfigLoader class)
//TODO: change to arg in loadGlobalConfigFrom() instead of global to avoid conflicts
final Properties globalDefaultConfig = new Properties();

//filled by loadConfig()
Properties globalLoadedConfig;

MidiBus myBus;

//background image
PGraphics pg;

////////RUNTIME GLOBALS (change after setup) /////////

Mode currentMode;
int currentModeIndex = 0;

//flags indicating a pad was pressed, set by midi callback and unset after each draw()
ArrayList<Boolean> padWasPressed;

//number of consecutive presses for each pad
//pressing any pad resets the count on all the others
//switching mode resets the count on all pads
ArrayList<Integer> pressCounter; 

void setup() {
  size(800, 600, P2D);
  //fullScreen(P2D);
  frameRate(30);

  globalDefaultConfig.setProperty("LOGO_SCALING", "0.05");
  globalDefaultConfig.setProperty("MIDI_DEVICE", "0");
  globalDefaultConfig.setProperty("PRESSES_FOR_MODE_SWITCH", "3");
  globalDefaultConfig.setProperty("BOTTOM_RIGHT_NOTE", "80");
  globalDefaultConfig.setProperty("BOTTOM_LEFT_NOTE", "84");
  globalDefaultConfig.setProperty("TOP_LEFT_NOTE", "82");
  globalDefaultConfig.setProperty("TOP_RIGHT_NOTE", "85");
  globalDefaultConfig.setProperty("AUX_PAD_NOTES", "");

  //read config file
  loadGlobalConfigFrom("config.properties");

  //parse auxiliary notes list from config
  List<String> string_aux_pad_notes = Arrays.asList(globalLoadedConfig.getProperty("AUX_PAD_NOTES").split("\\s*,\\s*"));
  Iterator<String> iter = string_aux_pad_notes.iterator();
  while (iter.hasNext()) {
    String next = iter.next();
    try {
      auxPadNotes.add(Integer.parseInt(next));
    } 
    catch (NumberFormatException e) {
      println("Warning: Config var AUX_PAD_NOTES is either empty or not of expected type (int). Ignoring its value: " + next);
    }
  }
  println("Global config: ");  
  println(globalLoadedConfig);
  println();

  //create pad list
  for (int i = 0; i < namedPads.length; i++) {
    int note = getIntProp(namedPads[i]);
    println(namedPads[i] + " : " + note);
    pads.add(new Pad(namedPads[i], note, false));
  }
  for (int i = 0; i < auxPadNotes.size(); i++) {
    int note = auxPadNotes.get(i);
    println("AUX_" + i + " : " + note);
    pads.add(new Pad(namedPads[i], note, true));
  }

  numPads = pads.size(); 

  //setup midi
  MidiBus.list(); 
  myBus = new MidiBus(this, getIntProp("MIDI_DEVICE"), 1); 

  //Create background static image (PGraphic)
  noFill();
  stroke(255, 0, 0);
  pg = createGraphics(width, height);
  PImage logo;
  logo = loadImage("bitmap.png");
  println();
  pg.beginDraw();
  pg.background(25);
  int newWidth = (int)(logo.width * getFloatProp("LOGO_SCALING"));
  int newHeight = (int) (logo.height * getFloatProp("LOGO_SCALING"));
  pg.image(logo, width/2-(newWidth/2), height/2-(newHeight/2), newWidth, newHeight);
  pg.endDraw();

  //global state init
  padWasPressed = new ArrayList<Boolean>();
  pressCounter = new ArrayList<Integer>();  
  for ( int padIndex = 0; padIndex < numPads; padIndex++) {
    padWasPressed.add(false);
    pressCounter.add(0);
  }

  //Create modes and initialize currentMode
  modes.add(new CircleMode());
  modes.add(new SuperluminalMode());
  modes.add(new WordMode());
  modes.add(new FlockMode());

  currentModeIndex = 0;
  currentMode = modes.get(currentModeIndex);
  currentMode.setup();

  //easier to scale
  colorMode(HSB, 255);
}

void draw() {
  //Redraw bg to erase previous frame
  background(pg);

  //Increment presses and check for mode switch
  for (int padIndex = 0; padIndex < numPads; padIndex++) {
    Pad pad = pads.get(padIndex);
    if (padWasPressed.get(padIndex)) {
      //reset pressCounter on other pads
      for (int otherpad = 0; otherpad<numPads; otherpad++) {
        if (otherpad != padIndex) {
          pressCounter.set(otherpad, 0);
        }
      }

      //increment own presscounter
      pressCounter.set(padIndex, pressCounter.get(padIndex) + 1);

      //switch modes
      if (pad.name == "TOP_LEFT_NOTE" && pressCounter.get(padIndex) >= getIntProp("PRESSES_FOR_MODE_SWITCH")) {
        currentModeIndex++;
        if (currentModeIndex >= modes.size()) {          
          currentModeIndex = 0;
        }        
        currentMode = modes.get(currentModeIndex);
        pressCounter.set(padIndex, 0);
        currentMode.setup();
        //reset pressed flag before drawing new mode
        padWasPressed.set(padIndex, false);
      }
    }
  }

  currentMode.draw();

  //reset pressed flag
  for (int padIndex = 0; padIndex < numPads; padIndex++) {
    padWasPressed.set(padIndex, false);
  }
}

void loadGlobalConfigFrom(String configFileName) {
  globalLoadedConfig = new Properties(globalDefaultConfig);
  InputStream is = null;
  try {
    is = createInput(configFileName);
    globalLoadedConfig.load(is);
  } 
  catch (IOException ex) {
    println("Error reading config file.");
  }
}

int getIntProp(String propName) {
  int toReturn;
  if (globalLoadedConfig.containsKey(propName)) {
    try {
      toReturn = Integer.parseInt(globalLoadedConfig.getProperty(propName));
    } 
    catch (NumberFormatException e) {
      println("WARNING: Config var" + propName + " is not of expected type (integer). Falling back to default config for this parameter.");
      toReturn = Integer.parseInt(globalDefaultConfig.getProperty(propName));
    }
  } else {
    println("Error: Couldn't find requested config var : " + propName);
    throw(new IllegalArgumentException());
  }
  return toReturn;
}

float getFloatProp(String propName) {
  float toReturn;
  if (globalLoadedConfig.containsKey(propName)) {
    try {
      toReturn = Float.parseFloat(globalLoadedConfig.getProperty(propName));
    } 
    catch (NumberFormatException e) {
      println("WARNING: Config var" + propName + " is not of expected type (float). Falling back to default config for this parameter.");
      toReturn = Float.parseFloat(globalDefaultConfig.getProperty(propName));
    }
  } else {
    println("Error: Couldn't find requested config var : " + propName);
    throw(new IllegalArgumentException());
  }
  return toReturn;
}


//Called by MidiBus library whenever a new midi message is received
void midiMessage(MidiMessage message) {
  byte messageType = message.getMessage()[0];
  int channel = -1;
  int note = -1;
  int vel = -1;
  int controllerNumber = -1;
  int controllerVal = -1;
  int padIndex = -1;
  Pad pad = null;

  //check if note one, note off or control change message
  if ((messageType & 0xF0) == 0x80 || (messageType & 0xF0) == 0x90 || (messageType & 0xF0) == 0xB0) {
    channel = (int) (messageType & 0x0F);

    //note messages
    if ((messageType & 0xF0) == 0x80 || (messageType & 0xF0) == 0x90) {
      note = (int)(message.getMessage()[1] & 0xFF);
      vel = (int)(message.getMessage()[2] & 0xFF);
      padIndex = Pad.noteToPad(note);
      
      if (padIndex >= 0){
        pad = pads.get(padIndex);
      }
      
      println("channel: " + channel + " note: " + note + " vel: "+ vel + " pad: " + padIndex);
    }

    //cc messages
    if ((messageType & 0xF0) == 0xB0) {
      controllerNumber = (int)(message.getMessage()[1] & 0xFF);
      controllerVal = (int)(message.getMessage()[2] & 0xFF);
      println("channel: " + channel + " controller: " + controllerNumber + " val: "+ controllerVal);
    }
  }

  //register pad press
  //used for mode switch and can be used within modes to check for pad presses
  if (padIndex >= 0 && (vel > 0)) {
    padWasPressed.set(padIndex, true);
  }

  currentMode.handleMidi(message.getMessage(), messageType, channel, note, vel, controllerNumber, controllerVal, pad);
}
