public class CircleMode extends Mode {
  //bg images shape
  private PShape planche; 
  //list of circles that represent sensors
  private ArrayList<PShape> sensorCircles; 
  private ArrayList<BouncingSlave> slaves;
  //list of circle sizes updated by callback
  private ArrayList<Integer> newWidths; 
  private float rotation = 0;

  public CircleMode() {
    this.modeName = "Circle";
    this.defaultConfig.setProperty("SHRINK_FACTOR", "0.95");
    this.defaultConfig.setProperty("MAX_CIRCLE_WIDTH", "200");
    this.defaultConfig.setProperty("MIN_CIRCLE_WIDTH", "40");
    this.defaultConfig.setProperty("MAX_SLAVE_CIRCLE_WIDTH", "100");
    this.defaultConfig.setProperty("MIN_SLAVE_CIRCLE_WIDTH", "66");
    this.defaultConfig.setProperty("ROTATION_SPEED", "0.0005");
    this.defaultConfig.setProperty("PRESSES_FOR_SLAVE", "2");
    this.defaultConfig.setProperty("MAX_SLAVES", "20");
    this.defaultConfig.setProperty("SLAVE_SHRINK_FACTOR", "0.9");
    //midi controller specific, usually 255 but our Planck caps earlier
    this.defaultConfig.setProperty("MAX_VELOCITY", "100");
    this.defaultConfig.setProperty("SENSOR_THICKNESS", "5");
    this.defaultConfig.setProperty("SLAVE_THICKNESS", "1");
    this.defaultConfig.setProperty("SENSOR_COLOR_RANGE_MIN", "0");
    this.defaultConfig.setProperty("SENSOR_COLOR_RANGE_MAX", "200");

    //sets loaded config
    loadConfigFrom("circle_config.properties");
    println("Circle config: ");
    println(loadedConfig);
  }

  public void setup() {
    System.out.println("MODE: Circle");

    stroke(0, 255, 0);

    //init vars used to update sensor circle width
    newWidths = new ArrayList<Integer>();
    for ( int pad = 0; pad < numPads; pad++) {
      newWidths.add(this.getIntProp("MIN_CIRCLE_WIDTH"));
    }

    //frame to position sensor circles
    planche = polygon(100, numPads, 45);

    //Initialize circles that will be representing sensors on the planck            
    sensorCircles = new ArrayList<PShape>();
    for (int pad = 0; pad < numPads; pad++) {
      //go to polygon vertex to place circle
      pushMatrix();
      PVector vertex = planche.getVertex(pad);
      translate(vertex.x, vertex.y);
      sensorCircles.add(createShape(ELLIPSE, 0, 0, this.getIntProp("MIN_CIRCLE_WIDTH"), this.getIntProp("MIN_CIRCLE_WIDTH")));
      popMatrix();
    }

    slaves = new ArrayList<BouncingSlave>();
  }

