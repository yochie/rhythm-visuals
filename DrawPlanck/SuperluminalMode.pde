/* //<>//
------------ SUPERLUMINAL MODE ------------
Creates 4 stars types depending on pressed pad
Triggers: bottom-left pad to turn background stars flow on / off
Available config:
  - bg stars: on/off, number of presses to trigger on/off, number and speed of stars
  - pad stars: number, speed and grow factor
  - all: stars stroke thickness
-------------------------------------------
*/

public class SuperluminalMode extends Mode {

  private ArrayList<Star> stars;
  //TODO - workaround for not being able to set config prop from draw loop
  private boolean bgFlow = true;

  public SuperluminalMode() {

    // TODO check how to set a bool prop
    this.defaultConfig.setProperty("BG_STARS", "1");
    this.defaultConfig.setProperty("BG_STARS_NUMBER", "4");
    this.defaultConfig.setProperty("BG_STARS_SPEED", "30");

    this.defaultConfig.setProperty("STARS1_WIDTH", "10");
    this.defaultConfig.setProperty("STARS2_WIDTH", "25");
    this.defaultConfig.setProperty("STARS3_WIDTH", "40");
    this.defaultConfig.setProperty("STARS4_WIDTH", "60");
    
    this.defaultConfig.setProperty("STARS1_SPEED", "0.95");
    this.defaultConfig.setProperty("STARS2_SPEED", "0.95");
    this.defaultConfig.setProperty("STARS3_SPEED", "0.95");
    this.defaultConfig.setProperty("STARS4_SPEED", "0.95");
    
    //TODO (play with doppler effect? Use config or random?)
    this.defaultConfig.setProperty("STARS1_COLOR", "30");
    this.defaultConfig.setProperty("STARS2_COLOR", "150");
    this.defaultConfig.setProperty("STARS3_COLOR", "200");
    this.defaultConfig.setProperty("STARS4_COLOR", "80");

    //midi controller specific, usually 255 but our Planck caps earlier
    this.defaultConfig.setProperty("MAX_VELOCITY", "100");
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
  }

  //Create stars when a sensor was pressed and keep them moving
  public void draw() {

    int starNumber;
    float starGrowFactor;
    int starSpeed;

    //create constant stars flow in background if config ON
    if(bgFlow) {
        for (int i = 0; i < this.getIntProp("BG_STARS_NUMBER"); i++) {
          stars.add(new Star(
            0, //do not grow
            this.getIntProp("BG_STARS_SPEED"),
            this.getIntProp("STAR_THICKNESS")
          ));
        }
    }

    for (int padIdx = 0; padIdx < numPads; padIdx++) {

      //create stars
      if (padWasPressed.get(padIdx)) {

        //set stars params depending on pad
        int starIdx = padIdx + 1;
        //default
        if(starIdx <= 0 || starIdx > 4) {
          starIdx = 1;
          println("Pad " + starIdx + " is not assigned - Falling to star1 config");
        }
        starNumber = this.getIntProp("STARS"+starIdx+"_NUMBER");
        starGrowFactor = this.getFloatProp("STARS"+starIdx+"_GROW_FACTOR");
        starSpeed = this.getIntProp("STARS"+starIdx+"_SPEED");

        //create as much stars as configured for this pad
        for (int i = 0; i < starNumber; i++) {
          stars.add(new Star(
            starGrowFactor,
            starSpeed,
            this.getIntProp("STAR_THICKNESS"))
          );
        }

        //Trigger stars bg flow on/off
        Pad pad = pads.get(padIdx);
        if (pad.name == "BOTTOM_LEFT_NOTE" && pressCounter.get(padIdx) >= this.getIntProp("BG_STARS_TRIGGER_PRESSES")) {
            if(bgFlow) {
              println("Background stars OFF");
              bgFlow = false;
              //TODO check why this doesn't work - workaround with var bgFlow
              //this.defaultConfig.setProperty("BG_STARS", "0");
            } else {
              println("Background stars ON");
              bgFlow = true;
              //TODO check why this doesn't work - workaround with var bgFlow
              //this.defaultConfig.setProperty("BG_STARS", "1");
            }
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
    // TODO: affect velocity changes to stars number
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
  private int circleColor = 0;

  public Star(float starGrowFactor, int speed, int starThickness) {

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
    // TODO make color change - use config or random?
    this.circleColor = (int)random(140, 190);
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
    this.circleColor = this.circleColor + 3;
      
    // Check if the star is still visible
    if (this.location.x > width+this.rad/2 || this.location.x < -this.rad/2) {
      this.visible = false;
    }
    if (this.location.y > height+this.rad/2 || this.location.y < -this.rad/2) {
      this.visible = false;
    }

    // Draw the shape
    stroke(color(this.circleColor, 255, 255));
    strokeWeight(this.starThickness);
    //fill(25);
    ellipse(this.location.x,this.location.y,this.rad, this.rad);
  }
 
}
