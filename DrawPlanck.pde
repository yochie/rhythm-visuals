/* FOR SERIAL 
 import processing.serial.*; 
 
 Serial myPort;    // The serial port
 String inString;  // Input string from serial port
 int lf = 10;      // ASCII linefeed 
 */
 
//Constants
final int NUM_SIDES = 6;
final float GROWTH_FACTOR = 1.8;
final float SHRINK_FACTOR = 0.98;
final float MAX_CIRCLE_WIDTH = 350;
final float MIN_CIRCLE_WIDTH = 20;

//Global vars
PShape planche;
ArrayList<PShape> sensorCircles;
PGraphics pg;

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

  /* FOR SERIAL
   // List all the available serial ports: 
   printArray(Serial.list()); 
   
   myPort = new Serial(this, Serial.list()[0], 115200); 
   myPort.bufferUntil(lf); 
   */
}

void draw() {
  
  //Set planck as bg image using static buffer
  background(pg);
  
  //Loop through vertices of the plank, draw circle while reducing its size if above min
  for (int i = 0; i < NUM_SIDES; i++) {
    pushMatrix();
    translate(planche.getVertex(i).x, planche.getVertex(i).y);
    PShape e = sensorCircles.get(i);
    if (e.getWidth() > MIN_CIRCLE_WIDTH) {
      e.scale(SHRINK_FACTOR);
    }
    shape(e);
    popMatrix();
    //str = String.format("V %d : " + planche.getVertex(i), i);
    //println(str);
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

/* FOR SERIAL 
 void serialEvent(Serial p) { 
 inString = p.readString();
 } 
 */

void mousePressed() {
  for (int i = 0; i < NUM_SIDES; i++) {
    PShape e = sensorCircles.get(i);
    
    //If not too large yet, grow circle
    if (e.getWidth()*GROWTH_FACTOR < MAX_CIRCLE_WIDTH) {
      e.scale(GROWTH_FACTOR);
    }
    //Otherwise, set circle to its max width
    else {
      e.resetMatrix();
      e.scale(MAX_CIRCLE_WIDTH / MIN_CIRCLE_WIDTH);
    }
  }
}