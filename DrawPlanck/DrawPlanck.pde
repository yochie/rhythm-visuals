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

////////CONSTANT GLOBALS (shouldn't change after setup) ////////

//list of Mode implementing instances to switch between
//Need to manually add instances to list here when adding a new mode
final ArrayList<Mode> modes = new ArrayList<Mode>();

//list of named config parameters that can have a note assigned
//used to know which config vars are pad notes without hardcoding names throughout the code
final String[] namedPads = {"BOTTOM_RIGHT_NOTE", "BOTTOM_LEFT_NOTE", "TOP_LEFT_NOTE", "TOP_RIGHT_NOTE"};

//static (non-changing) pad data (including name, index, note, whether its auxiliary or named) and helper methods
final ArrayList<Pad> pads = new ArrayList<Pad>();

//sum of named and auxiliary pads
int numPads;

//Should fill this with its default config vars before calling loadGlobalConfigFrom()
//Properties are stored as strings
//e.g. this.globalDefaultConfig.setProperty("SHRINK_FACTOR", "0.95");
//TODO: refactor config loading so that modes and main script can use same code (e.g. ConfigLoader class)
//TODO: change to arg in loadGlobalConfigFrom() instead of global to avoid conflicts (and globals in general...)
final Properties globalDefaultConfig = new Properties();

//filled by loadConfig()
Properties globalLoadedConfig;

MidiBus myBus;

//background image
PGraphics pg;

//for BPM running average calcs
final int bpmSampleSize = 8;

////////RUNTIME GLOBALS (change after setup) /////////

Mode currentMode;
int currentModeIndex = 0;

//flags indicating a pad was pressed, set by midi callback and consumed within modes by calling
//resetPressed(padIndex) just after checking its state.
ArrayList<Boolean> padWasPressed;

//number of consecutive presses for each pad
//pressing any pad resets the count on all the others
//switching mode resets the count on all pads
//WARNING: this is incremented synchronously, so checking
//its values asynchronously might yield  an outdated result
ArrayList<Integer> pressCounter; 

//holds most recent time pressed switching pad
//used to calculate press duration
long switchingPadHeldSince = Long.MAX_VALUE;
boolean switchingPadHeld = false;

//for BPM running average calcs
long millisBetweenBeats[] = new long[bpmSampleSize];
long lastBpmSampleTime = -1;
int bpmSampleIndex = 0;
long bpmRunningTotal = 0;
float currentBpm = -1;

PFont defaultFont;

int nextMode = -1;

void setup() {
  //size(800, 600, P2D);
  fullScreen(P3D, 2);
  frameRate(30);

  globalDefaultConfig.setProperty("LOGO_SCALING", "0.05");
  globalDefaultConfig.setProperty("MIDI_DEVICE", "0");
  globalDefaultConfig.setProperty("MILLISECONDS_FOR_MODE_SWITCH", "3000");
  globalDefaultConfig.setProperty("BOTTOM_RIGHT_NOTE", "80");
  globalDefaultConfig.setProperty("BOTTOM_LEFT_NOTE", "84");
  globalDefaultConfig.setProperty("TOP_LEFT_NOTE", "82");
  globalDefaultConfig.setProperty("TOP_RIGHT_NOTE", "85");
  globalDefaultConfig.setProperty("AUX_PAD_NOTES", "");
  globalDefaultConfig.setProperty("WITH_BACKGROUND", "1");

  //read config file
  loadGlobalConfigFrom("config.properties");

  //parse auxiliary notes list from config
  ArrayList<Integer> auxPadNotes = new ArrayList<Integer>(); 
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
  pg.background(0);

  if (getIntProp("WITH_BACKGROUND") == 1) {
    int newWidth = (int)(logo.width * getFloatProp("LOGO_SCALING"));
    int newHeight = (int) (logo.height * getFloatProp("LOGO_SCALING"));
    pg.tint(255, 64); //make transparent
    pg.image(logo, width/2-(newWidth/2), height/2-(newHeight/2), newWidth, newHeight);
  }

  pg.endDraw();

  //global state init
  padWasPressed = new ArrayList<Boolean>();
  pressCounter = new ArrayList<Integer>();  
  for ( int padIndex = 0; padIndex < numPads; padIndex++) {
    padWasPressed.add(false);
    pressCounter.add(0);
  }

  //Create modes and initialize currentMode
  modes.add(new MenuMode()); 
  modes.add(new CircleMode());
  modes.add(new SuperluminalMode());
  modes.add(new TreeMode());
  modes.add(new FlockMode());
  modes.add(new WordMode());
  modes.add(new AboutMode());

  currentModeIndex = 0;
  currentMode = modes.get(currentModeIndex);
  currentMode.setup();

  //easier to scale
  colorMode(HSB, 255);

  defaultFont = createFont("Arial", 14);
}

