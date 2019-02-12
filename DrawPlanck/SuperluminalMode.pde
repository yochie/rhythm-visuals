public class SuperluminalMode extends Mode {

  private ArrayList<Star> stars;
  private boolean bgFlow = true;
  private int padVelocity = 1;
  private int redRandomVal = 70;

  public SuperluminalMode() {

    // TODO check how to set a bool prop
    this.defaultConfig.setProperty("BG_STARS", "1");
    this.defaultConfig.setProperty("BG_STARS_NUMBER", "4");
    this.defaultConfig.setProperty("BG_STARS_SPEED", "30");

    this.defaultConfig.setProperty("STARS_START_COLOR_R", "75");
    this.defaultConfig.setProperty("STARS_START_COLOR_G", "0");
    this.defaultConfig.setProperty("STARS_START_COLOR_B", "200");
    
    this.defaultConfig.setProperty("STARS_END_COLOR_R", "200");
    this.defaultConfig.setProperty("STARS_END_COLOR_G", "0");
    this.defaultConfig.setProperty("STARS_END_COLOR_B", "0");

    this.defaultConfig.setProperty("STARS1_SPEED", "20");
    this.defaultConfig.setProperty("STARS2_SPEED", "15");
    this.defaultConfig.setProperty("STARS3_SPEED", "10");
    this.defaultConfig.setProperty("STARS4_SPEED", "5");

    //midi controller specific, usually 255 but our Planck caps earlier
    this.defaultConfig.setProperty("MAX_VELOCITY", "100");
    this.defaultConfig.setProperty("VELOCITY_FACTOR", "0.09");
    this.defaultConfig.setProperty("STAR_THICKNESS", "1");

    //sets loaded config
    loadConfigFrom("superluminal_config.properties");
    println("Supraluminal config: ");
    println(loadedConfig);
  }

  public void setup() {
    System.out.println("MODE: Supraluminal");
    stroke(0, 255, 0);
    stars = new ArrayList<Star>();
    if(this.getIntProp("BG_STARS") == 0) { bgFlow = false; }
    //Override Drawplanck HSB mode
    colorMode(RGB);
  }

  //Create stars when a sensor was pressed and keep them moving
  public void draw() {

    int starNumber;
    float starGrowFactor;
    int starSpeed;

    //create constant stars flow in background if config ON
    if(bgFlow) {
        for (int i = 0; i < this.getIntProp("BG_STARS_NUMBER"); i++) {
          //set color with smooth random
          int randomStartRed = this.getIntProp("STARS_START_COLOR_R") + (int) random(-redRandomVal,redRandomVal);
          int randomEndRed = this.getIntProp("STARS_END_COLOR_R") + (int) random(-redRandomVal,redRandomVal);
          color startCol = color(randomStartRed,this.getIntProp("STARS_START_COLOR_G"),this.getIntProp("STARS_START_COLOR_B"));
          color endCol = color(randomEndRed,this.getIntProp("STARS_END_COLOR_G"),this.getIntProp("STARS_END_COLOR_B"));
          //create star
          stars.add(new Star(
            0, //do not grow
            this.getIntProp("BG_STARS_SPEED"),
            startCol,
            endCol,
            this.getIntProp("STAR_THICKNESS")
          ));
        }
    }

    for (int padIdx = 0; padIdx < numPads; padIdx++) {

      //create stars
      if (padWasPressed.get(padIdx)) {
        this.resetPressed(padIdx);

        //set stars params depending on pad
        int starIdx = padIdx + 1;
        //default
        if(starIdx <= 0 || starIdx > 4) {
          starIdx = 1;
          println("Pad " + starIdx + " is not assigned - Falling to star1 config");
        }
        starNumber = this.getIntProp("STARS"+starIdx+"_NUMBER"); // TODO check: not set at init - how is it working?
        starGrowFactor = this.getFloatProp("STARS"+starIdx+"_GROW_FACTOR");
        starSpeed = this.getIntProp("STARS"+starIdx+"_SPEED");

        //set color with smooth random
        int randomStartRed = this.getIntProp("STARS_START_COLOR_R") + (int) random(-redRandomVal,redRandomVal);
        int randomEndRed = this.getIntProp("STARS_END_COLOR_R") + (int) random(-redRandomVal,redRandomVal);
        println("rand start:"+randomStartRed);
        println("rand end:"+randomEndRed);
        color startCol = color(randomStartRed,this.getIntProp("STARS_START_COLOR_G"),this.getIntProp("STARS_START_COLOR_B"));
        color endCol = color(randomEndRed,this.getIntProp("STARS_END_COLOR_G"),this.getIntProp("STARS_END_COLOR_B"));

        //create as much stars as configured for this pad
        //related to pad velocity
        starNumber *= padVelocity*this.getFloatProp("VELOCITY_FACTOR");
        for (int i = 0; i < starNumber; i++) {
          stars.add(new Star(
            starGrowFactor,
            starSpeed,
            startCol,
            endCol,
            this.getIntProp("STAR_THICKNESS"))
          );
        }

        //Trigger stars bg flow on/off
        Pad pad = pads.get(padIdx);
        if (pad.name == "BOTTOM_LEFT_NOTE" && pressCounter.get(padIdx) >= this.getIntProp("BG_STARS_TRIGGER_PRESSES")) {
            if(bgFlow) { bgFlow = false; }
            else { bgFlow = true; }
            //reset pad presses counter
            pressCounter.set(padIdx, 0);
        }

      }

    }

    //maintain stars movement
    for (int i = 0; i < stars.size(); i++) {
      Star star = stars.get(i);
      star.update();
      //remove out of screen stars - TODO => debug & FIX: biggest stars not removed / removed after a very long time
      if(!star.visible) {
        stars.remove(i);
      }
    }
    //printArray(stars);
  }

  public void handleMidi(byte[] raw, byte messageType, int channel, int note, int vel, int controllerNumber, int controllerVal, Pad pad) {
    // Do something on MIDI msg received
    // Keep track of pad velocity to affect stars number
    padVelocity = vel;
  }

}