  //Redraw circles, setting new widths when a sensor was pressed and
  //reducing their size otherwise
  public void draw() {    
    
    stroke(0, 255, 0);
    //continually rotate sensor circles
    pushMatrix();
    translate(width/2, height/2);
    rotation += TWO_PI * this.getFloatProp("ROTATION_SPEED");
    rotate(rotation);
    translate(-width/2, -height/2);
    for (int pad = 0; pad < numPads; pad++) {
      pushMatrix();
      PVector vertex = planche.getVertex(pad);
      translate(vertex.x, vertex.y);
      PShape circle = sensorCircles.get(pad);

      if (padWasPressed.get(pad)) {
        this.resetPressed(pad);

        //scale sensor circles
        circle.resetMatrix();
        circle.scale((float) newWidths.get(pad) / (float) this.getIntProp("MIN_CIRCLE_WIDTH"));

        //create slave
        if (pressCounter.get(pad) % this.getIntProp("PRESSES_FOR_SLAVE") == 0 && slaves.size() < this.getIntProp("MAX_SLAVES")) {
          slaves.add(new BouncingSlave(pad, 
            (int)screenX(0, 0), 
            (int)screenY(0, 0), 
            this.getIntProp("MIN_SLAVE_CIRCLE_WIDTH"), 
            this.getIntProp("MAX_SLAVE_CIRCLE_WIDTH"), 
            this.getFloatProp("SLAVE_SHRINK_FACTOR"), 
            this.getIntProp("SLAVE_THICKNESS"))
            );
        }

        //grow slaves
        for (BouncingSlave slave : slaves) {
          if (slave.master == pad) {
            slave.grow();
          }
        }
      } else if (circle.getWidth() * this.getFloatProp("SHRINK_FACTOR") >= this.getIntProp("MIN_CIRCLE_WIDTH")) {
        circle.scale(this.getFloatProp("SHRINK_FACTOR"));
      }
      //scale color      
      float constrainedBpm = constrain(currentBpm, 40, 150);
      int newColor = Math.round(map(constrainedBpm, 40, 150, this.getIntProp("SENSOR_COLOR_RANGE_MIN"), this.getIntProp("SENSOR_COLOR_RANGE_MAX")));
      
      circle.setStroke(color(newColor, 255, 255));  
      circle.setStrokeWeight(this.getIntProp("SENSOR_THICKNESS"));

      //push circle outwards    
      pushMatrix();
      rotate((TWO_PI/numPads) * (pad + 0.5));
      translate(circle.getWidth() - this.getIntProp("MIN_CIRCLE_WIDTH"), 0);

      //TODO: Figure out why shapes are disappearing and replace ellipse
      //shape(circle);
      stroke(newColor, 255, 255);
      strokeWeight(this.getIntProp("SENSOR_THICKNESS"));
      ellipse(0, 0, circle.getWidth(), circle.getWidth());

      popMatrix();
      popMatrix();
    }
    popMatrix();

    //maintain slave movement
    for (BouncingSlave slave : slaves) {
      slave.update();
    }
  }

  //TODO: move math to main loop, set newVelocity instead
  public void handleMidi(byte[] raw, byte messageType, int channel, int note, int vel, int controllerNumber, int controllerVal, Pad pad) {    
    //filter out unassigned notes and note_off messages
    if (pad != null && vel >= 0) {
      newWidths.set(pad.index, Math.round(map(constrain(vel, 60, this.getIntProp("MAX_VELOCITY")), 
        0, 
        this.getIntProp("MAX_VELOCITY"), 
        this.getIntProp("MIN_CIRCLE_WIDTH"), 
        this.getIntProp("MAX_CIRCLE_WIDTH"))));
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
}


//based on https://processing.org/examples/bounce.html
private class BouncingSlave {
  private int master;
  private int minrad;
  private int maxrad;
  private float shrinkfactor;
  private float slavethickness;

  private int rad;        // Width of the shape
  private float xpos, ypos;    // Starting position of shape    

  private float xspeed;  // Speed of the shape
  private float yspeed;  // Speed of the shape

  private int xdirection = 1;  // Left or Right
  private int ydirection = 1;  // Top to Bottom
  private int circleColor = 0;

  public BouncingSlave(int master, int xpos, int ypos, int minrad, int maxrad, float shrinkfactor, int slavethickness) {
    this.master = master;
    this.rad = minrad;
    this.minrad = minrad;
    this.maxrad = maxrad;  
    this.shrinkfactor = shrinkfactor;
    this.slavethickness = slavethickness;
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

    if (this.rad * this.shrinkfactor > this.minrad) {
      this.rad *= this.shrinkfactor;
    }

    // Draw the shape
    float constrainedBpm = constrain(currentBpm, 40, 150);
    stroke(color(constrain(this.circleColor*map(constrainedBpm, 40, 150, 2, 0.2), 0, 255), 255, 255));
    strokeWeight(slavethickness);
    ellipse(this.xpos, this.ypos, this.rad, this.rad);
  }
  public void grow() {
    this.rad = this.maxrad;
  }
}
