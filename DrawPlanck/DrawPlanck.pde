import processing.serial.*; 

//Constants
final int NUM_SIDES = 6;
final float GROWTH_FACTOR = 1.8;
final float SHRINK_FACTOR = 0.98;
final float MAX_CIRCLE_WIDTH = 350;
final float MIN_CIRCLE_WIDTH = 20;
final int BAUD_RATE = 19200;

//Global vars
PShape planche; //bg images shape
PGraphics pg; //bg images graphic
ArrayList<PShape> sensorCircles; //list of circles that represent sensors
Serial myPort;    // The serial port
String inString = "";  // Input string from serial port
int lf = 10;      // ASCII linefeed 
int jump;

void setup() {
  size(1024, 768, P2D);
  noFill();

  //Draw plank with appropriate number of sides
  stroke(255, 0, 0);
  planche = polygon(300, NUM_SIDES);
  pg = createGraphics(width, height);
  pg.beginDraw();
  pg.background(25);
  pg.shape(planche);
  pg.endDraw();

  //Initialize and draw circles that will be representing sensors on the planck
  sensorCircles = new ArrayList<PShape>();
  stroke(0, 255, 0);
  PShape e;
  for (int i = 0; i < NUM_SIDES; i++) {
    pushMatrix();
    translate(planche.getVertex(i).x, planche.getVertex(i).y);
    e = createShape(ELLIPSE, 0, 0, MIN_CIRCLE_WIDTH, MIN_CIRCLE_WIDTH);
    popMatrix();
    sensorCircles.add(e);
  }

  // List all the available serial ports: 
  printArray(Serial.list()); 

  myPort = new Serial(this, Serial.list()[0], BAUD_RATE); 
  myPort.bufferUntil(lf);
}

void draw() {

  //Set planck as bg image using static buffer
  background(pg);
  if (inString != "") {
    String current = inString.substring(3);
    jump = Integer.parseInt(current);
    inString = "";
    println("jump: " + jump);
    float desiredWidth = map(jump, 0, 512, 0, MAX_CIRCLE_WIDTH);
    PShape e = sensorCircles.get(0);
    e.resetMatrix();
    e.scale(desiredWidth / MIN_CIRCLE_WIDTH);
  }

  //Loop through vertices of the plank, draw circle while reducing its size if above min
  for (int i = 0; i < NUM_SIDES; i++) {
    pushMatrix();
    translate(planche.getVertex(i).x, planche.getVertex(i).y);
    PShape e = sensorCircles.get(i);
    int eWidth =(int) e.getWidth();
    if (eWidth > MIN_CIRCLE_WIDTH) {
      e.scale(SHRINK_FACTOR);
    }
    int ecolor = 150;
    stroke(ecolor);
    shape(e);
    popMatrix();
  }
}

//Function copied from https://processing.org/examples/regularpolygon.html and modified to return polygon aligned with center of screen
PShape polygon(float radius, int npoints) {
  float angle = TWO_PI / npoints;
  PShape s = createShape();
  s.beginShape();
  for (float a = 0; a < TWO_PI; a += angle) {
    float sx = width/2 + cos(a) * radius;
    float sy = height/2 + sin(a) * radius;
    s.vertex(sx, sy);
  }
  s.endShape(CLOSE);
  return s;
}

void serialEvent(Serial p) { 
  inString = p.readString();
} 