import java.util.Properties;

public class CircleMode extends Mode {
  //Shape globals
  private PShape planche; //bg images shape
  private ArrayList<PShape> sensorCircles; //list of circles that represent sensors
  private ArrayList<BouncingSlave> slaves;
  private ArrayList<Integer> newWidths; //list of circle sizes updated by callback
  private float rotation = 0;
  
  public CircleMode(){
    this.defaultConfig.setProperty("SHRINK_FACTOR", "0.95");
    this.defaultConfig.setProperty("MAX_CIRCLE_WIDTH", "200");
    this.defaultConfig.setProperty("MIN_CIRCLE_WIDTH", "40");
    this.defaultConfig.setProperty("MAX_SLAVE_CIRCLE_WIDTH", "100");
    this.defaultConfig.setProperty("MIN_SLAVE_CIRCLE_WIDTH", "66");
    this.defaultConfig.setProperty("LOGO_SCALING", "0.05");
    this.defaultConfig.setProperty("ROTATION_SPEED", "0.0005");
    this.defaultConfig.setProperty("PRESSES_FOR_SLAVE", "2");
    this.defaultConfig.setProperty("MAX_SLAVES", "20");
    this.defaultConfig.setProperty("SLAVE_SHRINK_FACTOR", "0.9");
    //midi controller specific, usually 255 but our Planck caps earlier
    this.defaultConfig.setProperty("MAX_VELOCITY", "100");
    
    //sets loaded config
    loadConfigFrom("circle_config.properties");
    println(configProps);
  }
  
  @Override
  public void setup(){
    System.out.println("MODE: Circle");
    
    stroke(0, 255, 0);
    
    //init vars used to update sensor circle width
    newWidths = new ArrayList<Integer>();
    for ( int pad = 0; pad < NUM_PADS; pad++) {
      newWidths.add((int)(this.getIntProp("MIN_CIRCLE_WIDTH")));
    }
    
    //frame to position sensor circles
    planche = polygon(100, NUM_PADS, 45);
    
    //Initialize circles that will be representing sensors on the planck            
    sensorCircles = new ArrayList<PShape>();
    for (int pad = 0; pad < NUM_PADS; pad++) {
      //go to polygon vertex to place circle
      pushMatrix();
      PVector vertex = planche.getVertex(pad);
      translate(vertex.x, vertex.y);
      sensorCircles.add(createShape(ELLIPSE, 0, 0, getIntProp("MIN_CIRCLE_WIDTH"), getIntProp("MIN_CIRCLE_WIDTH")));
      popMatrix();
    }
    
    slaves = new ArrayList<BouncingSlave>();    
  }
  
  //Redraw circles, setting new widths when a sensor was pressed and
  //reducing their size otherwise
  public void draw(){    
    //continually rotate sensor circles
    pushMatrix();
    translate(width/2, height/2);
    rotation += TWO_PI * getFloatProp("ROTATION_SPEED");
    rotate(rotation);
    translate(-width/2, -height/2);
    for (int pad = 0; pad < NUM_PADS; pad++) {
      pushMatrix();
      PVector vertex = planche.getVertex(pad);
      translate(vertex.x, vertex.y);
      PShape circle = sensorCircles.get(pad);
  
      if (padWasPressed.get(pad)) {
        //scale sensor circles
        circle.resetMatrix();
        circle.scale(newWidths.get(pad) / getIntProp("MIN_CIRCLE_WIDTH"));
  
        //create slave
        if (pressCounter.get(pad) % getIntProp("PRESSES_FOR_SLAVE") == 0 && slaves.size() < getIntProp("MAX_SLAVES")) {
          slaves.add(new BouncingSlave(
            pad,
            (int)screenX(0, 0),
            (int)screenY(0, 0),
            getIntProp("MIN_SLAVE_CIRCLE_WIDTH"),
            getIntProp("MAX_SLAVE_CIRCLE_WIDTH"),
            getFloatProp("SLAVE_SHRINK_FACTOR"))
          );          
        }
  
        //grow slaves
        for (BouncingSlave slave : slaves) {
          if (slave.master == pad) {
            slave.grow();
          }
        }
      } else if (circle.getWidth() > getIntProp("MIN_CIRCLE_WIDTH")) {
        circle.scale(Float.parseFloat(loadedConfig.getProperty("SHRINK_FACTOR")));
      }
      //scale color
      float constrainedWidth = constrain(circle.getWidth(), getIntProp("MIN_CIRCLE_WIDTH"), getIntProp("MAX_CIRCLE_WIDTH"));
      int newColor = Math.round(map(constrainedWidth, getIntProp("MIN_CIRCLE_WIDTH"), getIntProp("MAX_CIRCLE_WIDTH"), 0, 200));
      circle.setStroke(color(newColor, 255, 255));  
      circle.setStrokeWeight(5);
  
      //push circle outwards    
      pushMatrix();
      rotate(TWO_PI * (0.125 + (pad*0.25)));
      translate(circle.getWidth() - getIntProp("MIN_CIRCLE_WIDTH"), 0);
  
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
  
  public void handleMidi(Pad pad, int note, int vel){
    //TODO: move math to main loop, set newVelocity instead
    newWidths.set(pad.index, Math.round(map(constrain(vel, 0, getIntProp("MAX_VELOCITY")), 0, getIntProp("MAX_VELOCITY"), 0, getIntProp("MAX_CIRCLE_WIDTH"))));
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
}
  
  
  
//based on https://processing.org/examples/bounce.html
private class BouncingSlave {
  private int master;
  private int minrad;
  private int maxrad;
  private float shrinkfactor;
  private int rad;        // Width of the shape
  private float xpos, ypos;    // Starting position of shape    

  private float xspeed;  // Speed of the shape
  private float yspeed;  // Speed of the shape

  private int xdirection = 1;  // Left or Right
  private int ydirection = 1;  // Top to Bottom
  private int circleColor = 0;

  public BouncingSlave(int master, int xpos, int ypos, int minrad, int maxrad, float shrinkfactor) {
    this.master = master;
    this.rad = minrad;
    this.minrad = minrad;
    this.maxrad = maxrad;  
    this.shrinkfactor = shrinkfactor;
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

    if (this.rad > minrad) {
      this.rad *= shrinkfactor;
    }
    // Draw the shape
    stroke(color(this.circleColor, 255, 255));
    ellipse(this.xpos, this.ypos, this.rad, this.rad);
  }
  public void grow() {
    this.rad = maxrad;
  }
}
