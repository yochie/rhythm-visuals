import themidibus.*;
import javax.sound.midi.MidiMessage; 
import java.util.Arrays; 

//Midi config
//Look at console to see available midi inputs and set
//the index of your midi device here
//TODO:  use gui to select midi input device
int midiDevice  = 0;

MidiBus myBus;

//ordering here dictates correspondence to pads according to the following:
// BOTTOM_RIGHT // BOTTOM_LEFT // TOP_LEFT // TOP_RIGHT
Integer[] notes = {60, 62, 64, 65}; 

//midi controller specific
final int MAX_VELOCITY = 128;

//Drawing config
final int NUM_PADS = notes.length;
final float SHRINK_FACTOR = 0.95;
final int MAX_CIRCLE_WIDTH = 350;
final int MIN_CIRCLE_WIDTH = 20;

//Shape stuff
PShape planche; //bg images shape
PGraphics pg; //bg images graphic
ArrayList<PShape> sensorCircles; //list of circles that represent sensors
ArrayList<Integer> newWidths; //list of circle sizes updated by callback
ArrayList<Boolean> padWasPressed; //flags indicating a pad was pressed, also updated by callback

void setup() {
  size(1024, 768, P2D);

  //setup midi
  MidiBus.list(); 
  myBus = new MidiBus(this, midiDevice, 1); 

  //Create background shape and static image (PGraphic)
  noFill();
  stroke(255, 0, 0);
  planche = polygon(300, NUM_PADS, 45);
  pg = createGraphics(width, height);
  pg.beginDraw();
  pg.background(25);
  pg.shape(planche);
  pg.endDraw();

  //initialize variables set by midi callback
  newWidths = new ArrayList<Integer>();
  padWasPressed = new ArrayList<Boolean>();
  for ( int i = 0; i < NUM_PADS; i++) {
    newWidths.add((int)(MIN_CIRCLE_WIDTH));
    padWasPressed.add(false);
  }

  //Initialize and draw circles that will be representing sensors on the planck
  stroke(0, 255, 0);
  sensorCircles = new ArrayList<PShape>();
  for (int i = 0; i < NUM_PADS; i++) {
    pushMatrix();
    translate(planche.getVertex(i).x, planche.getVertex(i).y);
    sensorCircles.add(createShape(ELLIPSE, 0, 0, MIN_CIRCLE_WIDTH, MIN_CIRCLE_WIDTH));
    popMatrix();
  }
}

void draw() {

  //Redraw bg to erase previous frame
  background(pg);

  //Redraw circles, setting new widths when a sensor was pressed and
  //reducing their size otherwise
  for (int pad = 0; pad < NUM_PADS; pad++) {
    pushMatrix();
    PVector vertex = planche.getVertex(pad);
    translate(vertex.x, vertex.y);
    PShape circle = sensorCircles.get(pad);

    if (padWasPressed.get(pad)) {
      circle.resetMatrix();
      circle.scale(newWidths.get(pad) / MIN_CIRCLE_WIDTH);
      padWasPressed.set(pad, false);
    } else if (circle.getWidth() > MIN_CIRCLE_WIDTH) {
      circle.scale(SHRINK_FACTOR);
    }

    shape(circle);
    popMatrix();
  }
}

//copied from https://processing.org/examples/regularpolygon.html 
//and modified for angledOffset and centering
PShape polygon(float radius, int npoints, int angledOffset) {
  float angle = TWO_PI / npoints;
  PShape s = createShape();
  s.beginShape();
  for (float a = radians(angledOffset); a < TWO_PI + radians(angledOffset); a += angle) {
    int sx = Math.round(width/2 + cos(a) * radius);
    int sy = Math.round(height/2 + sin(a) * radius);
    s.vertex(sx, sy);
  }
  s.endShape(CLOSE);
  return s;
}

//Called by MidiBus library whenever a new midi message is received
void midiMessage(MidiMessage message) { 
  int note = (int)(message.getMessage()[1] & 0xFF) ;
  int vel = (int)(message.getMessage()[2] & 0xFF);
  println("note: " + note + " vel: "+ vel);
  
  int pad = noteToPad(note);
  if (pad >= 0 && (vel > 0)) {
    padWasPressed.set(pad, true);
    newWidths.set(pad, (int) map(constrain(vel, 0, MAX_VELOCITY), 0, MAX_VELOCITY, 0, MAX_CIRCLE_WIDTH));
  }
}

int noteToPad (int note) {
  return Arrays.asList(notes).indexOf(note);
}
