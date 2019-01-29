import themidibus.*;
import javax.sound.midi.MidiMessage; 
import java.util.Arrays; 

//Midi config
//Look at console to see available midi inputs and set
//the index of your midi device here
//TODO:  use gui to select midi input device
final int MIDI_DEVICE = 0;

//ordering here dictates correspondence to pads according to the following:
// BOTTOM_RIGHT // BOTTOM_LEFT // TOP_LEFT // TOP_RIGHT
final Integer[] NOTES = {85, 84, 80, 82}; 

//midi controller specific
final int MAX_VELOCITY = 100;

//planck config
final int NUM_PADS = NOTES.length;

//circles config
final float SHRINK_FACTOR = 0.95;
final int MAX_CIRCLE_WIDTH = 200;
final int MIN_CIRCLE_WIDTH = 40;
final int MAX_SLAVE_CIRCLE_WIDTH = MAX_CIRCLE_WIDTH/2;
final int MIN_SLAVE_CIRCLE_WIDTH = MIN_CIRCLE_WIDTH/3;
final float LOGO_SCALING = 0.05;
final float ROTATION_SPEED = 0.0005;
final int PRESSES_FOR_SLAVE = 2;
final int MAX_SLAVES = 20;
final float SLAVE_SHRINK_FACTOR = 0.9;

//Shape globals
PShape planche; //bg images shape
PGraphics pg; //bg images graphic
ArrayList<PShape> sensorCircles; //list of circles that represent sensors
ArrayList<BouncingSlave> slaves;
ArrayList<Integer> newWidths; //list of circle sizes updated by callback
ArrayList<Boolean> padWasPressed; //flags indicating a pad was pressed, also updated by callback
ArrayList<Integer> pressCounter; 
MidiBus myBus;
float rotation = 0;


void setup() {
  //size(800, 600, P2D);
  fullScreen(P2D);
  frameRate(100);

  //setup midi
  MidiBus.list(); 
  myBus = new MidiBus(this, MIDI_DEVICE, 1); 

  //Create background shape (PShape) and static image (PGraphic)
  noFill();
  stroke(255, 0, 0);
  planche = polygon(100, NUM_PADS, 45);
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
  newWidths = new ArrayList<Integer>();
  padWasPressed = new ArrayList<Boolean>();
  pressCounter = new ArrayList<Integer>();  
  for ( int pad = 0; pad < NUM_PADS; pad++) {
    newWidths.add((int)(MIN_CIRCLE_WIDTH));
    padWasPressed.add(false);
    pressCounter.add(0);
  }
  slaves = new ArrayList<BouncingSlave>();

  //Initialize circles that will be representing sensors on the planck
  stroke(0, 255, 0);
  sensorCircles = new ArrayList<PShape>();
  for (int pad = 0; pad < NUM_PADS; pad++) {
    //go to polygon vertex to place circle
    pushMatrix();
    PVector vertex = planche.getVertex(pad);
    translate(vertex.x, vertex.y);
    sensorCircles.add(createShape(ELLIPSE, 0, 0, MIN_CIRCLE_WIDTH, MIN_CIRCLE_WIDTH));
    popMatrix();
  }

  //easier to scale
  colorMode(HSB, 255);
}

void draw() {
  //Redraw bg to erase previous frame
  background(pg);

  //continually rotate sensor circles
  pushMatrix();
  translate(width/2, height/2);
  rotation += TWO_PI * ROTATION_SPEED;
  rotate(rotation);
  translate(-width/2, -height/2);

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

      //reset pressed flag
      padWasPressed.set(pad, false);

      //scale sensor circles
      circle.resetMatrix();
      circle.scale(newWidths.get(pad) / MIN_CIRCLE_WIDTH);

      //create slave
      if (pressCounter.get(pad) >= PRESSES_FOR_SLAVE && slaves.size() < MAX_SLAVES) {
        slaves.add(new BouncingSlave(pad, (int)screenX(0, 0), (int)screenY(0, 0)));
        pressCounter.set(pad, 0);
      }

      //Grow slaves
      for (BouncingSlave slave : slaves) {
        if (slave.master == pad) {
          slave.grow();
        }
      }
    } else if (circle.getWidth() > MIN_CIRCLE_WIDTH) {
      circle.scale(SHRINK_FACTOR);
    }
    //scale color
    float constrainedWidth = constrain(circle.getWidth(), MIN_CIRCLE_WIDTH, MAX_CIRCLE_WIDTH);
    int newColor = Math.round(map(constrainedWidth, MIN_CIRCLE_WIDTH, MAX_CIRCLE_WIDTH, 0, 200));
    circle.setStroke(color(newColor, 255, 255));  
    circle.setStrokeWeight(5);

    //push circle outwards    
    pushMatrix();
    rotate(TWO_PI * (0.125 + (pad*0.25)));
    translate(circle.getWidth() - MIN_CIRCLE_WIDTH, 0);

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

    //TODO: move math to main loop, set newVelocity instead
    newWidths.set(pad, Math.round(map(constrain(vel, 0, MAX_VELOCITY), 0, MAX_VELOCITY, 0, MAX_CIRCLE_WIDTH)));
  }
}

int noteToPad (int note) {
  return Arrays.asList(NOTES).indexOf(note);
}

//based on https://processing.org/examples/bounce.html
private class BouncingSlave {
  private int master;
  private int rad = MIN_SLAVE_CIRCLE_WIDTH;        // Width of the shape
  private float xpos, ypos;    // Starting position of shape    

  private float xspeed;  // Speed of the shape
  private float yspeed;  // Speed of the shape

  private int xdirection = 1;  // Left or Right
  private int ydirection = 1;  // Top to Bottom
  private int circleColor = 0;

  public BouncingSlave(int master, int xpos, int ypos) {
    this.master = master;
    this.xpos = xpos;
    this.ypos = ypos;
    this.xspeed = random(1, 4);
    this.yspeed = random(1, 4);
    this.circleColor = (int)random(50, 120);
    this.xdirection = (int) pow(-1, (int) random(1, 3));
    this.ydirection = (int) pow(-1, (int) random(1, 3));
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

    if (this.rad > MIN_SLAVE_CIRCLE_WIDTH) {
      this.rad *= SLAVE_SHRINK_FACTOR;
    }
    // Draw the shape
    stroke(color(this.circleColor, 255, 255));
    ellipse(this.xpos, this.ypos, this.rad, this.rad);
  }
  public void grow() {
    this.rad = MAX_SLAVE_CIRCLE_WIDTH;
  }
}