//based on https://processing.org/examples/bounce.html
//and https://processing.org/examples/accelerationwithvectors.html
private class Star {

  private boolean visible = true;

  // Always start at center
  private PVector location = new PVector(width/2,height/2);
  private PVector velocity;
  private PVector acceleration;
  private PVector destination;
  private float topspeed;

  private float growfactor;
  private float starThickness;
  private float rad;
  private color circleColor = color(0, 0, 0);
  private color circleColorEnd = color(255, 255, 255);

  public Star(float starGrowFactor, int speed, int startColor, int endColor, int starThickness) {

    this.velocity = new PVector(0,0);
    this.topspeed = speed;
    float destX = random(width);
    float destY = height*random(0,1);
    this.destination = new PVector(destX,destY);
    //this.destination = PVector.random2D();
    this.acceleration = PVector.sub(this.destination,this.location);

    this.rad = 1;
    this.growfactor = starGrowFactor;
    this.starThickness = starThickness;
    this.circleColor = startColor;
    this.circleColorEnd = endColor;
  }

  public void update() {

    // Velocity changes according to acceleration
    this.velocity.add(this.acceleration);
    // Limit the velocity by topspeed
    this.velocity.limit(this.topspeed);
    // Location changes by velocity
    this.location.add(this.velocity);
    
    // Update size and color of the star
    this.rad = this.rad + this.growfactor;
    this.circleColor = lerpColor(circleColor, circleColorEnd, .05);
      
    // Check if the star is still visible
    if (this.location.x > width+this.rad/2 || this.location.x < -this.rad/2) {
      this.visible = false;
    }
    if (this.location.y > height+this.rad/2 || this.location.y < -this.rad/2) {
      this.visible = false;
    }

    // Draw the shape
    stroke(this.circleColor);
    strokeWeight(this.starThickness);
    ellipse(this.location.x,this.location.y,this.rad, this.rad);
  }
 
}
