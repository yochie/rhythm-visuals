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
Integer[] notes = {85, 84, 80, 82}; 

//midi controller specific
final int MAX_VELOCITY = 128;

//Drawing config
final int NUM_PADS = notes.length;
final float SHRINK_FACTOR = 0.95;
final int MAX_CIRCLE_WIDTH = 200;
final int MIN_CIRCLE_WIDTH = 20;
final float rotationSpeed = 0.0005;
final int pressesForSlave = 4;
final int maxSlaves = 10;
float rotation = 0;

//Shape stuff
PShape planche; //bg images shape
PGraphics pg; //bg images graphic
ArrayList<PShape> sensorCircles; //list of circles that represent sensors
ArrayList<BouncingSlave> slaves;
ArrayList<Integer> newWidths; //list of circle sizes updated by callback
ArrayList<Boolean> padWasPressed; //flags indicating a pad was pressed, also updated by callback
ArrayList<Integer> pressCounter; 
void setup() {
  size(800, 600, P2D);
  //setup midi
  MidiBus.list(); 
  myBus = new MidiBus(this, midiDevice, 1); 

  //Create background shape (PShape) and static image (PGraphic)
  noFill();
  stroke(255, 0, 0);
  planche = polygon(50, NUM_PADS, 45);
  pg = createGraphics(width, height);
  pg.beginDraw();
  pg.background(25);
  //pg.shape(planche);
  pg.endDraw();
  background(pg);

  //initialize variables set by midi callback
  newWidths = new ArrayList<Integer>();
  padWasPressed = new ArrayList<Boolean>();
  pressCounter = new ArrayList<Integer>();

  for ( int pad = 0; pad < NUM_PADS; pad++) {
    newWidths.add((int)(MIN_CIRCLE_WIDTH));
    padWasPressed.add(false);
    pressCounter.add(0);
  }

  //Initialize circles that will be representing sensors on the planck
  stroke(0, 255, 0);
  sensorCircles = new ArrayList<PShape>();
  for (int pad = 0; pad < NUM_PADS; pad++) {
    pushMatrix();
    PVector vertex = planche.getVertex(pad);
    translate(vertex.x, vertex.y);
    sensorCircles.add(createShape(ELLIPSE, 0, 0, MIN_CIRCLE_WIDTH, MIN_CIRCLE_WIDTH));
    popMatrix();
  }
  slaves = new ArrayList<BouncingSlave>();
  colorMode(HSB, 255);
}

void draw() {
  pushMatrix();
  translate(width/2, height/2);
  rotation += TWO_PI * rotationSpeed;
  rotate(rotation);
  translate(-width/2, -height/2);
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
      //reset pressCounter on other pads
      for (int otherpad = 0; otherpad<NUM_PADS; otherpad++) {
        if (otherpad != pad) {
          pressCounter.set(otherpad, 0);
        }
      }
      //increment own presscounter
      pressCounter.set(pad, pressCounter.get(pad) + 1);
      
      //scale sensor circles
      circle.resetMatrix();
      circle.scale(newWidths.get(pad) / MIN_CIRCLE_WIDTH);
      
      //reset pressed flag
      padWasPressed.set(pad, false);
      
      //create slave
      if (pressCounter.get(pad) >= pressesForSlave && slaves.size() < maxSlaves) {
        slaves.add(new BouncingSlave(pad, (int)screenX(0, 0), (int)screenY(0, 0)));
        pressCounter.set(pad, 0);
      }
      
      //Grow slaves
      for (BouncingSlave slave : slaves) {
        if (slave.master == pad) {
          slave.grow();
          println("growing");
        }
      }
    } else if (circle.getWidth() > MIN_CIRCLE_WIDTH) {
      circle.scale(SHRINK_FACTOR);
    }
    
    //push circle outwards    
    pushMatrix();
    rotate(TWO_PI * (0.125 + (pad*0.25)));
    translate(circle.getWidth() - MIN_CIRCLE_WIDTH, 0);
    
    //scale color
    int newColor = Math.round(map(constrain(circle.getWidth(), MIN_CIRCLE_WIDTH, MAX_CIRCLE_WIDTH), MIN_CIRCLE_WIDTH, MAX_CIRCLE_WIDTH, 0, 255));
    circle.setStroke(color(newColor, 100, 200));
    shape(circle);
    popMatrix();
    popMatrix();
  }
  popMatrix();
  
  //maintain slave movement
  for (BouncingSlave slave : slaves) {
    slave.update();
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
    newWidths.set(pad, Math.round(map(constrain(vel, 0, MAX_VELOCITY), 0, MAX_VELOCITY, 0, MAX_CIRCLE_WIDTH)));
  }
}

int noteToPad (int note) {
  return Arrays.asList(notes).indexOf(note);
}

private class BouncingSlave {
  private int master;
  private int rad = MIN_CIRCLE_WIDTH;        // Width of the shape
  private float xpos, ypos;    // Starting position of shape    

  private float xspeed = 2.8;  // Speed of the shape
  private float yspeed = 2.2;  // Speed of the shape

  private int xdirection = 1;  // Left or Right
  private int ydirection = 1;  // Top to Bottom

  public BouncingSlave(int master, int xpos, int ypos) {
    this.master = master;
    this.xpos = xpos;
    this.ypos = ypos;
  }
  public void update() {
    // Update the position of the shape
    this.xpos = this.xpos + ( this.xspeed * this.xdirection );
    this.ypos = this.ypos + ( this.yspeed * this.ydirection );

    // Test to see if the shape exceeds the boundaries of the screen
    // If it does, reverse its direction by multiplying by -1
    if (this.xpos > width-this.rad || this.xpos < this.rad) {
      this.xdirection *= -1;
    }
    if (ypos > height-rad || ypos < rad) {
      this.ydirection *= -1;
    }

    if (this.rad > MIN_CIRCLE_WIDTH) {
      this.rad *= 0.95;
    }
    // Draw the shape
    ellipse(this.xpos, this.ypos, this.rad, this.rad);
  }
  public void grow() {
    this.rad = MAX_CIRCLE_WIDTH;
  }
}