void draw() {
  if (currentMode.redrawBackground)
    //Redraw bg to erase previous frame
    background(pg);

  //Increment synchronous press counters (don't check pressCounter asynchronously)
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
    }
  }

  //return to menu
  if (switchingPadHeld && System.currentTimeMillis() - switchingPadHeldSince >= this.getIntProp("MILLISECONDS_FOR_MODE_SWITCH")) {
    switchingPadHeldSince = System.currentTimeMillis();    
    nextMode = 0;
  }

  //switching modes
  if (nextMode >= 0) {
    currentMode = modes.get(nextMode);
    //reset colors
    defaultDrawing();
    currentMode.setup();
    //reset all pressed flags before drawing new mode
    for (int padIndex = 0; padIndex < numPads; padIndex++) {
      padWasPressed.set(padIndex, false);
      pressCounter.set(padIndex, 0);
    }  
    nextMode = -1;
  }

  currentMode.draw();

  //write BPM to screen
  defaultDrawing();
  fill(0, 0, 0);
  pushMatrix();
  translate(0, 0, 1);
  //noStroke();
  rect( 20, height - 20 - 20, 70, 20);
  fill(0, 0, 255);
  text("BPM: " + (int)currentBpm, 25, height - 20 - 5);
  popMatrix();
  defaultDrawing();
}

void loadGlobalConfigFrom(String configFileName) {
  globalLoadedConfig = new Properties(globalDefaultConfig);
  InputStream is = null;
  String customConfigName = "my_"  + configFileName;

  try {
    //try finding local config (prepended by "my_")
    is = createInput(customConfigName);
    if (is == null) {
      is = createInput(configFileName);
    }
    globalLoadedConfig.load(is);
  } 
  catch (IOException ex) {
    println("Error reading config file.");
  }
  finally {
    try {
      is.close();
    } 
    catch (IOException e) {
      e.printStackTrace();
    }
  }
}

int getIntProp(String propName) {
  int toReturn;
  if (globalLoadedConfig.getProperty(propName) != null) {
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
  if (globalLoadedConfig.getProperty(propName) != null) {
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

//returns config string property
//throws IllegalArgumentException when property not found
String getStringProp(String propName) {
  if (globalLoadedConfig.getProperty(propName) == null) {
    println("Error: Couldn't find requested config var : " + propName);
    throw(new IllegalArgumentException());
  }
  return globalLoadedConfig.getProperty(propName);
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

  //Parse messages
  if ((messageType & 0xF0) == 0x80 || (messageType & 0xF0) == 0x90 || (messageType & 0xF0) == 0xB0) {
    channel = (int) (messageType & 0x0F);

    //note messages
    if ((messageType & 0xF0) == 0x80 || (messageType & 0xF0) == 0x90) {
      note = (int)(message.getMessage()[1] & 0xFF);
      vel = (int)(message.getMessage()[2] & 0xFF);
      padIndex = Pad.noteToPad(note);

      if (padIndex >= 0) {
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

  //Set switching pad state
  //used for mode switch
  if (pad != null && pad.name == "TOP_LEFT_NOTE") {
    if (vel > 0) {
      switchingPadHeld = true;
      switchingPadHeldSince = System.currentTimeMillis();
    } else if (vel == 0) {
      switchingPadHeld = false;
    }
  }

  //BPM calcs
  if (pad != null && pad.name == "BOTTOM_RIGHT_NOTE" && vel > 0) {   

    //skips first sample to get non-zero lastBpmSampleTime
    if (lastBpmSampleTime > 0) {

      //subtract oldest time gap
      bpmRunningTotal -= millisBetweenBeats[bpmSampleIndex];

      //overwrite oldest time gap
      millisBetweenBeats[bpmSampleIndex] = System.currentTimeMillis() - lastBpmSampleTime;

      bpmRunningTotal += millisBetweenBeats[bpmSampleIndex];

      //on the second sample, fill running buffer with first gap val 
      if (currentBpm < 0) {
        for (int i = bpmSampleIndex + 1; i < millisBetweenBeats.length; i++) {
          millisBetweenBeats[i] = millisBetweenBeats[bpmSampleIndex];
        }
        bpmRunningTotal = millisBetweenBeats[bpmSampleIndex] * millisBetweenBeats.length;
      }

      currentBpm = Math.round(60.0/((bpmRunningTotal/millisBetweenBeats.length)/1000.0));

      //rotate array
      bpmSampleIndex++;
      if (bpmSampleIndex >= millisBetweenBeats.length) {
        bpmSampleIndex = 0;
      }
    }

    lastBpmSampleTime = System.currentTimeMillis();
  }


  //register pad press (make sure to consume this flag within modes after checking its state)
  if (padIndex >= 0 && (vel > 0)) {
    padWasPressed.set(padIndex, true);
  }

  currentMode.handleMidi(message.getMessage(), messageType, channel, note, vel, controllerNumber, controllerVal, pad);
}

void defaultDrawing() {
  colorMode(HSB, 255, 255, 255, 255);  
  fill(0, 0, 255);
  noFill();
  stroke(0, 0, 255);
  textFont(defaultFont);
  textAlign(LEFT);
  strokeWeight(1);
}
