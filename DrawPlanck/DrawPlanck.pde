import themidibus.*;
import javax.sound.midi.MidiMessage; 
import java.util.Arrays; 


//Midi config
int midiDevice  = 0;
MidiBus myBus;
int[] notes = {60, 62, 64, 65}; 

//Drawing config
final int NUM_PADS = 4;
final float SHRINK_FACTOR = 0.95;
final float MAX_CIRCLE_WIDTH = 350;
final float MIN_CIRCLE_WIDTH = 20;

//Shape stuff
PShape planche; //bg images shape
PGraphics pg; //bg images graphic
ArrayList<PShape> sensorCircles; //list of circles that represent sensors
ArrayList<Integer> newWidths; //list of circle circle sizes updated by callback
ArrayList<Boolean> widthChanged; //list of circle circle sizes updated by callback


void setup() {
  size(1024, 768, P2D);

  //setup midi
  MidiBus.list(); 
  myBus = new MidiBus(this, midiDevice, 1); 

  //Draw plank with appropriate number of sides
  noFill();
  stroke(255, 0, 0);
  planche = polygon(300, NUM_PADS, 45);
  pg = createGraphics(width, height);
  pg.beginDraw();
  pg.background(25);
  pg.shape(planche);
  pg.endDraw();

  //initialize dynamic widths
  newWidths = new ArrayList<Integer>();
  widthChanged = new ArrayList<Boolean>();
  for ( int i = 0; i < NUM_PADS; i++) {
    newWidths.add((int)(MIN_CIRCLE_WIDTH));
    widthChanged.add(false);
  }

  //Initialize and draw circles that will be representing sensors on the planck
  sensorCircles = new ArrayList<PShape>();
  stroke(0, 255, 0);
  PShape e;
  for (int i = 0; i < NUM_PADS; i++) {
    pushMatrix();
    translate(planche.getVertex(i).x, planche.getVertex(i).y);
    e = createShape(ELLIPSE, 0, 0, MIN_CIRCLE_WIDTH, MIN_CIRCLE_WIDTH);
    popMatrix();
    sensorCircles.add(e);
  }
}

void draw() {

  //Set planck as bg image using static buffer
  background(pg);

  //Loop through vertices of the plank, draw circle while reducing its size if above min
  for (int i = 0; i < NUM_PADS; i++) {
    pushMatrix();
    translate(planche.getVertex(i).x, planche.getVertex(i).y);
    PShape e = sensorCircles.get(i);
    int eWidth =(int) e.getWidth();
    
    if (widthChanged.get(i)) {
      e.resetMatrix();
      e.scale(newWidths.get(i) / MIN_CIRCLE_WIDTH);
      widthChanged.set(i, false);
    } else if (eWidth > MIN_CIRCLE_WIDTH) {
      e.scale(SHRINK_FACTOR);
    }

    int ecolor = 150;
    stroke(ecolor);
    shape(e);
    popMatrix();
  }
}

//Function copied from https://processing.org/examples/regularpolygon.html and modified to return polygon aligned with center of screen
PShape polygon(float radius, int npoints, int angled) {
  float angle = TWO_PI / npoints;
  PShape s = createShape();
  s.beginShape();
  for (float a = radians(angled); a < TWO_PI + radians(angled); a += angle) {
    float sx = width/2 + cos(a) * radius;
    float sy = height/2 + sin(a) * radius;
    s.vertex(sx, sy);
  }
  s.endShape(CLOSE);
  return s;
}
void midiMessage(MidiMessage message, long timestamp, String bus_name) { 
  int note = (int)(message.getMessage()[1] & 0xFF) ;
  int vel = (int)(message.getMessage()[2] & 0xFF);

  println("note: " + note + " vel: "+ vel);
  int pad = noteToPad(note);
  if (pad >= 0 && (vel != 0)) {
    println("tapped");
    newWidths.set(pad, (int) map(vel, 0, 128, 0, MAX_CIRCLE_WIDTH));
    widthChanged.set(pad, true);
  }
}

int noteToPad (int note) {
  Arrays.sort(notes);
  return Arrays.binarySearch(notes, note);
}
